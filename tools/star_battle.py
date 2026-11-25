"""Validate and solve square Star Battle puzzles with one star per line and region."""

from collections import deque


def neighbors(size, row, col):
    for y, x in ((row - 1, col), (row, col - 1), (row, col + 1), (row + 1, col)):
        if 0 <= y < size and 0 <= x < size:
            yield y, x


def validate_regions(regions):
    size = len(regions)
    if size not in range(6, 10) or any(len(row) != size for row in regions):
        raise ValueError("Expected a square grid of size 6–9")
    tiles = [set() for _ in range(size)]
    for y, row in enumerate(regions):
        for x, region in enumerate(row):
            if type(region) is not int or not 0 <= region < size:
                raise ValueError("Region labels must be between 0 and size - 1")
            tiles[region].add((y, x))
    for region in tiles:
        if not region:
            raise ValueError("Every region must be present")
        start = min(region)
        connected = {start}
        pending = deque([start])
        while pending:
            for cell in neighbors(size, *pending.popleft()):
                if cell in region and cell not in connected:
                    connected.add(cell)
                    pending.append(cell)
        if connected != region:
            raise ValueError("Regions must be orthogonally connected")


def valid_solution(regions, columns):
    """Each entry is the zero-based column of the star for that row."""
    size = len(regions)
    if len(columns) != size or any(type(x) is not int or not 0 <= x < size for x in columns):
        return False
    if len(set(columns)) != size or any(abs(a - b) <= 1 for a, b in zip(columns, columns[1:])):
        return False
    return len({regions[y][x] for y, x in enumerate(columns)}) == size


def solve(regions, limit=2):
    """Return up to limit solutions and the number of search nodes visited."""
    size = len(regions)
    paths = []
    visits = 0
    stars = [-size] * size

    def visit(open_rows, columns, used_regions):
        nonlocal visits
        visits += 1
        if not open_rows:
            paths.append(tuple(stars))
            return
        best_row, best_options = -1, None
        offered_columns = 0
        offered_regions = 0
        for row in open_rows:
            options = []
            above = stars[row - 1] if row > 0 else -size
            below = stars[row + 1] if row + 1 < size else -size
            for col, region in enumerate(regions[row]):
                col_bit, region_bit = 1 << col, 1 << region
                if columns & col_bit or used_regions & region_bit:
                    continue
                if abs(above - col) <= 1 or abs(below - col) <= 1:
                    continue
                options.append((col, col_bit, region_bit))
                offered_columns |= col_bit
                offered_regions |= region_bit
            if not options:
                return
            if best_options is None or len(options) < len(best_options):
                best_row, best_options = row, options
        if min(offered_columns.bit_count(), offered_regions.bit_count()) < len(open_rows):
            return
        remaining_rows = tuple(row for row in open_rows if row != best_row)
        for col, col_bit, region_bit in best_options:
            stars[best_row] = col
            visit(remaining_rows, columns | col_bit, used_regions | region_bit)
            stars[best_row] = -size
            if len(paths) >= limit:
                return

    visit(tuple(range(size)), 0, 0)
    return paths, visits


def canonical_grid(regions):
    """Identify duplicates even after rotation, reflection, or renaming regions."""
    variants = []
    rotated = regions
    for _ in range(4):
        for grid in (rotated, [row[::-1] for row in rotated]):
            lookup = {}
            variants.append(tuple(
                lookup.setdefault(region, len(lookup))
                for row in grid
                for region in row
            ))
        rotated = tuple(zip(*rotated[::-1]))
    return min(variants)
