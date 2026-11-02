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
    return style26_source(root, path) if raw is None else raw


STYLE26_ARCHIVE = 'docs/creative_direction/archive/ownership-closeout-before-style27'
STYLE26_MANIFEST_SHA = '28d6de8b60ae9ab0a254a46cf9c30effa68775b1d481921402271135a8007229'


def style26_source(root, path):
    """Seven prior26 leaves only; never used by current binding validators."""
    raw = archived_source(root, STYLE26_ARCHIVE, path, STYLE26_MANIFEST_SHA)
    return style27_source(root, path) if raw is None else raw


STYLE27_ARCHIVE = 'docs/creative_direction/archive/runtime-ownership-before-style28'
STYLE27_MANIFEST_SHA = '358a3b010b4b1e95772a13a2c5d3f219eb6da4eb8962004dfc73e59c08056e4a'


def style27_source(root, path):
    """Five prior27 leaves only; never used by current binding validators."""
    raw = archived_source(root, STYLE27_ARCHIVE, path, STYLE27_MANIFEST_SHA)
    return style28_source(root, path) if raw is None else raw


GIT_HISTORY_ARCHIVE = 'docs/creative_direction/archive/style-source-git-history'
GIT_HISTORY_MANIFEST_SHA = 'dcec926ec878a797ee8119769019c8edf9a04543d8837ca2f255729bc1fecfdc'


def git_history_source(root, commit, path):
    """Read only pinned historical Git leaves; never fetch or use live bytes."""
    raw = repository_file(GIT_HISTORY_ARCHIVE + '/manifest.json', root).read_bytes()
    if hashlib.sha256(raw).hexdigest() != GIT_HISTORY_MANIFEST_SHA:
        raise AssertionError('Frozen Git source manifest changed')
    manifest = json.loads(raw, object_pairs_hook=unique_object)
    rows = [row for row in manifest['sources']
            if row['source_commit'] == commit and row['path'] == path]
    if len(rows) != 1:
        raise AssertionError('Unknown or duplicate frozen Git source: ' + commit + ':' + path)
    row = rows[0]
    raw = repository_file(row['archive_path'], root).read_bytes()
    if len(raw) != row['size'] or hashlib.sha256(raw).hexdigest() != row['sha256']:
        raise AssertionError('Frozen Git source bytes changed: ' + commit + ':' + path)
    return raw


STYLE28_ARCHIVE = 'docs/creative_direction/archive/composition-closeout-before-style29'
STYLE28_MANIFEST_SHA = '9d2d76226ba552cbcfe71ab063c18ba809921f66b359f4576c42a678aed79f3b'


def style28_source(root, path):
    """Six prior28 leaves only; never used by current binding validators."""
    raw = archived_source(root, STYLE28_ARCHIVE, path, STYLE28_MANIFEST_SHA)
    return style29_source(root, path) if raw is None else raw


STYLE29_ARCHIVE = 'docs/creative_direction/archive/map-query-boundary-before-style30'
STYLE29_MANIFEST_SHA = '9a863035c38c8cf153c659a1761b3419eb782fb2f538cddda66b9102b4325c83'


def style29_source(root, path):
    """Three prior29 leaves only; never used by current binding validators."""
    raw = archived_source(root, STYLE29_ARCHIVE, path, STYLE29_MANIFEST_SHA)
    return style30_source(root, path) if raw is None else raw


STYLE30_ARCHIVE = 'docs/creative_direction/archive/mobile-combat-mesh-before-style31'
STYLE30_MANIFEST_SHA = '00af41bd539a814de7b2c4c01e239f45b91299d64c16e7fc30e57df45ef22b3b'


def style30_source(root, path):
    """Three prior30 leaves only; never used by current binding validators."""
    raw = archived_source(root, STYLE30_ARCHIVE, path, STYLE30_MANIFEST_SHA)
    return style31_source(root, path) if raw is None else raw


STYLE31_ARCHIVE = 'docs/creative_direction/archive/combat-perf-before-style32'
STYLE31_MANIFEST_SHA = 'ada060d5ca9b1728b9772c28ae1f1ec90c01d87535c4df4deecdc5031ec14058'


def style31_source(root, path):
    """Six prior31 leaves only; never used by current binding validators."""
    raw = archived_source(root, STYLE31_ARCHIVE, path, STYLE31_MANIFEST_SHA)
    return repository_file(path, root).read_bytes() if raw is None else raw
