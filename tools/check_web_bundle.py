"""Verify independently compressed pieces reconstruct the exact official resources."""
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys

def check(root):
    worker = (root / 'index.cache-sw.js').read_text()
    resources = json.loads(re.search(r'const RESOURCE_MAP = (.*);', worker).group(1))
    total = 0
    for name, info in resources.items():
        if 'chunks' not in info:
            continue
        parts = []
        for part in info['chunks']:
            compressed = (root / part['url']).read_bytes()
            assert len(compressed) == part['gzip_bytes'], part['url']
            block = gzip.decompress(compressed)
            assert len(block) == part['bytes'] and hashlib.sha256(block).hexdigest() == part['sha256'], part['url']
            assert len(block) <= 512 * 1024
            parts.append(block); total += len(compressed)
        complete = b''.join(parts)
        assert complete == (root / name).read_bytes(), name
        assert hashlib.sha256(complete).hexdigest() == info['sha256']
    metadata = json.loads((root / 'build-info.json').read_text())
    assert metadata['download_bytes'] == total
    assert metadata['cache_schema'] == 2
    assert metadata['build_id'] == hashlib.sha256((root / metadata['pack']).read_bytes()).hexdigest()[:12]
    # Excluded candidates have no runtime consumer. New consumers must revisit this export policy.
    repo = Path(__file__).resolve().parents[1]
    for directory in ('scripts', 'scenes', 'resources', 'config'):
        for source in (repo / directory).rglob('*'):
            if source.suffix in ('.gd', '.tscn', '.tres', '.json'):
                assert 'assets/painterly_v2/' not in source.read_text(), str(source)
    print(json.dumps({'checked_resources': len([r for r in resources.values() if 'chunks' in r]), 'download_bytes': total, 'failed': 0}))

if __name__ == '__main__':
    check(Path(sys.argv[1]) if len(sys.argv) > 1 else Path('build/web'))
