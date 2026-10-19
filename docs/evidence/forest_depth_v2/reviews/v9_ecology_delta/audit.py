import pathlib,tarfile,gzip,json,hashlib
repo=pathlib.Path('/workspace/gunman-rush-design');configs=[('D14','docs/evidence/forest_depth_v2/ecology/formal_crossbranch13_14/selected-evidence.tar.gz','actual14/run/00-crossbranch_live_H/capture.json'),('R08crown','docs/evidence/forest_depth_v2/root_entry01/root-entry01-selected.tar.gz','actual/capture.json.gz')];out={}
for name,file,member in configs:
 with tarfile.open(repo/file) as t:
  raw=t.extractfile(member).read();raw=gzip.decompress(raw) if member.endswith('.gz') else raw;d=json.loads(raw)
 frames=d['frames'];events=d['events'];states={}
 for f in frames:
  for e in f.get('enemies',[]):
   r=states.setdefault(e['id'],{'states':{},'HP_min':e['health'],'HP_max':e['health']})
   r['states'][e['state']]=r['states'].get(e['state'],0)+1;r['HP_min']=min(r['HP_min'],e['health']);r['HP_max']=max(r['HP_max'],e['health'])
 out[name]={'archive':file,'archive_sha256':hashlib.sha256((repo/file).read_bytes()).hexdigest(),'member':member,'raw_sha256':hashlib.sha256(raw).hexdigest(),'frames':len(frames),'initial':d['initial_snapshot'],'final':d['final_snapshot'],'choices':d['manifest']['choices'],'layout':d['manifest'].get('layout_version'),'completed_legs':d['completed_legs'],'enemy_states':states,'significant_events':[e for e in events if 'damage' in e['kind'] or any(s in e['kind'] for s in ('spider','apex','actual_contact','crossbranch','C_arrival'))],'requests':d['requests']}
 print(name,'frames',len(frames),'final',d['final_snapshot']);print('legs',[(e['edge_id'],e['tick']) for e in d['completed_legs']]);print('states',states);print('events',[(e['tick'],e['kind']) for e in out[name]['significant_events']])
(repo/'build/forest_depth/independent/v9-ecology-delta/raw-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
