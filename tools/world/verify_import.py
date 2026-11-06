"""Verify the supplied lightweight snapshot, without interpreting omitted previews as loss."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPORT = ROOT / 'docs/data/world/import-v04'


def validate(folder=IMPORT):
    errors = []
    manifest = json.loads((folder / 'MANIFEST.json').read_text())
    expected = {'MANIFEST.json'}
    for row in manifest['files']:
        relative = Path(row['path'])
        if relative.is_absolute() or '..' in relative.parts:
            errors.append('Unsafe manifest path: ' + str(relative))
            continue
        expected.add(relative.as_posix())
        path = folder / relative
        if not path.is_file():
            errors.append('Missing imported file: ' + str(relative))
        elif path.stat().st_size != row['size_bytes'] or hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
            errors.append('Imported bytes changed: ' + str(relative))
    actual = {p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
    if actual != expected:
        errors.append('Unexpected imported paths: ' + str(sorted(actual - expected)))
    return errors


if __name__ == '__main__':
    errors = validate()
    print('\n'.join(errors) if errors else 'PASS: lightweight import file set, sizes and SHA256; omitted previews are intentional')
    raise SystemExit(bool(errors))
