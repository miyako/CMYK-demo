#!/usr/bin/env python3
"""Geometry audit for the Lab form.

The form is a hand-written .4DForm, so nothing prevents a control from
overlapping a neighbour or spilling outside the fixed window. This script
flattens the object list, checks every rectangle against the window and the
group boxes, and reports unintended overlaps. It is a cheap substitute for
eyeballing a rendered PNG and works on CI.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

CONTAINERS = {"groupBox", "rectangle"}


def rect(name: str, obj: dict) -> tuple[int, int, int, int]:
    return (obj["left"], obj["top"], obj["width"], obj["height"])


def right_bottom(r: tuple[int, int, int, int]) -> tuple[int, int]:
    return (r[0] + r[2], r[1] + r[3])


def intersects(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> bool:
    return (
        a[0] < b[0] + b[2]
        and b[0] < a[0] + a[2]
        and a[1] < b[1] + b[3]
        and b[1] < a[1] + a[3]
    )


def contains(outer: tuple[int, int, int, int], inner: tuple[int, int, int, int]) -> bool:
    return (
        outer[0] <= inner[0]
        and outer[1] <= inner[1]
        and right_bottom(inner)[0] <= right_bottom(outer)[0]
        and right_bottom(inner)[1] <= right_bottom(outer)[1]
    )


def audit(form_path: Path) -> list[str]:
    doc = json.loads(form_path.read_text(encoding="utf-8"))
    width = doc.get("windowMinWidth") or 0
    height = doc.get("windowMinHeight") or 0
    objects: dict[str, dict] = {}
    for page in doc["pages"]:
        objects.update(page.get("objects", {}))

    problems: list[str] = []
    if width <= 0 or height <= 0:
        problems.append("windowMinimumWidth/Height missing; cannot audit bounds")

    leaves = {n: o for n, o in objects.items() if o.get("type") not in CONTAINERS}
    boxes = {n: o for n, o in objects.items() if o.get("type") in CONTAINERS}

    for name, obj in objects.items():
        r = rect(name, obj)
        if r[2] <= 0 or r[3] <= 0:
            problems.append(f"{name}: empty or negative size {r[2]}x{r[3]}")
        if width and height:
            if r[0] < 0 or r[1] < 0:
                problems.append(f"{name}: negative origin {r[0]},{r[1]}")
            if right_bottom(r)[0] > width or right_bottom(r)[1] > height:
                problems.append(
                    f"{name}: spills past {width}x{height} -> right {right_bottom(r)[0]}, bottom {right_bottom(r)[1]}"
                )

    # A leaf may sit inside exactly one group box (many are placed inside a
    # group; some, like the title, are not in any group at all).
    for name, obj in leaves.items():
        owners = [
            g for g, box in boxes.items()
            if box.get("type") == "groupBox" and contains(rect(g, box), rect(name, obj))
        ]
        if len(owners) > 1:
            problems.append(f"{name}: inside multiple group boxes {owners}")

    # Overlaps between leaves are always a layout bug.
    names = sorted(leaves)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if intersects(rect(a, leaves[a]), rect(b, leaves[b])):
                problems.append(f"{a} overlaps {b}")

    # Group boxes must not overlap each other either.
    gnames = sorted(boxes)
    for i, a in enumerate(gnames):
        for b in gnames[i + 1:]:
            ra, rb = rect(a, boxes[a]), rect(b, boxes[b])
            if boxes[a].get("type") == "rectangle" or boxes[b].get("type") == "rectangle":
                continue  # the backdrop rectangle is meant to cover the form
            if intersects(ra, rb):
                problems.append(f"group {a} overlaps group {b}")

    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "form",
        nargs="?",
        type=Path,
        default=Path("Project/Sources/Forms/Lab/form.4DForm"),
    )
    args = parser.parse_args()

    problems = audit(args.form)
    for problem in problems:
        print(f"layout: {problem}")
    if problems:
        print(f"{len(problems)} layout problem(s)", file=sys.stderr)
        return 1
    print(f"layout OK: {args.form}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
