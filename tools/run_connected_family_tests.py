"""Verify real rooted-family Nodes with strict Godot diagnostics and source binding."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time

import level_formal

ROOT=Path(__file__).resolve().parents[1]
# All historical renderer consumers below are explicit test-only fixtures; formal Pixel defaults are unchanged.
LEGACY_FIXTURE_SCOPE = "explicit_legacy_presentation_not_default"
ERRORS=r'(?m)SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:|ObjectDB.*leaked'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    evidence_root=ROOT/'build/production_repair/art'
    evidence_root.mkdir(parents=True,exist_ok=True)
    if args.output and args.output.exists():
        raise ValueError('Use a new output directory; original failed attempts remain immutable')
    folder=args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='connected-family-',dir=evidence_root))
    folder.mkdir(parents=True,exist_ok=True)
    paths=['tools/run_connected_family_tests.py','game/presentation/world/art/plains_connected_landscape.gd','game/presentation/world/art/plains_region_composition.gd',
           'game/presentation/world/art/plains_landscape_observer.gd','tests/plains_connected_family_contract_runner.gd',
           'tests/legacy_plains_presentation_fixture.gd','game/application/demo_app.gd','game/world/levels/providers/plains_region_stage.gd',
           'game/presentation/world/art/plains_terrain_study.gd','game/presentation/world/art/plains_terrain_family_sampler.gd',
           'game/presentation/world/art_foundation/pixel_region_scenery.gd','game/presentation/world/art_foundation/pixel_region_landmarks.gd','game/presentation/world/art_foundation/pixel_plains_parallax.gd',
           'config/player_tuning.json','resources/player/traversal.tres','assets/production_repair/rooted_plants_v1/raw.png','assets/production_repair/rooted_plants_v1/family.json']
    def sources():return level_formal.source_files(extra_paths=paths)
    before=sources()
    command=['bash','tools/godot.sh','--verbose','--headless','--path','.', '--script','tests/plains_connected_family_contract_runner.gd','--','--legacy-presentation-fixture=connected_family','--output='+str(folder/'consumer.json')]
    started=time.time();clock=time.monotonic()
    report={'consumer_mode':LEGACY_FIXTURE_SCOPE,'status':'failed','command':command,'source_before':before,'started_at_unix':started,'errors':[]}
    try:
        result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=120)
        log=result.stdout+result.stderr
        (folder/'godot.log').write_text(log)
        report.update(exit_code=result.returncode,source_after=sources())
        if result.returncode or re.search(ERRORS,log):raise RuntimeError('Godot runtime/exit diagnostics rejected; read original godot.log')
        if not re.search(r'^CONNECTED FAMILY CONTRACT: [1-9]\d* assertions, 0 failures$',log,re.MULTILINE):raise RuntimeError('Native completion absent')
        actual=json.loads((folder/'consumer.json').read_text())
        if actual['failures'] or actual['consumer']['issues'] or before!=report['source_after']:raise RuntimeError('Actual consumer/source binding failed')
        report['status']='passed'
    except subprocess.TimeoutExpired as error:
        def decode(value):return value.decode(errors='replace') if isinstance(value,bytes) else (value or '')
        (folder/'godot.log').write_text(decode(error.stdout)+decode(error.stderr))
        report['errors'].append('bounded_timeout')
    except Exception as error:
        report['errors'].append(type(error).__name__+': '+str(error))
    report.update(ended_at_unix=time.time(),duration_seconds=time.monotonic()-clock)
    (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('CONNECTED FAMILY CHECK: '+report['status']+' evidence='+str(folder))
    if report['errors']:print('\n'.join(report['errors']));print((folder/'godot.log').read_text(errors='replace')[-7000:])
    return 0 if report['status']=='passed' else 1


if __name__=='__main__':raise SystemExit(main())
