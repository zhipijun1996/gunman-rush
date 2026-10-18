"""Counterexamples against fake topology variety; no Godot or art-pass claim."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1] / 'tools'))
from run_plains_regional_art_tests import isomorphic


def manifest(edges, prefix='n'):
    return {'areas':[{'id':prefix+str(i)} for i in range(6)],
            'connections':[{'a':prefix+str(a),'b':prefix+str(b)} for a,b in edges]}


class TopologyCounterexamples(unittest.TestCase):
    def test_renaming_and_order_do_not_count(self):
        edges = [(0,1),(1,2),(2,3),(3,4),(4,5),(5,0),(0,3)]
        first = manifest(edges)
        permutation = [5,2,0,4,1,3]
        second = manifest([(permutation[b],permutation[a]) for a,b in reversed(edges)],'renamed')
        self.assertTrue(isomorphic(first,second))

    def test_same_degrees_different_connectivity(self):
        # Two connected 3-regular six-node graphs: K3,3 vs triangular prism.
        bipartite = [(a,b) for a in range(3) for b in range(3,6)]
        prism = [(0,1),(1,2),(2,0),(3,4),(4,5),(5,3),(0,3),(1,4),(2,5)]
        self.assertFalse(isomorphic(manifest(bipartite),manifest(prism)))

    def test_geometry_and_phase_do_not_count(self):
        edges = [(0,1),(1,2),(2,3),(3,4),(4,5)]
        first, second = manifest(edges), manifest(edges)
        for i,area in enumerate(second['areas']):
            area.update(position=[i*920,400-i*72],identity='different-'+str(i))
        for i,edge in enumerate(second['connections']):
            edge.update(kind='other',phase=i*0.7)
        self.assertTrue(isomorphic(first,second))


if __name__ == '__main__':
    unittest.main()
