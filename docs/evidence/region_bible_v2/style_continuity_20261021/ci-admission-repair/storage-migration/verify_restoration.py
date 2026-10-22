"""Actual /tmp recoverability verification; contains NO unlink of original captures."""
from pathlib import Path
import binascii
import datetime
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import zipfile
import restore

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def save(proof):
    (HERE / 'restoration-verification.json').write_text(json.dumps(proof, indent=2) + '\n')


def raw_guard(row):
    path = ROOT / row['path']
    info = path.stat()
    observed = {'bytes': info.st_size, 'device': info.st_dev, 'inode': info.st_ino,
                'nlink': info.st_nlink, 'mode': info.st_mode & 0o7777, 'mtime_ns': info.st_mtime_ns}
    assert all(observed[k] == row[k] for k in observed), row['path']
    assert restore.sha(path) == row['sha256'], row['path']


def preserved_guard(index):
    for ref in index['preserved_receipts_and_logs']:
        path = ROOT / ref['path']
        assert restore.sha(path) == ref['sha256'] and path.stat().st_mtime_ns == ref['mtime_ns']


def source_guard(index):
    for name in ('native_receipt', 'portable_native_receipt', 'portable_index', 'portable_archive_index',
                 'portable_archive', 'independent_review'):
        ref = index[name]
        assert restore.sha(ROOT / ref['path']) == ref['sha256']
    for row in index['files']:
        source = row['source']
        if source['kind'] == 'raw':
            assert restore.sha(ROOT / source['path']) == source['sha256']


def member_byte_comparison(row, archive):
    source = row['source']
    stream = archive.open(source['member']) if source['kind'] == 'zip' else (ROOT / source['path']).open('rb')
    digest, crc, size = hashlib.sha256(), 0, 0
    with stream, (ROOT / row['path']).open('rb') as original:
        while True:
            block, actual = stream.read(1048576), original.read(1048576)
            assert block == actual, row['path']
            digest.update(block)
            crc = binascii.crc32(block, crc)
            size += len(block)
            if not block:
                break
    assert digest.hexdigest() == row['sha256'] and size == row['bytes']
    if source['kind'] == 'zip':
        assert archive.getinfo(source['member']).CRC == crc
    return {'path': row['path'], 'bytes': size, 'sha256': digest.hexdigest(), 'CRC32': crc,
            'source_kind': source['kind'], 'source_to_original_full_byte_comparison': True}


def main():
    index = restore.load_index()
    assert len(index['files']) == 80
    assert not (HERE / 'restoration-verification.json').exists()
    tmp = Path(tempfile.mkdtemp(prefix='gunman-final80-restore-probe-', dir='/tmp'))
    assert tmp.stat().st_dev != ROOT.stat().st_dev
    proof = {'scope': 'Actual /tmp restore validation only; no unlink authorized/executed; no gameplay rerun',
             'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
             'index_sha256': restore.INDEX_SHA, 'probe_root': str(tmp), 'probe_device': tmp.stat().st_dev,
             'original_device': ROOT.stat().st_dev, 'cases': [], 'all80_originals_retained': True}
    save(proof)
    source_guard(index)
    preserved_guard(index)
    with zipfile.ZipFile(ROOT / index['portable_archive']['path']) as archive:
        assert len(archive.infolist()) == 78
        assert archive.testzip() is None
        proof['all78_member_CRC_verified'] = True
        for row in index['files']:
            raw_guard(row)
            checked = member_byte_comparison(row, archive)
            result = restore.restore(row, ROOT, tmp)
            assert result['status'] == 'restored'
            path = tmp / row['path']
            stat = path.stat()
            assert restore.sha(path) == row['sha256']
            assert stat.st_size == row['bytes'] and (stat.st_mode & 0o7777) == row['mode']
            assert stat.st_mtime_ns == row['mtime_ns']
            assert stat.st_uid == row['uid'] and stat.st_gid == row['gid']
            with path.open('rb') as a, (ROOT / row['path']).open('rb') as b:
                while True:
                    first, second = a.read(1048576), b.read(1048576)
                    assert first == second
                    if not first:
                        break
            assert restore.restore(row, ROOT, tmp)['status'] == 'already_present'
            proof['cases'].append(dict(checked, actual_restore=True, restored_to_original_relative_path=True,
                                       restored_mode_uid_gid_mtime_ns_exact=True, repeat_idempotent=True,
                                       original_raw_retained=True))
            if len(proof['cases']) % 20 == 0:
                save(proof)
                print(f'ACTUAL_RESTORES {len(proof["cases"])}/80', flush=True)
    # Exercise real CLI refusal for both source kinds, leaving foreign bytes untouched.
    refusals = []
    for kind in ('zip', 'raw'):
        row = next(r for r in index['files'] if r['source']['kind'] == kind)
        other = tmp / ('wrong-existing-' + kind)
        target = other / row['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b'INTENTIONAL NON EVIDENCE WRONG DESTINATION BYTES\n')
        before = restore.sha(target)
        result = subprocess.run([sys.executable, '-B', str(HERE / 'restore.py'), '--workspace-root', str(ROOT),
                                 '--destination-root', str(other), '--one', row['path']], capture_output=True, text=True,
                                env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'))
        assert result.returncode != 0 and 'REFUSE_DIFFERENT_BYTES_EXISTING_DESTINATION' in result.stderr
        assert restore.sha(target) == before
        refusals.append({'kind': kind, 'path': row['path'], 'refused': True,
                         'foreign_bytes_unchanged': True, 'exit_code': result.returncode})
    # Exercise actual CLI idempotence on a fully restored existing destination.
    first = index['files'][0]
    result = subprocess.run([sys.executable, '-B', str(HERE / 'restore.py'), '--workspace-root', str(ROOT),
                             '--destination-root', str(tmp), '--one', first['path']], capture_output=True, text=True,
                            env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'))
    assert result.returncode == 0 and json.loads(result.stdout)['status'] == 'already_present'
    proof['wrong_existing_refusals'] = refusals
    proof['real_CLI_idempotent'] = True
    source_guard(index)
    preserved_guard(index)
    with zipfile.ZipFile(ROOT / index['portable_archive']['path']) as archive:
        assert archive.testzip() is None
        proof['reverification_all80'] = []
        for row in index['files']:
            raw_guard(row)
            proof['reverification_all80'].append(member_byte_comparison(row, archive))
    proof['all_original_receipts_logs_source_proof_unchanged'] = True
    proof['all80_originals_retained'] = all((ROOT / row['path']).is_file() for row in index['files'])
    proof['new_archive_created'] = False
    proof['unlink_executed'] = False
    proof['status'] = 'ALL80_RESTORATION_VERIFIED_AWAIT_EXACT_ROOT_GO_TO_UNLINK'
    proof['restore_script_sha256'] = restore.sha(HERE / 'restore.py')
    proof['verification_script_sha256'] = restore.sha(Path(__file__))
    proof['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save(proof)
    print(proof['status'], flush=True)


if __name__ == '__main__':
    main()
