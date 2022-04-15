#!/usr/bin/env python3
# requires  Python 3.8+
# requires xeda>=0.1.0.a10


"LWC script"

import argparse
import csv
import logging
import re
import sys
from copy import copy
from pathlib import Path
from typing import Any, Dict, List, Union

import cryptotvgen
from rich.console import Console
from rich.table import Table
from xeda.flow_runner import DefaultRunner
from xeda.flows import GhdlSim

SCRIPT_DIR = Path(__file__).parent.resolve()

sys.path.append(str(SCRIPT_DIR / "scripts"))

from gen_shared import run as run_gen_shared

try:
    from lwc_design import LwcDesign
except ImportError:
    from .scripts.lwc_design import LwcDesign

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
console = Console()

CREF_DIR = SCRIPT_DIR / "cref"

KAT_FOLDER = Path("BENCH_KAT")


RBPB = "rand b/B"


def parse_timing_report(timing_report, timing_tests_desc: List[Dict[Any, Any]], RW):
    """extract timing results in timing_report using meta-data in timing_tests_desc"""
    assert timing_report.exists()

    msg_cycles: Dict[str, int] = {}
    rdi_words: Dict[str, int] = {}
    with open(timing_report) as f:
        for l in f.readlines():
            kv = re.split(r"\s*,\s*", l.strip())
            if len(kv) >= 2:
                msg_cycles[kv[0]] = int(kv[1])
            if RW and len(kv) >= 3:
                rdi_words[kv[0]] = RW * int(kv[2])
    results: List[dict[str, Union[int, float, str]]] = []
    for row in timing_tests_desc:
        msgid = row["msgId"]
        assert isinstance(msgid, str)
        row["Cycles"] = msg_cycles[msgid]
        if msgid in rdi_words:
            row["Random"] = rdi_words[msgid]
        if row["hash"] == "True":
            row["Op"] = "Hash"
        else:
            row["Op"] = "Dec" if row["decrypt"] == "True" else "Enc"
            # if row["newKey"] == "False":
            #     row["Op"] += ":reuse-key"
        row["Reuse Key"] = (
            True if row["newKey"] == "False" and row["Op"] != "Hash" else False
        )
        row["adBytes"] = int(row["adBytes"])
        row["msgBytes"] = int(row["msgBytes"])
        total_bytes = row["adBytes"] + row["msgBytes"]
        row["Throughput"] = round(total_bytes / msg_cycles[msgid], 3)
        if "Random" in row:
            row[RBPB] = round(row["Random"] / total_bytes, 3)
        results.append(row)
        if row["longN+1"] == "True":
            long_row = copy(results[-2])
            # just to silence the type checker:
            assert isinstance(long_row, dict)
            prev_id: str = str(long_row["msgId"])
            prev_ad = int(long_row["adBytes"])
            prev_msg = int(long_row["msgBytes"])
            ad_diff = int(row["adBytes"]) - prev_ad
            msg_diff = int(row["msgBytes"]) - prev_msg
            cycle_diff = msg_cycles[msgid] - msg_cycles[prev_id]
            long_row["adBytes"] = "long" if int(row["adBytes"]) else 0
            long_row["msgBytes"] = "long" if int(row["msgBytes"]) else 0
            long_row["Cycles"] = cycle_diff
            if msgid in rdi_words:
                rdi_diff = rdi_words[msgid] - rdi_words[prev_id]
                long_row["Random"] = rdi_diff
                long_row[RBPB] = round(rdi_diff / (ad_diff + msg_diff), 3)
            long_row["msgId"] = prev_id + ":" + msgid
            long_row["Throughput"] = round((ad_diff + msg_diff) / cycle_diff, 3)
            results.append(long_row)

    def sort_order(x):
        return [
            ["Enc", "Dec", "Hash"].index(x["Op"]),  # 1: order of operations
            x["Reuse Key"],  # 2: key reuse (if supported and Enc/Dec)
            0
            if x["adBytes"] == 0
            else 1
            if x["msgBytes"] == 0
            else 2,  # 3: PT/CT, AD, AD+PT/CT
            *[
                99999 if x[f] == "long" else x[f] for f in ("msgBytes", "adBytes")
            ],  # 4: PT/CT or AD size, "long" goes last
        ]

    return sorted(results, key=sort_order)


def run(args=None):
    """main entry"""
    if not args:
        args = sys.argv[1:]
    parser = argparse.ArgumentParser(description="LWC Benchmarking")

    parser.add_argument(
        "--design-toml",
        default="TinyJAMBU-DOM1-v1.toml",
        type=Path,
        help="variant description file",
    )
    parser.add_argument(
        "--cref-dir",
        default=None,
        type=Path,
        help="Path to directory containing the C reference implementation",
    )
    parser.add_argument(
        "--skip-sim",
        default=False,
        action="store_true",
        help="Don't actually run the simulation. Use previously generated report files.",
    )
    parsed_args = parser.parse_args(args)
    design = LwcDesign.from_toml(parsed_args.design_toml)
    bench = True

    lwc = design.lwc
    assert lwc.aead and lwc.aead.algorithm
    w = lwc.ports.pdi.bit_width
    sw = lwc.ports.sdi.bit_width
    args = [
        "--aead",
        lwc.aead.algorithm,
        "--io",
        str(w),
        str(sw),
        "--verify_lib",
        "--dest",
        str(KAT_FOLDER),
    ]

    if parsed_args.cref_dir:
        args += [
            "--candidates_dir",
            str(parsed_args.cref_dir),
        ]

    args += [
        "--block_size",
        str(lwc.block_size["xt"]),
        "--block_size_ad",
        str(lwc.block_size["ad"]),
        "--block_size_msg_digest",
        str(lwc.block_size["hm"]),
    ]

    if bench:
        args += ["--gen_benchmark"]
        if lwc.aead and lwc.aead.key_reuse:
            args += ["--with_key_reuse"]
    else:
        # '--gen_hash', '1', '20', '2' ?
        args += ["--gen_test_combined", "1", "33", str(0)]  # 0: all random

    KAT_FOLDER.mkdir(exist_ok=True, parents=True)
    cryptotvgen.cli.run_cryptotvgen(args, logfile=None)

    pdi_shares = lwc.ports.pdi.num_shares
    sdi_shares = lwc.ports.sdi.num_shares

    timing_report = Path.cwd() / (design.name + "_timing.txt")

    for kat_folder, testmode in [
        # (KAT_FOLDER / "kats_for_verification", 1),
        (KAT_FOLDER / "timing_tests", 4),
    ]:
        pdi_txt = kat_folder / "pdi.txt"
        sdi_txt = kat_folder / "sdi.txt"
        if pdi_shares > 1 or sdi_shares > 1:
            gs_args = [
                "--pdi-file",
                str(pdi_txt),
                "--sdi-file",
                str(sdi_txt),
                "--pdi-width",
                str(w),
                "--sdi-width",
                str(sw),
                "--pdi-shares",
                str(pdi_shares),
                "--sdi-shares",
                str(sdi_shares),
            ]
            if lwc.ports.rdi:
                gs_args += [
                    "--rdi-width",
                    str(lwc.ports.rdi.bit_width),
                ]
            run_gen_shared(gs_args)
            pdi_txt = kat_folder / f"pdi_shared_{pdi_shares}.txt"
            sdi_txt = kat_folder / f"sdi_shared_{sdi_shares}.txt"

        design.tb.parameters = {
            **design.tb.parameters,
            "G_FNAME_PDI": {"file": pdi_txt},
            "G_FNAME_SDI": {"file": sdi_txt},
            "G_FNAME_DO": {"file": kat_folder / "do.txt"},
            "G_FNAME_TIMING": str(timing_report),
            "G_TEST_MODE": testmode,
            "G_RANDOM_STALL": True,  # only effective in testmode == 1
            "G_PRNG_RDI": True,
            "G_MAX_FAILURES": 0,
            "G_TIMEOUT_CYCLES": 1000,
        }

        if not parsed_args.skip_sim:
            runner = DefaultRunner()
            f = runner.run_flow(GhdlSim, design)
            assert f.succeeded
        if testmode == 4:
            with open(kat_folder / "timing_tests.csv", encoding="utf-8") as f:
                timing_tests_desc = list(csv.DictReader(f))

            results = parse_timing_report(
                timing_report,
                timing_tests_desc,
                lwc.ports.rdi and lwc.ports.rdi.bit_width,
            )
            results_file = design.name + "_timing_results.csv"
            fieldnames = [
                "Op",
                "Reuse Key",
                "msgBytes",
                "adBytes",
                "Cycles",
                "Throughput",
                "Random",
                RBPB,
            ]
            with open(results_file, "w") as f:
                writer = csv.DictWriter(
                    f,
                    fieldnames=fieldnames,
                    extrasaction="ignore",
                )
                writer.writeheader()
                writer.writerows(results)
            table = Table(*fieldnames)
            for row in results:
                row["Reuse Key"] = "✓" if row["Reuse Key"] else ""
                table.add_row(
                    *(str(row[fn]) for fn in fieldnames),
                    end_section=row["adBytes"] == "long" and row["msgBytes"] == "long",
                )
            console.print(table)
            logger.info("Timing results written to %s", results_file)


if __name__ == "__main__":
    run()
