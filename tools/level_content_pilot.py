#!/usr/bin/env python3
"""Run a bounded design experiment with the existing Godot consumer, serially.

Raw failing traces are retained. Expected ablations are experiment evidence,
never physical passes. Cache entries bind every materialized runtime byte and
the actual native log; no static label can enter the measured archive.
"""
import argparse
from contextlib import redirect_stdout
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from level_content import archive, digest, sha, write
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use at exit')
_ENGINE_CACHE = {}
_FILE_CACHE = {}


def source_sha(path):
    stat = path.stat()
    key = (str(path.resolve()), stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns)
    if key not in _FILE_CACHE: _FILE_CACHE[key] = sha(path)
    return _FILE_CACHE[key]


def engine_identity(root):
    toolchain = Path(os.environ.get('GUNMAN_TOOLCHAIN_ROOT', root.parent / 'toolchains'))
    path = Path(os.environ.get('GODOT_BIN', toolchain / 'godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64'))
    if not path.is_file() or not os.access(path, os.X_OK):
        fallback = shutil.which('godot') or shutil.which('godot4')
        if not fallback: raise ValueError('Actual Godot binary unavailable')
        path = Path(fallback)
    path = path.resolve()
    stat = path.stat()
    key = (str(path), stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns)
    if key not in _ENGINE_CACHE:
        version = subprocess.check_output([str(path), '--version'], text=True, timeout=10).strip()
        if not version.startswith('4.7.2.stable.official.') or 'mono' in version:
            raise ValueError('Wrong real engine: ' + version)
        _ENGINE_CACHE[key] = {'version': version, 'binary_sha256': sha(path), 'bytes': stat.st_size,
                              'binary': str(path)}
    return _ENGINE_CACHE[key]


def snapshot(root, catalog=None):
    paths = []
    for folder in ('scripts', 'scenes', 'resources', 'config', 'assets', 'shaders', 'addons', 'game'):
        paths += [p for p in (root / folder).rglob('*') if p.is_file()]
    paths += [root / p for p in ('project.godot', 'tools/level_pilot_validate.gd',
                                'tools/level_content_pilot.py', 'tools/level_content.py',
                                'tools/run_tests.py', 'tools/godot.sh',
                                'tests/branch_module_driver.gd', 'tests/audio_teardown.gd',
                                'tests/plains_exploration_motion.gd', 'tests/plains_interactive_motion.gd')]
    identity_path = root / 'build/ai_level_design_v1/engine-identity.json'
    write(identity_path, engine_identity(root))
    paths.append(identity_path)
    if catalog:
        extra = (root / catalog).resolve()
        if not extra.is_relative_to(root.resolve()) or not extra.is_file(): raise ValueError('Unsafe or missing catalog')
        paths.append(extra)
    return {str(p.relative_to(root)): source_sha(p) for p in sorted(set(paths)) if p.suffix != '.import'}


def cached_valid(old, raw_path, log, identity, request, root):
    if (old.get('identity') != identity or not raw_path.is_file() or not log.is_file()
            or old.get('raw_sha256') != sha(raw_path) or old.get('log_sha256') != sha(log)
            or old.get('terminal') != 'completed' or old.get('source_stable') is not True):
        return False
    if old.get('engine_identity') != engine_identity(root): return False
    raw, output = json.loads(raw_path.read_text()), log.read_text()
    if (ERROR.search(output) or not raw.get('frames')
            or raw.get('candidate') != request['candidate'] or raw.get('strategy') != request['strategy']
            or raw.get('variant') != request['variant']
            or raw.get('source_hash') != sha(root / 'tools/level_pilot_validate.gd')
            or raw.get('catalog_sha256') != sha(root / request['catalog'])
            or 'LEVEL PILOT RECEIPT_SHA256: ' + sha(raw_path) not in output):
        return False
    native_pass = raw.get('passed') is True and raw.get('ok') is True and raw.get('exit_code') == 0
    terminal_line = 'LEVEL PILOT: ' + ('PASS' if native_pass else 'FAIL') + ' / ' + request['candidate'] + ' / ' + request['strategy']
    if terminal_line not in output or old.get('technical_pass') is not native_pass: return False
    if native_pass:
        from level_content_contract import make_content, _physics_receipt, PILOT_SCOPE
        content = make_content(request['candidate'], 'module', 'pilot', 'tools/level_pilot_validate.gd',
                               '0' * 40, sha(root / 'tools/level_pilot_validate.gd'))
        content['runtime']['consumer'] = raw.get('runtime_consumer', '')
        return _physics_receipt(raw_path, content, {'scope': PILOT_SCOPE}, root)
    return True


def run_case(root, folder, request, source, reuse=False):
    identity = digest({'request': request, 'runtime_bytes': source})
    if reuse:
        for previous in sorted(folder.glob(identity[:20] + '*'), reverse=True):
            try:
                old = json.loads((previous / 'receipt.json').read_text())
                if cached_valid(old, previous / 'native.json', previous / 'native.log', identity, request, root):
                    return old, json.loads((previous / 'native.json').read_text()), True
            except (OSError, ValueError, KeyError):
                pass
    dest = folder / identity[:20]
    if dest.exists(): dest = folder / (identity[:20] + '-attempt-' + str(time.time_ns()))
    receipt, raw_path, log = dest / 'receipt.json', dest / 'native.json', dest / 'native.log'
    dest.mkdir(parents=True, exist_ok=False)
    relative = raw_path.relative_to(root)
    args = ['--headless', '--fixed-fps', '60', '--path', '.', '--script', 'tools/level_pilot_validate.gd', '--',
            '--candidate=' + request['candidate'], '--strategy=' + request['strategy'],
            '--variant=' + str(request['variant']), '--output=res://' + str(relative)]
    if request.get('catalog'): args.append('--catalog=res://' + request['catalog'])
    before, started = digest(snapshot(root, request.get('catalog'))), time.monotonic()
    # run_engine is the existing strict error/teardown/timeout guard. A native
    # exit1 may be an ordinary retained design refusal, not an infrastructure pass.
    exception = None
    with log.open('w') as stream, redirect_stdout(stream):
        try: output = run_engine(args, 90)
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
            exception = str(error)
            print('STRICT_RUNNER_REFUSAL: ' + exception)
    raw = json.loads(raw_path.read_text()) if raw_path.exists() else {}
    text = log.read_text()
    completed = (bool(raw.get('frames')) and 'LEVEL PILOT:' in text and not ERROR.search(text)
                 and 'LEVEL PILOT RECEIPT_SHA256: ' + sha(raw_path) in text)
    stable = before == digest(source) == digest(snapshot(root, request.get('catalog')))
    native_pass = completed and raw.get('passed') is True and not exception
    value = {'schema_version': 1, 'identity': identity, 'request': request,
             'engine_identity': engine_identity(root),
             'source_fingerprint': digest(source), 'runtime_source': source,
             'command': ['bash', 'tools/godot.sh', *args],
             'seconds': round(time.monotonic()-started, 3),
             'terminal': 'completed' if completed and stable else 'blocked',
             'technical_pass': native_pass and stable, 'strict_runner_error': exception,
             'source_stable': stable, 'raw_path': str(raw_path.relative_to(root)) if raw_path.exists() else None,
             'raw_sha256': sha(raw_path) if raw_path.exists() else None, 'log_sha256': sha(log),
             'expected_ablation': request['strategy'] == 'no_jump',
             'scope': 'isolated Module Router Controller Motor; no formal map/admission, rewards or human judgment'}
    write(receipt, value)
    return value, raw, False


def execute(args):
    root = ROOT
    folder = root / args.output
    catalog_path = root / args.catalog
    catalog = json.loads(catalog_path.read_text())
    candidates = catalog['candidates']
    if args.only: candidates = [c for c in candidates if c['id'] in args.only]
    if not candidates: raise ValueError('No requested candidates')
    source = snapshot(root, args.catalog)
    results, receipts, blocked = [], [], []
    for candidate in candidates:
        strategies = args.strategies or candidate['strategies']
        for variant in args.variants:
            for strategy in strategies:
                request = {'candidate': candidate['id'], 'strategy': strategy, 'variant': variant,
                           'catalog': args.catalog}
                receipt, raw, reused = run_case(root, folder / 'cases', request, source, args.reuse)
                receipts.append(receipt)
                if receipt['terminal'] == 'blocked': blocked.append(receipt['identity'])
                if raw:
                    results.append({'id': candidate['id'], 'variant': variant, 'condition': strategy,
                                    'ok': receipt['technical_pass'], 'errors': raw.get('failures', []) + raw.get('danger_contacts', []),
                                    'frames': raw.get('frames', []), 'raw_path': receipt['raw_path'],
                                    'raw_sha256': receipt['raw_sha256']})
                print(f"CASE: {candidate['id']}/{strategy}/v{variant} {receipt['terminal']} physical={receipt['technical_pass']} cache={reused}", flush=True)
                if blocked: break
            if blocked: break
        if blocked: break
    summary = {'schema_version': 1, 'source_fingerprint': digest(source), 'source_commit': subprocess.check_output(
                ['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
               'catalog_sha256': sha(catalog_path), 'results': results, 'receipts': receipts,
               'source_identity_scope': 'source_commit is base Git HEAD; runtime_source binds materialized bytes and uncommitted overlays',
               'blocked': blocked, 'failures_retained': sum(not r['technical_pass'] for r in receipts),
               'human': 'unverified', 'fun': 'unverified'}
    write(folder / 'experiment.json', summary)
    archive(folder / 'experiment.json', folder / 'archive.json')
    if blocked: raise ValueError('Experiment blocked; inspect retained native logs: ' + ', '.join(blocked))
    print('PILOT EXPERIMENT: completed with physical failures retained; human fun unverified')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--catalog', default='config/level_pilot_candidates.json')
    p.add_argument('--output', default='build/ai_level_design_v1/pilot')
    p.add_argument('--only', nargs='+')
    p.add_argument('--strategies', nargs='+', choices=['main', 'reward', 'direct', 'near_reward', 'no_jump'])
    p.add_argument('--variants', nargs='+', type=int, choices=[0, 1], default=[0])
    p.add_argument('--reuse', action='store_true')
    args = p.parse_args()
    try: execute(args)
    except (ValueError, OSError, KeyError) as error:
        print('PILOT BLOCKED: ' + str(error), file=sys.stderr); return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
