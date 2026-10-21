"""Execute root's exact80 unlink GO after fresh full recoverability guards."""
from pathlib import Path
import datetime
import json
import os
import zipfile
import restore
import verify_restoration

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
VERIFICATION_SHA = '0e65925fb4564694125a09171bf2126ee736815a1fd6112487b02ae1e0aeb288'
RESTORE_TOOL_SHA = 'b9c1d5d93e419dc21e5a73ed2baa05e5e03acabb47bc3388dc75d150c8f58db0'


def free(path):
    info = os.statvfs(path)
    return info.f_bavail * info.f_frsize


def save(proof):
    (HERE / 'unlink-execution.json').write_text(json.dumps(proof, indent=2) + '\n')


def review_fds(rows):
    targets = {(r['device'], r['inode']): r['path'] for r in rows}
    hits, inaccessible = [], []
    for process in Path('/proc').iterdir():
        if not process.name.isdigit():
            continue
        try:
            descriptors = list((process / 'fd').iterdir())
        except (PermissionError, FileNotFoundError):
            try:
                status = {line.split(':', 1)[0]: line.split(':', 1)[1].strip()
                          for line in (process / 'status').read_text().splitlines()
                          if line.startswith(('Name:', 'State:', 'Uid:'))}
            except (PermissionError, FileNotFoundError):
                continue
            if not status.get('State', '').startswith('Z'):
                inaccessible.append(dict(pid=int(process.name), **status))
            continue
        for descriptor in descriptors:
            try:
                info = descriptor.stat()
            except (PermissionError, FileNotFoundError):
                continue
            key = (info.st_dev, info.st_ino)
            if key in targets:
                hits.append({'pid': int(process.name), 'fd': descriptor.name, 'path': targets[key]})
    unknown = [r for r in inaccessible if not (r.get('Name') in ('dockerd', 'containerd')
                                               and r.get('Uid', '').split()[0] == '0')]
    if hits or unknown:
        raise ValueError(f'STOP selected FD/unknown live owner: {hits}, {unknown}')
    return {'visible_selected_inode_hits': hits, 'inaccessible_live_root_infrastructure': inaccessible,
            'scope': 'Available FD snapshot plus root engine-idle lease, not global FD absence proof'}


def main():
    index = restore.load_index()
    assert restore.sha(HERE / 'restoration-verification.json') == VERIFICATION_SHA
    assert restore.sha(HERE / 'restore.py') == RESTORE_TOOL_SHA
    verification = json.loads((HERE / 'restoration-verification.json').read_text())
    assert verification['status'] == 'ALL80_RESTORATION_VERIFIED_AWAIT_EXACT_ROOT_GO_TO_UNLINK'
    assert len(verification['cases']) == 80 and len(verification['reverification_all80']) == 80
    rows = index['files']
    assert len(rows) == 80 and len({r['path'] for r in rows}) == 80
    assert all(r['path'].startswith('build/forest_depth/region/harness-matrix/harness-17b1b4b56b8747208164999beefbcd32/')
               and r['path'].endswith('/capture.json') for r in rows)
    assert not (HERE / 'unlink-execution.json').exists()
    proof = {'scope': 'Only exact root-authorized third80 raw storage relocation; no new gameplay claim',
             'root_exact_GO_index_SHA256': restore.INDEX_SHA,
             'verified_restore_proof_SHA256': VERIFICATION_SHA,
             'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
             'free_before_bytes': free(ROOT), 'tmp_free_before_bytes': free('/tmp'),
             'removed': [], 'source_Git_engine_media_or_other_raw_mutation': False}
    save(proof)
    verify_restoration.source_guard(index)
    verify_restoration.preserved_guard(index)
    proof['fresh_FD_before'] = review_fds(rows)
    tmp = Path(verification['probe_root'])
    assert tmp.is_dir() and tmp.stat().st_dev != ROOT.stat().st_dev
    for row in rows:
        verify_restoration.raw_guard(row)
        staged = tmp / row['path']
        info = staged.stat()
        assert restore.sha(staged) == row['sha256'] and info.st_size == row['bytes']
        assert (info.st_mode & 0o7777) == row['mode'] and info.st_mtime_ns == row['mtime_ns']
        assert info.st_uid == row['uid'] and info.st_gid == row['gid']
    proof['all80_tmp_restores_reverified_retained'] = True
    proof['tmp_restore_root'] = str(tmp)
    with zipfile.ZipFile(ROOT / index['portable_archive']['path']) as archive:
        assert len(archive.infolist()) == 78 and archive.testzip() is None
        proof['fresh_all80_retained_source_raw_bytecomparison'] = [
            verify_restoration.member_byte_comparison(row, archive) for row in rows]
    # Final source/proof/raw guards complete before the first unlink.
    verify_restoration.source_guard(index)
    verify_restoration.preserved_guard(index)
    for row in rows:
        verify_restoration.raw_guard(row)
    proof['fresh_FD_immediately_before_unlink'] = review_fds(rows)
    proof['all78_CRC_and_all80_full_SHA_size_raw_metadata_reverified'] = True
    proof['free_immediately_before_unlink_bytes'] = free(ROOT)
    save(proof)
    for row in rows:
        verify_restoration.raw_guard(row)
        path = ROOT / row['path']
        info = path.stat()
        path.unlink()
        proof['removed'].append({'path': row['path'], 'bytes': row['bytes'], 'sha256': row['sha256'],
                                 'device': info.st_dev, 'inode': info.st_ino, 'nlink': info.st_nlink,
                                 'allocated_bytes_before_unlink': info.st_blocks * 512})
        save(proof)
    verify_restoration.source_guard(index)
    verify_restoration.preserved_guard(index)
    assert all(not (ROOT / row['path']).exists() for row in rows)
    assert all((tmp / row['path']).is_file() for row in rows)
    proof['original_receipts_logs_and_committed_sources_unchanged'] = True
    proof['all80_selected_raw_absent_explicit_restore_available'] = True
    proof['all80_tmp_restores_retained'] = True
    proof['raw_logical_bytes_relocated'] = sum(r['bytes'] for r in proof['removed'])
    proof['raw_allocated_bytes_relocated'] = sum(r['allocated_bytes_before_unlink'] for r in proof['removed'])
    proof['all_removed_nlink_values'] = sorted({r['nlink'] for r in proof['removed']})
    proof['free_after_bytes'] = free(ROOT)
    proof['tmp_free_after_bytes'] = free('/tmp')
    proof['observed_free_increase_bytes'] = proof['free_after_bytes'] - proof['free_before_bytes']
    proof['observed_free_increase_unlink_window_bytes'] = proof['free_after_bytes'] - proof['free_immediately_before_unlink_bytes']
    proof['status'] = 'EXACT80_UNLINK_COMPLETE_EXISTING_COMMITTED_EVIDENCE_REUSED_NOT_GAMEPLAY_ACCEPTANCE'
    proof['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save(proof)
    print(json.dumps({k: proof[k] for k in ('status', 'raw_logical_bytes_relocated', 'raw_allocated_bytes_relocated',
                                         'free_before_bytes', 'free_after_bytes', 'observed_free_increase_bytes')}))


if __name__ == '__main__':
    main()
