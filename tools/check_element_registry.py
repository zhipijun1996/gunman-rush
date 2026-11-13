"""Validate the single library and all canonical room instance references."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def check(root=ROOT):
    base=root/'config/world_elements';index=json.loads((base/'index.json').read_text());catalog={}
    for group in ('behaviors','definitions'):
        catalog[group]={};paths=set()
        for key,ref in index[group].items():
            assert ref.startswith(f'res://config/world_elements/{group}/') and '..' not in ref,ref
            path=root/ref[6:];assert path not in paths,ref;paths.add(path)
            value=json.loads(path.read_text());assert value['id']==key,key;catalog[group][key]=value
        assert paths==set((base/group).glob('*.json')),f'Unregistered {group} file'
    documentation=(root/'docs/data/world_objects.md').read_text()
    scripts=set()
    for key,b in catalog['behaviors'].items():
        if b.get('script'):
            assert (root/b['script'][6:]).is_file(),key
            assert b['script'] not in scripts,key;scripts.add(b['script'])
        assert b['default_definition'] in catalog['definitions'],key
    for key,d in catalog['definitions'].items():
        assert d['documentation']=='docs/data/world_objects.md',key
        assert d['version']>=1,key
        assert f'`{key}`' in documentation,f'Library documentation missing {key}'
        if 'members' in d:
            for m in d['members']:assert m['definition'] in catalog['definitions'],key
        else:
            b=catalog['behaviors'][d['component']]
            assert not (b.get('root') or b.get('internal_service') or b['category']=='internal') or not d['placeable'],key
    count=0
    for path in (root/'config/world/rooms').glob('*.json'):
        document=json.loads(path.read_text());assert document['schema']==3,path
        for row in [document['root'],*document['entities'].values()]:
            assert not {'component','node_path','node_name'}&row.keys(),path
            d=catalog['definitions'][row['definition_id']];assert row['definition_version']==d['version'],path
            assert 'members' not in d,path
        count+=1
    assert not (root/'config/world_elements.json').exists(),'Old duplicate registry remains'
    print(f'ELEMENT REGISTRY: {len(catalog["behaviors"])} behaviors, {len(catalog["definitions"])} definitions, {count} canonical rooms')
if __name__=='__main__':check()
