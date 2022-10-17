#!/usr/bin/env python3
# requires  Python 3.6+

import argparse
import toml
import json
from pathlib import Path

arg_parser = argparse.ArgumentParser()
arg_parser.add_argument(
    "design_toml", type=argparse.FileType("r"), help="Design description file"
)
arg = arg_parser.parse_args()

xeda_design = toml.load(arg.design_toml)

sigasi_lib_map = {
    "version": "0.1",
    "mappings": [{"library": "work", "files": []}],
    "excludedFiles": [""],
}

sigasi_lib_map["mappings"][0]["files"].extend(xeda_design["rtl"]["sources"])
sigasi_lib_map["mappings"][0]["files"].extend(
    xeda_design.get("tb", {}).get("sources", [])
)

with open("library_mapping.json", "w") as f:
    json.dump(sigasi_lib_map, f, indent=2)
