"""Check quality evidence paths in an exact Git commit, without reading evidence bytes.

This G0 closure check does not replace check_quality schema, SHA or quality gates.
It never uses local build files or fetches missing Git objects.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


def git(*args, data=None):
    return subprocess.run(['git', *args], cwd=ROOT, input=data, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=True,
                          env={**os.environ, 'GIT_NO_LAZY_FETCH': '1'}).stdout


def canonical(path):
    return (isinstance(path, str) and bool(path) and '\\' not in path and ':' not in path
            and not any(ord(c) < 32 for c in path) and not PurePosixPath(path).is_absolute()
            and bool(PurePosixPath(path).parts) and PurePosixPath(path).as_posix() == path
            and all(p not in ('.', '..') for p in PurePosixPath(path).parts))


def check(commit):
    resolved = git('rev-parse', '--verify', '--end-of-options', commit + '^{commit}').decode().strip()
    tree = {}
    for item in git('ls-tree', '-r', '-z', '--full-tree', resolved).split(b'\0'):
        if item:
            meta, name = item.split(b'\t', 1)
            tree[name.decode()] = meta.decode().split()
    cards = sorted(p for p in tree if PurePosixPath(p).parent == PurePosixPath('docs/quality/records')
                   and p.endswith('.json'))
    if not cards:
        raise ValueError('No quality cards in specified commit')
    for p in cards:
        if tree[p][0] not in ('100644', '100755') or tree[p][1] != 'blob':
            raise ValueError('Quality card is not a regular Git file: ' + p)
    blobs = git('cat-file', '--batch', data=('\n'.join(tree[p][2] for p in cards) + '\n').encode())
    offset, count, missing = 0, 0, []
    for card in cards:
        end = blobs.index(b'\n', offset)
        header = blobs[offset:end].split()
        if len(header) != 3 or header[1] != b'blob':
            raise ValueError('Quality card blob unavailable locally: ' + card)
        size = int(header[2])
        record = json.loads(blobs[end + 1:end + 1 + size])
        offset = end + 1 + size + 1
        for evidence in record.get('evidence', []):
            count += 1
            ref = evidence if isinstance(evidence, dict) else {}
            path, reason = ref.get('path'), None
            if not canonical(path):
                reason = 'noncanonical_repo_path'
            elif path not in tree:
                reason = 'absent_from_commit_tree'
            elif tree[path][0] not in ('100644', '100755') or tree[path][1] != 'blob':
                reason = 'not_regular_git_file'
            if reason:
                missing.append({'card': card, 'id': ref.get('id'), 'path': path, 'reason': reason})
    return {'commit': resolved, 'card_count': len(cards), 'evidence_count': count,
            'missing_count': len(missing), 'missing': missing}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--commit', default='HEAD')
    args = parser.parse_args()
    started, clock = time.time(), time.monotonic()
    report = {'requested_commit': args.commit, 'status': 'failed', 'started_at_unix': started,
              'scope': 'Commit-tree evidence paths only; schema/SHA/quality remain check_quality responsibility'}
    try:
        report.update(check(args.commit))
        report['status'] = 'passed' if not report['missing'] else 'failed'
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        report['error'] = str(error)
    report.update(ended_at_unix=time.time(), duration_seconds=time.monotonic() - clock)
    folder = ROOT / 'build/verification/release-evidence'
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ') + '_' + uuid.uuid4().hex + '.json')
    with path.open('x') as handle:
        json.dump(report, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    print('RELEASE EVIDENCE: ' + report['status'] + ' ' + str(path.relative_to(ROOT)))
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
