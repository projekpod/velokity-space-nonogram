"""Check solver results against a small exhaustive reference."""

from collections import Counter
from itertools import product
import unittest

from nonogram import clues, count_solutions, puzzle_clues


class NonogramTests(unittest.TestCase):
    def test_clue_groups(self):
        self.assertEqual(clues([0, 0]), ())
        self.assertEqual(clues([1, 1, 0, 1, 0, 1, 1, 1]), (2, 1, 3))

    def test_no_solution(self):
        self.assertEqual(count_solutions(((1,),), ((),)), 0)

    def test_known_fills_and_crosses_restrict_line_candidates(self):
        clues = ((1,), (1,))
        self.assertEqual(count_solutions(clues, clues), 2)
        self.assertEqual(count_solutions(clues, clues, givens={(0, 0): True}), 1)
        self.assertEqual(count_solutions(clues, clues, givens={(0, 0): False}), 1)
        self.assertEqual(count_solutions(clues, clues, givens={(0, 0): True, (1, 0): True}), 0)

    def test_all_three_by_three_pictures(self):
        counts = Counter(
            puzzle_clues((bits[:3], bits[3:6], bits[6:]))
            for bits in product((False, True), repeat=9)
        )
        for (rows, columns), total in counts.items():
            self.assertEqual(count_solutions(rows, columns), min(total, 2))
            self.assertEqual(count_solutions(rows, columns, limit=6), total)


if __name__ == "__main__":
    unittest.main()
