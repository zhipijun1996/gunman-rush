"""Verify the current world through actual input, a separate restart, and failure fixtures."""
import re
from pathlib import Path
from run_tests import run_engine
from world.build import build

ROOT=Path(__file__).resolve().parents[1]
def main():
    build()
    for script,marker,timeout in [
        ('state_contracts.gd',r'WORLD STATE: \d+ assertions, 0 failures',30),
        ('service_contracts.gd',r'WORLD SERVICES: \d+ assertions, 0 failures',60),
        ('economy.gd',r'WORLD GOLD: \d+ assertions, 0 failures',60),
        ('economy_restart.gd',r'WORLD GOLD RESTART: 0 failures',30),
        ('traversal_contracts.gd',r'WORLD TRAVERSAL: \d+ assertions, 0 failures',60),
        ('room_contracts.gd',r'WORLD ROOMS: \d+ assertions, 0 failures',180),
        ('ui_contracts.gd',r'WORLD UI: \d+ assertions, 0 failures',60),
        ('presentation_contracts.gd',r'WORLD PRESENTATION: \d+ assertions, 0 failures',60),
        ('demo_regressions.gd',r'WORLD DEMO: \d+ assertions, 0 failures',60),
        ('focus_heal.gd',r'WORLD HEAL: \d+ assertions, 0 failures',90),
        ('focus_heal_restart.gd',r'WORLD HEAL RESTART: 0 failures',30),
        ('lifecycle.gd',r'WORLD LIFECYCLE: \d+ assertions, 0 failures',60),
        ('plains_state_contracts.gd',r'PLAINS STATE: \d+ assertions, 0 failures',60),
        ('plains_motor.gd',r'PLAINS MOTOR: 0 failures',90),
        ('plains_intro.gd',r'PLAINS INTRO: 0 failures',180),
        ('plains_first_loop.gd',r'PLAINS FIRST LOOP: 0 failures',360),
        ('plains_boss.gd',r'PLAINS BOSS: 0 failures',180),
        ('plains_bellstrider.gd',r'PLAINS BELLSTRIDER: 0 failures',180),
        ('plains_gates.gd',r'PLAINS GATES: 0 failures',90),
        ('plains_gate_counterexamples.gd',r'PLAINS COUNTEREXAMPLES: 0 failures',120),
        ('plains_acquisitions.gd',r'PLAINS ACQUISITIONS: 0 failures',180),
        ('plains_carriers.gd',r'PLAINS CARRIERS: 0 failures',120),
        ('plains_mill.gd',r'PLAINS MILL: 0 failures',120),
        ('plains_orchard.gd',r'PLAINS ORCHARD: 0 failures',120),
        ('plains_recoil_edges.gd',r'PLAINS RECOIL EDGES: 0 failures',240),
        ('plains_west_pressure.gd',r'PLAINS WEST PRESSURE: 0 failures',180),
        ('plains_interiors.gd',r'PLAINS INTERIORS: 0 failures',120),
        ('plains_gear_route.gd',r'PLAINS GEAR ROUTE: 0 failures',120),
        ('plains_cellar.gd',r'PLAINS CELLAR: 0 failures',120),
        ('plains_well.gd',r'PLAINS WELL: 0 failures',120),
        ('plains_return_galleries.gd',r'PLAINS RETURN GALLERIES: 0 failures',120),
        ('plains_thresholds.gd',r'PLAINS THRESHOLDS: 0 failures',120),
        ('plains_mechanisms.gd',r'PLAINS MECHANISMS: 0 failures',120),
        ('plains_returns.gd',r'PLAINS RETURNS: 0 failures',180),
        ('plains_places.gd',r'PLAINS PLACES: 0 failures',120),
        ('plains_east_routes.gd',r'PLAINS EAST ROUTES: 0 failures',240),
        ('restart.gd',r'WORLD RESTART: 0 failures',30),
        ('service_ui.gd',r'WORLD SERVICE UI: 0 failures',120),
        ('service_restart.gd',r'WORLD SERVICE RESTART: 0 failures',30),
    ]:
        output=run_engine(['--headless','--fixed-fps','60','--path','.', '--script','tests/world/'+script],timeout)
        if 'SCRIPT ERROR:' in output or re.search(r'^ERROR:',output,re.M) or not re.search(marker,output):
            raise RuntimeError('World validation failed: '+script)
    print('PASS: plains continuous first loop, qualified branches, 35-room contracts, disk restart, services and lifecycle counterexamples')
if __name__=='__main__':main()
