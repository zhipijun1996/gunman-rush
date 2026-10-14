import copy,json,sys
from pathlib import Path
from argparse import Namespace
ROOT=Path('/workspace/gunman-rush')
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tests')]
import level_design as cli
from level_design_analysis import compare_reports,analyze_capture
from test_level_design_analysis import capture
from level_design_contracts import validate_design
from level_design_golden import bind_design_cards
out=ROOT/'build/verification/v2-review'
results={}
data=capture()
p=out/'fabricated_capture.json'; log=p.with_suffix('.log')
cli.write(p,data); log.write_text('This is synthetic fixture text. No engine was invoked.\n')
cli.write(p.with_suffix('.invocation.json'),{'exit_code':0,'capture_sha256':cli.file_hash(p),'source_commit':data['source_commit'],'source_files':cli.source_files(),'log_sha256':cli.file_hash(log)})
args=Namespace(capture=str(p),output=str(out/'fabricated_report.json'),policy=None,evidence=[])
exit_code=cli.analyze(args)
results['R1_receipt']={'exit_code':exit_code,'provenance':cli.read(args.output)['provenance']}
empty={'verdict':'REVIEW','routes':[{'manifest_hash':'fake','stats':{},'action_signature':{'descriptor':[]}}]}
cli.write(out/'empty_report.json',empty)
results['R2_compare_empty']=compare_reports(empty,empty)
# Requests which do not produce an accepted state change must not erase a grounded gap.
base=capture(); baseline=analyze_capture(base)
for frame in base['traces'][0]['frames']:
    if frame['tick']%30==0: frame['actions']=[{'type':'jump','direction':[0,0]}]
results['R3_rejected_input_gap']={'before':[f['code'] for f in baseline['findings']], 'after':[f['code'] for f in analyze_capture(base)['findings']], 'actual_action_signature':analyze_capture(base)['routes'][0]['action_signature']}
cli.write(out/'rejected_requests_capture.json',base)
# Matching template alone does not enforce the design itinerary phrase count.
design=cli.read(ROOT/'tests/fixtures/level_design_v2/golden_challenges.json')
for card in design['challenges']:
    if card['id']=='master':card['foundry']['phrase_count']=99
cli.write(out/'wrong_golden_card.json',design)
results['R4_golden_card_contract']=validate_design(design)
fake_records={'records':[{'manifest_id':'height','template_id':'height_then_precision'},{'manifest_id':'resource','template_id':'resource_then_rhythm'},{'manifest_id':'route','kind':'itinerary','phrase_ids':['a','b','c']}]}
results['R4_golden_binding']=bind_design_cards(out/'wrong_golden_card.json',fake_records)
cli.write(out/'counterexamples.json',results)
print(json.dumps(results,ensure_ascii=False,indent=2))
