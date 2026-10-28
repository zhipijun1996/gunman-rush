import datetime
import hashlib
import json
import pathlib
import re
import time
import urllib.parse
import urllib.request

root = pathlib.Path(__file__).resolve().parents[2]
bundle = root / 'build/web'
out = pathlib.Path(__file__).with_name('main-public-exact.json')
identity = json.loads(pathlib.Path(__file__).with_name('main-web-identity.json').read_text())
info = identity['build_info']
base = 'https://zhipijun1996.github.io/gunman-rush/'
start = time.monotonic()
receipt = {'status': 'failed', 'url': base, 'source_commit': info['source_commit'],
           'build_id': info['build_id'], 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
           'files': [], 'scope': 'Exact public bytes, no gameplay/device acceptance'}
try:
    names = ['build-info.json', 'index.html', 'index.cache-sw.js', 'build_report.json']
    names += [p.name for p in sorted(bundle.iterdir()) if p.is_file()
              and (p.suffix in ('.txt', '.adoc') or 'license' in p.name.lower() or 'sources' in p.name.lower())]
    for name in dict.fromkeys(names):
        assert time.monotonic() - start < 480
        local = (bundle / name).read_bytes()
        url = urllib.parse.urljoin(base, name) + '?verify=' + info['build_id']
        with urllib.request.urlopen(url, timeout=15) as response:
            data = response.read()
            assert response.status == 200
        assert data == local, f'Public bytes differ: {name}'
        receipt['files'].append({'file': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'equal': True})
    worker = (bundle / 'index.cache-sw.js').read_text()
    resources = json.loads(re.search(r'^const RESOURCE_MAP = (.*);$', worker, re.M).group(1))
    pack_spec = resources[info['pack']]
    assert pack_spec['sha256'] == identity['pack_sha256']
    digest = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(urllib.parse.urljoin(base, info['pack']), timeout=15) as response:
        assert response.status == 200
        assert int(response.headers['Content-Length']) == info['pack_bytes']
        while block := response.read(1024 * 1024):
            assert time.monotonic() - start < 480
            digest.update(block)
            size += len(block)
    assert digest.hexdigest() == identity['pack_sha256'] == pack_spec['sha256']
    assert size == info['pack_bytes'] == pack_spec['bytes']
    receipt['pack'] = {'file': info['pack'], 'bytes': size, 'sha256': digest.hexdigest(), 'equal': True}
    receipt['status'] = 'passed'
finally:
    receipt['seconds'] = time.monotonic() - start
    out.write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({'status': receipt['status'], 'source': info['source_commit'], 'build': info['build_id'], 'seconds': receipt['seconds']}))
