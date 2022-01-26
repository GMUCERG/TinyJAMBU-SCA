#!/usr/bin/env python3

# Update LWC package files

from genericpath import getmtime
from munch import Munch
import toml
from pathlib import Path
from shutil import copyfile
from os.path import getmtime

DESIGN_LWC_FOLDER = Path('src_rtl/LWC')
DESIGN_TB_FOLDER = Path('src_tb/')
src_lwc_folder = Path('../lwc/LWC')

lwc_rtl_folder = 'hardware/LWC_rtl'
lwc_tb_folder = 'hardware/LWC_tb'


def update_if_newer(lwc_copy: Path, local_copy: Path):
    if lwc_copy.exists():
        if not local_copy.exists() or getmtime(lwc_copy) > getmtime(local_copy):
            print(f"Updating {local_copy} from {lwc_copy}")
            copyfile(lwc_copy, local_copy)
        else:
            print(f"{local_copy} is up to date")


with open("./TinyJAMBU-DOM1-v1.toml") as f:
    design = Munch.fromDict(toml.load(f))
    for s in design.rtl.sources:
        local_copy = Path(s)
        if local_copy.is_relative_to(DESIGN_LWC_FOLDER):
            lwc_copy = src_lwc_folder / lwc_rtl_folder / local_copy.name
            update_if_newer(lwc_copy, local_copy)
    for s in design.tb.sources:
        local_copy = Path(s)
        if local_copy.is_relative_to(DESIGN_TB_FOLDER):
            lwc_copy = src_lwc_folder / lwc_tb_folder / local_copy.name
            update_if_newer(lwc_copy, local_copy)