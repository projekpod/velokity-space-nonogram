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


def generated_files():
    return {
        level["id"] + ".json": json.dumps(level, ensure_ascii=False, indent=2) + "\n"
        for planet, entry in PLANETS.items()
        for level in read_source(
            SOURCES / f"{planet}.txt", entry["palette"],
            entry["size"] if planet in LEGACY_PLANETS else None,
        )
    }


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
