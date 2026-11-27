"""Build the game catalog from the original text pixel art."""

import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "art" / "levels_src"
OUTPUT = ROOT / "data" / "levels"
BONUS_OUTPUT = OUTPUT / "bonus"
BONUS_PALETTE = {"a": "#8de5e5", "b": "#9d9af4", "c": "#ffdf8e", "d": "#fba1bd"}
MANIFEST = ROOT / "data" / "config" / "planets.json"
LEGACY_PLANETS = ("moon", "mars", "saturn")
TWIST_ORDER = ("revealed", "asteroid", "star", "shield", "comet", "perfect")
TWIST_INTERVAL = 12
PLANETS = {
    entry["id"]: entry
    for entry in json.loads(MANIFEST.read_text(encoding="utf-8"))
}


def read_source(source, palette, fixed_size=None):
    for index, block in enumerate(source.read_text(encoding="utf-8").strip().split("\n\n"), 1):
        header, *rows = block.strip().splitlines()
        slug, title_en, title_id, *motifs = header.split("|")
        if not re.fullmatch(r"[a-z0-9-]+", slug) or not title_en or not title_id:
            raise ValueError(f"{source.name}: invalid header {header!r}")
        if fixed_size is None:
            if len(motifs) != 1 or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", motifs[0]):
                raise ValueError(f"{source.name}: {slug} needs one motif ID")
        elif motifs:
            raise ValueError(f"{source.name}: {slug} has an unexpected motif ID")
        size = len(rows)
        if not size or (fixed_size is not None and size != fixed_size) or any(len(row) != size for row in rows):
            raise ValueError(f"{source.name}: {slug} must be a {fixed_size or size}x{fixed_size or size} grid")
        if set("".join(rows)) - set(palette) - {"."}:
            raise ValueError(f"{source.name}: unknown palette symbol in {slug}")
        level = {
            "id": f"{source.stem}-{index:02d}-{slug}",
            "size": size,
            "solution": rows,
            "palette": palette,
            "planet": source.stem,
            "title": {"en": title_en, "id": title_id},
        }
        if motifs:
            level["motif"] = motifs[0]
        yield level


def level_twist(level, index):
    """Choose one rule per twelve newer levels in the album order."""
    kind = TWIST_ORDER[index // TWIST_INTERVAL % len(TWIST_ORDER)]
    twist = {"kind": kind}
    rows = level["solution"]
    size = level["size"]
    if kind in ("revealed", "asteroid", "star"):
        count = 1 if kind == "star" else 3
        # Skip lines that the ordinary board automatically crosses on entry.
        used_rows = [bool(row.strip(".")) for row in rows]
        used_cols = [any(pixel != "." for pixel in col) for col in zip(*rows)]
        pool = [
            y * size + x
            for y, row in enumerate(rows)
            for x, pixel in enumerate(row)
            if used_rows[y] and used_cols[x] and (pixel == ".") == (kind == "asteroid")
        ]
        if len(pool) <= count:
            raise ValueError(f'{level["id"]}: too few eligible {kind} cells')
        cells = [pool[len(pool) * (i + 1) // (count + 1)] for i in range(count)]
        if kind == "star":
            twist["cell"] = cells[0]
        else:
            twist["cells"] = cells
    elif kind == "comet":
        twist["seconds"] = 7 * size
    return twist


def generated_files():
    levels = (
        level
        for planet, entry in PLANETS.items()
        for level in read_source(
            SOURCES / f"{planet}.txt", entry["palette"],
            entry["size"] if planet in LEGACY_PLANETS else None,
        )
    )
    files = {}
    twist_index = 0
    for level in levels:
        if level["planet"] not in LEGACY_PLANETS:
            level["twist"] = level_twist(level, twist_index)
            twist_index += 1
        files[level["id"] + ".json"] = json.dumps(level, ensure_ascii=False, indent=2) + "\n"
    return files


def generated_bonus_files():
    return {
        level["id"] + ".json": json.dumps(level, ensure_ascii=False, indent=2) + "\n"
        for level in read_source(SOURCES / "bonus.txt", BONUS_PALETTE, 5)
    }


def main():
    for filename, content in generated_files().items():
        (OUTPUT / filename).write_text(content, encoding="utf-8")
    BONUS_OUTPUT.mkdir(exist_ok=True)
    for filename, content in generated_bonus_files().items():
        (BONUS_OUTPUT / filename).write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
