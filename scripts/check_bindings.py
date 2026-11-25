#!/usr/bin/env python3
"""Cross-check form data sources against the form class properties.

4D resolves `Form.<name>` bindings lazily: a typo in a `dataSource` does not
fail `FORM LOAD`, it fails when the widget is drawn. This script parses the
class's `property` declarations and reports any binding that has no matching
property, plus properties that no widget uses (usually dead state).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

PROPERTY = re.compile(r"^property\s+(\w+)\s*(?::\s*([\w.]+))?\s*$", re.M)
FORM_REF = re.compile(r"^Form\.(\w+)")


def collect_refs(node: object, refs: set[str]) -> None:
    if isinstance(node, dict):
        for key, value in node.items():
            if key in {"dataSource", "currentItemSource", "dataSourceFormula"} and isinstance(value, str):
                match = FORM_REF.match(value)
                if match:
                    refs.add(match.group(1))
            collect_refs(value, refs)
    elif isinstance(node, list):
        for item in node:
            collect_refs(item, refs)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--class", dest="class_file", type=Path, required=True)
    parser.add_argument("--form", dest="form_file", type=Path, required=True)
    args = parser.parse_args()

    source = args.class_file.read_text(encoding="utf-8")
    props = {name: (kind or "Variant") for name, kind in PROPERTY.findall(source)}

    refs: set[str] = set()
    collect_refs(json.loads(args.form_file.read_text(encoding="utf-8")), refs)

    missing = sorted(refs - set(props))
    # Functions are also referenced as Form.<fn>() in object methods, not in
    # the form JSON, so an unused property is only informative.
    unused = sorted(set(props) - refs)

    for name in missing:
        print(f"binding: Form.{name} has no matching property in {args.class_file.name}")
    if unused:
        print("binding: properties with no form widget: " + ", ".join(unused))
    if missing:
        print(f"{len(missing)} broken binding(s)", file=sys.stderr)
        return 1
    print(f"bindings OK: {len(refs)} widget reference(s), {len(props)} propert(ies)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
