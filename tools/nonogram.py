"""Clue extraction and a bounded Nonogram solver using line candidates."""

from functools import lru_cache


def clues(line):
    groups = []
    run = 0
    for filled in (*line, False):
        if filled:
            run += 1
        elif run:
            groups.append(run)
            run = 0
    return tuple(groups)


def puzzle_clues(grid):
    return tuple(map(clues, grid)), tuple(map(clues, zip(*grid)))


@lru_cache(maxsize=4096)
def line_patterns(length, blocks):
    if not blocks:
        return (0,)
    width, *rest = blocks
    minimum_tail = sum(rest) + len(rest)
    patterns = []
    for start in range(length - width - minimum_tail + 1):
        end = start + width
        block = ((1 << width) - 1) << start
        if rest:
            patterns.extend(
                block | (tail << (end + 1))
                for tail in line_patterns(length - end - 1, tuple(rest))
            )
        else:
            patterns.append(block)
    return tuple(patterns)


def count_solutions(row_clues, column_clues, limit=2):
    """Return the number of solutions up to limit."""
    height, width = len(row_clues), len(column_clues)
    lines = [line_patterns(width, line) for line in row_clues]
    lines.extend(line_patterns(height, line) for line in column_clues)

    def search(domains, remaining):
        updated = True
        while updated:
            updated = False
            if any(not line for line in domains):
                return 0
            for y in range(height):
                for x in range(width):
                    column = height + x
                    row_values = {(pattern >> x) & 1 for pattern in domains[y]}
                    column_values = {(pattern >> y) & 1 for pattern in domains[column]}
                    shared = row_values & column_values
                    if not shared:
                        return 0
                    if shared != row_values:
                        domains[y] = tuple(
                            p for p in domains[y] if (p >> x) & 1 in shared
                        )
                        updated = True
                    if shared != column_values:
                        domains[column] = tuple(
                            p for p in domains[column] if (p >> y) & 1 in shared
                        )
                        updated = True
        branch = min(
            (i for i, line in enumerate(domains) if len(line) > 1),
            key=lambda i: len(domains[i]),
            default=None,
        )
        if branch is None:
            return 1
        total = 0
        for pattern in domains[branch]:
            candidate = domains.copy()
            candidate[branch] = (pattern,)
            total += search(candidate, remaining - total)
            if total >= remaining:
                break
        return total

    return search(lines, limit)
