"""Review-only fail-closed probes. No production or original artifact mutations."""
from pathlib import Path
import json, sys
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools'))
import run_plains_redesign_golden_tests as golden
source=ROOT/'build/plains_redesign/golden/run_zco65_rd/positive.json'
data=json.loads(source.read_text())
assert golden.validate_positive(data)
results=[]
def probe(name,mutate):
 undo=mutate()
 try:
  golden.validate_positive(data)
  rejected=False; reason='unexpected accept'
 except (AssertionError,KeyError,ValueError,StopIteration,TypeError) as e:
  rejected=True; reason=type(e).__name__+': '+str(e)
 finally: undo()
 results.append(dict(mode=name,rejected=rejected,reason=reason))
def change_receipt():
 o=next(o for o in data['observations'] if o['kind']=='main' and o['forward_entry'])
 e=next(e for e in o['events'] if e['kind']=='latch_health_commit');old=e['event_id'];e['event_id']='wrong:session:shot'
 return lambda:e.update(event_id=old)
def change_zero():
 f=next(o for o in data['observations'] if o['low_initial_energy'])['frames'][0];old=f['energy'];f['energy']=100
 return lambda:f.update(energy=old)
def empty_high_events():
 old=[(o,o['events'],o['shots']) for o in data['observations'] if o['kind']=='high']
 for o,_,_ in old:o['events']=[];o['shots']=0
 return lambda:[o.update(events=events,shots=shots) for o,events,shots in old]
def empty_return():
 old=[(o['legs'][1],o['legs'][1]['phrases']) for o in data['observations'] if o['kind']=='high']
 for leg,_ in old:leg['phrases']=[]
 return lambda:[leg.update(phrases=phrases) for leg,phrases in old]
for name,mutate in [('wrong_session_receipt',change_receipt),('false_zero_energy',change_zero),('empty_high_events',empty_high_events),('empty_high_second_leg_phrases',empty_return)]:probe(name,mutate)
print(json.dumps(results,indent=2))
raise SystemExit(0 if all(r['rejected'] for r in results) else 1)
