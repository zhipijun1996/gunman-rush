"""Verify the current world through actual input, a separate restart, and failure fixtures."""
import re
from pathlib import Path
from run_tests import run_engine
from world.build import build
import json
import sys

ROOT=Path(__file__).resolve().parents[1]
def main():
    build()
    sys.path.insert(0, str(ROOT / "tools/world"))
    from workbench_seed import preview_catalog
    target = ROOT / "build/workbench/preview-world.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(preview_catalog(ROOT), ensure_ascii=False) + "\n")
    for script,marker,timeout in [
        ('state_contracts.gd',r'WORLD STATE: \d+ assertions, 0 failures',30),
        ('service_contracts.gd',r'WORLD SERVICES: \d+ assertions, 0 failures',60),
        ('economy.gd',r'WORLD GOLD: \d+ assertions, 0 failures',60),
        ('economy_restart.gd',r'WORLD GOLD RESTART: 0 failures',30),
        ('traversal_contracts.gd',r'WORLD TRAVERSAL: \d+ assertions, 0 failures',60),
        ('spatial_contracts.gd',r'WORLD SPACE: 0 failures',60),
        ('room_contracts.gd',r'WORLD ROOMS: \d+ assertions, 0 failures',180),
        ('room_review.gd',r'WORLD ROOM REVIEW: 0 failures',120),
        ('ui_contracts.gd',r'WORLD UI: \d+ assertions, 0 failures',60),
        ('camera_controller.gd',r'CAMERA CONTROLLER: \d+ checks; 0 failures',90),
        ('camera_zones.gd',r'CAMERA ZONES: \d+ checks; 0 failures',90),
        ('camera_vertical.gd',r'CAMERA VERTICAL/ARENA: \d+ checks; 0 failures',90),
        ('camera_arena.gd',r'CAMERA ARENA: \d+ checks; 0 failures',90),
        ('camera_motion.gd',r'CAMERA MOTION: \d+ checks; 0 failures',90),
        ('presentation_contracts.gd',r'WORLD PRESENTATION: \d+ assertions, 0 failures',60),
        ('demo_regressions.gd',r'WORLD DEMO: \d+ assertions, 0 failures',60),
        ('focus_heal.gd',r'WORLD HEAL: \d+ assertions, 0 failures',90),
        ('focus_heal_restart.gd',r'WORLD HEAL RESTART: 0 failures',30),
        ('lifecycle.gd',r'WORLD LIFECYCLE: \d+ assertions, 0 failures',60),
        ('plains_state_contracts.gd',r'PLAINS STATE: \d+ assertions, 0 failures',60),
        ('plains_intro.gd',r'PLAINS REVISION: 0 failures',180),
        ('plains_readability.gd',r'PLAINS INTRO: 0 failures',180),
        ('platform_dwell.gd',r'PLATFORM DWELL: .*0 failures',60),
        ('workbench.gd',r'WORKBENCH: .*0 failures',180),
        ('service_ui.gd',r'WORLD SERVICE UI: 0 failures',120),
        ('service_restart.gd',r'WORLD SERVICE RESTART: 0 failures',30),
    ]:
        output=run_engine(['--headless','--fixed-fps','60','--path','.', '--script','tests/world/'+script],timeout)
        if 'SCRIPT ERROR:' in output or re.search(r'^ERROR:',output,re.M) or not re.search(marker,output):
            raise RuntimeError('World validation failed: '+script)
    print('PASS: current tutorial local fixtures, camera/workbench, world contracts, service disk restart, services and lifecycle counterexamples')
if __name__=='__main__':main()
