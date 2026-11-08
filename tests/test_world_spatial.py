"""Physical concave rooms: one shape for boundaries, door seams and map scale."""
import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from world.spatial import room_space, contains_rect, door_on_boundary, navigation_geometry

class RoomSpaceTests(unittest.TestCase):
    def test_concave_edge_is_real_boundary_not_bounding_box(self):
        s=room_space([[0,0,800,448],[0,448,320,512]],[800,960])
        self.assertEqual(len(s['outline']),6)
        self.assertTrue(contains_rect(s,[32,384,128,160]))
        self.assertFalse(contains_rect(s,[256,384,128,160]))
        self.assertTrue(door_on_boundary(s,{'direction':'right','position_candidate':{'local_world_units':[320,800]}}))
        self.assertFalse(door_on_boundary(s,{'direction':'right','position_candidate':{'local_world_units':[800,800]}}))
        self.assertFalse(door_on_boundary(s,{'direction':'down','position_candidate':{'local_world_units':[160,448]}}))

    def test_disconnected_corner_touch_and_hole_are_not_rooms(self):
        for rects,extent in [([[0,0,320,320],[640,0,320,320]],[960,320]),
                             ([[0,0,320,320],[320,320,320,320]],[640,640]),
                             ([[0,0,960,320],[0,640,960,320],[0,320,320,320],[640,320,320,320]],[960,960])]:
            with self.subTest(rects=rects),self.assertRaises(ValueError):room_space(rects,extent)

    def test_nonrectangular_neighbours_share_a_physical_seam(self):
        a={'world_geometry':{'space_rects':[[0,0,800,448],[0,448,320,512]],'bounds_world_units':[0,0,800,960]},'doors':[{'id':'ab','target_door_id':'ba','target_room':'b','direction':'right','position_candidate':{'local_world_units':[320,800]}}]}
        b={'world_geometry':{'space_rects':[[0,0,480,512]],'bounds_world_units':[0,0,480,512]},'doors':[{'id':'ba','target_door_id':'ab','target_room':'a','direction':'left','position_candidate':{'local_world_units':[0,352]}}]}
        result=navigation_geometry({'a':a,'b':b},'a')
        self.assertEqual(result['b']['origin'],[320,448])
        b['doors'][0]['position_candidate']['local_world_units']=[0,384]
        with self.assertRaisesRegex(ValueError,'overlap'):navigation_geometry({'a':a,'b':b},'a')
        a['world_geometry']['map_origin']=[10,10]
        with self.assertRaisesRegex(ValueError,'map_origin'):navigation_geometry({'a':a,'b':b},'a')

if __name__=='__main__':unittest.main()
