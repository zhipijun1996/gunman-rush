"""Fully download both deployed comparison packs and immutable engine files."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import urllib.request


def download(url):
    digest, amount = hashlib.sha256(), 0
    with urllib.request.urlopen(urllib.request.Request(url, headers={'Cache-Control':'no-cache'}), timeout=180) as response:
        status, final_url = response.status, response.url
        while block := response.read(1024 * 1024):
            digest.update(block)
            amount += len(block)
    return {'url':url, 'final_url':final_url, 'status':status, 'bytes':amount, 'sha256':digest.hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root-url', required=True)
    parser.add_argument('--prepared', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    report = {'time_utc':datetime.now(timezone.utc).isoformat(), 'root_url':args.root_url,
        'scope':'Actual full HTTP response bytes, not only metadata/headers/chunk hashes; no device acceptance', 'results':[]}
    jobs = []
    for directory in ('', 'audio-before/'):
        root = args.prepared / directory
        expected = json.loads((root / 'build-info.json').read_text())
        url = args.root_url + directory
        with urllib.request.urlopen(url + 'build-info.json?audit=' + expected['build_id'], timeout=90) as response:
            actual = json.load(response)
        assert actual == expected, (actual,expected)
        receipt = json.loads((args.prepared / 'audio-comparison.json').read_text())['before' if directory else 'after']
        jobs.append((url+expected['pack'], receipt['pack_bytes'], receipt['pack_sha256']))
        for suffix in ('.js','.wasm','.audio.worklet.js','.audio.position.worklet.js'):
            name = 'index.' + expected['engine_id'] + '.engine' + suffix
            local = root / name
            jobs.append((url+name, local.stat().st_size, hashlib.sha256(local.read_bytes()).hexdigest()))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=2) as executor:
        for (url, size, digest), result in zip(jobs, executor.map(download, [job[0] for job in jobs])):
            report['results'].append(result)
            args.output.write_text(json.dumps(report, indent=2)+'\n')
            assert result['status']==200 and result['bytes']==size and result['sha256']==digest, result
    report['failed']=0
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({'checked':len(jobs),'failed':0,'output':str(args.output)}))


if __name__ == '__main__':
    main()
