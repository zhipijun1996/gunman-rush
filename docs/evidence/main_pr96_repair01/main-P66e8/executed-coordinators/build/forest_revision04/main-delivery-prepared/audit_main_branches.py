import argparse,datetime,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--expected-main',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
assert not a.output.exists()
raw=subprocess.check_output(['git','ls-remote','--heads','origin'],text=True)
heads=[{'head':s,'branch':r.removeprefix('refs/heads/')} for s,r in (line.split() for line in raw.splitlines())]
assert next(h['head'] for h in heads if h['branch']=='main')==a.expected_main
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==a.expected_main
rows=[]
for h in heads:
 r=subprocess.run(['git','merge-base','--is-ancestor',h['head'],a.expected_main],capture_output=True,text=True)
 assert r.returncode in (0,1),'Missing local commit object; fetch exact remote head before audit: '+h['branch']
 rows.append({**h,'included_in_main':r.returncode==0})
remaining=[h for h in rows if not h['included_in_main']]
groups={'old_art_UI_candidates':[h for h in remaining if h['branch'] in ('feature/biome-style-review','feature/demo-plains-art','feature/painterly-plains-v2','feature/plains-art-v3','feature/title-home-ui')],'deploy_playtest_snapshots':[h for h in remaining if h['branch'].startswith(('deploy/','playtest/'))]}
known={h['branch'] for v in groups.values() for h in v};groups['other_unmerged']=[h for h in remaining if h['branch'] not in known]
d={'observed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'actual_main':a.expected_main,'remote_head_count':len(rows),'heads_included_in_main':sum(h['included_in_main'] for h in rows),'remaining_unmerged_count':len(remaining),'groups':groups,'branches':rows,'scope':'Read-only actual remote heads and Git ancestry; no branch deletion or blind content merge. Current deployment separate.'}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(d,indent=2)+'\n');a.output.with_suffix('.ls-remote.txt').write_text(raw);print({k:d[k] for k in ['actual_main','remote_head_count','heads_included_in_main','remaining_unmerged_count']})
