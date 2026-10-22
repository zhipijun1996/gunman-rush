#!/usr/bin/env python3
"""Choose review evidence and stage immutable Godot previews; never deploy main."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HOST_REPOSITORY = "zhipijun1996/gunman-rush-previews"
HOST_URL = "https://zhipijun1996.github.io/gunman-rush-previews/"
BOOTSTRAP = "scenes/dev/cloud_preview.tscn"
LIMIT = 900 * 1024 * 1024
KIND_NEEDS = {
    'local_animation': ('observe',), 'local_vfx': ('observe',),
    'controls': ('interact',), 'weapon': ('observe', 'interact'),
    'enemy': ('observe', 'interact'), 'boss': ('observe', 'interact'),
    'region': ('interact',), 'ui': ('observe', 'interact'),
    'home': ('interact',), 'tool': ('engineering',), 'performance': ('engineering',),
}


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def select_delivery(observe=False, interact=False, engineering=False, long_task=False, kind=None):
    if kind is not None and kind not in KIND_NEEDS:
        raise ValueError('Unknown task kind: ' + str(kind))
    defaults = KIND_NEEDS.get(kind, ())
    explicit = [name for name, value in (('observe', observe), ('interact', interact), ('engineering', engineering)) if value]
    observe = observe or 'observe' in defaults
    interact = interact or 'interact' in defaults
    engineering = engineering or 'engineering' in defaults
    if observe and interact:
        delivery, reason = 'both', 'Visual detail and hands-on control both require review.'
    elif interact:
        delivery, reason = 'web', 'The reviewer must operate the real game.'
    elif observe:
        delivery, reason = 'video', 'A short continuous engine recording can demonstrate the change.'
    elif engineering:
        delivery, reason = 'engineering', 'No direct visual change: use actual tests, metrics and logs.'
    else:
        raise ValueError('Declare --observe, --interact or --engineering; task size alone is insufficient')
    if kind:
        reason = 'Task kind ' + kind + ' requires ' + ', '.join(defaults) + '. ' + reason
    if long_task:
        reason += ' Milestone checkpoints accompany this evidence; duration does not choose the medium.'
    evidence = (['video', 'web'] if delivery == 'both' else [delivery])
    if engineering and 'engineering' not in evidence:
        evidence.append('engineering')
        reason += ' Engineering tests, metrics and logs are also required.'
    if long_task:
        evidence.append('milestone')
    return {'delivery': delivery, 'milestone': long_task, 'reason': reason,
            'kind': kind, 'kind_source': 'task_kind' if kind else 'explicit_flags',
            'default_needs': list(defaults), 'explicit_needs': explicit, 'required_evidence': evidence,
            'review': 'Human aesthetics, feel and fun remain unverified until actual feedback.'}


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()


def validate_task(task):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,63}', task):
        raise ValueError('Task ID must be 1–64 ASCII letters, digits, underscores or hyphens')


def clean_runtime(root):
    changed = subprocess.check_output(['git', '-C', str(root), 'diff', '--name-only', '-z', 'HEAD']).decode().split('\0')
    changed += subprocess.check_output(['git', '-C', str(root), 'ls-files', '--others', '--exclude-standard', '-z']).decode().split('\0')
    prefixes = ('scripts/', 'scenes/', 'resources/', 'assets/', 'config/', 'shaders/', 'addons/', 'tools/')
    dirty = [p for p in changed if p.startswith(prefixes) or p in ('project.godot', 'export_presets.cfg')]
    if dirty:
        raise ValueError('Runtime source is dirty; commit and rebuild before staging: ' + ', '.join(dirty))


def validate_host(root):
    root = Path(root).resolve()
    remote = git(root, 'remote', 'get-url', 'origin')
    accepted = ('https://github.com/' + HOST_REPOSITORY, 'git@github.com:' + HOST_REPOSITORY)
    if remote.removesuffix('.git').rstrip('/') not in accepted:
        raise ValueError('Preview host origin must be the isolated ' + HOST_REPOSITORY + '; main hosting is forbidden')
    return root


def no_links(root):
    if root.is_symlink() or any(p.is_symlink() for p in root.rglob('*')):
        raise ValueError('Symlinks are not permitted in preview bundles or hosting trees')


def validate_scene(scene):
    if (not isinstance(scene, str) or not scene.startswith('res://scenes/')
            or not scene.endswith('.tscn') or '..' in scene or '\\' in scene
            or any(ord(c) < 32 for c in scene)):
        raise ValueError('Scene must be a safe res://scenes/*.tscn path without traversal or backslashes')
    relative = scene.removeprefix('res://')
    if any(part in ('', '.') or ':' in part for part in relative.split('/')):
        raise ValueError('Scene must use canonical res://scenes/*.tscn path components')
    if relative == BOOTSTRAP:
        raise ValueError('Preview bootstrap cannot recursively load itself')
    return relative


def validate_bundle(bundle, source_root, scene=None):
    from style_exploration_delivery import reconstruct_pack, resource
    from check_web_bundle import Pack
    bundle, source_root = Path(bundle).resolve(), Path(source_root).resolve()
    no_links(bundle)
    clean_runtime(source_root)
    head = git(source_root, 'rev-parse', 'HEAD')
    info = json.loads((bundle / 'build-info.json').read_text())
    if info.get('source_commit') != head or not re.fullmatch(r'[0-9a-f]{40}', head):
        raise ValueError('Bundle source SHA is not the exact current HEAD; rebuild instead of relabeling')
    report = json.loads((bundle / 'build_report.json').read_text())
    if report.get('platform') != 'web' or report.get('export_exit_code') != 0 or not report.get('artifacts'):
        raise ValueError('Missing successful original Web export report')
    prefix = bundle.relative_to(source_root)
    seen = set()
    for entry in report['artifacts']:
        name = Path(entry['path'])
        if name.is_absolute() or '..' in name.parts:
            raise ValueError('Unsafe original export artifact path')
        relative = name.relative_to(prefix)
        path = bundle / relative
        if relative in seen or not path.is_file() or path.stat().st_size != entry['bytes'] or sha(path) != entry['sha256']:
            raise ValueError('Original export artifact bytes changed: ' + str(relative))
        seen.add(relative)
    required = {Path('index.html'), Path('build-info.json'), Path('index.cache-sw.js'), Path(info['pack'])}
    if not required <= seen:
        raise ValueError('Original export report does not cover HTML, metadata, worker and PCK')
    receipt = reconstruct_pack(bundle)
    pack = Pack(bundle / info['pack'])
    if not resource(pack, BOOTSTRAP):
        raise ValueError('Preview bootstrap is absent from actual exported PCK')
    if scene is not None and not resource(pack, validate_scene(scene)):
        raise ValueError('Requested test scene is absent from actual exported PCK')
    return info, receipt


def inject_entry(page, task, seed, entry, scene=None):
    marker = 'engine.startGame({'
    if page.count(marker) != 1 or 'cloud-preview-entry' in page:
        raise ValueError('Expected a fresh official Godot startGame call')
    args = ['res://' + BOOTSTRAP, '--', '--task=' + task, '--seed=' + seed, '--entry=' + entry]
    if scene is not None:
        args.append('--scene=' + scene)
    page = page.replace(marker, marker + '\n/* cloud-preview-entry */ args: ' + json.dumps(args).replace('<', '\\u003c') + ',')
    badge = '<div style="position:fixed;right:6px;bottom:6px;z-index:30;background:#182131dd;color:white;padding:5px;font:12px sans-serif">开发 Preview · ' + html.escape(task) + ' · 非正式发布</div>'
    return page.replace('</body>', badge + '\n</body>')


def list_previews(site):
    result = []
    for path in sorted((site / 'previews').rglob('preview.json')):
        data = json.loads(path.read_text())
        validate_task(data['task'])
        expected = Path('previews') / data['task'] / data['source_commit'] / data['build_id']
        if not re.fullmatch(r'[0-9a-f]{40}', data['source_commit']) or not re.fullmatch(r'[0-9a-f]{12}', data['build_id']) or path.parent.relative_to(site) != expected:
            raise ValueError('Preview identity/path mismatch: ' + str(path))
        result.append((path.parent, data))
    return result


def index_page(site):
    links = []
    for path, data in list_previews(site):
        relative = path.relative_to(site).as_posix() + '/'
        links.append('<li><a href="' + relative + '">' + html.escape(data['task'] + ' / ' + data['source_commit'][:12] + ' / ' + data['build_id']) + '</a> · Seed ' + html.escape(data['seed']) + '</li>')
    (site / 'index.html').write_text('<!doctype html><meta charset="utf-8"><title>失序之钟 · 开发预览</title><h1>开发 Preview</h1><p>以下为独立开发版本；审美、手感和设备体验以真人反馈为准。</p><ul>' + ''.join(links) + '</ul><p><a href="https://zhipijun1996.github.io/gunman-rush/">正式试玩</a></p>')


def validate_site(site, reconstruct=True):
    from style_exploration_delivery import reconstruct_pack
    no_links(site)
    results = []
    for folder, data in list_previews(site):
        for name, expected in data['files'].items():
            if Path(name).is_absolute() or '..' in Path(name).parts or '\\' in name:
                raise ValueError('Unsafe staged file inventory')
            path = folder / name
            if not path.is_file() or sha(path) != expected:
                raise ValueError('Staged preview bytes changed: ' + str(path))
        receipt = reconstruct_pack(folder) if reconstruct else data['pack_verification']
        if receipt['source_commit'] != data['source_commit'] or receipt['build_id'] != data['build_id'] or receipt['pack_sha256'] != data['pack_verification']['pack_sha256']:
            raise ValueError('Reconstructed preview identity differs')
        results.append(receipt)
    if not results:
        raise ValueError('Refusing an empty preview site')
    amount = sum(p.stat().st_size for p in site.rglob('*') if p.is_file())
    if amount > LIMIT:
        raise ValueError('Preview site exceeds 900MiB; explicitly retire history or change hosting, never silently delete it')
    return {'status': 'verified', 'scope': 'Export bytes and immutable hosting; GUI, feel and devices unverified', 'bytes': amount, 'previews': results}


def stage_preview(bundle, host_root, task, seed, entry='actions', pr=None, source_root=ROOT, scene=None):
    validate_task(task)
    if entry not in ('actions', 'menu', 'scene') or not seed or len(seed) > 256 or any(ord(c) < 32 for c in seed):
        raise ValueError('Invalid preview entry or Seed')
    if entry == 'scene':
        validate_scene(scene)
    elif scene is not None:
        raise ValueError('--scene is accepted only with --entry scene')
    if pr is not None and pr <= 0:
        raise ValueError('PR must be positive')
    host_root = validate_host(host_root)
    source_root, bundle = Path(source_root).resolve(), Path(bundle).resolve()
    info, receipt = validate_bundle(bundle, source_root, scene)
    identity = Path('previews') / task / info['source_commit'] / info['build_id']
    site = host_root / 'site'
    destination = site / identity
    no_links(host_root)
    if destination.exists():
        raise ValueError('Immutable preview already exists; refusing overwrite')
    site.mkdir(exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix='.cloud-preview-', dir=host_root))
    published = False
    try:
        candidate = temporary / 'bundle'
        shutil.copytree(bundle, candidate)
        original_html = sha(candidate / 'index.html')
        (candidate / 'index.html').write_text(inject_entry((candidate / 'index.html').read_text(), task, seed, entry, scene))
        # Git transports checked chunks; Pages reconstructs the exact original PCK.
        (candidate / info['pack']).unlink()
        for path in candidate.rglob('*'):
            if path.is_file() and path.stat().st_size >= 100 * 1024 * 1024:
                raise ValueError('Git transport file exceeds 100MiB: ' + path.name)
        metadata = {'schema_version': 1, 'task': task, 'pr': pr, 'source_commit': info['source_commit'], 'build_id': info['build_id'], 'seed': seed, 'entry': entry, 'scene': scene,
                    'url': HOST_URL + identity.as_posix() + '/', 'original_html_sha256': original_html, 'pack_verification': receipt,
                    'validation': 'Original export report and exact PCK verified; browser/GUI and player acceptance unverified. Custom scenes must be self-contained and require actual consumer validation.',
                    'files': {p.relative_to(candidate).as_posix(): sha(p) for p in sorted(candidate.rglob('*')) if p.is_file()}}
        write_json(candidate / 'preview.json', metadata)
        # Include raw PCK expansion in the cap without writing it into Git.
        current = sum(p.stat().st_size for p in site.rglob('*') if p.is_file())
        expansion = sum(d['pack_verification']['pack_bytes'] for p, d in list_previews(site) if not (p / d['pack_verification']['pack']).exists())
        candidate_size = sum(p.stat().st_size for p in candidate.rglob('*') if p.is_file()) + info['pack_bytes']
        if current + expansion + candidate_size > LIMIT:
            raise ValueError('Preview site would exceed 900MiB after PCK reconstruction')
        clean_runtime(source_root)
        if git(source_root, 'rev-parse', 'HEAD') != info['source_commit']:
            raise ValueError('Source HEAD changed during preview staging')
        destination.parent.mkdir(parents=True, exist_ok=True)
        candidate.rename(destination)
        published = True
        latest = site / 'previews' / task / 'latest'
        latest.mkdir(exist_ok=True)
        target = '../' + info['source_commit'] + '/' + info['build_id'] + '/'
        (latest / 'index.html').write_text('<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=' + target + '"><a href="' + target + '">打开最新开发预览</a>')
        index_page(site)
        (site / '.nojekyll').touch()
        helper = host_root / '_tools'
        helper.mkdir(exist_ok=True)
        for name in ('style_exploration_delivery.py', 'cloud_delivery.py'):
            shutil.copyfile(source_root / 'tools' / name, helper / name)
        workflows = host_root / '.github/workflows'
        workflows.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source_root / 'tools/preview_host_workflow.yml', workflows / 'preview.yml')
        return metadata
    except BaseException as error:
        # Before publishing, failure leaves no playable identity behind.
        if not published:
            shutil.rmtree(destination, ignore_errors=True)
        else:
            raise ValueError('Partial staging retained at ' + str(destination)
                             + '; the immutable preview identity must not be overwritten. '
                             + 'Inspect the retained preview.json and files, then complete the hosting '
                             + 'helpers, workflow, index and latest link before committing. '
                             + 'Do not treat this partial staging as a successful deployment. Cause: '
                             + str(error)) from error
        raise
    finally:
        shutil.rmtree(temporary, ignore_errors=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    choose = commands.add_parser('select')
    choose.add_argument('--kind', choices=tuple(KIND_NEEDS))
    for flag in ('observe', 'interact', 'engineering', 'long-task'):
        choose.add_argument('--' + flag, action='store_true')
    stage = commands.add_parser('stage-preview')
    stage.add_argument('--bundle', type=Path, default=ROOT / 'build/web')
    stage.add_argument('--host-root', type=Path, required=True)
    stage.add_argument('--task', required=True)
    stage.add_argument('--pr', type=int)
    stage.add_argument('--seed', required=True)
    stage.add_argument('--entry', choices=('actions', 'menu', 'scene'), default='actions')
    stage.add_argument('--scene', help='Self-contained res://scenes/*.tscn test scene; requires --entry scene and actual consumer validation')
    verify = commands.add_parser('verify-host')
    verify.add_argument('--host-root', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'select':
        result = select_delivery(args.observe, args.interact, args.engineering, args.long_task, args.kind)
    elif args.command == 'stage-preview':
        result = stage_preview(args.bundle, args.host_root, args.task, args.seed, args.entry, args.pr, scene=args.scene)
    else:
        host = validate_host(args.host_root)
        result = validate_site(host / 'site')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        raise SystemExit('Cloud delivery failed: ' + str(error))
