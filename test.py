#! /usr/bin/env python3
from pathlib import Path
import re
import sys
import logging
from xeda.flow_runner import DefaultRunner
from xeda.flows import GhdlSim
from xeda import load_design_from_toml
import toml


logger = logging.getLogger()

toml = next(Path.cwd().glob("*.toml"), None)

design = load_design_from_toml(toml)

def gen_tv():
    import cryptotvgen
    w = design.lwc.get('ports',{}).get('pdi',{}).get('bit_width', 32)
    args = [
        # '--candidates_dir', str(tvgen_cand_dir),
        '--aead', design.lwc['aead']['algorithm'],
        '--io', str(w), str(w),
        # '--message_digest_size', '256',
        '--block_size', '128',
        '--block_size_ad', '128',
        # '--dest', str(dest_dir),
        # '--max_ad', '80',
        # '--max_d', '80',
        # '--max_io_per_line', '8',
        # '--verify_lib',
    ]
    args += ['--gen_benchmark', '--with_key_reuse']
    cryptotvgen.cli.run_cryptotvgen(args, logfile=None)

"./gen_shared.py --pdi-file ./kats_for_verification/pdi.txt --sdi-file ./kats_for_verification/sdi.txt --pdi-width 32 --pdi-shares 2 --rdi-width 96"

def test_dut(args=None):
    gen_tv()
    xeda_runner = DefaultRunner()
    xeda_runner.run_flow(
        GhdlSim, design
    )

if __name__ == "__main__":
    test_dut(sys.argv)