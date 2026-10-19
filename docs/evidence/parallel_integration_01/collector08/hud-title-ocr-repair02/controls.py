from pathlib import Path
import sys,json,hashlib,shutil,time
sys.path.insert(0,'tools');from verify_forest_browser import validate_region_heading
out=Path(__file__).parent;inputs=[('ci7_plains1',Path('build/integration01/local-gui07/touch-plains-map1-entry.png'),'plains',1,True)]
for device in ['mouse','touch']:
 for index in [1,2]:inputs.append((f'old_{device}_forest{index}',Path(f'build/forest_grapple02/browser_gui02/{device}-thorn_forest-map{index}-entry.png'),'thorn_forest',index,True))
for name in ['wrong_region','wrong_map','blank','actual_glyphs_with_suffix','duplicate_title']:inputs.append((name,Path(f'build/integration01/hud-title-ocr-diagnosis01/{name}.png'),'plains',1,False))
inputs.append(('separated_visible_suffix',Path('build/integration01/hud-title-ocr-A-final01/separated_visible_suffix.png'),'plains',1,False));rows=[]
for name,src,region,index,should_pass in inputs:
 path=out/(name+'.png');shutil.copyfile(src,path);start=time.monotonic();row={'case':name,'source':str(src),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'expected_region':region,'expected_map':index,'should_pass':should_pass}
 try:row.update(accepted=True,point=validate_region_heading(path,region,index))
 except ValueError as e:row.update(accepted=False,error=str(e))
 row.update(correct_outcome=row['accepted']==should_pass,seconds=time.monotonic()-start);rows.append(row);print(name,row['accepted'],row['correct_outcome'],flush=True)
p=Path('tools/verify_forest_browser.py');(out/'collector-source.py').write_bytes(p.read_bytes());(out/'report.json').write_text(json.dumps({'collector_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'scope':'Production collector offline: currentCI7Plains1 plus4 OLD nativeForest images;6 pixelnegative controls. Not8actualGUIcontexts/currentForest/pause/nativegame acceptance; title-field only, no arbitrary hidden field-external text guarantee.','cases':rows},indent=2)+'\n');assert all(r['correct_outcome']for r in rows)
