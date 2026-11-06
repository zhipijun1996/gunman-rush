"""Package the current checked snapshot with an integrity manifest."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent / 'world-graybox-kit-v04.zip'
EXCLUDE = {'MANIFEST.json', 'simulation/route-summary-v04.txt'}


def main():
    status = json.loads((ROOT / 'handoff-status.json').read_text())
    if not status['ready_for_world_structure_graybox']:
        raise SystemExit('Handoff status has a failed structural check.')
    files = sorted(p for p in ROOT.rglob('*') if p.is_file()
                   and '__pycache__' not in p.parts
                   and p.relative_to(ROOT).as_posix() not in EXCLUDE
                   and not p.name.endswith('.bookmarked.pdf'))
    entries = [{'path': p.relative_to(ROOT).as_posix(), 'size_bytes': p.stat().st_size,
                'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]
    manifest = {
        'schema': 'world.graybox-kit-manifest.v04', 'date': '2026-11-06',
        'canonical_sha256': status['canonical_sha256'],
        'ready_for_world_structure_graybox': True,
        'readable_atlas': 'world-development-atlas-v07.pdf',
        'machine_checks': status['machine_checks'],
        'scope': status['meaning'],
        'not_validated': status['not_a_claim_of'],
        'source_inputs_policy': 'Historical migration inputs only; never replace current rules.',
        'files': entries
    }
    mp = ROOT / 'MANIFEST.json'
    mp.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED, compresslevel=8) as z:
        for p in files + [mp]:
            z.write(p, 'world-graybox-kit-v04/' + p.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(OUT) as z:
        bad = z.testzip()
        if bad:
            raise SystemExit('ZIP integrity failed: ' + bad)
        for item in entries:
            data = z.read('world-graybox-kit-v04/' + item['path'])
            if hashlib.sha256(data).hexdigest() != item['sha256']:
                raise SystemExit('ZIP digest mismatch: ' + item['path'])
    print(json.dumps({'zip': str(OUT), 'files': len(files) + 1,
                      'bytes': OUT.stat().st_size,
                      'sha256': hashlib.sha256(OUT.read_bytes()).hexdigest()}, ensure_ascii=False))


if __name__ == '__main__':
    main()
