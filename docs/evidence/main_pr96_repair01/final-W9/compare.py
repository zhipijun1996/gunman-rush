"""Exact W9 Foundry comparison against frozen c77f resources, with explicit stamp paths only."""
from pathlib import Path
import copy,hashlib,json,re
BASE=Path(__file__).resolve().parent

def read(path):return json.loads(path.read_text())
def diff(a,b,path=''):
    if type(a)!=type(b):return [path+': type changed']
    if isinstance(a,dict):
        result=[path+'/'+k+': missing' for k in sorted(a.keys()-b.keys())]+[path+'/'+k+': added' for k in sorted(b.keys()-a.keys())]
        for k in sorted(a.keys()&b.keys()):result+=diff(a[k],b[k],path+'/'+k)
        return result
    if isinstance(a,list):
        if len(a)!=len(b):return [path+': array length changed']
        result=[]
        for i,(x,y) in enumerate(zip(a,b)):result+=diff(x,y,path+'/'+str(i))
        return result
    return [] if a==b else [path+': value changed']
def stamp(d,key,path,allowed):
    assert key in d and isinstance(d[key],str) and re.fullmatch('[0-9a-f]{64}',d[key]),path+'/'+key
    allowed.add(path+'/'+key);del d[key]
def manifest(value,path,allowed):
    result=copy.deepcopy(value)
    stamp(result,'basis',path,allowed);stamp(result,'hash',path,allowed)
    if result.get('kind')=='itinerary':
        for i,p in enumerate(result['phrases']):
            # The exact known one-level Foundry phrase structure, never recursive wildcard removal.
            stamp(p,'basis',f'{path}/phrases/{i}',allowed);stamp(p,'hash',f'{path}/phrases/{i}',allowed)
    return result

def validate_tree(folder):
    batch=read(folder/'batch.json');export=read(folder/'export_basis.json')
    assert len(batch['accepted'])==36 and len(batch['itineraries'])==18 and len(batch['connection_proofs'])==18 and not batch['rejected']
    assert export['basis']==batch['basis'] and export['engine']==batch['engine']
    by_id={x['manifest']['id']:x['manifest'] for x in batch['accepted']};by_id.update({m['id']:m for m in batch['itineraries']});assert len(by_id)==54
    assert {p.name for p in (folder/'replays').glob('*.json')}=={k+'.json' for k in by_id}
    frames=0
    for key,m in by_id.items():
        assert m['basis']==batch['basis']
        for phrase in m.get('phrases',[]):assert phrase==by_id[phrase['id']]
        replay=read(folder/'replays'/(key+'.json'))
        assert replay['basis']==batch['basis'] and replay['manifest_hash']==m['hash'] and replay['capability_profile']==m['capability_profile']
        assert set(replay)=={'basis','capability_profile','frames','manifest_hash','schema'}
        for frame in replay['frames']:assert set(frame)=={'actions','axis','position','shots'}
        frames+=len(replay['frames'])
    assert frames==56113
    for x in batch['accepted']:assert x['replay']['ok'] and x['replay']['max_position_error']==0.0
    for x in batch['connection_proofs']:assert x['ok'] and x['replay']['ok'] and x['replay']['max_position_error']==0.0
    return batch,export

def compare(after_folder):
    before_folder=BASE/'baseline_c77f';inventory=read(BASE/'baseline_inventory.json')
    for row in inventory['files']:
        p=before_folder/Path(row['path']).relative_to('resources/foundry')
        assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'],'Baseline mutation: '+str(p)
    a,export_a=validate_tree(before_folder);b,export_b=validate_tree(after_folder)
    original_basis=a['basis'];new_basis=b['basis'];assert original_basis!=new_basis,'Expected freshly computed final source basis, old c77f stamp retained'
    allowed=set();stamp(a,'basis','/batch',allowed);stamp(b,'basis','/batch',allowed)
    for data in [a,b]:
        for i,x in enumerate(data['accepted']):x['manifest']=manifest(x['manifest'],f'/batch/accepted/{i}/manifest',allowed)
        data['itineraries']=[manifest(x,f'/batch/itineraries/{i}',allowed) for i,x in enumerate(data['itineraries'])]
    changes=diff(a,b,'/batch');frames=0
    stamp(export_a,'basis','/export_basis',allowed);stamp(export_b,'basis','/export_basis',allowed)
    changes+=diff(export_a,export_b,'/export_basis')
    for old in sorted((before_folder/'replays').glob('*.json')):
        x=read(old);y=read(after_folder/'replays'/old.name);frames+=len(x['frames'])
        for value in [x,y]:
            stamp(value,'basis','/replays/'+old.name,allowed);stamp(value,'manifest_hash','/replays/'+old.name,allowed)
        changes+=diff(x,y,'/replays/'+old.name)
    result={'status':'passed' if not changes else 'failed','baseline_commit':inventory['baseline_commit'],'before_basis':original_basis,'after_basis':new_basis,'phrases':36,'itineraries':18,'replays':54,'frames':frames,'all_nonwhitelist_fields_compared_exactly_including_types':True,'allowed_stamp_paths':sorted(allowed),'differences':changes,'scope':'All original actions/axis/positions/shots and repair/route IDs preserved. Only explicitly indexed source basis/direct derived hash paths excluded. No generic recursive ID/hash omission.'}
    (BASE/'comparison.json').write_text(json.dumps(result,indent=2)+'\n')
    return result
if __name__=='__main__':
    result=compare(Path('resources/foundry'))
    print(json.dumps({k:v for k,v in result.items() if k!='allowed_stamp_paths'},indent=2))
    raise SystemExit(0 if result['status']=='passed' else 1)
