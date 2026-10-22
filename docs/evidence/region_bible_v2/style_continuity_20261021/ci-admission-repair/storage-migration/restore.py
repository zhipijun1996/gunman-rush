"""Restore only exact indexed final-native80 capture paths from committed evidence."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
INDEX_SHA = '62e6bbcbacc625415d36251bc8d678c5472da183487585a1be684dc5e907236b'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def bounded(root, relative):
    rel = Path(relative)
    if rel.is_absolute() or '..' in rel.parts:
        raise ValueError('Unsafe relative path')
    path = (root / rel).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError('Escaped destination/source root')
    return path


def load_index():
    index_path = HERE / 'restore-index.json'
    if sha(index_path) != INDEX_SHA:
        raise ValueError('Frozen exact80 index SHA mismatch')
    return json.loads(index_path.read_text())


def restore(row, workspace_root, destination_root):
    destination = bounded(destination_root, row['path'])
    if destination.exists():
        if destination.stat().st_size != row['bytes'] or sha(destination) != row['sha256']:
            raise ValueError('REFUSE_DIFFERENT_BYTES_EXISTING_DESTINATION')
        info = destination.stat()
        if (info.st_mode & 0o7777) != row['mode'] or info.st_mtime_ns != row['mtime_ns']:
            raise ValueError('Existing matching bytes have different preserved metadata')
        return {'path': row['path'], 'status': 'already_present'}
    source = row['source']
    source_path = bounded(workspace_root, source['path'])
    if sha(source_path) != source['sha256']:
        raise ValueError('Committed evidence source full SHA mismatch')
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix='.exact80-restore-', dir=destination.parent)
    temporary = Path(temporary)
    archive = None
    try:
        if source['kind'] == 'zip':
            archive = zipfile.ZipFile(source_path)
            member = archive.getinfo(source['member'])
            if member.file_size != row['bytes']:
                raise ValueError('ZIP member size mismatch')
            stream = archive.open(member)
        elif source['kind'] == 'raw':
            stream = source_path.open('rb')
        else:
            raise ValueError('Only committed ZIP/raw sources are supported')
        digest = hashlib.sha256()
        size = 0
        with stream, os.fdopen(descriptor, 'wb') as target:
            while block := stream.read(1048576):
                target.write(block)
                digest.update(block)
                size += len(block)
            target.flush()
            os.fsync(target.fileno())
        if size != row['bytes'] or digest.hexdigest() != row['sha256']:
            raise ValueError('Restored full SHA/size mismatch')
        os.chmod(temporary, row['mode'])
        os.utime(temporary, ns=(row['atime_ns'], row['mtime_ns']))
        # Atomic exclusive creation refuses a destination that appears concurrently.
        os.link(temporary, destination)
        return {'path': row['path'], 'status': 'restored', 'bytes': size}
    finally:
        if archive is not None:
            archive.close()
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace-root', type=Path, default=HERE.parents[2])
    parser.add_argument('--destination-root', type=Path)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--one', help='Exact root-relative raw capture path from the frozen index')
    selection.add_argument('--all', action='store_true', help='Restore exactly all80 indexed captures')
    args = parser.parse_args()
    index = load_index()
    rows = index['files'] if args.all else [r for r in index['files'] if r['path'] == args.one]
    if not rows or (not args.all and len(rows) != 1):
        raise ValueError('Requested path is not an exact selected capture')
    for row in rows:
        print(json.dumps(restore(row, args.workspace_root, args.destination_root or args.workspace_root)), flush=True)


if __name__ == '__main__':
    main()
