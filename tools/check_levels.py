"""Check catalog consistency and prove uniqueness of each shipped puzzle."""

from collections import Counter
import json

from build_levels import OUTPUT, PLANETS, ROOT, generated_files
from nonogram import count_solutions, puzzle_clues


def check_levels():
    files = {path.name: path.read_text(encoding="utf-8") for path in OUTPUT.glob("*.json")}
    if files != generated_files():
        raise SystemExit("Nonogram JSON differs from pixel sources. Run tools/build_levels.py.")
    albums = Counter()
    images = set()
    for content in files.values():
        level = json.loads(content)
        albums[level["planet"]] += 1
        image = tuple(tuple(pixel != "." for pixel in row) for row in level["solution"])
        if image in images or not any(map(any, image)):
            raise SystemExit(f'{level["id"]}: empty or duplicate puzzle')
        images.add(image)
        solutions = count_solutions(*puzzle_clues(image))
        if solutions != 1:
            raise SystemExit(f'{level["id"]}: expected one solution, found {solutions}')
    if albums != dict.fromkeys(PLANETS, 20):
        raise SystemExit(f"Expected 20 levels per planet, got {dict(albums)}")
    print(f"Nonogram: {len(files)} levels, one solution each")


def main():
    check_levels()
    daily = sorted((ROOT / "data" / "daily").glob("*.json"))
    if daily:
        raise SystemExit(f"Daily: {len(daily)} puzzle files lack a uniqueness validator.")
    print("Daily: no puzzles yet")


if __name__ == "__main__":
    main()
