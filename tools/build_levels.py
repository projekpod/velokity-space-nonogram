"""Build the game catalog from the original text pixel art."""

import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "art" / "levels_src"
OUTPUT = ROOT / "data" / "levels"
BONUS_OUTPUT = OUTPUT / "bonus"
BONUS_PALETTE = {"a": "#8de5e5", "b": "#9d9af4", "c": "#ffdf8e", "d": "#fba1bd"}
PLANETS = {
    "moon": (5, {"a": "#75e4df", "b": "#6596ef", "c": "#fff1a8", "d": "#f58eaa"}),
    "mars": (8, {"a": "#ff9c7a", "b": "#ffd275", "c": "#bd6cef", "d": "#fff3dd"}),
    "saturn": (10, {"a": "#ffd27b", "b": "#b492fa", "c": "#79e3d5", "d": "#fff1e2"}),
}


def read_source(source, size, palette):
    for index, block in enumerate(source.read_text(encoding="utf-8").strip().split("\n\n"), 1):
        header, *rows = block.strip().splitlines()
        slug, title_en, title_id = header.split("|")
        if not re.fullmatch(r"[a-z0-9-]+", slug) or not title_en or not title_id:
            raise ValueError(f"{source.name}: invalid header {header!r}")
        if len(rows) != size or any(len(row) != size for row in rows):
            raise ValueError(f"{source.name}: {slug} must be {size}x{size}")
        if set("".join(rows)) - set(palette) - {"."}:
            raise ValueError(f"{source.name}: unknown palette symbol in {slug}")
        yield {
            "id": f"{source.stem}-{index:02d}-{slug}",
            "size": size,
            "solution": rows,
            "palette": palette,
            "planet": source.stem,
            "title": {"en": title_en, "id": title_id},
        }


def generated_files():
    return {
        level["id"] + ".json": json.dumps(level, ensure_ascii=False, indent=2) + "\n"
        for planet in PLANETS
        for level in read_source(SOURCES / f"{planet}.txt", *PLANETS[planet])
    }


def generated_bonus_files():
    return {
        level["id"] + ".json": json.dumps(level, ensure_ascii=False, indent=2) + "\n"
        for level in read_source(SOURCES / "bonus.txt", 5, BONUS_PALETTE)
    }


def main():
    for filename, content in generated_files().items():
        (OUTPUT / filename).write_text(content, encoding="utf-8")
    BONUS_OUTPUT.mkdir(exist_ok=True)
    for filename, content in generated_bonus_files().items():
        (BONUS_OUTPUT / filename).write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
