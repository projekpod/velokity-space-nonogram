import unittest

from check_levels import check_canvas, check_pictures, check_progression


PICTURE = (
    "aaa.......",
    "aaab......",
    ".aaabb....",
    "..aaab....",
    "...aba....",
    "....abba..",
    ".....aba..",
    "......aab.",
    ".......aab",
    "........aa",
)


def level(planet, number, rows, motif="spacecraft"):
    return {"id": f"{planet}-{number:02d}", "planet": planet, "size": len(rows), "solution": rows, "motif": motif}


def add_detail(x, y):
    rows = list(PICTURE)
    rows[y] = rows[y][:x] + "d" + rows[y][x + 1:]
    return rows


class PictureQualityTests(unittest.TestCase):
    def test_canvas_checks_interior_empty_lines(self):
        check_canvas("wide", PICTURE)
        with self.assertRaisesRegex(SystemExit, "empty row"):
            rows = [row if y not in (3, 6) else "." * 10 for y, row in enumerate(PICTURE)]
            check_canvas("gap", rows)
        with self.assertRaisesRegex(SystemExit, "empty column"):
            check_canvas("gap", tuple(map("".join, zip(*rows))))

    def test_canvas_checks_bounding_box_area(self):
        with self.assertRaisesRegex(SystemExit, "80%"):
            check_canvas("small", ["." * 8] + ["a" * 7 + "."] * 7)

    def test_reused_drawings_fail_even_with_a_new_motif_and_palette(self):
        recolored = [row[::-1].translate(str.maketrans("ab", "dc")) for row in PICTURE]
        with self.assertRaisesRegex(SystemExit, "repeats the picture"):
            check_pictures([level("earth", 1, PICTURE), level("venus", 1, recolored, "satellite")])

    def test_motif_cannot_repeat_in_one_album_or_three_times_overall(self):
        first, second = level("earth", 1, PICTURE), level("earth", 2, add_detail(3, 3))
        with self.assertRaisesRegex(SystemExit, "within a planet"):
            check_pictures([first, second])
        second = level("venus", 1, add_detail(3, 3))
        third = level("mercury", 1, add_detail(4, 4))
        with self.assertRaisesRegex(SystemExit, "more than twice"):
            check_pictures([first, second, third])

    def test_variant_must_change_more_than_one_pixel(self):
        with self.assertRaisesRegex(SystemExit, "clearer difference"):
            check_pictures([level("earth", 1, PICTURE), level("venus", 1, add_detail(3, 3))])

    def test_catalog_requires_200_motifs(self):
        with self.assertRaisesRegex(SystemExit, "at least 200"):
            check_pictures([level("earth", 1, PICTURE)])

    def test_progression_requires_short_increasing_bands(self):
        def album(sizes):
            return {"earth": [({"size": size}, score) for score, size in enumerate(sizes)]}

        check_progression(album([10] * 6 + [11] * 8 + [12] * 6))
        with self.assertRaisesRegex(SystemExit, "sizes must rise"):
            check_progression(album([10] * 6 + [12] * 8 + [13] * 6))
        with self.assertRaisesRegex(SystemExit, "at most eight"):
            check_progression(album([10] * 9 + [11] * 6 + [12] * 5))


if __name__ == "__main__":
    unittest.main()
