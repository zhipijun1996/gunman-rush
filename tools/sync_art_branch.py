"""Finite read-only branch monitor; never merges or overwrites gameplay files."""
import argparse
import json
from pathlib import Path
import subprocess
import time

def git(*args):
    return subprocess.run(['git', *args], check=True, text=True, capture_output=True).stdout.strip()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--branch', required=True)
    parser.add_argument('--remote', default='origin')
    parser.add_argument('--watch', type=int, default=1, help='Number of checks; default once')
    parser.add_argument('--interval', type=int, default=30)
    args = parser.parse_args()
    if not 1 <= args.watch <= 120 or not 5 <= args.interval <= 60:
        parser.error('watch must be 1..120; interval 5..60 seconds')
    git('check-ref-format', '--branch', args.branch)
    previous = None
    report_dir = Path('.art_sync')
    report_dir.mkdir(exist_ok=True)
    for index in range(args.watch):
        git('fetch', '--no-tags', args.remote, f'refs/heads/{args.branch}')
        current = git('rev-parse', 'FETCH_HEAD')
        changed = git('diff', '--name-only', previous, current).splitlines() if previous else []
        contracts = [path for path in changed if path.startswith(('scenes/', 'scripts/', 'resources/', 'docs/', 'config/'))]
        report = {'branch': args.branch, 'commit': current, 'previous': previous,
                  'changed_files': changed, 'review_art_integration': contracts,
                  'checked_at_unix': int(time.time()), 'mode': 'fetch_only_no_merge'}
        (report_dir / 'latest.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report), flush=True)
        previous = current
        if index + 1 < args.watch:
            time.sleep(args.interval)

if __name__ == '__main__':
    main()
