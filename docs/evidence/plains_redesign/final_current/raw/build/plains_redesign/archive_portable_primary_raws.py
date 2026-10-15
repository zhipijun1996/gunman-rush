"""After final portable pack: retain exact raw bytes in verified gzip, reclaim duplicate build storage.

Never touches receipt/batch/log/source/media. --restore rehydrates original absolute paths.
"""
from pathlib import Path
import gzip,hashlib,json,sys,time
R=Path('/workspace/gunman-rush'); O=Path('/workspace/plains-redesign-baseline')
B=R/'build/plains_redesign'; P=B/'portable_primary_storage.json'
sha=lambda data:hashlib.sha256(data).hexdigest()
if '--restore' in sys.argv:
    d=json.loads(P.read_text())
    for row in d['members']:
        raw=gzip.decompress((R/row['stored']).read_bytes())
        assert sha(raw)==row['raw_sha256']
        target=Path(row['original'])
        if target.exists():assert sha(target.read_bytes())==row['raw_sha256']
        else:target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    print('Original240 raw paths restored byte-exactly; portable originals retained.');raise SystemExit(0)
assert not P.exists(),'Keep original storage record; no overwrite'
assert json.loads((B/'worst_movie_v2_execution.json').read_text())['status']=='recorded'
E=R/'docs/evidence/plains_redesign/final_current';idx=json.loads((E/'index.json').read_text())
assert idx['status']=='portable_bytes_verified'
members={m['original_path']:m for m in idx['members']};rows=[]
for side in ['before','after']:
    files=sorted((B/'controlled_comparison'/side).rglob('capture.json'));assert len(files)==80
    for p in files:
        rel=str(p.relative_to(R));m=members[rel];stored=E/m['stored']
        assert m['compression']=='gzip' and sha(stored.read_bytes())==m['stored_sha256']
        raw=gzip.decompress(stored.read_bytes());assert sha(raw)==m['sha256'] and p.read_bytes()==raw
        paths=[p]+([O/rel] if side=='before' else [])
        for target in paths:
            assert target.is_file() and target.read_bytes()==raw
            rows.append({'original':str(target),'portable_original_path':rel,
                'stored':str(stored.relative_to(R)),'raw_sha256':sha(raw),'raw_bytes':len(raw)})
assert len(rows)==240
d={'status':'verified_preflight','scope':'Only completed primary before80/after80 captures and the identical old workspace mirror. All raw bytes retained losslessly in final_current, original hashes/receipts untouched. Restore before local legacy reanalysis. No source/test/log/media or failed evidence deletion.',
    'members':rows,'restore_argv':['python3','build/plains_redesign/archive_portable_primary_raws.py','--restore'],
    'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
P.write_text(json.dumps(d,indent=2)+'\n')
for row in rows:
    p=Path(row['original']);assert sha(p.read_bytes())==row['raw_sha256'];p.unlink()
d.update(status='archived_reversible',finished_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),unlinked_duplicate_bytes=sum(r['raw_bytes'] for r in rows))
P.write_text(json.dumps(d,indent=2)+'\n');print('Original raw bytes retained in portable verified gzip; reclaimed duplicate build storage:',d['unlinked_duplicate_bytes'])
