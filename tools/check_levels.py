"""Check catalog consistency and prove uniqueness of each shipped puzzle."""

from collections import defaultdict
from itertools import groupby, permutations
import json
from math import log2
import re
from statistics import median

from build_daily import BANDS, COUNTS, SIZES, OUTPUT as DAILY_OUTPUT
from build_levels import BONUS_OUTPUT, LEGACY_PLANETS, OUTPUT, PLANETS, generated_bonus_files, generated_files
from nonogram import count_solutions, line_patterns, puzzle_clues
from star_battle import canonical_grid, solve, valid_solution, validate_regions

LEGACY_MOTIFS = {
    "eclipse": "solar-eclipse",
    "mars-rover": "rover",
    "red-helmet": "helmet",
    "ring-helmet": "helmet",
}
PICTURE_SAMPLE_SIZE = 16


def check_canvas(level_id, rows):
    size = len(rows)
    used_rows = [y for y, row in enumerate(rows) if any(pixel != "." for pixel in row)]
    used_cols = [x for x, col in enumerate(zip(*rows)) if any(pixel != "." for pixel in col)]
    if not used_rows or len(used_rows) < size - 1 or len(used_cols) < size - 1:
        raise SystemExit(f"{level_id}: at most one empty row and one empty column are allowed")
    area = (used_rows[-1] - used_rows[0] + 1) * (used_cols[-1] - used_cols[0] + 1)
    if 5 * area < 4 * size * size:
        raise SystemExit(f"{level_id}: picture bounds must cover at least 80% of the board")


def sample_picture(rows):
    """Compare pictures at a common resolution, including transparent space."""
    size = len(rows)
    indices = [(2 * i + 1) * size // (2 * PICTURE_SAMPLE_SIZE) for i in range(PICTURE_SAMPLE_SIZE)]
    return tuple("".join(rows[y][x] for x in indices) for y in indices)


def picture_signature(rows):
    """Find literal art reuse even after cropping the borders or swapping colors."""
    filled_rows = [y for y, row in enumerate(rows) if row.strip(".")]
    filled_cols = [x for x, col in enumerate(zip(*rows)) if any(pixel != "." for pixel in col)]
    grid = tuple(row[filled_cols[0]:filled_cols[-1] + 1] for row in rows[filled_rows[0]:filled_rows[-1] + 1])
    variants = []
    for _ in range(4):
        for view in (grid, tuple(row[::-1] for row in grid)):
            symbols = {".": 0}
            variants.append(tuple(tuple(symbols.setdefault(pixel, len(symbols)) for pixel in row) for row in view))
        grid = tuple(zip(*grid[::-1]))
    return min(variants)


def check_pictures(levels):
    motifs = defaultdict(list)
    pictures = {}
    for level in levels:
        level_id, planet, rows = level["id"], level["planet"], level["solution"]
        legacy = planet in LEGACY_PLANETS
        if legacy:
            title_slug = re.sub(r"[^a-z0-9]+", "-", level["title"]["en"].lower()).strip("-")
            motif = LEGACY_MOTIFS.get(title_slug, title_slug)
        else:
            check_canvas(level_id, rows)
            motif = level["motif"]
        signature = picture_signature(rows)
        if signature in pictures and (not legacy or pictures[signature]["planet"] not in LEGACY_PLANETS):
            raise SystemExit(f'{level_id}: repeats the picture from {pictures[signature]["id"]}')
        pictures[signature] = level
        motifs[motif].append(level)

    for motif, matches in motifs.items():
        if all(level["planet"] in LEGACY_PLANETS for level in matches):
            continue
        if len({level["planet"] for level in matches}) != len(matches):
            raise SystemExit(f"{motif}: picture motif repeats within a planet")
        if len(matches) > 2:
            raise SystemExit(f"{motif}: picture motif appears more than twice in the catalog")
        if len(matches) == 2:
            first, second = matches
            # A two-cell size change or a visible change to at least 12% of the
            # sampled picture makes a variant distinct. Ignore palette swaps.
            a = "".join(sample_picture(first["solution"]))
            b = "".join(sample_picture(second["solution"]))
            difference = min(
                sum(x != y for x, y in zip(a, b.translate(str.maketrans("abcd", "".join(order)))))
                for order in permutations("abcd")
            )
            if abs(first["size"] - second["size"]) < 2 and difference * 100 < 12 * len(a):
                raise SystemExit(f"{motif}: the two versions need a clearer difference in size, pose or detail")
    if len(motifs) < 200:
        raise SystemExit(f"Expected at least 200 distinct picture motifs, found {len(motifs)}")
    return len(motifs)


def check_progression(albums):
    album_scores = []
    album_sizes = []
    for planet, levels in albums.items():
        if len(levels) != 20:
            raise SystemExit(f"{planet}: expected 20 levels, found {len(levels)}")
        sizes = [level["size"] for level, _ in levels]
        if planet not in LEGACY_PLANETS:
            if not (10 <= sizes[0] < sizes[-1] <= 15) or any(b - a not in (0, 1) for a, b in zip(sizes, sizes[1:])):
                raise SystemExit(f"{planet}: sizes must rise one cell at a time within the album")
            bands = [[score for _, score in band] for _, band in groupby(levels, key=lambda entry: entry[0]["size"])]
            if any(len(band) > 8 for band in bands):
                raise SystemExit(f"{planet}: at most eight levels per size")
            if any(band != sorted(band) for band in bands) or any(median(a) >= median(b) for a, b in zip(bands, bands[1:])):
                raise SystemExit(f"{planet}: clue ambiguity must rise within and across size bands")
        album_scores.append(median(score for _, score in levels))
        album_sizes.append(median(sizes))
    if album_sizes != sorted(album_sizes) or any(b - a > 1 for a, b in zip(album_sizes[2:], album_sizes[3:])):
        raise SystemExit("Median board sizes must rise gradually after Saturn")
    if album_scores != sorted(album_scores):
        raise SystemExit("Album median clue ambiguity must rise with progression")


def check_levels():
    files = {path.name: path.read_text(encoding="utf-8") for path in OUTPUT.glob("*.json")}
    if files != generated_files():
        raise SystemExit("Nonogram JSON differs from pixel sources. Run tools/build_levels.py.")
    albums = {planet: [] for planet in PLANETS}
    images = set()
    levels = [json.loads(files[name]) for name in sorted(files)]
    for level in levels:
        image = tuple(tuple(pixel != "." for pixel in row) for row in level["solution"])
        if image in images or not any(map(any, image)):
            raise SystemExit(f'{level["id"]}: empty or duplicate puzzle')
        images.add(image)
        clues = puzzle_clues(image)
        solutions = count_solutions(*clues)
        # More plausible line fillings are typically harder to rule out.
        score = sum(
            log2(len(line_patterns(level["size"], line))) for axis in clues for line in axis
        )
        albums[level["planet"]].append((level, score))
        if solutions != 1:
            raise SystemExit(f'{level["id"]}: expected one solution, found {solutions}')
    motifs = check_pictures(levels)
    check_progression(albums)
    print(f"Nonogram: {len(files)} levels, {motifs} distinct motifs, one solution each")
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
