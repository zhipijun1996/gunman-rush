"""Finite source adapters for retained Bible tests; never used by live binding.

The manifest.sources format and source SHA check are shared by the existing
Boss-parent readers and the one pre-layout snapshot. Unindexed dependencies
stay live; an indexed missing/corrupt source must never fall back to live bytes.
"""
import hashlib
import json

from region_creative_direction import repository_file, unique_object

STYLE25_ARCHIVE = 'docs/creative_direction/archive/feature-layout-before-style26'
STYLE25_MANIFEST_SHA = 'e7d7c7b016dea2f8a42f30736a40ecc89a625ec90715d0258a04ca42d1cb3ca9'
STYLE25_SCENE_ARCHIVE = STYLE25_ARCHIVE + '/scene-reference-supplement'
STYLE25_SCENE_MANIFEST_SHA = '0a893d58b17e1ddf96bb142cb52af9ac1f7325cb6b1ae07afb14596bd4859e8c'


def archived_source(root, archive, path, manifest_sha=None):
    """Read one explicit old leaf using the existing finite manifest schema."""
    raw = repository_file(archive + '/manifest.json', root).read_bytes()
    if manifest_sha is not None and hashlib.sha256(raw).hexdigest() != manifest_sha:
        raise AssertionError('Frozen source manifest changed: ' + archive)
    manifest = json.loads(raw, object_pairs_hook=unique_object)
    rows = [row for row in manifest['sources'] if row['path'] == path]
    if not rows:
        return None
    if len(rows) != 1:
        raise AssertionError('Duplicate frozen source: ' + path)
    row = rows[0]
    raw = repository_file(archive + '/' + row['archive_path'], root).read_bytes()
    if hashlib.sha256(raw).hexdigest() != row['sha256']:
        raise AssertionError('Frozen combination parent source changed: ' + path)
    return raw


def style25_source(root, path):
    """One version adapter; current registry and live validators never call it."""
    raw = archived_source(root, STYLE25_ARCHIVE, path, STYLE25_MANIFEST_SHA)
    if raw is None:
        raw = archived_source(root, STYLE25_SCENE_ARCHIVE, path, STYLE25_SCENE_MANIFEST_SHA)
    return repository_file(path, root).read_bytes() if raw is None else raw


STYLE26_ARCHIVE = 'docs/creative_direction/archive/ownership-closeout-before-style27'
STYLE26_MANIFEST_SHA = '28d6de8b60ae9ab0a254a46cf9c30effa68775b1d481921402271135a8007229'


def style26_source(root, path):
    """Seven prior26 leaves only; never used by current binding validators."""
    raw = archived_source(root, STYLE26_ARCHIVE, path, STYLE26_MANIFEST_SHA)
    return repository_file(path, root).read_bytes() if raw is None else raw
