"""Compare the Star Battle solver with enumeration and test invalid inputs."""

from copy import deepcopy
from itertools import permutations
import json
import unittest

from build_daily import OUTPUT, catalog
from star_battle import canonical_grid, solve, valid_solution, validate_regions

# A legal placement on a six-by-six board with one vertical region per column.
COLUMNS = (1, 3, 5, 0, 2, 4)
STRIPES = [list(range(6)) for _ in range(6)]


class StarBattleTests(unittest.TestCase):
    def test_star_rules(self):
        self.assertTrue(valid_solution(STRIPES, COLUMNS))
        self.assertFalse(valid_solution(STRIPES, (1, 3, 5, 0, 2)))
        self.assertFalse(valid_solution(STRIPES, (1, 3, 5, 0, 2, 1)))  # Same column.
        self.assertFalse(valid_solution(STRIPES, (1, 0, 5, 3, 2, 4)))  # Touching diagonals.
        same_region = deepcopy(STRIPES)
        same_region[2][5] = same_region[0][1]
        self.assertFalse(valid_solution(same_region, COLUMNS))
        self.assertFalse(valid_solution(STRIPES, (1, 3, 5, 0, 2, 6)))

    def test_region_connectivity(self):
        validate_regions(STRIPES)
        disconnected = deepcopy(STRIPES)
        disconnected[2][5] = 0
        with self.assertRaisesRegex(ValueError, "orthogonally connected"):
            validate_regions(disconnected)
        with self.assertRaisesRegex(ValueError, "must be present"):
            validate_regions([[0] * 6 for _ in range(6)])
        with self.assertRaisesRegex(ValueError, "between 0"):
            validate_regions([[9] * 6 for _ in range(6)])
        with self.assertRaisesRegex(ValueError, "square grid"):
            validate_regions([list(range(6))] * 5)

    def test_solver_against_brute_force(self):
        regions = json.loads((OUTPUT / "daily-1-01.json").read_text(encoding="utf-8"))["regions"]
        layouts = [regions, STRIPES]
        impossible = [[0, 1, 2, 3, 4, 4]] + [[5] * 6 for _ in range(5)]
        validate_regions(impossible)
        layouts.append(impossible)
        for grid, expected in zip(layouts, (1, 2, 0)):
            exhaustive = {
                arrangement
                for arrangement in permutations(range(6))
                if len({grid[y][x] for y, x in enumerate(arrangement)}) == 6
                and all(abs(a - b) > 1 for a, b in zip(arrangement, arrangement[1:]))
            }
            solutions, _ = solve(grid)
            self.assertEqual(len(solutions), expected)
            self.assertEqual(len(solutions), min(2, len(exhaustive)))
            self.assertTrue(set(solutions) <= exhaustive)

    def test_canonical_grid(self):
        grid = [[0, 0, 1], [0, 2, 1], [2, 2, 1]]
        mirrored = [[2 - region for region in row[::-1]] for row in grid]
        rotated = list(zip(*grid[::-1]))
        self.assertEqual(canonical_grid(grid), canonical_grid(mirrored))
        self.assertEqual(canonical_grid(grid), canonical_grid(rotated))

    def test_generator_reproduces_catalog(self):
        generated = catalog()
        self.assertEqual(len(generated), 365)
        for name, puzzle in generated.items():
            with self.subTest(puzzle=name):
                shipped = json.loads((OUTPUT / name).read_text(encoding="utf-8"))
                self.assertEqual(shipped, {**puzzle, "solution": list(puzzle["solution"])})


if __name__ == "__main__":
    unittest.main()
