#!/usr/bin/env python3
"""Composes the parity frames and writes the difference report.

    python3 tool/landing_parity_diff.py [--dir doc/landing/parity]

Reads `src_<n>.png` / `rep_<n>.png`, writes `side_<n>.png` (the pair at half
scale) and `REPORT.md` with the per-frame difference table.
"""
from __future__ import annotations

import argparse
import pathlib

from PIL import Image, ImageChops

SECTIONS = [
    "hero",
    "hero → demo panel",
    "demo panel",
    "what you install + setup",
    "what the runtime handles",
    "the primitives",
    "social proof",
    "get started + footer",
]


def diff_percent(a: Image.Image, b: Image.Image) -> float:
    if a.size != b.size:
        b = b.resize(a.size)
    histogram = ImageChops.difference(a.convert("L"), b.convert("L")).histogram()
    return sum(histogram[60:]) / sum(histogram) * 100


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", default="doc/landing/parity")
    args = parser.parse_args()

    folder = pathlib.Path(args.dir)
    frames = sorted(folder.glob("src_*.png"), key=lambda p: int(p.stem.split("_")[1]))
    if not frames:
        print(f"no src_*.png in {folder}")
        return 1

    rows: list[tuple[int, str, float]] = []
    for src_path in frames:
        index = int(src_path.stem.split("_")[1])
        rep_path = folder / f"rep_{index}.png"
        if not rep_path.exists():
            continue
        src = Image.open(src_path).convert("RGB")
        rep = Image.open(rep_path).convert("RGB")

        width, height = src.size
        scale = 0.5
        tw, th = int(width * scale), int(height * scale)
        sheet = Image.new("RGB", (tw * 2 + 4, th), (255, 0, 0))
        sheet.paste(src.resize((tw, th)), (0, 0))
        sheet.paste(rep.resize((tw, th)), (tw + 4, 0))
        sheet.save(folder / f"side_{index}.png", quality=88)

        rows.append((index, SECTIONS[index] if index < len(SECTIONS) else "", diff_percent(src, rep)))

    if not rows:
        print("no matching pairs")
        return 1

    mean = sum(row[2] for row in rows) / len(rows)
    lines = [
        "## Latest run",
        "",
        "| Frame | Section | Pixels differing > 60 (0–255) |",
        "|---|---|---|",
    ]
    for index, section, percent in rows:
        lines.append(f"| {index} | {section} | {percent:.1f}% |")
    lines.append(f"| **mean** | | **{mean:.1f}%** |")
    lines.append("")

    report = folder / "REPORT.md"
    existing = report.read_text() if report.exists() else ""
    # Keep the method notes, replace the results block.
    marker = "## Latest run"
    head = existing.split(marker)[0].rstrip()
    report.write_text((head + "\n\n" if head else "") + "\n".join(lines))
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
