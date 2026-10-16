"""Remove one directory entry from a real PCK; retain its entire original payload.

The unreachable old bytes remain in the data area; FileAccess cannot address the
removed path. All remaining entries, imported textures and payload bytes remain.
This is a derived native-pack negative, not a fabricated fixture pack.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools'))
from check_web_bundle import Pack


def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def derive(source, output, removed):
    source = Path(source).resolve()
    output = Path(output).resolve()
    if output.exists() or source == output:
        raise ValueError('Never overwrite native or prior derived evidence')
    original = Pack(source)
    if removed not in original.entries:
        raise ValueError('Requested negative must remove a real existing raw entry')
    with source.open('rb') as stream:
        stream.seek(32)
        directory = struct.unpack('<Q', stream.read(8))[0]
        stream.seek(0)
        with output.open('xb') as target:
            remaining = directory
            body = hashlib.sha256()
            while remaining:
                chunk = stream.read(min(1024 * 1024, remaining))
                if not chunk:
                    raise ValueError('Truncated original payload')
                target.write(chunk)
                body.update(chunk)
                remaining -= len(chunk)
            target.write(struct.pack('<I', len(original.entries) - 1))
            for name, (offset, size, md5) in original.entries.items():
                if name == removed:
                    continue
                encoded = name.encode() + b'\0'
                encoded += b'\0' * (-len(encoded) % 4)
                target.write(struct.pack('<I', len(encoded)) + encoded)
                target.write(struct.pack('<QQ', offset - original.file_base, size))
                target.write(md5 + struct.pack('<I', 0))
    derived = Pack(output)
    assert removed not in derived.entries
    assert derived.entries == {name: row for name, row in original.entries.items() if name != removed}
    with output.open('rb') as stream:
        remaining = directory
        derived_body = hashlib.sha256()
        while remaining:
            chunk = stream.read(min(1024 * 1024, remaining))
            derived_body.update(chunk)
            remaining -= len(chunk)
    assert derived_body.hexdigest() == body.hexdigest()
    return {'source': str(source.relative_to(ROOT)), 'source_sha256': digest(source),
            'derived': str(output.relative_to(ROOT)), 'derived_sha256': digest(output),
            'removed': removed, 'entries_before': len(original.entries),
            'entries_after': len(derived.entries), 'all_remaining_entries_identical': True,
            'complete_native_payload_preserved_sha256': body.hexdigest(),
            'import_mapping_retained': removed + '.import' in derived.entries,
            'mutation': 'Only the named raw directory entry removed; inaccessible original bytes remain, all native payload and imported derivatives retained'}


if __name__ == '__main__':
    print(json.dumps(derive(*sys.argv[1:]), indent=2))
