#!/usr/bin/env python3
"""One-off current-world candidate adapter; preserves existing PCK/host primitives."""
import argparse, hashlib, importlib.util, json, os, re, selectors, shutil, subprocess, sys, time, zipfile
from pathlib import Path
ROOT=Path('/workspace/art-direction-exploration')
sys.path.insert(0,str(ROOT/'tools'))
import harness
from check_web_bundle import Pack, texture_import_targets
from run_plains_world_rebuild_tests import source_files, EXTRA
BASE=ROOT/'docs/evidence/p1_environment/delivery/producers/prepare_local_review_bundle.py'
source=BASE.read_text().replace('ROOT = Path(__file__).resolve().parents[2]', 'ROOT = Path('+repr(str(ROOT))+')')
source=source.replace('tools/plains_environment_preview.gd','tools/plains_world_rebuild_preview.gd')
producer={'__file__':str(BASE),'__name__':'_preserved_world_pack_primitives'}
exec(compile(source,str(BASE),'exec'),producer)
ENTRY='tools/plains_world_rebuild_preview.gd'
ENGINE=producer['ENGINE']
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def inventory():
    rows={r['path']:r for r in producer['source_manifest']()}
    names={p.relative_to(ROOT).as_posix() for p in (ROOT/'assets/visual_development/plains_world_rebuild').glob('*') if p.is_file()}
    for name in list(names):
        mapping=ROOT/(name+'.import')
        if mapping.is_file():names.add(name+'.import')
    for name in list(names):
        if name.endswith('.import'):names.update(texture_import_targets((ROOT/name).read_text()).values())
    for name in names:
        p=ROOT/name
        if not p.is_file():raise ValueError('Missing current dependency: '+name)
        rows[name]={'path':name,'source':str(p),'sha256':sha(p),'bytes':p.stat().st_size}
    return sorted(rows.values(),key=lambda r:r['path'])
SMOKE='''extends "res://tools/plains_world_rebuild_preview.gd"
func run() -> void:
\tawait super.run()
\tif app == null or closing:return
\tfor unused: int in 30:await physics_frame
\tprint("WORLD PACK ACTUAL: ",JSON.stringify(app.stage.call("get_world_rebuild_snapshot")))
\tvar image_path := OS.get_environment("REVIEW_SCREENSHOT_PATH")
\tif not image_path.is_empty():
\t\tawait RenderingServer.frame_post_draw
\t\tif root.get_texture().get_image().save_png(image_path) != OK:push_error("Packed screenshot failed");rejected=true
\tprint("WORLD PACK SMOKE COMPLETE: actual manual entry; no route driver")
\tawait close_review()
'''
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--execute',action='store_true');ap.add_argument('--expected-commit');ap.add_argument('--capture-report',type=Path);ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    rows=inventory()
    if not args.execute:
        print(json.dumps({'status':'prepared_not_executed','producer':str(BASE),'producer_sha256':sha(BASE),'inputs':len(rows),'pck_input_bytes':sum(r['bytes'] for r in rows),'engine_bytes':ENGINE.stat().st_size,'godot_started':False}));return
    if not args.expected_commit or not args.capture_report:raise ValueError('Frozen source and genuine GUI capture required')
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    capture=json.loads(args.capture_report.read_text());before=source_files(EXTRA)
    if head!=args.expected_commit or capture.get('source_commit')!=head or capture.get('status')!='passed' or capture.get('source_before')!=before or capture.get('source_after')!=before:raise ValueError('Source/capture mismatch')
    native=json.loads((args.capture_report.parent/'frames/receipt.json').read_text())
    if native['seed']!='world-rebuild-01' or native['variant']!=0 or native['source_commit']!=head or not native.get('rendered_png_capture'):raise ValueError('Unexpected captured candidate')
    expected=native['actual']
    out=args.output.resolve()
    if not out.is_relative_to(Path('/tmp/plains_world_rebuild/delivery')) or out.exists():raise ValueError('New delivery /tmp directory required')
    out.mkdir(parents=True);bundle=out/'plains-world-rebuild-candidate-linux-x86_64';(bundle/'bin').mkdir(parents=True);logs=bundle/'logs';logs.mkdir();empty=out/'empty-cwd';empty.mkdir()
    smoke=out/'world_pack_smoke.gd';smoke.write_text(SMOKE);rows.append({'path':smoke.name,'source':str(smoke),'sha256':sha(smoke),'bytes':smoke.stat().st_size})
    manifest=out/'pack_inputs.json';write(manifest,rows);packer=out/'pack_sources.gd';packer.write_text(producer['PACKER'])
    receipt={'status':'building','source_commit':head,'entry':ENTRY,'candidate_seed':'world-rebuild-01','variant':0,'art_admitted':False,'formal_release':False,'producer_sha256':sha(BASE),'adapter_sha256':sha(__file__),'capture_report_sha256':sha(args.capture_report),'steps':{},'scope':'Local Linux manual candidate startup only; route evidence remains separate; no art/user/market/device/listening acceptance'}
    def check(label,command,cwd,pattern,env={}):
        log=logs/(label+'.log');result=harness.run_check({'argv':command,'timeout_seconds':120,'success_pattern':pattern},log,cwd,{**os.environ,'LIBGL_ALWAYS_SOFTWARE':'1','LP_NUM_THREADS':'1',**env});receipt['steps'][label]={**result,'command':command,'cwd':str(cwd),'log_sha256':sha(log)};write(out/'build_receipt.json',receipt)
        text=log.read_text()
        if result['status']!='passed' or result['exit_code']!=0 or re.search(r'(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)|ObjectDB.*leaked|resources? still in use at exit',text):raise ValueError('Strict step failed '+label)
        return text
    def observed(text):
        found=[json.loads(line.split('WORLD PACK ACTUAL: ',1)[1]) for line in text.splitlines() if line.startswith('WORLD PACK ACTUAL: ')]
        if len(found)!=1 or found[0]!=expected:raise ValueError('Packed actual world snapshot differs from frozen real capture')
        actual=found[0]
        if actual.get('ready') is not True or actual.get('production_pool') is not False or actual.get('legacy_modules')!=0 or not actual.get('actual_collisions') or actual.get('actual_enemies',0)<1:raise ValueError('Incomplete actual world')
        if not actual.get('painting',{}).get('bodies'):raise ValueError('Missing actual paintings')
        return {'actual_snapshot_sha256':hashlib.sha256(json.dumps(actual,sort_keys=True,separators=(',',':')).encode()).hexdigest(),'exact_capture_snapshot_match':True,'actual_body_count':len(actual['actual_collisions']),'actual_enemies':actual['actual_enemies']}
    display=None
    try:
        pack=bundle/'world-review.pck'
        check('pack',['bash','tools/godot.sh','--headless','--path','.', '--script',str(packer),'--',str(manifest),str(pack),str(bundle/'GODOT_LICENSE.txt')],ROOT,r'^ENVIRONMENT SOURCE PACK COMPLETE:')
        pck=Pack(pack)
        if set(pck.entries)!={r['path'] for r in rows}:raise ValueError('PCK closure mismatch')
        for row in rows:
            if hashlib.sha256(pck.read(row['path'])).hexdigest()!=row['sha256']:raise ValueError('PCK byte mismatch '+row['path'])
        engine=bundle/'bin'/ENGINE.name
        try:os.link(ENGINE,engine)
        except OSError:shutil.copy2(ENGINE,engine)
        receipt['engine_sha256']=sha(engine)
        version=subprocess.check_output([str(engine),'--version'],text=True,timeout=10).strip()
        if not re.fullmatch(r'4\.7\.2\.stable\.official\.[A-Za-z0-9]+',version):raise ValueError('Unexpected engine version')
        receipt['engine_version']=version
        common=[str(engine),'--path',str(empty),'--main-pack',str(pack),'--script','res://world_pack_smoke.gd']
        receipt['headless']=observed(check('headless',[*common,'--headless','--audio-driver','Dummy','--','--seed=world-rebuild-01','--variant=0'],empty,r'^WORLD PACK SMOKE COMPLETE:'))
        binary=shutil.which('Xvfb') or str(ROOT.parent/'toolchains/xvfb/usr/bin/Xvfb')
        with (logs/'display.log').open('wb') as dl:
            display=subprocess.Popen([binary,'-displayfd','1','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=dl)
            with selectors.DefaultSelector() as selector:
                selector.register(display.stdout,selectors.EVENT_READ)
                if not selector.select(20):raise ValueError('Display timeout')
                number=display.stdout.readline().decode().strip()
            if not number.isdigit():raise ValueError('Invalid display')
            image=bundle/'actual_packed_gui.png'
            receipt['gui']=observed(check('gui',[*common,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--','--seed=world-rebuild-01','--variant=0'],empty,r'^WORLD PACK SMOKE COMPLETE:',{'DISPLAY':':'+number,'REVIEW_SCREENSHOT_PATH':str(image)}))
        from PIL import Image
        with Image.open(image) as rendered:
            if rendered.size!=(1280,720):raise ValueError('Packed normal viewport size differs')
        if (empty/'project.godot').exists() or source_files(EXTRA)!=before:raise ValueError('Fallback or source drift')
        for row in rows:
            if sha(row['source'])!=row['sha256']:raise ValueError('Packed source drift')
        (bundle/'play.sh').write_text('#!/usr/bin/env bash\nset -euo pipefail\nbundle_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"\nreview_cwd="$(mktemp -d)"\ntrap \'rm -rf -- "$review_cwd"\' EXIT\ncd "$review_cwd"\n"$bundle_dir/bin/'+ENGINE.name+'" --path "$review_cwd" --main-pack "$bundle_dir/world-review.pck" --script res://'+ENTRY+' -- --seed=world-rebuild-01 --variant=0 "$@"\n');(bundle/'play.sh').chmod(0o755)
        (bundle/'README.txt').write_text('失序之钟：连续世界重建候选，未艺术准入。Linux x86_64运行 ./play.sh。A/D移动、空格跳跃、鼠标瞄准与左键射击。保持原PlayerMotor/战斗；不写存档。此包仅有限平原实验，不是完整区域或正式发布。没有真人、手机、手柄或实机听音认可。新图像模型和商用许可未知；Godot许可见GODOT_LICENSE.txt。\n')
        receipt.update(status='strict_local_candidate_smoke_passed_not_release',pck_sha256=sha(pack),pck_bytes=pack.stat().st_size,all_pack_entry_hashes_checked=True,input_count=len(rows),gui_sha256=sha(image),source_before=before,source_after=source_files(EXTRA))
        write(bundle/'version.json',receipt);write(out/'build_receipt.json',receipt)
        archive=out/(bundle.name+'.zip')
        with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for p in sorted(bundle.rglob('*')):
                if p.is_file():z.write(p,p.relative_to(out))
        download={'path':str(archive),'bytes':archive.stat().st_size,'sha256':sha(archive),'source_commit':head,'scope':receipt['scope']};write(out/'download.json',download);print(json.dumps(download))
    except BaseException as exc:
        receipt.update(status='blocked',error=str(exc));write(out/'build_receipt.json',receipt);raise
    finally:
        if display:
            display.terminate()
            try:display.wait(timeout=5)
            except subprocess.TimeoutExpired:display.kill();display.wait(timeout=5)
if __name__=='__main__':main()
