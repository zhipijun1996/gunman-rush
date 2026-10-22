from pathlib import Path
import json,hashlib,re,collections
D=Path(__file__).resolve().parent;R=Path('/tmp/gunman-v16-twelfth/bends/report.json');r=json.loads(R.read_text());s=(D/'source/scripts/generation/forest_thorn_corridor_modules.gd').read_text();cases={x['id']:x for x in r['native_cases']}
def fn(name):return re.search(r'^static func '+name+r'\([^\n]*\):?[^\n]*\n(.*?)(?=^static func |\Z)',s,re.M|re.S).group(1)
modules={}
for mid,name in [('thorn_l_root_turn','_l_root_turn'),('thorn_7_root_fold','_seven_root_fold'),('thorn_z_root_switchback','_z_root_switchback')]:
 body=fn(name);platforms={m[1]:json.loads(m[2]) for m in re.finditer(r'_p\(m,"([^"]+)",(\[[^\n]+?\])(?:,true)?\)',body)};hazards=[json.loads(m[1]) for m in re.finditer(r'_hazard\(m,"[^"]+","(?:up|down)",(\[[^\n]+?\])\)',body)]
 if mid=='thorn_l_root_turn':platforms['catch']=[-160,320,1360,40];platforms.update({'return_root_'+str(i):[-128,256-i*64,128,16] for i in range(4)})
 else:
  m=re.search(r'_tall_recovery\(m,([\d.]+),([\d.]+)\)',body);floor,far=map(float,m.groups());platforms['catch']=[-160,floor,far+160,40];y=floor-128;i=0
  while y>=64:platforms['return_root_'+str(i)]=[-128,y,128,16];i+=1;y-=128
 modules[mid]={'platforms':platforms,'hazards':hazards}
def hit(a,b,z):
 lo=0.;hi=1.
 for i in [0,1]:
  v=b[i]-a[i]
  if abs(v)<1e-12:
   if a[i]<=z[i] or a[i]>=z[i]+z[i+2]:return False
  else:
   x=(z[i]-a[i])/v;y=(z[i]+z[i+2]-a[i])/v;lo=max(lo,min(x,y));hi=min(hi,max(x,y))
   if lo>hi:return False
 return lo<=hi and hi>=0 and lo<=1
frames=r['native_frames'];bytick={f['tick']:f for f in frames};findings=[];last={};cache_hits={k:False for k in cases}
for f in frames:
 c=cases[f['case']];mod=modules[c['module_id']]
 if f['motor_step_delta']!=1:findings.append(['motor',f['tick']])
 if f['case'] in last and last[f['case']]!=f['previous_position']:findings.append(['position_discontinuity',f['tick']])
 last[f['case']]=f['position']
 for i,z in enumerate(mod['hazards']):
  if hit(f['previous_position'],f['position'],[z[0]-12,z[1]-18,z[2]+24,z[3]+36]):findings.append(['raw_hazard',f['tick'],i])
 point=c['reward_position']
 if hit(f['previous_position'],f['position'],[point[0]-28,point[1]-34,56,68]):cache_hits[f['case']]=True
for leg in r['native_legs']:
 c=cases[leg['case']];p=modules[c['module_id']]['platforms'][leg['support_id']]
 for tick in range(leg['tick']-11,leg['tick']+1):
  f=bytick[tick];x,y=f['position'];tx,ty=leg['target']
  if not(f['case']==leg['case'] and f['grounded'] and abs(f['velocity'][0])<1 and abs(x-tx)<=1 and abs(y-ty)<=1 and abs(y+18-p[1])<=1 and x-12>=p[0]-.1 and x+12<=p[0]+p[2]+.1):findings.append(['support_tail',leg['case'],leg['label'],tick])
jumptrue=[x for x in r['native_requests'] if x['kind']=='jump_held' and x['held']];events=[x for x in r['native_events'] if x['kind']=='jumped']
for q in jumptrue:
 if not any(x['case']==q['case'] and x['tick']==q['tick'] for x in events):findings.append(['jump_request_unmatched',q['case'],q['tick']])
for c in cases.values():
 if c['cheap_ordinary_onward'] and cache_hits[c['id']]:findings.append(['cheap_swept_cache',c['id']])
result={'verdict':'ACCEPT_SCOPED_ISOLATED_THREE_BENDS_AND_TWO_ORDINARY_NO_CACHE_BYPASSES' if not findings else 'REJECT_OR_UNVERIFIED','scope':'Independent Python replay of native12 original5650frame trace against archived module geometry, actual held-input edges, complete12-frame support tails. No engine by reviewer, no formal DamagePolicy/reward payout/world/FUN claim.','result':[r['assertions'],r['failures']],'frames':len(frames),'legs':len(r['native_legs']),'jump_requests':len(jumptrue),'jump_events':len(events),'findings':findings,'cache_point_swept_by_body_plus16':cache_hits,'cases':[{k:c[k] for k in ['id','module_id','passed','cheap_ordinary_onward','reward_checkpoint_verified','reward_position','reward_support_id']} for c in cases.values()],'actual_cache_arrivals':[e for e in r['native_events'] if e['kind']=='actual_cache_arrival'],'health_values':sorted(set(f['health'] for f in frames)),'shot_values':sorted(set(f['shots'] for f in frames)),'source_sha256':{'geometry':hashlib.sha256((D/'source/scripts/generation/forest_thorn_corridor_modules.gd').read_bytes()).hexdigest(),'runner':hashlib.sha256((D/'source/tests/forest_thorn_corridor_modules_runner.gd').read_bytes()).hexdigest()},'reported_source_matches':r['geometry_sha256']==hashlib.sha256((D/'source/scripts/generation/forest_thorn_corridor_modules.gd').read_bytes()).hexdigest() and r['runner_sha256']==hashlib.sha256((D/'source/tests/forest_thorn_corridor_modules_runner.gd').read_bytes()).hexdigest(),'report_sha256':hashlib.sha256(R.read_bytes()).hexdigest(),'retained_failure':'Native11 118/4 actual hazard collisions remain failed; same-support pilot now waits for designated landingx before releasing, instead of accepting any position on the same wide root. L different-support release contract is unchanged.','acceptance_limit':'7 west fast drop and Z right fast drop are intentionally legal progress-only choices. They do not enter the new far7/middle-leftZ cache even by continuous body+16 sweep. Positive reward routes visit their exact support/point and return, but formal transactions, living alternatives, actual world packing, art and FUN remain unverified.'};(D/'bends-review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:result[k] for k in ['verdict','frames','legs','jump_requests','jump_events','findings','reported_source_matches']}))
