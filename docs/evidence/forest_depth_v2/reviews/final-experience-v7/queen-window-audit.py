import gzip,json,hashlib
from pathlib import Path
p=Path('docs/evidence/forest_depth_v2/queen36/movies/adaptive_H/capture.json.gz')
d=json.loads(gzip.decompress(p.read_bytes()));frames=d['frames'];window=[f for f in frames if 960<=f['tick']<=1440]
stationary=[f for f in frames if 1028<=f['tick']<=1206]
assert len(stationary)==179
assert all(f['axis']==0 and f['grounded'] and f['boss_hp']==11 and f['player']==stationary[0]['player'] for f in stationary)
r={'scope':'Offline raw window, not new native or claim of globally optimal ordinary strategy','source':str(p),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'window_ticks':[960,1440],'window_frames':len(window),'grounded_frames':sum(f['grounded'] for f in window),'hook_states':sorted(set(f['hook'] for f in window)),'stationary_interval_ticks':[1028,1206],'stationary_frames':len(stationary),'player':stationary[0]['player'],'boss_hp_through_interval':11,'geometry_fact':{'start_y':570,'tip_y':585,'max_upward_translation':180,'strand_radius':6,'lowest_possible_danger_y':384,'middle_branch_feet_y':360,'minimum_separation':24},'not_proven':'No manual reaction comfort, human enjoyment, audio or final source native rerun'}
Path('build/forest_depth/independent/final-experience-v7/queen-window-audit.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r,indent=2))
