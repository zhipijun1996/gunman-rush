"""Restore this bundle's original byte paths into a NEW isolated root; no engines."""
import argparse, gzip, hashlib, json
from pathlib import Path

MAX_BYTES = 95 * 1024 * 1024
def require(ok, reason):
    if not ok: raise ValueError(reason)
def digest(data): return hashlib.sha256(data).hexdigest()
def relative(value):
    p = Path(value)
    require(not p.is_absolute() and p.parts and '..' not in p.parts, 'Unsafe member path')
    return p
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--resume-identical', action='store_true', help='Only existing byte-identical targets may be skipped')
    args=parser.parse_args(); bundle=Path(__file__).resolve().parent
    index=json.loads((bundle/'index.json').read_text())
    require(index.get('status')=='portable_bytes_verified', 'Bundle incomplete, not restorable as final')
    require(digest(Path(__file__).read_bytes())==index['generated_files']['restore.py']['sha256'], 'Restore producer changed')
    root=args.root.resolve()
    require(root!=bundle and not root.is_relative_to(bundle) and not bundle.is_relative_to(root), 'Root overlaps bundle')
    require(not root.exists() or (args.resume_identical and root.is_dir()), 'Use a NEW isolated root or explicit identical-only resume')
    seen=set()
    # Check all archive bytes and target conflicts before writing any originals.
    for member in index['members']:
        rel=relative(member['original_path']); stored=(bundle/relative(member['stored'])).resolve()
        require(str(rel) not in seen, 'Duplicate original path'); seen.add(str(rel))
        require(stored.is_relative_to(bundle) and stored.is_file(), 'Missing/outside stored member')
        payload=stored.read_bytes()
        require(len(payload)<MAX_BYTES and digest(payload)==member['stored_sha256'], 'Stored SHA/size mismatch')
        require(member['compression'] in ('gzip','none'), 'Unknown compression')
        raw=gzip.decompress(payload) if member['compression']=='gzip' else payload
        require(len(raw)<MAX_BYTES and len(raw)==member['bytes'] and digest(raw)==member['sha256'], 'Restored raw SHA/size mismatch')
        target=(root/rel).resolve(); require(target.is_relative_to(root), 'Target escapes isolated root')
        if target.exists():
            require(target.is_file() and digest(target.read_bytes())==member['sha256'], 'Different existing file; never overwrite: '+str(rel))
    root.mkdir(parents=True, exist_ok=args.resume_identical)
    restored=skipped=0
    for member in index['members']:
        target=root/relative(member['original_path'])
        if target.exists():
            require(target.is_file() and digest(target.read_bytes())==member['sha256'], 'Existing file changed after preflight')
            skipped+=1; continue
        payload=(bundle/relative(member['stored'])).read_bytes()
        require(digest(payload)==member['stored_sha256'], 'Stored file changed after preflight')
        raw=gzip.decompress(payload) if member['compression']=='gzip' else payload
        require(digest(raw)==member['sha256'] and len(raw)==member['bytes'], 'Decode changed after preflight')
        target.parent.mkdir(parents=True,exist_ok=True)
        with target.open('xb') as stream: stream.write(raw)
        require(digest(target.read_bytes())==member['sha256'], 'Written raw SHA mismatch')
        restored+=1
    print('Restored',restored,'original files; identical skipped',skipped,'Q6/fun/device remain unaccepted:',root)
if __name__=='__main__': main()
