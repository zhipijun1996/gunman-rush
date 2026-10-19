import pathlib,json,hashlib
repo=pathlib.Path('/workspace/gunman-rush-design');root=repo/'build/forest_depth/snapshots/crown_reverse01';base=root/'build/forest_depth/ecology/crown_reverse01'
paths=sorted(base.glob('[012]*/capture.json'));ds=[json.loads(p.read_text()) for p in paths];r=json.loads((base/'receipt.json').read_text())
result={'scope':'Offline frozen-source/raw review, no native or movie observation','receipt_passed':r['passed'],'receipt_source_guard':r['source_guard'],'source_before_count':len(r['source_before']),'source_mismatches':[k for k,h in r['source_before'].items() if not(root/k).is_file() or hashlib.sha256((root/k).read_bytes()).hexdigest()!=h],'prefix521':{},'ordinary_two_budget_equals_one_actual':{'frames':ds[1]['frames']==ds[2]['frames'],'requests':ds[1]['requests']==ds[2]['requests']},'cases':[]}
for key in ['frames','requests']:
 ps=[[f for f in d[key] if f['tick']<=521] for d in ds];result['prefix521'][key]={'lengths':[len(p) for p in ps],'exact_equal':ps[0]==ps[1]==ps[2]}
for p,d in zip(paths,ds):
 start=d['crown_return_started'];end=d['crown_return_finished'];half=d['crown_return_contract']['body_size'][1]/2
 branch=[f for f in d['frames'] if start<=f['tick']<=end]
 result['cases'].append({'path':str(p.relative_to(repo)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'strategy':d['crown_return_strategy'],'completed_legs':d['completed_legs'],'upper_ticks':end-start+1,'upper_min_feet':min(f['position'][1]+half for f in branch),'C_snapshot':d['crown_return_exit'],'final_snapshot':d['final_snapshot'],'upper_shots':[e for e in d['events'] if start<=e['tick']<=end and e['kind']=='shot_fired'],'producer_failures':d['failures']})
(repo/'build/forest_depth/independent/crown-reverse01/raw-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
