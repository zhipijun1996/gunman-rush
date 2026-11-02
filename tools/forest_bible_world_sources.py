"""Byte inventory of the real runtime and its test/tool consumers, never build/.git."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOTS = ('scripts', 'scenes', 'resources', 'config', 'shaders', 'assets', 'tests', 'tools', 'game', 'experiments')


def inventory(root=ROOT):
    root = Path(root)
    paths = [root / 'project.godot']
    for directory in SOURCE_ROOTS:
        paths.extend(path for path in (root / directory).rglob('*')
                     if path.is_file() and '__pycache__' not in path.parts
                     and path.suffix != '.pyc')
    result = {}
    for path in sorted(paths):
        with path.open('rb') as source:
            result[path.relative_to(root).as_posix()] = hashlib.file_digest(source, 'sha256').hexdigest()
    return result
