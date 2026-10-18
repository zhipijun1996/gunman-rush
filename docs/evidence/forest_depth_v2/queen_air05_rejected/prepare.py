from pathlib import Path
import os,subprocess,hashlib,shutil,json,time
r=Path('/workspace/gunman-rush-design');src=r/'build/forest_depth/snapshots/queen-air-motion04-axis';d=r/'build/forest_depth/snapshots/queen-air-motion05-controls';o=r/'build/forest_depth/queen/air-motion-05-controls';assert not d.exists();old=json.loads((src/'build/snapshot-receipt.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();before={p:sha(src/p) for p in old['source_files']};d.mkdir();links={}
for p,h in before.items():
 s=src/p;t=d/p;t.parent.mkdir(parents=True,exist_ok=True)
 if p.startswith('assets/') and s.suffix.lower() in ('.png','.jpg','.jpeg','.webp','.ogg','.wav','.ttf','.woff','.woff2','.otf'):os.link(s,t);links[p]=str(s)
 else:shutil.copy2(s,t)
 assert sha(t)==h
assert before=={p:sha(src/p) for p in before}
subprocess.run(['git','init','--quiet',str(d)],check=True);objects=subprocess.check_output(['git','rev-parse','--path-format=absolute','--git-path','objects'],cwd=r,text=True).strip();(d/'.git/objects/info/alternates').write_text(objects+'\n');subprocess.run(['git','update-ref','--no-deref','HEAD',old['base_commit']],cwd=d,check=True);subprocess.run(['git','read-tree','HEAD'],cwd=d,check=True);(d/'.git/info/exclude').write_text('build/\n.godot/\n');(d/'build').mkdir();receipt={'scope':'Exact frozen04 production/geometry; only three finite control driver selectors plus wrapper strict cases','base_commit':old['base_commit'],'source_root':str(src),'snapshot_root':str(d),'source_files':before,'source_copy_guard':True,'shared_media_links':links,'created':time.time()};(d/'build/snapshot-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');(o/'copy-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
p=d/'tests/thorn_queen_sweep_runner.gd';s=p.read_text();s=s.replace('func run() -> void:',(o/'controls.gd.txt').read_text()+'\nfunc run() -> void:\n\tif selected=="air_ordinary": await air_ordinary()\n\tif selected=="air_camp": await air_camp()\n\tif selected=="air_wrong": await air_wrong()');p.write_text(s)
p=d/'tools/run_thorn_queen_sweep.py';s=p.read_text().replace("'adaptive_full','air_purpose']","'adaptive_full','air_purpose','air_ordinary','air_camp','air_wrong']");needle='    fights=[r for r in rows if not r.get(\'explicit_initial_probe\')]';insert='''    if selected in ('air_ordinary','air_camp','air_wrong'):
        expected = {'air_ordinary': ['air_ordinary'], 'air_camp': ['air_camp_canopy','air_camp_left_floor'], 'air_wrong': ['air_wrong']}[selected]
        if [r['id'] for r in rows] != expected:
            raise ValueError('Missing actual bounded control fixtures')
        for row in rows:
            if (row['initial_player_hp'], row['initial_boss_hp'], row['initial_energy']) != (5,24,100):
                raise ValueError('Same real initial resources required')
            if selected != 'air_wrong' and row['grapple_inputs']:
                raise ValueError('NoH control used actual H input')
        if selected == 'air_ordinary' and not (rows[0]['boss_defeated'] and not rows[0]['player_dead'] and rows[0]['wide_support_frames'] >= 12):
            raise ValueError('Ordinary strategy actual death/timeout/failed recovery retained')
        if selected == 'air_camp' and any(not r['reached'] or not (r['cycles_observed']>=2 or r['boss_defeated'] or r['player_dead']) for r in rows):
            raise ValueError('Camp requires real access and complete path observation')
        if selected == 'air_wrong' and not (rows[0]['support_reached'] and rows[0]['boss_hp'] < rows[0]['boss_hp_before_recovery'] and not rows[0]['player_dead']):
            raise ValueError('Wrong H must naturally recover and actually attack again')
''';assert needle in s;s=s.replace(needle,insert+needle);p.write_text(s)
after={p:sha(d/p) for p in before};changes={p:{'before':h,'after':after[p]} for p,h in before.items() if after[p]!=h};assert set(changes)=={'tests/thorn_queen_sweep_runner.gd','tools/run_thorn_queen_sweep.py'};(o/'overlay.json').write_text(json.dumps({'changes':changes,'production_and_geometry_exact04':True,'native_yet':False,'caps':{'cold':90,'native':120,'outer':210}},indent=2)+'\n');(o/'checkpoint-inventory.json').write_text(json.dumps(after,indent=2)+'\n');print(json.dumps({'files':len(before),'guard':True,'overlay':list(changes),'native':False}))
