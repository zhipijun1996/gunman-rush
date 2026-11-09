"""Authored camera contracts fail before export instead of producing undefined clamps."""
import copy
import json
import sys
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/world'))
from build import validate_cameras

class CameraContracts(unittest.TestCase):
    def setUp(self):
        self.rooms = json.loads((ROOT/'config/world/construction.json').read_text())
        self.settings = json.loads((ROOT/'config/world/player.json').read_text())['camera']

    def test_current_world(self):
        validate_cameras(self.rooms, self.settings)

    def test_invalid_link_rejected(self):
        room = next(r for r in self.rooms['rooms'] if r['room_id']=='P-R22')
        room['camera']['links'][0]['b'] = 'missing-zone'
        with self.assertRaises(ValueError): validate_cameras(self.rooms, self.settings)

    def test_reversed_display_rejected(self):
        room = next(r for r in self.rooms['rooms'] if r['camera']['zones'])
        room['camera']['zones'][0]['display'][2] = -400
        with self.assertRaises(ValueError): validate_cameras(self.rooms, self.settings)

    def test_zero_time_or_zoom_rejected(self):
        for name in ['zoom','horizontal_seconds','look_delay_seconds']:
            settings = copy.deepcopy(self.settings); settings[name] = 0
            with self.assertRaises(ValueError): validate_cameras(self.rooms, settings)

    def test_no_fifth_template(self):
        self.settings['templates']['air_lock'] = [0,0]
        with self.assertRaises(ValueError): validate_cameras(self.rooms, self.settings)

    def test_arena_and_small_focus_limits_rejected(self):
        for key,value in [('vertical_focus_height',.2),('arena_vertical_padding',float('nan'))]:
            settings=copy.deepcopy(self.settings);settings[key]=value
            with self.assertRaises(ValueError):validate_cameras(self.rooms,settings)
