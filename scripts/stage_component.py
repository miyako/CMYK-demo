#!/usr/bin/env python3
"""Stage the pinned CMYK component for tool4d and offline runs.

`Project/Sources/dependencies.json` is what the full 4D IDE reads: it fetches
miyako/CMYK at the pinned tag and installs it into `Components/`. tool4d does
not run the Dependency Manager (`PackageManager No component ...` on every
launch is expected), so this script puts the exact same released component in
`Components/CMYK.4dbase` by hand.

The download is pinned by tag *and* SHA256; a mismatch is fatal. The archive's
`CMYK.4dbase` directory becomes `Components/CMYK.4dbase` verbatim.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

TAG = "0.1.2"
ASSET = "CMYK.zip"
SHA256 = "4570f79a3121dd7b49452d7fdb57ddd14855262ae0db6a10d1e8237809909fdb"
URL = f"https://github.com/miyako/CMYK/releases/download/{TAG}/{ASSET}"


def download(url: str, target: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "CMYK-demo"})
    with urllib.request.urlopen(request, timeout=60) as response, target.open("wb") as out:
        shutil.copyfileobj(response, out)


def find_component_member(names: list[str]) -> str:
    for name in names:
        parts = Path(name).parts
        if parts and parts[0] == "CMYK.4dbase":
            return "CMYK.4dbase"
    raise SystemExit(f"{ASSET} does not contain a CMYK.4dbase root")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--force", action="store_true", help="replace an existing Components/CMYK.4dbase")
    args = parser.parse_args()

    root = args.root.resolve()
    destination = root / "Components" / "CMYK.4dbase"
    if destination.exists() and not args.force:
        print(f"already staged: {destination}")
        return 0

    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / ASSET
        print(f"download {URL}")
        download(URL, archive)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if digest != SHA256:
            print(f"SHA256 mismatch: {digest} != {SHA256}", file=sys.stderr)
            return 1
        extracted = Path(tmp) / "unpacked"
        with zipfile.ZipFile(archive) as zf:
            member = find_component_member(zf.namelist())
            # zipfile.extractall drops Unix modes; the component's native
            # executables must stay executable or SystemWorker cannot launch.
            for info in zf.infolist():
                zf.extract(info, extracted)
                mode = (info.external_attr >> 16) & 0o777
                if mode & 0o111:
                    (extracted / info.filename).chmod(mode)
        if destination.exists():
            shutil.rmtree(destination)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(extracted / member, destination)

    marker = destination / "Libraries"
    if not marker.is_dir():
        print(f"staged component has no Libraries folder: {destination}", file=sys.stderr)
        return 1
    print(f"staged {destination} ({TAG}, sha256 {SHA256[:12]}...)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
