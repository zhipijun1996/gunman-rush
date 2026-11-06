"""Prevent retired report storage and keep ordinary searches focused on sources."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RETIRED = 'docs/' + 'evidence'
SEARCH_EXCLUDES = ('/build/', '/.godot/', '/.local/', '/.toolchains/', '/.environment/', '/docs/data/world/import-v04/', '**/__pycache__/', '/docs/data/creative_direction/sources/', '/tests/fixtures/forest_h_trace/*.json', '/tests/fixtures/save_compat/*.json')


def validate(root=ROOT):
    errors = []
    retired = root / RETIRED
    if retired.exists() and any(retired.rglob('*')):
        errors.append('Retired report directory is nonempty: ' + RETIRED)
    for filename, entries in (('.ignore', SEARCH_EXCLUDES), ('.gitignore', ('/' + RETIRED + '/',))):
        path = root / filename
        lines = path.read_text().splitlines() if path.is_file() else []
        for entry in entries:
            if entry not in lines:
                errors.append(f'{filename} missing generated/context exclusion: {entry}')
    for path in (root / 'tools').rglob('*'):
        if path.suffix in {'.py', '.gd', '.sh', '.mjs', '.js'} and path.is_file():
            if RETIRED + '/' in path.read_text():
                errors.append('Tool still references retired report storage: ' + str(path.relative_to(root)))
    return errors
