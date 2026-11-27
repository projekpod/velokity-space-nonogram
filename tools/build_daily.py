"""Generate reproducible, uniquely solvable Star Battle boards."""

from itertools import islice, permutations
import json
from pathlib import Path

from star_battle import canonical_grid, neighbors, solve

OUTPUT = Path(__file__).resolve().parents[1] / "data" / "daily"
COUNTS = (53, 52, 52, 52, 52, 52, 52)
# Each weekday uses a disjoint range of search effort.
BANDS = ((13, 15), (16, 23), (24, 29), (30, 38), (39, 48), (49, 65), (66, float("inf")))
SIZES = (6, 6, 7, 7, 8, 8, 9)


def region_grid(columns, variant):
    """Grow regions from a legal star arrangement along orthogonal edges."""
    size = len(columns)
    grid = [[-1] * size for _ in columns]
    frontier = [set() for _ in columns]
    for row, col in enumerate(columns):
        grid[row][col] = row
        frontier[row].update(neighbors(size, row, col))
    areas = [1] * size
    skew = variant % 4 + 1
    # Freeze some seed regions so the solver can deduce starting stars.
    fixed = {(variant + index * (size - 1)) % size for index in range(variant // 4)}
    growing = tuple(region for region in range(size) if region not in fixed)
    for turn in range(size * size - size):
        def priority(item):
            region, (row, col) = item
            dy, dx = row - region, col - columns[region]
            distance = abs(dy) + abs(dx)
            axis_cost = abs(dx if variant % 2 else dy)
            slope = (dx + dy * skew) % (size + 1)
            return (
                distance + ((region + variant) % size) * skew + (areas[region] + axis_cost) % (size - 1),
                slope,
                (region - variant - turn) % size,
                row,
                col,
            )

        region, (row, col) = min(
            ((region, cell) for region in growing
             for cell in frontier[region] if grid[cell[0]][cell[1]] == -1),
            key=priority,
        )
        grid[row][col] = region
        areas[region] += 1
        frontier[region].update(
            cell for cell in neighbors(size, row, col) if grid[cell[0]][cell[1]] == -1
        )
    return grid


def candidates(size):
    legal = (
        columns for columns in permutations(range(size))
        if all(abs(a - b) > 1 for a, b in zip(columns, columns[1:]))
    )
    visited = set()
    # Sample the lexicographic permutations evenly while varying growth priorities.
    stride = (1, 3, 12, 47)[size - 6]
    for columns in islice(legal, 0, None, stride):
        for variant in range(0, 4 * (size - 1), 2):
            grid = region_grid(columns, variant)
            signature = canonical_grid(grid)
            if signature in visited:
                continue
            visited.add(signature)
            paths, effort = solve(grid)
            if len(paths) == 1:
                yield effort, grid, paths[0]


def catalog():
    pools = [[] for _ in COUNTS]
    for size in sorted(set(SIZES)):
        tiers = [index for index, board_size in enumerate(SIZES) if board_size == size]
        for effort, grid, solution in candidates(size):
            for tier in tiers:
                minimum, maximum = BANDS[tier]
                if minimum <= effort <= maximum and len(pools[tier]) < COUNTS[tier]:
                    pools[tier].append((size, effort, grid, solution))
                    break
            if all(len(pools[tier]) == COUNTS[tier] for tier in tiers):
                break
    if [len(pool) for pool in pools] != list(COUNTS):
        raise ValueError(f"Insufficient unique puzzles: {[len(pool) for pool in pools]}")
    return {
        f"daily-{tier}-{index:02d}.json": {
            "size": size,
            "difficulty": tier,
            "effort": effort,
            "regions": grid,
            "solution": solution,
        }
        for tier, pool in enumerate(pools, 1)
        for index, (size, effort, grid, solution) in enumerate(pool, 1)
    }


def main():
    for name, puzzle in catalog().items():
        (OUTPUT / name).write_text(json.dumps(puzzle, separators=(",", ":")) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
