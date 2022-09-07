#!/usr/bin/env python3

import csv
import logging
import os
import re
import sys
from copy import copy
from cryptotvgen.cli import run_cryptotvgen
from pathlib import Path
from typing import Any, Dict, List, Literal, Optional, Sequence, Union
from rich.console import Console
from rich.table import Table
from xeda import Design
from xeda.dataclass import Extra, Field, XedaBaseModel as BaseModel
from xeda.flow_runner import DefaultRunner as FlowRunner
from xeda.flows import GhdlSim
import click

SCRIPT_DIR = Path(__file__).parent.resolve()

sys.path.append(str(SCRIPT_DIR / "scripts"))

try:
    from gen_shared import run as run_gen_shared
except ImportError:
    from .scripts.gen_shared import run as run_gen_shared

# try:
#     from lwc_design import LwcDesign
# except ImportError:
#     from .scripts.lwc_design import LwcDesign

console = Console()

logger = logging.getLogger(__name__)
logger.root.setLevel(logging.INFO)


class Lwc(BaseModel):
    """design.lwc"""

    class Aead(BaseModel):
        class InputSequence(BaseModel):
            encrypt: Optional[Sequence[Literal["ad", "pt", "npub", "tag"]]] = Field(
                ["npub", "ad", "pt", "tag"],
                description="Sequence of inputs during encryption",
            )
            decrypt: Optional[Sequence[Literal["ad", "ct", "npub", "tag"]]] = Field(
                ["npub", "ad", "ct", "tag"],
                description="Sequence of inputs during decryption",
            )

        algorithm: Optional[str] = Field(
            None,
            description="Name of the implemented AEAD algorithm based on [SUPERCOP](https://bench.cr.yp.to/primitives-aead.html) convention",
            examples=["giftcofb128v1", "romulusn1v12", "gimli24v1"],
        )
        key_bits: Optional[int] = Field(description="Size of key in bits.")
        npub_bits: Optional[int] = Field(description="Size of public nonce in bits.")
        tag_bits: Optional[int] = Field(description="Size of tag in bits.")
        input_sequence: Optional[InputSequence] = Field(
            None,
            description="Order in which different input segment types should be fed to PDI.",
        )
        key_reuse: bool = False

    class Hash(BaseModel):
        algorithm: str = Field(
            description="Name of the hashing algorithm based on [SUPERCOP](https://bench.cr.yp.to/primitives-aead.html) convention. Empty string if hashing is not supported",
            examples=["", "gimli24v1"],
        )
        digest_bits: Optional[int] = Field(
            description="Size of hash digest (output) in bits."
        )

    class Ports(BaseModel):
        class Pdi(BaseModel):
            bit_width: Optional[int] = Field(
                32,
                ge=8,
                le=32,
                description="Width of each word of PDI data in bits (`w`). The width of 'pdi_data' signal would be `pdi.bit_width × pdi.num_shares` (`w × n`) bits.",
            )
            num_shares: int = Field(1, description="Number of PDI shares (`n`)")

        class Sdi(BaseModel):
            bit_width: Optional[int] = Field(
                32,
                ge=8,
                le=32,
                description="Width of each word of SDI data in bits (`sw`). The width of `sdi_data` signal would be `sdi.bit_width × sdi.num_shares` (`sw × sn`) bits.",
            )
            num_shares: int = Field(1, description="Number of SDI shares (`sn`)")

        class Rdi(BaseModel):
            bit_width: int = Field(
                0,
                ge=0,
                # le=2048,
                description="Width of the `rdi` port in bits (`rw`), 0 if the port is not used.",
            )

        pdi: Pdi = Field(description="Public Data Input port")
        sdi: Sdi = Field(description="Secret Data Input port")
        rdi: Optional[Rdi] = Field(None, description="Random Data Input port.")

    class ScaProtection(BaseModel):
        class Config:
            extra = Extra.allow

        target: Optional[Sequence[str]] = Field(
            None,
            description="Type of side-channel analysis attack(s) against which this design is assumed to be secure.",
            examples=[["spa", "dpa", "cpa", "timing"], ["dpa", "sifa", "dfia"]],
        )
        masking_schemes: Optional[Sequence[str]] = Field(
            [],
            description='Masking scheme(s) applied in this implementation. Could be name/abbreviation of established schemes (e.g., "DOM", "TI") or reference to a publication.',
            examples=[["TI"], ["DOM", "https://eprint.iacr.org/2022/000.pdf"]],
        )
        order: int = Field(
            ..., description="Claimed order of protectcion. 0 means unprotected."
        )
        notes: Optional[Sequence[str]] = Field(
            [],
            description="Additional notes or comments on the claimed SCA protection.",
        )

    aead: Optional[Aead] = Field(
        None, description="Details about the AEAD scheme and its implementation"
    )
    hash: Optional[Hash] = None
    ports: Ports = Field(description="Description of LWC ports.")
    sca_protection: Optional[ScaProtection] = Field(
        None, description="Implemented countermeasures against side-channel attacks."
    )
    block_size: Dict[str, int] = Field({"xt": 128, "ad": 128, "hm": 128})


class LwcDesign(Design):
    """A Lightweight Cryptography hardware implementations"""

    lwc: Lwc


SCRIPT_DIR = Path(__file__).parent.resolve()


def build_libs(algos: List[str], cref_dir: Union[None, str, os.PathLike, Path] = None):
    args = ["--prepare_libs"] + algos
    if cref_dir is not None:
        if not isinstance(cref_dir, Path):
            cref_dir = Path(cref_dir)
        if cref_dir.exists():
            args += ["--candidates_dir", str(cref_dir)]
    return run_cryptotvgen(args)


def gen_tv(
    lwc: Lwc,
    dest_dir: Union[str, os.PathLike],
    blocks_per_segment=None,
    bench=False,
    cref_dir=None,
):
    args = [
        "--dest",
        str(dest_dir),
        "--max_ad",
        "80",
        "--max_d",
        "80",
        "--max_io_per_line",
        "32",
        "--verify_lib",
    ]
    if cref_dir:
        args += [
            "--candidates_dir",
            str(cref_dir),
        ]
    if lwc.aead:
        assert lwc.aead.algorithm
        args += [
            "--aead",
            lwc.aead.algorithm,
        ]
        if lwc.aead.input_sequence:
            args += ["--msg_format", *lwc.aead.input_sequence]

    if lwc.hash:
        args += [
            "--hash",
            lwc.hash.algorithm,
        ]
    args += [
        "--io",
        str(lwc.ports.pdi.bit_width),
        str(lwc.ports.sdi.bit_width),
        # '--key_size', '128',
        # '--npub_size', '96',
        # '--nsec_size', '0',
        # '--message_digest_size', '256',
        # '--tag_size', '128',
        "--block_size",
        str(lwc.block_size["xt"]),
        "--block_size_ad",
        str(lwc.block_size["ad"]),
        "--block_size_msg_digest",
        str(lwc.block_size["hm"]),
    ]

    if blocks_per_segment:
        args += ["--max_block_per_sgmt", str(blocks_per_segment)]

    # gen_hash = '--gen_hash 1 20 2'.split()
    if bench:
        args += ["--gen_benchmark"]
        if lwc.aead and lwc.aead.key_reuse:
            args += ["--with_key_reuse"]
    else:
        args += ["--gen_test_combined", "1", "33", str(0)]  # 0: all random

    # TODO
    # args += gen_hash

    return run_cryptotvgen(args, logfile=None)


KATS_DIR = SCRIPT_DIR / "GMU_KAT"


@click.command()
@click.argument("toml_path")
@click.option(
    "--debug",
    is_flag=True,
    show_default=True,
    default=False,
    help="run flows in debug mode",
)
@click.option(
    "--build",
    is_flag=True,
    show_default=True,
    default=False,
    help="force build reference libraries",
)
def cli(toml_path, debug, build=False):
    """toml_path: Path to design description TOML file."""
    design = LwcDesign.from_toml(toml_path)
    lwc = design.lwc
    assert lwc.aead and lwc.aead.algorithm
    w = lwc.ports.pdi.bit_width
    sw = lwc.ports.sdi.bit_width
    pdi_shares = lwc.ports.pdi.num_shares
    sdi_shares = lwc.ports.sdi.num_shares
    tv_dir = KATS_DIR / design.name
    timing_report = Path.cwd() / (design.name + "_timing.txt")
    cref_dir = Path(toml_path).parent / "cref"
    if not cref_dir.exists():
        cref_dir = None
    if build:
        algs = []
        if lwc.aead and lwc.aead.algorithm:
            algs.append(lwc.aead.algorithm)
        if lwc.hash and lwc.hash.algorithm:
            algs.append(lwc.hash.algorithm)
        build_libs(algs, cref_dir)
    gen_tv(design.lwc, tv_dir, bench=True, cref_dir=cref_dir)
    # KATs must exist
    kat_dir = tv_dir / "timing_tests"
    pdi_txt = kat_dir / "pdi.txt"
    sdi_txt = kat_dir / "sdi.txt"
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
        pdi_txt = kat_dir / f"pdi_shared_{pdi_shares}.txt"
        sdi_txt = kat_dir / f"sdi_shared_{sdi_shares}.txt"
    design.tb.parameters = {
        **design.tb.parameters,
        "G_FNAME_PDI": {"file": pdi_txt},
        "G_FNAME_SDI": {"file": sdi_txt},
        "G_FNAME_DO": {"file": kat_dir / "do.txt"},
        "G_FNAME_TIMING": str(timing_report),
        "G_TEST_MODE": 4,
    }
    settings = {}
    if debug:
        settings["wave"] = "benchmark.ghw"
        # settings["debug"] = True
    f = FlowRunner().run_flow(GhdlSim, design, settings)
    if not f.succeeded:
        raise Exception("Ghdl flow failed")

    assert timing_report.exists()

    msg_cycles: Dict[str, int] = {}
    msg_fresh_rand: Dict[str, int] = {}
    fresh_rand_col_name = "Rand.\n[B]"
    RBPB = "Rand.\n\\[b/B]"
    with open(timing_report) as f:
        for l in f.readlines():
            kv = re.split(r"\s*,\s*", l.strip())
            if len(kv) >= 2:
                msg_cycles[kv[0]] = int(kv[1])
            if len(kv) >= 3:
                msg_fresh_rand[kv[0]] = int(kv[2], 16)
    results: List[dict[str, Union[int, float, str]]] = []
    with open(kat_dir / "timing_tests.csv") as f:
        rows: List[Dict[Any, Any]] = list(csv.DictReader(f))
        for row in rows:
            msgid = row["msgId"]
            assert isinstance(msgid, str)
            row["Cycles"] = msg_cycles[msgid]
            row[fresh_rand_col_name] = msg_fresh_rand[msgid]
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
            if fresh_rand_col_name in row:
                row[RBPB] = round(row[fresh_rand_col_name] / total_bytes, 3)
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
                long_row["msgId"] = prev_id + ":" + msgid
                long_row["Throughput"] = round((ad_diff + msg_diff) / cycle_diff, 3)
                if msgid in msg_fresh_rand:
                    rnd_diff = msg_fresh_rand[msgid] - msg_fresh_rand[prev_id]
                    long_row[fresh_rand_col_name] = rnd_diff
                    long_row[RBPB] = round(rnd_diff / (ad_diff + msg_diff), 3)
                results.append(long_row)
    results_file = design.name + "_timing_results.csv"
    fieldnames = [
        "Op",
        "Reuse Key",
        "msgBytes",
        "adBytes",
        "Cycles",
        "Throughput",
        fresh_rand_col_name,
        RBPB,
    ]

    def sorter(x):
        k = [99999 if x[f] == "long" else x[f] for f in fieldnames]
        k.insert(2, 0 if x["msgBytes"] == 0 else 1 if x["adBytes"] == 0 else 2)
        k[0] = ["Enc", "Dec", "Hash"].index(str(k[0]))
        return k

    results = sorted(results, key=sorter)
    with open(results_file, "w") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=fieldnames,
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(results)
    table = Table()

    def tr(f):
        tr_map = {
            "Throughput": "Throughput\n[B/cycle]",
            "msgBytes": "PT/CT\n[B",
            "adBytes": "AD\n[B]",
        }
        return tr_map.get(f, f)

    for f in fieldnames:
        table.add_column(tr(f), justify="right")
    for row in results:
        row["Reuse Key"] = "✓" if row["Reuse Key"] else ""
        table.add_row(
            *(str(row[fn]) for fn in fieldnames),
            end_section=row["adBytes"] == "long" and row["msgBytes"] == "long",
        )
    console.print(table)
    logger.info("Timing results written to %s", results_file)


if __name__ == "__main__":
    cli()
