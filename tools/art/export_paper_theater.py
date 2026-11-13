"""Export the isolated P04 experiment with the existing verified dependency closure.

Restores both production configuration files even on export failure. Run alone,
after tools/setup_environment.py --godot-only. Outputs never replace build/web.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import export_workbench as web
from godot_identity import verified_engine, verify_templates
from build import prepare_web_playtest

ENTRY = 'game/experiments/paper_theater/paper_lab.tscn'


def main():
    output = ROOT / 'build/paper_theater/web'
    output.mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, 'tools/world/build.py'], cwd=ROOT, check=True)
    # FixedWorldApp and the existing region art use computed source paths. Reuse
    # their controlled closure rather than shipping all historical project art.
    web.ENTRY = ENTRY
    plan = web.manifest(formal_only=True)
    closure = ROOT / 'build/native/export-closure.json'
    closure.parent.mkdir(parents=True, exist_ok=True)
    closure.write_text(json.dumps(plan, indent=2)+'\n')
    identity = verified_engine()
    verify_templates()
    project = ROOT / 'project.godot'
    presets = ROOT / 'export_presets.cfg'
    original_project = project.read_text()
    original_presets = presets.read_text()
    try:
        project.write_text(re.sub(r'^run/main_scene=.*$', 'run/main_scene="res://'+ENTRY+'"', original_project, flags=re.M))
        configured = web.configured_preset(original_presets, plan)
        # The raw exporter selects the formal closure; the workbench bridge is
        # intentionally disabled. WebGL2 uses the nonthreaded locked template.
        configured = re.sub(r'(\[preset\.3\][\s\S]*?custom_features=)"[^"]*"', r'\1"fixed_world_release"', configured, count=1)
        presets.write_text(configured)
        web.run(['bash','tools/godot.sh','--headless','--path',str(ROOT),'--export-debug','Web Workbench',str(output/'index.html')],output/'export.log',600)
    finally:
        project.write_text(original_project)
        presets.write_text(original_presets)
    checked = web.verify_pack(output/'index.pck',plan)
    files = prepare_web_playtest(output/'index.html',{k:v for k,v in identity.items() if k!='binary'})
    info = json.loads((output/'build-info.json').read_text())
    info.update(paper_theater=True, room='P-R04', entry='res://'+ENTRY, source_tree_sha256=plan['source_tree_sha256'], source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip())
    (output/'build-info.json').write_text(json.dumps(info,indent=2)+'\n')
    report = {'entry':ENTRY,'source_tree_sha256':plan['source_tree_sha256'],'closure':checked,'pack_bytes':info['pack_bytes'],'download_bytes':info['download_bytes'],'engine':identity,'mobile_device':'unverified'}
    (output/'paper-build.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='engine'}))


if __name__ == '__main__':
    main()
