import copy,json,sys
from pathlib import Path
from argparse import Namespace
ROOT=Path('/workspace/gunman-rush');sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tests')]
import level_design as cli
from level_design_analysis import compare_reports,analyze_capture,seal_report
from test_level_design_analysis import capture
from level_design_contracts import validate_design
from level_design_golden import bind_design_cards
out=ROOT/'build/verification/v2-review/retest'
results={}
data=capture();p=out/'fabricated_capture.json';log=p.with_suffix('.log')
cli.write(p,data);log.write_text('Synthetic fixture text; no engine invoked.\n')
cli.write(p.with_suffix('.invocation.json'),{'exit_code':0,'capture_sha256':cli.file_hash(p),'source_commit':data['source_commit'],'source_files':cli.source_files(),'log_sha256':cli.file_hash(log)})
args=Namespace(capture=str(p),output=str(out/'fabricated_report.json'),policy=None,evidence=[])
code=cli.analyze(args);r=cli.read(args.output)
assert code==1 and r['provenance']['status']=='failed'
results['R1']={'rejected':True,'problems':r['provenance']['problems']}
empty={'verdict':'REVIEW','routes':[{'manifest_hash':'fake','stats':{},'action_signature':{'descriptor':[]}}]}
for case in [empty,seal_report(copy.deepcopy(empty))]:assert compare_reports(case,case)['verdict']=='REJECT'
results['R2']={'empty_and_rehashed_empty_rejected':True}
x=capture()
for f in x['traces'][0]['frames']:
    if f['tick']%30==0:f['actions']=[{'type':'jump','direction':[0,0]}]
r=analyze_capture(x);assert 'low_interaction_candidate' in {f['code'] for f in r['findings']}
assert r['routes'][0]['action_signature']['descriptor']==[[]]
results['R3']={'rejected_requests_do_not_clear_gap':True}
golden=cli.read(out/'golden/report.json')
design=cli.read(ROOT/'tests/fixtures/level_design_v2/golden_challenges.json')
for c in design['challenges']:
    if c['id']=='master':c['foundry']['phrase_count']=99
p=out/'wrong_golden_card.json';cli.write(p,design)
assert 'foundry_card' in {f['code'] for f in validate_design(design)}
try:bind_design_cards(p,golden)
except ValueError as e:results['R4']={'wrong_count_rejected':True,'reason':str(e)}
else:raise AssertionError('99 phrase accepted')
for record in golden['records']:
    if record['kind']=='itinerary':record['phrase_count']=99
try:bind_design_cards(ROOT/'tests/fixtures/level_design_v2/golden_challenges.json',golden)
except ValueError as e:results['R4']['wrong_record_metadata_rejected']=str(e)
else:raise AssertionError('wrong record accepted')
cli.write(out/'counterexamples.json',results)
print(json.dumps(results,ensure_ascii=False,indent=2))
