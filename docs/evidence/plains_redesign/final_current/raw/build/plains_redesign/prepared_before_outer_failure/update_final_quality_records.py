"""Root metadata update after actual terminal evidence packaging. No source/test changes."""
from pathlib import Path
import hashlib,json,subprocess

R=Path('/workspace/gunman-rush'); B=R/'build/plains_redesign'
C4='a39ea373105c24b09c59b9d51b7c440440bc0a17'
C3='ee821ce18746253c01ad9e27270df96488870264'
E=R/'docs/evidence/plains_redesign/final_current'
index=json.loads((E/'index.json').read_text())
members={x['original_path']:x for x in index['members']}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def read(p):return json.loads((R/p).read_text())
def write(p,d):
    p=R/p;p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def evidence(record,eid,path,kind,observed,producer='Codex /root',commit=C4,**extra):
    m=members.get(path)
    actual=E/m['stored'] if m else R/path
    assert actual.is_file(),actual
    if m:
        assert sha(R/path)==m['sha256'],('Packaged original is stale',path)
        assert sha(actual)==m['stored_sha256'],('Stored bytes changed',path)
    item={'id':eid,'path':str(actual.relative_to(R)),'sha256':sha(actual),'kind':kind,
          'producer':producer,'source_commit':commit,'content_version':record['content_version'],
          'method':'Actual original execution or independently attributed observation; portable index preserves raw/stored SHA and original source version. '+extra.pop('method',''),
          'observed':observed,**extra}
    record['evidence'].append(item);return eid
def state(status,reason,*refs):return {'status':status,'reason':reason,'evidence':list(refs)}
def criterion(record,cid,gate,dimension,status,scenario,method,expected,failure,*refs):
    record['criteria'].append({'id':cid,'gate':gate,'dimension':dimension,'status':status,
        'scenario':scenario,'method':method,'expected':expected,'failure':failure,'evidence':list(refs)})

assert read('build/plains_redesign/controlled_comparison/execution.json')['commands'][-1]['exit_code']==0
assert read('build/plains_redesign/worst_movie_execution.json')['status']=='recorded'

# Parent is deliberately not completed: scope includes failed composition goals and unverified play quality.
p='docs/quality/records/PLAINS-REDESIGN-01.json';d=read(p)
d.update(reviewed_commit=C4,workflow='review');d['evidence']=[];d['criteria']=[]
cohort=evidence(d,'controlled160','build/plains_redesign/controlled_comparison/execution.json','command',
    'Actual old80/new80 with identical19driver/133core/initial capability and kill_from_bank policy; analysis2 and strict compare exit0. Collection integrity is not all-goal success.',
    command='python3 build/plains_redesign/run_controlled_comparison.py',exit_code=0,environment='Godot4.7.2 Standard; LP_NUM_THREADS=1; CPU quota4; two cases per side, before side then after side, no other engine')
readout=evidence(d,'paired_observations','build/plains_redesign/controlled_comparison/after_experience.json','runtime_trace',
    '51→71 strategy goals, no new reached→failed pairs;9 unresolved. Both-reached51: low-interaction candidates52→33, player harm46→49. These are proxies/facts, not fun scores.')
full=evidence(d,'original_c3_delivery','build/verification/delivery/20261015T105103Z/report.json','command',
    'OriginalC3 12/12actual steps, fresh49+22 checks with19overlap=52 distinct; originalC3 fingerprint retained. Not a fresh52 C4 invocation.',commit=C3,
    command='python3 tools/deliver.py --jobs 4',exit_code=0,environment='OriginalC3 Linux/Godot4.7.2/Xvfb/Chromium; see original12 command logs')
guard=evidence(d,'independent_engineering_guard','build/plains_redesign/final_regression_review/c4/closure.md','review',
    'ACCEPT scoped to test preservation, exact rollback, originalC3 release plus C4 test-only bridge, GUI and160 provenance. Does not accept Q6/fun/device/full weapon or bidirectional fairness.',
    producer='/root/plains_spatial_audit',reviewer='/root/plains_spatial_audit',implementers=['Codex /root','/root/plains_scene_worker','/root/plains_spatial_worker'],verdict='ACCEPT',independent=True,
    independence_basis='Different read-only agent; actual commands inspect source/receipts/logs and original assertions, no production changes or engines.')
gui=evidence(d,'actual_gui_v2','build/plains_redesign/final_gui_v2/execution.json','gui',
    'Actual Fog map8/floating touch7 checks, no failures, C3 unchanged build with C4 test-only bridge. Seeded9notes and emulated touch remain explicit fixtures.')
spec=evidence(d,'design_contract','docs/quality/plains_redesign_design.md','spec',
    'Authorized full Plains redesign intent; individual candidate decisions remain proposed, not final user acceptance.')
design=evidence(d,'independent_design','build/plains_redesign/final_design_review/report.md','review',
    'Independent Q1–Q8 design observations; actual improvement and remaining risks remain separated. Read the original final report for its precise verdict and frame-view scope.',
    producer='/root/plains_design_challenge',reviewer='/root/plains_design_challenge',implementers=['Codex /root','/root/plains_scene_worker','/root/plains_spatial_worker'],verdict='UNVERIFIED',independent=True,
    independence_basis='Read-only different agent, independently reviews implemented contracts and actual route evidence; no candidate implementation.')
vfinal=read('build/plains_redesign/final_visual_review/finalization.json')
assert vfinal['status']=='completed_bounded_review' and vfinal['report_sha256']==sha(R/'build/plains_redesign/final_visual_review/report.md')
visual=evidence(d,'independent_visual','build/plains_redesign/final_visual_review/report.md','review',
    'Final actual frame-sampled visual review only; exact viewed PNG hashes/ticks and exclusions retained. Repeated unsupported ivy/arch and absent strong well identity remain Q6 failure, no full-film/audio/human/device approval.',
    producer='/root/plains_visual_independent',reviewer='/root/plains_visual_independent',implementers=['Codex /root','/root/plains_scene_worker'],verdict=vfinal['verdict'],independent=True,
    independence_basis='Different read-only visual reviewer, actual original-resolution PNG viewing with provenance; no production edits or native reruns.')
shot=evidence(d,'actual_current_composition','build/plains_redesign/matched_movies/after/intro_fast/frames/frame_001680.png','screenshot',
    'Actual current source C4 rendered frame1680; floating ivy, rectangular support and DEEP DROP label can be examined. One frame is not whole-region quality proof.')
d['dimensions']['technical']=state('passed','Original freshC3 release52 union plus independently checked C4 test-only bridge, current actual160 and GUI; no globalfresh52C4 claim.',cohort,guard)
d['dimensions']['design']=state('unverified','Whole-area quality and candidate creative decisions have not been accepted; specific improvements do not satisfy all goals.',spec,design)
d['dimensions']['formal_integration']=state('unverified','Actual two maps and legal loader observed;9 policy goals unresolved and all legal builds/full two-Boss campaign not covered.',cohort,gui)
d['dimensions']['visual']=state('failed','Four strong spatial/composition identities not achieved; two rejected prop variants and one rejected atlas remain blocked; restore is not aesthetic success.',design,visual,shot)
for name in ['animation','audio_vfx','gameplay','performance','device','player_acceptance']:
    d['dimensions'][name]=state('unverified',{
        'animation':'Normal-speed movie evidence exists; complete motion/aesthetic acceptance has not been signed.',
        'audio_vfx':'Actual60FPS stereo48k media retained, no full soundtrack listening or subjective mix approval.',
        'gameplay':'No actual player fun acceptance; observed goal/interaction gains do not prove enjoyment or ordinary-player fairness.',
        'performance':'Offline software-GPU wall time is not target device performance; existing exit warnings retained.',
        'device':'Chromium emulation/native synthetic input do not prove physical keyboard/gamepad/Android/iPhone usability.',
        'player_acceptance':'User has not approved this candidate game/art/fun quality.'}[name],cohort if name=='gameplay' else gui if name=='device' else guard)
d['dimensions']['independent_review']=state('unverified','Engineering scope accepted; overall design/composition/fun target not accepted.',guard,design)
for gate in d['gates']:d['gates'][gate]=state('unverified','Whole-region gate remains incomplete; see bounded actual scenarios and dimensions.',cohort,design)
d['gates']['G2']=state('failed','Q6 target demonstrably not achieved; rejected source/media preserved.',design,visual,shot)
criterion(d,'SAME_POLICY_160','G1','technical','passed','Same10roots×2maps×4goals and initialPulseLv1 base ability.',
    'Actual source-bound native captures, strict analysis2 recomputation, pair comparison; all failures retained.',
    '160 valid captures with identical driver/core/capability basis, not160 successful routes.',
    'Any missing/raw/receipt/source mismatch, changed core/capability or invalid compare.',cohort,guard)
criterion(d,'VISUAL_IDENTITIES','G2','visual','failed','Clock court and creek should have distinct, credible spatial silhouettes.',
    'Actual normal-resolution golden frames and independent design/visual review, preserving rejected variants.',
    'Different meaningful composition and readable anchors, not giant recycled props.',
    'Repeated thin arches/ivy or suspended oversized prop substitutes; current target not met.',design,visual,shot)
criterion(d,'FINAL_PLAYER_FUN','G5','gameplay','unverified','Ordinary player can find enjoyable exploration and learnable short chains.',
    'Actual future human play and final creative acceptance, separate from synthetic policy.',
    'Source-bound player feedback covering exploration, challenge and recovery.',
    'Missing player evidence or continued negative feedback.',design)
cases=read('build/plains_redesign/controlled_comparison/after_experience.json')['cases'];consumers=[];observations=[]
for c in cases:
    q=c['case'];cid=f"plains/map{q['map_index']}/{q['root_seed']}/{q['strategy']}/phase{q['phase_wait_ticks']}"
    consumers.append({'id':cid,'runtime_call_path':'DemoApp → PlainsRegionStage → actual generated layout, Motor/Router, live enemies and actual mechanisms',
        'case':q,'manifest_hash':c['manifest_hash'],'outcome':c['outcome'],'source_commit':c['source_commit']})
    observations.append({'consumer':cid,'status':'passed' if c['route_reached'] else 'failed','output':'behavior',
        'reason':'Actual tested strategy reached its bounded goal; not all strategies or human fairness.' if c['route_reached'] else 'Actual strategy policy stopped; not physical impossibility, alternate path unverified.',
        'evidence':[readout]})
inventory='docs/evidence/plains_redesign/acceptance/consumer_inventory.json'
write(inventory,{'scope':'Actual80 formal route-case consumers only, not31 test suites, every actor/state/build, full campaign, or subjective quality.',
    'source_commit':C4,'content_version':d['content_version'],'producer':'Root derivation from strict-recomputed actual after report; no invented runtime consumers.',
    'input_sha256':sha(R/'build/plains_redesign/controlled_comparison/after_experience.json'),'consumers':consumers})
inv=evidence(d,'runtime_consumer_inventory',inventory,'runtime_trace','80 actual current route-case consumers with precise source/Manifest/outcome. Bounded partial inventory; unknown coverage remains unknown.')
next(x for x in d['evidence'] if x['id']==readout)['consumers']=[x['id'] for x in consumers]
d['consumer_coverage']={'scope':'80actual formal route goals, PulseLv1/1jump/2airshots, phase0 and enemy policy only. No all-consumer claim.9 failed goal observations remain blockers.','inventory_evidence':inv,'observations':observations}
d['unverified_items']=['Whole Q1–Q8 goal NOT complete: Q6failed and remaining enemy-bank policy/fairness issues.',
    'Nine unresolved map2 reward/return strategies, clockwise outer return and repetitive remote composition.',
    'Both-reached51 harmed46→49; map2fast10 paired harmed4→10; not hidden by total aggregate.',
    'Full two-Boss campaign, all legal whole-region weapon/build routes, physical devices and target performance.',
    'Final human art/fun/gamefeel/audio acceptance; normal movie existence does not prove it.']
write(p,d)

# Test-only locator is a separately completed process scope, never a content-quality pass.
p='docs/quality/records/PLAINS-REDESIGN-GUI-LOCATOR-01.json';d=read(p);d.update(reviewed_commit=C4,workflow='done');d['evidence']=[];d['criteria']=[]
s=evidence(d,'locator_spec','docs/quality/plains_redesign_gui_locator.md','spec','Locate actual compact map-chip pixels, require unique same-line MAP1/2EXPLORE, preserve all original modal/movement assertions.')
c=evidence(d,'actual_gui','build/plains_redesign/final_gui_v2/execution.json','command','Actual full original region8 and floating7 GUI checks passed; old failure retained, runtime/build bytes unchanged.',command='python3 build/plains_redesign/run_final_gui_v2.py',exit_code=0,environment='Actual isolated Chromium/Xvfb/WebC3 unchanged; GUNMAN_RECORD_GUI=1; C4 test-only source bridge')
r=evidence(d,'independent_guard','build/plains_redesign/final_regression_review/c4/closure.md','review','Independent actual AST/source preservation, negative parser observations and successful actualGUI admitted; scope test locator only.',producer='/root/plains_spatial_audit',reviewer='/root/plains_spatial_audit',implementers=['Codex /root'],verdict='ACCEPT',independent=True,independence_basis='Different read-only agent, no production edits; actual commands and preserved original negative evidence.')
for n in d['gates']:d['gates'][n]=state('not_applicable','Pure verification locator process; no runtime content change.')
for n in d['dimensions']:d['dimensions'][n]=state('not_applicable','Pure verification locator process; no content/device/aesthetic acceptance claimed.')
d['dimensions']['design']=state('passed','Exact source-pixel locating contract and no fallback/injection.',s)
d['dimensions']['technical']=state('passed','Actual original GUI assertions pass; real prior failure and parser negatives preserved.',c)
d['dimensions']['independent_review']=state('passed','Independent scope-specific preservation/admission audit.',r)
d['gates']['G0']=state('passed','Bounded test-only process design.',s)
d['gates']['G4']=state('passed','Actual GUI plus independent preservation review.',c,r)
criterion(d,'VISIBLE_CHIP','G0','design','passed','Compact visible label, real Home/Title missing label and ambiguous parser observations.',
    'Finite actual-pixel OCR windows; same-line strict tokens and unique candidate; no fixed coordinate success.',
    'Visible real label located; missing/ambiguous labels refused, all original game assertions retained.',
    'Fallback/injected label, missing-label acceptance or removed original assertion.',s,r)
criterion(d,'ACTUAL_GUI','G4','technical','passed','Original real Home/Fog/map-input path and independent three-touch contact path.',
    'Original browser probes, source/build bridge and retained raw screens/events/WebM.',
    '8+7actual checks failed0 on unchanged C3build with current C4 locator.',
    'Any timeout, engine error, missing assertion, source drift or failed check.',c,r)
d['unverified_items']=['C3original52 not globally freshC4; actual explicit runtime/test-only bridge retained.','No Q6/fun/device content completion implied.'];write(p,d)

# Exact restoration has real regression evidence, but retain review for its formal visual scope.
p='docs/quality/records/PLAINS-REDESIGN-Q6-ROLLBACK-01.json';d=read(p);d.update(reviewed_commit=C4,workflow='review');d['evidence']=[]
c=evidence(d,'current_original_tests','build/plains_redesign/controlled_comparison/execution.json','command','Actual frozen current native captures and strict comparison; original freshC3 full release joined by immutable C4 source bridge.',command='python3 build/plains_redesign/run_controlled_comparison.py',exit_code=0,environment='ActualGodot4.7.2 LP1 two-case captures; before then after')
r=evidence(d,'independent_exact_restore','build/plains_redesign/final_regression_review/c4/closure.md','review','Four exact20f files, original59/10/12 strong matrix preserved, rejected14/14 source retained; no Q6 acceptance.',producer='/root/plains_spatial_audit',reviewer='/root/plains_spatial_audit',implementers=['Codex /root'],verdict='ACCEPT',independent=True,independence_basis='Independent read-only source and actual report/receipt/log audit.')
d['dimensions']['technical']=state('passed','Actual original release plus current actual captures/source bridge and exact byte audit.',c,r)
d['dimensions']['formal_integration']=state('unverified','Actual visible restoration observed, whole visual/fairness target remains outside accepted scope.',c,r)
d['unverified_items']=['Restoration mechanically revalidated; Q6 stillfailed and user/device/fun not accepted.','Original backwards enemy-bank fairness limits remain.'];write(p,d)
print('Updated parent REVIEW with failed visual and actual partial inventory; process-only locator DONE; restoration REVIEW. No content completion.')
