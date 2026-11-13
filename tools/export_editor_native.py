"""Export the real, shared editor runtime PCK for the native Android host."""
from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import export_runtime as pack_tools
from godot_identity import verified_engine,read_config

def main():
    verified_engine()
    subprocess.run([sys.executable,'tools/world/build.py'],cwd=ROOT,check=True)
    subprocess.run([sys.executable,'-c',"import json,sys; from pathlib import Path; sys.path.insert(0,'tools/world'); from preview_catalog import preview_catalog; Path('build/preview').mkdir(parents=True,exist_ok=True); Path('build/preview/preview-world.json').write_text(json.dumps(preview_catalog(Path.cwd()),ensure_ascii=False))"],cwd=ROOT,check=True)
    plan=pack_tools.manifest()
    behavior_files=[row for row in plan['files'] if not row['path'].startswith('config/world/rooms/') and not ('/rooms/' in row['path'] and row['path'].endswith('.tscn'))]
    behavior_hash=hashlib.sha256(json.dumps(behavior_files,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    closure=ROOT/'build/preview/export-closure.json';closure.parent.mkdir(parents=True,exist_ok=True);closure.write_text(json.dumps(plan,indent=2))
    out=ROOT/'build/editor-native';out.mkdir(parents=True,exist_ok=True)
    preset=ROOT/'export_presets.cfg';original=preset.read_text()
    try:
        preset.write_text(pack_tools.configured_preset(original,plan))
        with (out/'export.log').open('w') as log:
            subprocess.run(['bash','tools/godot.sh','--headless','--path','.', '--export-pack','Web Runtime',str(out/'game.pck')],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
    finally:preset.write_text(original)
    checked=pack_tools.verify_pack(out/'game.pck',plan)
    runtime=json.loads((ROOT/'build/world/runtime.json').read_text())
    manifest={'schema':3,'document_schema':3,'content_version':runtime['content_version'],'behavior_hash':behavior_hash,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'engine':read_config()['godot']['version_exact'],'pck_sha256':hashlib.file_digest((out/'game.pck').open('rb'),'sha256').hexdigest(),'bytes':(out/'game.pck').stat().st_size,'source_tree_sha256':plan['source_tree_sha256'],'checked':checked}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in manifest.items() if k!='checked'},indent=2))
if __name__=='__main__':main()
