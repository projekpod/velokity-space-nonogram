"""Check catalog consistency and prove uniqueness of each shipped puzzle."""

from collections import Counter
import json
from math import log2
from statistics import median

from build_daily import BANDS, COUNTS, SIZES, OUTPUT as DAILY_OUTPUT
from build_levels import BONUS_OUTPUT, OUTPUT, PLANETS, generated_bonus_files, generated_files
from nonogram import count_solutions, line_patterns, puzzle_clues
from star_battle import canonical_grid, solve, valid_solution, validate_regions


def check_levels():
    files = {path.name: path.read_text(encoding="utf-8") for path in OUTPUT.glob("*.json")}
    if files != generated_files():
        raise SystemExit("Nonogram JSON differs from pixel sources. Run tools/build_levels.py.")
    albums = Counter()
    clue_scores = {planet: [] for planet in PLANETS}
    images = set()
    for content in files.values():
        level = json.loads(content)
        albums[level["planet"]] += 1
        image = tuple(tuple(pixel != "." for pixel in row) for row in level["solution"])
        if image in images or not any(map(any, image)):
            raise SystemExit(f'{level["id"]}: empty or duplicate puzzle')
        images.add(image)
        clues = puzzle_clues(image)
        solutions = count_solutions(*clues)
        # More plausible line fillings are typically harder to rule out.
        clue_scores[level["planet"]].append(sum(
            log2(len(line_patterns(level["size"], line))) for axis in clues for line in axis
        ))
        if solutions != 1:
            raise SystemExit(f'{level["id"]}: expected one solution, found {solutions}')
    if albums != dict.fromkeys(PLANETS, 20):
        raise SystemExit(f"Expected 20 levels per planet, got {dict(albums)}")
    sizes = [size for size, _ in PLANETS.values()]
    if sizes != sorted(sizes) or any(b - a > 1 for a, b in zip(sizes[2:], sizes[3:])):
        raise SystemExit("Board sizes must rise gradually after Saturn")
    scores = [median(clue_scores[planet]) for planet in PLANETS]
    if scores != sorted(scores):
        raise SystemExit("Album median clue ambiguity must rise with progression")
    print(f"Nonogram: {len(files)} levels, one solution each")
    return images


def check_bonus(main_images):
    files = {path.name: path.read_text(encoding="utf-8") for path in BONUS_OUTPUT.glob("*.json")}
    if len(files) < 12 or len(files) % 3 or files != generated_bonus_files():
        raise SystemExit("Bonus JSON must match the pixel sources in sets of three, with at least 12 puzzles")
    seen = {canonical_grid(image) for image in main_images if len(image) == 5}
    for content in files.values():
        level = json.loads(content)
        image = tuple(tuple(pixel != "." for pixel in row) for row in level["solution"])
        signature = canonical_grid(image)
        if signature in seen or not any(map(any, image)):
            raise SystemExit(f'{level["id"]}: empty or duplicate bonus puzzle')
        seen.add(signature)
        solutions = count_solutions(*puzzle_clues(image))
        if solutions != 1:
            raise SystemExit(f'{level["id"]}: expected one solution, found {solutions}')
    print(f"Bonus Round: {len(files)} separate 5x5 levels, one solution each")


def check_daily():
    expected = {
        f"daily-{tier}-{index:02d}.json": tier
        for tier, count in enumerate(COUNTS, 1)
        for index in range(1, count + 1)
    }
    paths = list(DAILY_OUTPUT.rglob("*.json"))
    files = {path.name: path for path in paths}
    if len(paths) != len(expected) or set(files) != set(expected) or any(path.parent != DAILY_OUTPUT for path in paths):
        raise SystemExit("Daily catalog filenames do not match the weekday rotation")
    seen = set()
    for name, tier in expected.items():
        try:
            puzzle = json.loads(files[name].read_text(encoding="utf-8"))
            regions = puzzle["regions"]
            columns = puzzle["solution"]
            validate_regions(regions)
            if not (puzzle["difficulty"] == tier and len(regions) == puzzle["size"] == SIZES[tier - 1]):
                raise ValueError("Unexpected size or difficulty tier")
            if not valid_solution(regions, columns):
                raise ValueError("Invalid stored solution")
            signature = canonical_grid(regions)
            if signature in seen:
                raise ValueError("Duplicate region layout")
            seen.add(signature)
            paths, effort = solve(regions)
            if paths != [tuple(columns)]:
                raise ValueError("Expected exactly one solution matching the stored solution")
            lower, upper = BANDS[tier - 1]
            if puzzle["effort"] != effort or not lower <= effort <= upper:
                raise ValueError("Search effort is outside the weekday band")
        except (KeyError, TypeError, ValueError) as error:
            raise SystemExit(f"{name}: {error}") from error
    print(f"Rasi Bintang: {len(files)} puzzles, one solution each, seven increasing difficulty bands")


def main():
    check_bonus(check_levels())
    check_daily()


if __name__ == "__main__":
    main()
