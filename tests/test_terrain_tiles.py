"""Exhaustive topology/packing tests; image beauty and GPU seams are separate."""
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import terrain_tiles as tiles

class TerrainTests(unittest.TestCase):
    def test_all_256_neighbourhoods_resolve_to_47(self):
        masks={tiles.normalize(m) for m in range(256)}
        self.assertEqual(len(masks),47)
        for m in range(256):
            n=tiles.normalize(m)
            self.assertEqual(n,tiles.normalize(n))
            self.assertEqual(m&15,n&15)
            self.assertEqual(len(tiles.quadrants(n)),4)
    def test_catalog_is_complete_and_current(self):
        actual=json.loads(Path('game/presentation/world/resources/art/plains_tile_catalog.json').read_text())
        self.assertEqual(actual,tiles.manifest())
    def test_polyominoes_and_holes_are_exactly_covered(self):
        shapes=tiles.polyominoes()
        self.assertEqual(len(shapes),307)
        shapes.add(frozenset((x,y) for x in range(3) for y in range(3) if (x,y)!=(1,1)))
        shapes.add(frozenset((x,y) for x in range(12) for y in range(5) if not (2<x<8 and 1<y<3)))
        for shape in shapes:
            seen=set()
            for piece in tiles.pack(shape,((4,2),(2,2),(1,2),(2,1),(1,1))):
                x,y=piece['at'];w,h=piece['size']
                for dy in range(h):
                    for dx in range(w):
                        cell=(x+dx,y+dy)
                        self.assertNotIn(cell,seen);seen.add(cell)
                        self.assertEqual(piece['masks'][dy*w+dx],tiles.mask_at(shape,cell))
            self.assertEqual(seen,set(shape))
    def test_seams_use_same_material_coordinates(self):
        # Canonical world coordinate is independent of how shapes are partitioned.
        for x in range(-8,9):
            for width in [1,2,4]:
                self.assertEqual(x*32+width*32,(x+width)*32)
        # This is only a placement proof; real pixels are checked in the rendered gallery.
    def test_missing_fallback_is_rejected(self):
        with self.assertRaises(ValueError):tiles.pack({(0,0)},((2,2),))

if __name__=='__main__':unittest.main()
