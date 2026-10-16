import ast, csv, hashlib, io, json, re, subprocess, sys
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace
R=Path.cwd();O=R/'build/plains_redesign/final_regression_review/c4';H=lambda b:hashlib.sha256(b).hexdigest()
C3='ee821ce18746253c01ad9e27270df96488870264';C4='a39ea373105c24b09c59b9d51b7c440440bc0a17';tool='tools/verify_plains_region_browser.py'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==C4
old=subprocess.check_output(['git','show',C3+':'+tool],text=True);new=(R/tool).read_text();assert subprocess.check_output(['git','show',C4+':'+tool],text=True)==new
oldprobe=next(n for n in ast.parse(old).body if isinstance(n,ast.AsyncFunctionDef) and n.name=='probe');newprobe=next(n for n in ast.parse(new).body if isinstance(n,ast.AsyncFunctionDef) and n.name=='probe')
oldtap=next(i for i,n in enumerate(oldprobe.body) if isinstance(n,ast.Expr) and 'touchscreen.tap' in ast.unparse(n))
assert 'text_center' in ast.unparse(oldprobe.body[oldtap]);assert 'map_chip_center' in ast.unparse(newprobe.body[oldtap]);assert 'actual_map_chip_locator' in ast.unparse(newprobe.body[oldtap+1]);assert 'touchscreen.tap(*point)' in ast.unparse(newprobe.body[oldtap+2])
oldprobe.body[oldtap:oldtap+1]=[];newprobe.body[oldtap:oldtap+3]=[];assert ast.dump(oldprobe,include_attributes=False)==ast.dump(newprobe,include_attributes=False)
# Actual complete source map, not just git committed comparison.
folder=R/'build/plains_redesign/gui_locator_diagnosis';before=json.loads((folder/'c3_complete_source_before_fix.json').read_text());bridge=json.loads((folder/'c3_to_current_bridge.json').read_text());assert before['source_digest']==bridge['original_source_digest'];assert bridge['current_commit']==C4
files=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z']).decode().split('\0');files=sorted(set(x for x in files if x));current={p:H((R/p).read_bytes()) if (R/p).is_file() else 'deleted' for p in files};assert current==bridge['current_files']
changed=[p for p in sorted(before['files'].keys()|current.keys()) if before['files'].get(p)!=current.get(p)];assert changed==bridge['changed_paths'];assert bridge['runtime_changed_paths']==[];assert [p for p in changed if not p.startswith('docs/')]==[tool]
# Each original 12 delivery log/exit and all independent49+22 fresh check completion patterns.
dp=R/'build/verification/delivery/20261015T105103Z/report.json';d=json.loads(dp.read_text());assert d['status']=='passed' and len(d['steps'])==12 and d['commit']==C3 and d['source_digest']==before['source_digest'];logs=[]
for s in d['steps']:
 assert s['status']=='passed' and s['exit_code']==0
 p=dp.parent/s['log'];logs.append(dict(path=str(p.relative_to(R)),sha256=H(p.read_bytes()),bytes=p.stat().st_size))
manifest=json.loads((R/'tools/harness/profiles.json').read_text());reports=[];sets=[]
for name,count in [('20261015T105150.413469Z',49),('20261015T111159.550455Z',22)]:
 p=R/'build/verification/harness'/name/'report.json';j=json.loads(p.read_text());assert j['status']=='passed' and j['commit']==C3 and j['release'] is True and not j['targeted_checks'] and len(j['checks'])==count and j['manifest_sha256']==H((R/'tools/harness/profiles.json').read_bytes());checks={c['id']:c for c in j['checks']};sets.append(checks)
 for c in j['checks']:
  assert c['status']=='passed' and c['exit_code']==0 and c['reused'] is False
  conf=manifest['checks'][c['id']];assert c['argv']==conf['argv'] and c['timeout_seconds']==conf['timeout_seconds'];log=p.parent/c['log'];text=log.read_text();assert re.search(conf['success_pattern'],text,re.M) and not re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script',text);logs.append(dict(path=str(log.relative_to(R)),sha256=H(log.read_bytes()),bytes=log.stat().st_size))
 reports.append(dict(path=str(p.relative_to(R)),sha256=H(p.read_bytes()),checks=count))
a,b=sets;assert len(a.keys()&b.keys())==19 and len(a.keys()|b.keys())==52 and a.keys()|b.keys()==set(manifest['checks']);assert all(a[k]['input_digest']==b[k]['input_digest'] for k in a.keys()&b.keys())
assert d['build_info']['build_id']=='eeeb0759998d' and d['build_info']['engine_id']=='d20938d2db49';actualbuild=json.loads((R/'build/web/build-info.json').read_text());assert actualbuild==d['build_info'] and H((R/'build/web/build-info.json').read_bytes())==d['build_info_sha256']
# Re-run current locator's Python selection logic with preserved real TSV bytes.
# OCR executables are deliberately mocked: no Tesseract/browser/engine is run.
sys.path.insert(0,str(R/'tools'));import verify_plains_region_browser as locator
cases=json.loads((folder/'actual_locator_cases.json').read_text())['cases'];mock_results=[]
source=R/cases[0]['source'];assert H(source.read_bytes())==cases[0]['sha256']
positive=[(folder/'real_compact_chip'/n).read_text() for n in ['top.tsv','bottom.tsv']]
negative=[(folder/'real_home'/n).read_text() for n in ['top.tsv','bottom.tsv']]
def evaluate(name,streams,accept,expected=None):
 with patch.object(locator.subprocess,'run',side_effect=[SimpleNamespace(stdout=s) for s in streams]):
  try:point,obs=locator.map_chip_center(source,O/'locator_cases'/name);accepted=True;error=None
  except RuntimeError as e:point=None;accepted=False;error=str(e)
 assert accepted==accept,(name,point,error)
 if expected is not None:assert point==expected,(name,point,expected)
 mock_results.append(dict(case=name,accepted=accepted,point=point,error=error,scope='Current Python helper; preserved real TSV or explicit TSV mutation, OCR subprocess mocked'))
evaluate('real_tsv_positive',positive,True,cases[0]['point']);evaluate('real_home_tsv_missing',negative,False)
# two genuine full-label lines in separate search windows must fail ambiguity.
full=next(s for s in positive if 'EXPLORE' in s);evaluate('duplicate_full_label',[full,full],False)
rows=list(csv.DictReader(io.StringIO(full),delimiter='\t'));header=list(rows[0])
def rewrite(rows):
 out=io.StringIO();w=csv.DictWriter(out,fieldnames=header,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows);return out.getvalue()
split=[dict(r) for r in rows]
for i,r in enumerate(split):
 if r.get('text','').strip().upper() in ['MAP','1/2','EXPLORE']:r['line_num']=str(100+i)
evaluate('tokens_split_lines',[rewrite(split),negative[1]],False)
partial=[dict(r) for r in rows]
for r in partial:
 if r.get('text','').strip().upper()=='EXPLORE':r['text']='EXPLORE!'
evaluate('near_match_not_exact',[rewrite(partial),negative[1]],False)
# Verify offline original screenshot tests source hashes/recorded raw observations.
for case in cases:
 image=R/case['source'];assert H(image.read_bytes())==case['sha256'];obs=json.loads((folder/case['name']/'observation.json').read_text());assert obs['source_sha256']==case['sha256'];assert len(obs['candidates'])==(1 if case['actually_located'] else 0)
result=dict(verdict='UNVERIFIED pending final floating/cohort admission',source_commit=C4,previous_source_commit=C3,original_probe_except_locator_ast_exact=True,complete_source_before_count=len(before['files']),complete_source_current_count=len(current),changed_paths=changed,runtime_changed_paths=[],delivery_status='passed',delivery_steps=12,reports=reports,overlap=19,union=52,common_input_digest_equal=True,current52_fresh_claim=False,build_id=d['build_info']['build_id'],engine_id=d['build_info']['engine_id'],locator_python_results=mock_results,limitations=['No native/browser/OCR executable rerun by reviewer.','C3 original52 union is fresh on C3 complete inputs; C4 GUI locator is a separately bridged test-only delta.','No fun/visual/device/all-weapons full-region/fairness acceptance.'])
(O/'checks.json').write_text(json.dumps(result,indent=2));(O/'log_inventory.json').write_text(json.dumps(logs,indent=2));(O/'source_current_inventory.json').write_text(json.dumps(current,indent=2));print('C4 checked exact probe preservation, four-path bridge, actual C3 12/12 and49+22 fresh union52; five Python locator cases; UNVERIFIED')
