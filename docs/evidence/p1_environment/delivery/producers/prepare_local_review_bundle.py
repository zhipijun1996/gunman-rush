#!/usr/bin/env python3
"""Build-only explicit environment candidate bundle. Read-only plan unless --execute."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT.parent / 'toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64'
BASE_INVENTORY = ROOT / 'docs/evidence/p1_environment/delivery/producers/baseline_asset_paths.json'
ENTRY = 'tools/plains_environment_preview.gd'
CAPTURE = 'tools/plains_environment_capture.gd'
sys.path.insert(0, str(ROOT / 'tools'))
import visual_director as visual
from check_web_bundle import Pack, texture_import_targets

PACKER = '''extends SceneTree
func _initialize() -> void:
\tvar args := OS.get_cmdline_user_args()
\tif args.size() != 3: quit(2); return
\tvar manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
\tif not manifest is Array: quit(2); return
\tvar packer := PCKPacker.new()
\tif packer.pck_start(args[1]) != OK: quit(2); return
\tfor row: Dictionary in manifest:
\t\tif packer.add_file("res://" + str(row.path), str(row.source)) != OK:
\t\t\tpush_error("Candidate pack source refused: " + str(row.path)); quit(2); return
\tif packer.flush() != OK: quit(2); return
\tvar license_file := FileAccess.open(args[2], FileAccess.WRITE)
\tif license_file == null: quit(2); return
\tlicense_file.store_string(Engine.get_license_text())
\tlicense_file.close()
\tprint("ENVIRONMENT SOURCE PACK COMPLETE: ", manifest.size(), " current frozen inputs")
\tquit(0)
'''
SMOKE = '''extends "res://tools/plains_environment_preview.gd"
func run() -> void:
\tawait super.run()
\tif app == null or closing: return
\tfor unused: int in 90:
\t\tawait physics_frame
\t\tawait process_frame
\tvar image_path := OS.get_environment("REVIEW_SCREENSHOT_PATH")
\tif not image_path.is_empty():
\t\tawait RenderingServer.frame_post_draw
\t\tif root.get_texture().get_image().save_png(image_path) != OK:
\t\t\tpush_error("Candidate package GUI image failed")
\tawait close_review()
\tprint("ENVIRONMENT PACK SMOKE COMPLETE: original manual entry; bounded app/audio release; no gameplay driver")
'''
PLAY = '''#!/usr/bin/env bash
set -euo pipefail
bundle_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
review_cwd="$(mktemp -d "${TMPDIR:-/tmp}/plains-environment.XXXXXXXX")"
trap 'rm -rf -- "$review_cwd"' EXIT
cd "$review_cwd"
"$bundle_dir/bin/Godot_v4.7.2-stable_linux.x86_64" --path "$review_cwd" --main-pack "$bundle_dir/environment-review.pck" --script res://tools/plains_environment_preview.gd -- "$@"
'''


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def source_manifest():
    """Archived conservative path seed only; current files/cache supply every byte."""
    baseline = json.loads(BASE_INVENTORY.read_text())
    if baseline.get('schema_version') != 1 or not isinstance(baseline.get('paths'), list):
        raise ValueError('Invalid archived baseline path inventory')
    selected = set()
    for directory in ('scripts', 'scenes', 'resources', 'config', 'shaders', 'addons'):
        selected.update(p.relative_to(ROOT).as_posix() for p in (ROOT / directory).rglob('*')
                        if p.is_file() and p.suffix not in ('.import', '.remap', '.gdc'))
    selected.add('project.godot')
    selected.update(('tools/plains_environment_preview.gd', 'tools/spatial_golden_preview.gd', 'tools/observed_audio_teardown.gd', 'tools/level_capability_snapshot.gd'))
    selected.update(p.relative_to(ROOT).as_posix() for p in (ROOT / 'assets').rglob('*')
                    if p.is_file() and p.suffix in ('.gd', '.uid', '.json', '.gdshader', '.gdshaderinc', '.tres', '.tscn'))
    for name in baseline['paths']:
        if not isinstance(name, str) or not name.startswith('assets/') or '..' in Path(name).parts or name.endswith(('.remap', '.gdc')):
            raise ValueError('Unsafe archived asset path')
        if not (ROOT / name).is_file(): raise ValueError('Missing current conservative asset input: ' + name)
        selected.add(name)
    pending = ['resources/art/avatars.json', 'resources/visual_development/p1_environment_assets.json', 'resources/visual_development/p1_candidate.json']
    visited = set()
    while pending:
        name = pending.pop()
        if name in visited: continue
        visited.add(name)
        path = ROOT / name
        if not path.is_file(): raise ValueError('Missing explicit runtime catalog: ' + name)
        selected.add(name)
        for value in re.findall(r'res://([^"\s]+)', path.read_text()):
            source = ROOT / value
            if source.is_file() and value.startswith(('assets/', 'resources/')):
                selected.add(value)  # Raw PNG is required by runtime source SHA consumers.
                if source.suffix == '.json': pending.append(value)
    for name in list(selected):
        mapping = ROOT / (name + '.import')
        if mapping.is_file(): selected.add(mapping.relative_to(ROOT).as_posix())
    for name in list(selected):
        if not name.endswith('.import'): continue
        for backend in texture_import_targets((ROOT / name).read_text()).values():
            if not (ROOT / backend).is_file(): raise ValueError('Missing current imported backend: ' + backend)
            selected.add(backend)
    for name in ('.godot/global_script_class_cache.cfg', '.godot/uid_cache.bin'):
        if not (ROOT / name).is_file(): raise ValueError('Import/class cache missing: ' + name)
        selected.add(name)
    literal_dependency = re.compile(r'''preload\(["']res://([^"']+)["']\)|\[ext_resource[^\n]*path="res://([^"]+)"''')
    for name in sorted(selected):
        if Path(name).suffix not in ('.gd', '.tscn', '.tres'): continue
        for match in literal_dependency.finditer((ROOT / name).read_text()):
            dependency = match.group(1) or match.group(2)
            if dependency not in selected and dependency + '.import' not in selected:
                raise ValueError('Literal compile/resource dependency missing: ' + name + ' -> ' + dependency)
    return [{'path': name, 'source': str(ROOT / name), 'sha256': sha(ROOT / name), 'bytes': (ROOT / name).stat().st_size}
            for name in sorted(selected)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--expected-commit')
    parser.add_argument('--expected-capture', type=Path)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'build/plains_environment/local_review_01')
    args = parser.parse_args()
    manifest = source_manifest()
    if not args.execute:
        print(json.dumps({'status': 'read_only_prepared_not_executed', 'entry': ENTRY, 'input_count': len(manifest),
                          'estimated_pck_bytes_before_directory': sum(x['bytes'] for x in manifest),
                          'engine_bytes': ENGINE.stat().st_size, 'source_copy': False, 'godot_started': False,
                          'baseline_path_inventory_only': str(BASE_INVENTORY), 'output': str(args.output_dir)}, indent=2))
        return 0
    if not args.expected_commit or not args.expected_capture:
        raise ValueError('Execute requires exact final commit and strict final capture')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if head != args.expected_commit: raise ValueError('HEAD differs from frozen commit')
    captured, native = visual.load_capture(args.expected_capture)
    before = visual.sources(CAPTURE)
    if captured['source_before'] != before or captured['source_after'] != before:
        raise ValueError('Current runtime differs from strict captured source')
    if captured['request'].get('source_commit') != head or captured['request'].get('capture_script') != CAPTURE:
        raise ValueError('Capture is not this exact environment/source entry')
    out = args.output_dir.resolve()
    if not out.is_relative_to(ROOT / 'build/plains_environment') or out.exists():
        raise ValueError('Use a NEW build/plains_environment output directory')
    out.mkdir(parents=True)
    bundle = out / 'plains-environment-candidate-linux-x86_64'
    (bundle / 'bin').mkdir(parents=True)
    logs = bundle / 'logs'; logs.mkdir()
    empty = out / 'isolated-empty-boot'; empty.mkdir()
    smoke = out / 'review_smoke.gd'; smoke.write_text(SMOKE)
    manifest.append({'path': 'review_smoke.gd', 'source': str(smoke), 'sha256': sha(smoke), 'bytes': smoke.stat().st_size})
    manifest_path = out / 'pack_inputs.json'; write(manifest_path, manifest)
    packer_script = out / 'pack_sources.gd'; packer_script.write_text(PACKER)
    receipt = {'status': 'building', 'scope': 'Explicit failed-or-unverified art candidate; local manual review only, not release or artistic/user/device acceptance',
               'source_commit': head, 'capture': visual.artifact(args.expected_capture), 'runtime_sources': before,
               'manifest_hash': native['manifest_hash'], 'entry': ENTRY, 'producer_sha256': sha(__file__),
               'baseline_inventory': {'path': str(BASE_INVENTORY), 'sha256': sha(BASE_INVENTORY), 'scope': 'Archived conservative names only, not a minimum closure; no old PCK required or old bytes copied'},
               'pack_inputs': {'path': str(manifest_path), 'sha256': sha(manifest_path)}, 'steps': {},
               'started_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
    write(out / 'build_receipt.json', receipt)
    import harness
    environment = {**os.environ, 'LP_NUM_THREADS': '1', 'LIBGL_ALWAYS_SOFTWARE': '1'}

    def check(label, command, success, cwd=ROOT, extra_env=None, timeout=120):
        log = logs / (label + '.log')
        result = harness.run_check({'argv': command, 'timeout_seconds': timeout, 'success_pattern': success}, log, cwd,
                                   {**environment, **(extra_env or {})})
        result.update(command=command, cwd=str(cwd), log_sha256=sha(log))
        receipt['steps'][label] = result; write(out / 'build_receipt.json', receipt)
        text = log.read_text()
        if result['status'] != 'passed' or result['exit_code'] != 0 or re.search(r'(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)|ObjectDB.*leaked|resources? still in use at exit', text):
            raise RuntimeError('Strict package ' + label + ' failed; original log retained')
        return text

    def observed_consumer(text):
        def row(prefix):
            lines = [line.split(prefix, 1)[1] for line in text.splitlines() if line.startswith(prefix)]
            if len(lines) != 1: raise ValueError('Missing/duplicate actual packed consumer: ' + prefix)
            return json.loads(lines[0])
        actual = row('PLAINS ENVIRONMENT REVIEW READY: ')
        avatar = row('PLAINS ENVIRONMENT AVATAR READY: ')
        if actual.get('environment_plan') != native['manifest']['environment_plan'] or actual.get('manifest_hash') != native['manifest_hash']:
            raise ValueError('Packed real environment differs from captured shared plan')
        if actual.get('production_pool') is not False or not actual.get('solid_polygons') or not actual.get('saws'):
            raise ValueError('Packed real environment consumer incomplete')
        expected_art = native['environment_initial_physics']['art']
        for key in ('catalog_path', 'catalog_sha256', 'plan_contract_sha256'):
            if not expected_art.get(key) or actual.get('art', {}).get(key) != expected_art[key]:
                raise ValueError('Packed actual art binding differs: ' + key)
        actual_art = actual.get('art', {})
        for key in ('terrain', 'objects', 'layers'):
            if not expected_art.get(key) or len(actual_art.get(key, [])) != len(expected_art[key]):
                raise ValueError('Packed actual art consumer count differs: ' + key)
        if actual_art.get('omitted') != expected_art.get('omitted'):
            raise ValueError('Packed art has a different missing-consumer list')
        def observed_sources(value):
            if isinstance(value, dict):
                if 'source' in value and 'source_sha256' in value:
                    source = value['source'].removeprefix('res://')
                    if value['source_sha256'] != before.get(source) or not before.get(source):
                        raise ValueError('Packed actual rendered source hash mismatch: ' + source)
                for child in value.values(): observed_sources(child)
            elif isinstance(value, list):
                for child in value: observed_sources(child)
        observed_sources(actual_art)
        if avatar.get('selected_id') != 'p1_girl' or avatar.get('painted_owner_count') != 1 or avatar.get('gameplay_changed') is not False:
            raise ValueError('Packed actual avatar missing/duplicated')
        for path_key, hash_key in (('source_calibration', 'source_sha256'), ('texture_source', 'texture_sha256')):
            path = avatar.get(path_key, '').removeprefix('res://')
            if avatar.get(hash_key) != before.get(path) or not before.get(path):
                raise ValueError('Packed avatar source hash mismatch')
        return {'environment': actual, 'avatar': avatar}

    display = None; display_log = None
    try:
        pack = bundle / 'environment-review.pck'
        check('pack', ['bash', 'tools/godot.sh', '--headless', '--path', '.', '--script', str(packer_script), '--', str(manifest_path), str(pack), str(bundle / 'GODOT_LICENSE.txt')], r'^ENVIRONMENT SOURCE PACK COMPLETE:')
        actual_pack = Pack(pack)
        if set(actual_pack.entries) != {item['path'] for item in manifest}: raise ValueError('Actual PCK directory differs from exact current-input manifest')
        for item in manifest:
            if hashlib.sha256(actual_pack.read(item['path'])).hexdigest() != item['sha256']:
                raise ValueError('Actual PCK bytes mismatch: ' + item['path'])
        receipt['actual_pck_closure'] = {'entry_count': len(manifest), 'all_entry_sha256_checked': True, 'raw_gd_not_old_gdc': True, 'raw_json_and_png_preserved': True}
        engine = bundle / 'bin' / ENGINE.name; shutil.copy2(ENGINE, engine); engine.chmod(0o755)
        receipt['engine_sha256'] = sha(engine)
        version = subprocess.check_output([str(engine), '--version'], text=True, timeout=10).strip()
        if not re.fullmatch(r'4\.7\.2\.stable\.official\.[A-Za-z0-9]+', version): raise ValueError('Wrong Standard engine')
        receipt['engine_version'] = version
        command = [str(engine), '--headless', '--path', str(empty), '--main-pack', str(pack), '--script', 'res://review_smoke.gd', '--audio-driver', 'Dummy', '--quit-after', '600']
        text = check('isolated_headless', command, r'^ENVIRONMENT PACK SMOKE COMPLETE:', empty, timeout=90)
        receipt['headless_consumer'] = observed_consumer(text)
        binary = shutil.which('Xvfb') or str(ROOT.parent / 'toolchains/xvfb/usr/bin/Xvfb')
        display_log = (logs / 'display.log').open('wb')
        display = subprocess.Popen([binary, '-displayfd', '1', '-screen', '0', '1280x720x24', '-nolisten', 'tcp', '-ac'], stdout=subprocess.PIPE, stderr=display_log)
        with selectors.DefaultSelector() as selector:
            selector.register(display.stdout, selectors.EVENT_READ)
            if not selector.select(20): raise RuntimeError('Xvfb readiness timeout')
            number = display.stdout.readline().decode().strip()
        if not number.isdigit(): raise ValueError('Invalid Xvfb display')
        screenshot = bundle / 'actual_packed_gui.png'
        command = [str(engine), '--rendering-method', 'gl_compatibility', '--path', str(empty), '--main-pack', str(pack), '--script', 'res://review_smoke.gd', '--audio-driver', 'ALSA', '--quit-after', '600']
        text = check('isolated_gui', command, r'^ENVIRONMENT PACK SMOKE COMPLETE:', empty, {'DISPLAY': ':' + number, 'REVIEW_SCREENSHOT_PATH': str(screenshot)}, timeout=90)
        receipt['gui_consumer'] = observed_consumer(text)
        from PIL import Image
        with Image.open(screenshot) as image:
            if image.size != (1280, 720): raise ValueError('Packed GUI resolution mismatch')
        if (empty / 'project.godot').exists(): raise ValueError('Isolated boot acquired source-project fallback')
        if visual.sources(CAPTURE) != before: raise ValueError('Runtime source drift during packaging')
        for item in manifest:
            if sha(item['source']) != item['sha256']: raise ValueError('Imported/current input drift: ' + item['path'])
        receipt.update(status='strict_local_candidate_smoke_passed_not_release', pck_sha256=sha(pack), pck_bytes=pack.stat().st_size,
                       build_id=sha(pack)[:12], gui_sha256=sha(screenshot), isolated_empty_boot=True, manual_entry_no_driver_no_save=True,
                       ended_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                       limits='Startup/actual consumer/strict cleanup only; no route replay, visual acceptance, listening or physical device acceptance inferred')
        (bundle / 'play.sh').write_text(PLAY); (bundle / 'play.sh').chmod(0o755)
        (bundle / 'README.txt').write_text('风铃平原整体环境开发候选 · Linux x86_64\n\n运行 ./play.sh。A/D或方向键移动，空格跳，鼠标瞄准/左键射击。右上角可选择原信使、围巾旅人或修钟少女，仅改变会话外观。\n\n当前画面可能已被艺术审查要求返工；这是原样候选手动试玩，非正式发布、完整地区、艺术定稿或设备认可。version.json列出准确源与验证范围。资源全部来自PCK，使用空工作目录，无自动驾驶、能力注入或Meta写入。Godot采用MIT许可，见GODOT_LICENSE.txt；游戏资产沿原项目来源，不新增商店发布授权。\n')
        write(bundle / 'version.json', receipt); write(out / 'build_receipt.json', receipt)
        archive = out / (bundle.name + '.zip')
        with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
            for path in sorted(bundle.rglob('*')):
                if path.is_file(): zipped.write(path, path.relative_to(out))
        download = {'path': str(archive), 'sha256': sha(archive), 'bytes': archive.stat().st_size, 'build_id': receipt['build_id'], 'source_commit': head, 'scope': receipt['scope']}
        write(out / 'download.json', download); print(json.dumps(download, indent=2))
    except BaseException as error:
        receipt.update(status='blocked', error=type(error).__name__ + ': ' + str(error), ended_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
        write(out / 'build_receipt.json', receipt)
        raise
    finally:
        if display:
            display.terminate()
            try: display.wait(timeout=5)
            except subprocess.TimeoutExpired: display.kill(); display.wait(timeout=5)
        if display_log: display_log.close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
