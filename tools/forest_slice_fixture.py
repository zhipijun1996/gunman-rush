"""Explicit legacy H-only test capability, independent of current world progression."""
import hashlib
import json
from pathlib import Path

PATH = 'tests/fixtures/forest_slice_regression.json'


def load_fixture(kind, root=Path(__file__).resolve().parents[1]):
    root = Path(root)
    raw = (root / PATH).read_bytes()
    data = json.loads(raw)
    if (data.get('schema_version') != 1 or data.get('scope') != 'legacy_controller_regression_not_fixed_world_design'
            or data.get('region_id') != 'thorn_forest' or data.get('allowed_capabilities') != ['H']):
        raise ValueError('Invalid legacy forest slice fixture')
    case = data['cases'][kind]
    expected = {
        'current': ('tests/forest_current_slice_runner.gd', 'resources/player/traversal.tres'),
        'historical': ('tests/forest_h_slice_runner.gd', 'tests/fixtures/forest_h_legacy_traversal.tres'),
    }
    if (case['runner'], case['traversal']) != expected[kind]:
        raise ValueError('Forest fixture does not match the real runner/traversal consumers')
    sources = [{'path': PATH, 'sha256': hashlib.sha256(raw).hexdigest()}]
    for field in ('runner', 'traversal'):
        path = Path(case[field])
        if path.is_absolute() or '..' in path.parts:
            raise ValueError('Unsafe forest slice fixture path')
        sources.append({'path': path.as_posix(), 'sha256': hashlib.sha256((root / path).read_bytes()).hexdigest()})
    return {'scope': data['scope'], 'allowed_capabilities': data['allowed_capabilities'],
            'case': case, 'sources': sources}
