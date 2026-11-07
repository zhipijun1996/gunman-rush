"""The original Underworld clockwise, eight-neighbor blob47 convention.

This module selects authored quarter images. It never draws material texture.
Coordinates are grid cells, with positive y pointing down.
"""

NEIGHBORS = (
    ("N", 1, 0, -1, 12, "top_side"),
    ("NE", 2, 1, -1, 15, "top_right_corner"),
    ("E", 4, 1, 0, 0, "right_side"),
    ("SE", 8, 1, 1, 3, "bottom_right_corner"),
    ("S", 16, 0, 1, 4, "bottom_side"),
    ("SW", 32, -1, 1, 7, "bottom_left_corner"),
    ("W", 64, -1, 0, 8, "left_side"),
    ("NW", 128, -1, -1, 11, "top_left_corner"),
)
DIAGONALS = ((2, 1 | 4), (8, 4 | 16), (32, 16 | 64), (128, 64 | 1))


def normalize(mask):
    mask = int(mask) & 255
    for diagonal, adjacent in DIAGONALS:
        if mask & adjacent != adjacent:
            mask &= ~diagonal
    return mask


MASKS = tuple(sorted({normalize(mask) for mask in range(256)}))
MASK_TO_ATLAS = {mask: (index % 8, index // 8) for index, mask in enumerate(MASKS)}


def mask_at(cells, x, y):
    return normalize(sum(bit for _, bit, dx, dy, _, _ in NEIGHBORS if (x + dx, y + dy) in cells))


# Name, local quarter origin, two adjacent sides, their diagonal,
# nine-slice outer corner, edge if first side is absent, edge if second is absent.
QUADRANTS = (
    ("NW", 0, 0, 1, 64, 128, "tl", "t", "l"),
    ("NE", 16, 0, 1, 4, 2, "tr", "t", "r"),
    ("SE", 16, 16, 16, 4, 8, "br", "b", "r"),
    ("SW", 0, 16, 16, 64, 32, "bl", "b", "l"),
)


def quarter_recipes(mask):
    assert normalize(mask) == mask
    result = []
    for name, x, y, first, second, diagonal, outer, first_edge, second_edge in QUADRANTS:
        if not mask & first and not mask & second:
            state, tile = "outer", outer
        elif not mask & first:
            state, tile = "edge", first_edge
        elif not mask & second:
            state, tile = "edge", second_edge
        elif not mask & diagonal:
            state, tile = "concave", None
        else:
            state, tile = "interior", "i"
        result.append({"quadrant": name, "destination": [x, y, 16, 16], "state": state, "tile": tile})
    return result


def all_mask_fixture():
    """47 isolated 3x3 neighborhoods; each labeled center realizes its mask."""
    cells, centers = set(), []
    for index, mask in enumerate(MASKS):
        x, y = (index % 8) * 5 + 2, (index // 8) * 5 + 2
        cells.add((x, y))
        for _, bit, dx, dy, _, _ in NEIGHBORS:
            if mask & bit:
                cells.add((x + dx, y + dy))
        centers.append({"cell": [x, y], "mask": mask})
    return {"tile": 32, "origin": [0, 0], "widthCells": 40, "heightCells": 30,
            "cells": [list(cell) for cell in sorted(cells, key=lambda c: (c[1], c[0]))], "centers": centers}


def feature_fixture():
    """A practical cave/platform sample with holes, thin bars and junctions."""
    cells = {(x, y) for y in range(9, 15) for x in range(2, 35)}
    cells |= {(x, y) for y in range(2, 10) for x in range(2, 8)}
    cells |= {(x, y) for y in range(1, 4) for x in range(8, 25)}
    cells |= {(x, y) for y in range(3, 10) for x in range(23, 28)}
    cells -= {(x, y) for y in range(10, 13) for x in range(5, 9)}
    cells -= {(x, y) for y in range(9, 12) for x in range(15, 20)}
    cells -= {(x, y) for y in range(5, 8) for x in range(24, 26)}
    cells |= {(x, 7) for x in range(9, 16)}
    cells |= {(13, y) for y in range(4, 10)}
    cells |= {(x, 5) for x in range(29, 34)}
    cells |= {(31, y) for y in range(2, 8)}
    cells |= {(18, 6), (21, 7), (10, 5)}
    return {"tile": 32, "origin": [0, 0], "widthCells": 37, "heightCells": 17,
            "cells": [list(cell) for cell in sorted(cells, key=lambda c: (c[1], c[0]))],
            "features": ["isolated", "one-cell horizontal", "one-cell vertical", "T", "cross", "enclosed holes", "open caves"]}


if __name__ == "__main__":
    assert len(MASKS) == 47
    assert all(normalize(normalize(m)) == normalize(m) for m in range(256))
    fixture = all_mask_fixture()
    cells = {tuple(c) for c in fixture["cells"]}
    assert all(mask_at(cells, *c["cell"]) == c["mask"] for c in fixture["centers"])
    print("47 normalized masks; all 256 inputs idempotent; 47 fixture centers verified.")
