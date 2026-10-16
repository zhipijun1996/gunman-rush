"""Independent read-only check of an actual export plus derived-directory negatives.
Writes reports here; full negative PCKs exist only in an ephemeral child directory.
Usage: python3 THIS.py /absolute/candidate.pck
"""
from pathlib import Path
import hashlib, json, struct, sys, tempfile, time
REPO=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(REPO/'tools'))
import check_web_bundle as bundle
OUT=Path(__file__).resolve().parent
sha=lambda data:hashlib.sha256(data).hexdigest()
def main():
    candidate=Path(sys.argv[1]).resolve()
    original=candidate.read_bytes()
    started=time.monotonic()
    closure=bundle.check_runtime_closure(candidate,REPO)
    pack=bundle.Pack(candidate)
    raw=[]
    for name in closure['raw_png']:
        packed=pack.read(name)
        source=(REPO/name).read_bytes()
        assert packed==source
        raw.append({'path':name,'bytes':len(packed),'sha256':sha(packed),'source_identical':True})
    base,directory=struct.unpack_from('<QQ',original,24)
    negative=[]
    with tempfile.TemporaryDirectory(prefix='derived_pack_',dir=OUT) as temp:
        path=Path(temp)/'removed_raw.pck'
        for missing in closure['raw_png']:
            rows=bytearray(struct.pack('<I',len(pack.entries)-1))
            for name,(offset,size,digest) in pack.entries.items():
                if name==missing:continue
                encoded=name.encode()+b'\0';encoded+=b'\0'*(-len(encoded)%4)
                rows.extend(struct.pack('<I',len(encoded))+encoded+struct.pack('<QQ',offset-base,size)+digest+struct.pack('<I',0))
            derived=original[:directory]+rows
            path.write_bytes(derived)
            # Preserve all payload bytes, import mappings and imported textures.
            # Only this raw resource directory entry is removed.
            removed=bundle.Pack(path)
            assert missing not in removed.entries and missing+'.import' in removed.entries
            assert removed.read(missing+'.import')==pack.read(missing+'.import')
            expected='PCK missing runtime resource: '+missing
            try:bundle.check_runtime_closure(path,REPO)
            except ValueError as error:
                assert str(error)==expected,(str(error),expected)
                negative.append({'removed_entry':missing,'derived_sha256':sha(derived),'bytes':len(derived),'status':'rejected','reason':str(error),'import_mapping_preserved':True,'all_payload_bytes_preserved':True})
            else:raise AssertionError('Missing raw PNG accepted: '+missing)
    result={'candidate':str(candidate),'pack_sha256':sha(original),'pack_bytes':len(original),'closure':closure,'raw_byte_checks':raw,'negative_cases':negative,'original_pack_unchanged':sha(candidate.read_bytes())==sha(original),'duration_seconds':round(time.monotonic()-started,3),'scope':'Actual export PCK byte/directory/import closure only; no engine export execution, browser, pixels, Windows export or device acceptance.'}
    assert result['original_pack_unchanged']
    (OUT/'actual_pack_review.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
if __name__=='__main__':main()
