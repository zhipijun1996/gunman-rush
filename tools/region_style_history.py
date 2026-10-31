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
    return repository_file(path, root).read_bytes() if raw is None else raw
