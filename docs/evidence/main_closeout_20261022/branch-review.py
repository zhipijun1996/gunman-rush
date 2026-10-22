import subprocess,json,hashlib
from pathlib import Path
R=Path('/workspace/gunman-rush')
def git(*args):return subprocess.check_output(['git',*args],cwd=R,text=True).strip()
def ancestor(a,b):return subprocess.run(['git','merge-base','--is-ancestor',a,b],cwd=R,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
main=git('rev-parse','origin/main');forest=git('rev-parse','origin/feature/region-bible-v2-forest');refs=git('for-each-ref','--format=%(refname:short) %(objectname)','refs/remotes/origin').splitlines();rows=[]
for line in refs:
 name,sha=line.split(' ',1)
 if name in ['origin','origin/main']:continue
 inmain=ancestor(sha,main);inforest=ancestor(sha,forest);row={'branch':name,'head':sha,'included_in_main':inmain,'included_in_forest':inforest,'main_unique_count':int(git('rev-list','--count',main+'..'+sha)),'forest_unique_count':int(git('rev-list','--count',forest+'..'+sha))}
 if not inforest:
  row['forest_cherry']=git('cherry',forest,sha).splitlines();row['main_cherry']=git('cherry',main,sha).splitlines();row['unique_commits']=git('log','--format=%H %s',forest+'..'+sha).splitlines();row['diff_files_from_merge_base']=git('diff','--name-only',git('merge-base',forest,sha),sha).splitlines() if subprocess.run(['git','merge-base',forest,sha],cwd=R,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0 else None
 rows.append(row)
out={'scope':'read-only remote-ref snapshot ancestry and patch-ID classification, no merge/engine/browser','main':main,'forest':forest,'remote_branches_reviewed':len(rows),'main_is_ancestor_of_forest':ancestor(main,forest),'rows':rows}
Path('/tmp/gunman-main-closeout-branch-review.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({'main':main,'forest':forest,'count':len(rows),'main_in_forest':out['main_is_ancestor_of_forest'],'included_main':sum(r['included_in_main'] for r in rows),'included_forest':sum(r['included_in_forest'] for r in rows),'not_in_forest':[{k:v for k,v in r.items() if k not in ['forest_cherry','main_cherry','diff_files_from_merge_base']} for r in rows if not r['included_in_forest']]},indent=2))
