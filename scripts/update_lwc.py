#!/usr/bin/env python3

# Update LWC package files

import argparse
import re
from pathlib import Path
import requests

from xeda import Design

GITHUB_URL = "https://raw.githubusercontent.com/{user}/{repo}/{branch}/{path}"

argparser = argparse.ArgumentParser()
argparser.add_argument(
    "--design_toml",
    type=argparse.FileType("r"),
    default=next(Path.cwd().glob("*.toml"), None),
    help="Design description TOML file",
)
argparser.add_argument("--lwc_folder", required=False)
argparser.add_argument(
    "--local-lwc-root", default="./src_rtl/LWC", help="Set to . to copy anyways"
)
argparser.add_argument(
    "--local-tb-root", default="./src_tb/", help="Set to . to copy anyways"
)
argparser.add_argument(
    "--only-newer",
    default=True,
    help="Update files only if the copy in lwc_folder is newer (mtime)",
)
argparser.add_argument("--git-branch", default="dev")
args = argparser.parse_args()

LWC_RTL = "hardware/LWC_rtl"
LWC_TB = "hardware/LWC_tb"


def update_from_github(file: Path, tb: bool, branch):
    github_path = (LWC_TB if tb else LWC_RTL) + "/" + file.name
    url = GITHUB_URL.format(user="GMUCERG", repo="LWC", branch=branch, path=github_path)
    r = requests.get(url)
    if r:
        d = {}
        for a in re.split(r";\s*", r.headers.get("Content-Type", "")):
            l = re.split(r"\s*=\s*", a)
            if len(l) == 2:
                d[l[0]] = l[1]
        with open(file, "w") as f:
            f.write(r.content.decode(d.get("charset", "utf-8")))
        print(f"updated {file}")
    else:
        print(f"{url} [{r.status_code}]")


design = Design.from_toml(args.design_toml)

for s in design.rtl.sources + design.tb.sources:
    update_from_github(s.file, s.file.parent.name == "src_tb" , branch=args.git_branch)
