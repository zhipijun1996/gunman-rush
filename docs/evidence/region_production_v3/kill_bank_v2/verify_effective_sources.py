"""Verify archived native bytes and exact original Git-base + dirty source projection.
Local consistency only; never rerun native or alter the original source_commit.
"""
from pathlib import Path
import hashlib,json,subprocess,zipfile
HERE=Path(__file__).resolve().parent
REPO=HERE.parents[3]
def digest(data): return hashlib.sha256(data).hexdigest()
summary=json.loads((HERE/'effective_sources/summary.json').read_text())
index=json.loads((HERE/'native_archive_index.json').read_text())
with zipfile.ZipFile(HERE/'actual_native_and_sources.zip') as archive:
    for item in index['files']:
        raw=archive.read(item['archive_member'])
        assert len(raw)==item['size'] and digest(raw)==item['sha256'],item
    bases={};requests=set()
    for case in summary['cases']:
        commit=case['original_source_commit_field_unchanged']
        if commit not in bases:
            tree={}
            for line in subprocess.check_output(['git','ls-tree','-r',commit],cwd=REPO).decode().splitlines():
                meta,path=line.split('\t',1);mode,kind,oid=meta.split()
                if kind=='blob':tree[path]=oid
            bases[commit]=tree
        manifest=json.loads((HERE/'effective_sources'/str(case['case']+'.json')).read_text())
        requests.update(b['git_blob'] for b in manifest['bindings'] if b['basis']=='original_git_blob')
    ids=sorted(requests)
    proc=subprocess.Popen(['git','cat-file','--batch'],cwd=REPO,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    raw,err=proc.communicate(('\n'.join(ids)+'\n').encode(),timeout=60)
    assert proc.returncode==0,err.decode()
    blobs={};offset=0
    for oid in ids:
        end=raw.index(b'\n',offset);header=raw[offset:end].decode().split();assert header[:2]==[oid,'blob']
        size=int(header[2]);offset=end+1;blobs[oid]=raw[offset:offset+size];offset+=size;assert raw[offset:offset+1]==b'\n';offset+=1
    total=0
    for case in summary['cases']:
        manifest=json.loads((HERE/'effective_sources'/str(case['case']+'.json')).read_text())
        member=case['original_receipt'].removeprefix('build/region_production_v3/kill_bank_v2/')
        receipt_raw=archive.read(member);assert digest(receipt_raw)==case['original_receipt_sha256']
        receipt=json.loads(receipt_raw);assert receipt['source_before']==receipt['source_after']
        assert receipt['source_commit']==manifest['original_source_commit_field_unchanged']
        inventory={}
        for binding in manifest['bindings']:
            if binding['basis']=='original_git_blob':
                assert bases[receipt['source_commit']][binding['path']]==binding['git_blob']
                value=blobs[binding['git_blob']]
            else:
                local=(HERE/'effective_sources'/binding['overlay_blob']).resolve()
                assert local.is_relative_to((HERE/'effective_sources/dirty_blobs').resolve())
                value=local.read_bytes()
            assert digest(value)==binding['sha256'],binding['path']
            inventory[binding['path']]=digest(value)
        assert inventory==receipt['source_before']
        projection=json.dumps(inventory,sort_keys=True,separators=(',',':')).encode()
        assert digest(projection)==manifest['inventory_projection_sha256']
        total+=len(inventory)
print(json.dumps({'status':'verified_local_consistency','archived_original_files':len(index['files']),'original_native_cases':len(summary['cases']),'original_source_bindings_verified':total,'scope':'Original Git base + exact preserved dirty overlay; original source_commit unmodified, no native rerun or clean-commit claim'}))
