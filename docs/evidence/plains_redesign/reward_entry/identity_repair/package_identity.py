from pathlib import Path
import copy,gzip,hashlib,io,json,re,sys,tarfile
ROOT=Path.cwd();sys.path.insert(0,str(ROOT/'tools'));import level_formal as f
F=ROOT/'build/plains_redesign/reward_entry/identity_repair';OUT=ROOT/'docs/evidence/plains_redesign/reward_entry';NEW=OUT/'identity_repair'
sha=lambda b:hashlib.sha256(b).hexdigest()
old_index=json.loads((F/'rejected_r1/index.json').read_text());index=copy.deepcopy(old_index);assert len(index['members'])==594
# Never overwrite the previous594 native/rendered/source artifacts.
for m in old_index['members']:
 packed=(ROOT/m['portable']).read_bytes();assert sha(packed)==m['portable_sha256'],m['portable']
 raw=gzip.decompress(packed) if m['compression']=='gzip' else packed
 assert sha(raw)==m['source_sha256'] and len(raw)==m['source_bytes'],m['portable']
before=json.loads((F/'source_before.json').read_text())['formal_runtime'];assert f.source_files()==before
extras=['tools/run_plains_encounter_policy_tests.py','tools/run_plains_redesign_golden_tests.py','tools/run_plains_redesign_spatial_tests.py','tools/run_plains_experience_golden_tests.py','tools/harness/profiles.json']
current=before|{p:f.file_hash(ROOT/p) for p in extras}
old_snapshot=json.loads((F/'rejected_r1/sources/source_snapshot.json').read_text());old_members=old_snapshot['members']
delta=[p for p in set(current)|set(old_members) if current.get(p)!=old_members.get(p)]
assert delta==['tools/run_plains_encounter_policy_tests.py'],delta
archive=F/'current_source.tar.gz'
with tarfile.open(archive,'w:gz') as tar:
 for name,digest in sorted(current.items()):
  raw=(ROOT/name).read_bytes();assert sha(raw)==digest,name
  info=tarfile.TarInfo(name);info.size=len(raw);info.mtime=0;tar.addfile(info,io.BytesIO(raw))
snapshot=copy.deepcopy(old_snapshot);snapshot.update(members=current,archive_sha256=sha(archive.read_bytes()),archive_path=str((NEW/'current_source.tar.gz').relative_to(ROOT)),previous_reviewed22_snapshot='docs/evidence/plains_redesign/reward_entry/sources/source_snapshot.json',delta_from_reviewed22=delta,formal_runtime_unchanged_from_rejected_r1=True,scope='Exact current32 verifier with unchanged finalB runtime/observer/core; original22 source and REWARD-R1 remain preserved; G0/G1 technical candidate only')
(F/'source_snapshot.json').write_text(json.dumps(snapshot,ensure_ascii=False,indent=2)+'\n')
proof=json.loads((F/'encounter.receipt.json').read_text());assert proof['exit_code']==0 and proof['source_before']==proof['source_after']==before
log=(F/'encounter.log').read_text();match=re.findall(r'PLAINS ENCOUNTER RECEIPT: (.+)',log);assert match,log
receipt_path=Path(match[-1]);receipt_path=receipt_path if receipt_path.is_absolute() else ROOT/receipt_path
receipt=json.loads(receipt_path.read_text());assert receipt['status']=='passed' and receipt['source_before']==receipt['source_after']==before
assert receipt['verifier_sources']['tools/run_plains_encounter_policy_tests.py']==current['tools/run_plains_encounter_policy_tests.py']
assert len(receipt['reward_entry']['runs'])==14 and len(receipt['reward_entry']['validator_refusals'])==32
cases=[]
for run in receipt['reward_entry']['runs']:
 data=json.loads((ROOT/run['output']).read_text());assert f.file_hash(ROOT/run['output'])==run['sha256'];row=data['cases'][0]
 edge=next(e for e in row['manifest']['connections'] if e['kind']=='challenge' and e['b']=='deep_'+row['tier'])
 expected='plains/enemy/'+edge['a'];assert row['guard_id']==expected
 cases.append(dict(name=run['name'],expected_physical_failure=bool(run['expected_physical_failure']),physical_failure_mode=run['expected_physical_failure'],exit_code=run['exit_code'],ticks=len(row['frames']),min_health=min(f['health'] for f in row['frames']),claimed=row['claimed'],entry_area=edge['a'],expected_guard_id=expected,manifest_guard_count=sum(e['id']==expected for e in row['manifest']['enemies'])))
assert sum(not c['expected_physical_failure'] for c in cases)==11
movie=ROOT/'build/plains_redesign/render_timing_diagnosis';trial=json.loads((movie/'controlled_trial.json').read_text());assert trial['source_before']==trial['source_after']==before
assert trial['exit_code']==0 and trial['route_reached'] and trial['ticks']==2287 and not trial['shoot_request_frames_without_accept_or_reject']
report=json.loads((movie/'current_content_serial_movie/rendered_report.json').read_text());assert report['source_files']==before
capture=json.loads((movie/'current_content_serial_movie/capture.json').read_text());assert min(f['health'] for f in capture['frames'])==5 and not capture['capture_errors']
summary=dict(status='G0_G1_technical_candidate_awaiting_distinct_review',repair='REWARD-R1 identity binding to unique Manifest challenge entrance, actual area and grounded frame',old_review_status='REJECT (retained, not overwritten)',runtime_changed_this_round=False,changed_verifier=delta,normal_cases=11,physical_negatives=3,causal_refusals=32,original22_preserved=True,new_identity_refusals=10,actual_cases=cases,actual_fresh_specialty=dict(receipt=str(receipt_path.relative_to(ROOT)),duration_seconds=proof['duration_seconds'],source_before_equals_after=True,verifier_sha256=current['tools/run_plains_encounter_policy_tests.py']),unchanged_regression_scope='R1 original15/20maps+350/255+18/3105+64 are unchanged684-GD-source proofs, not relabelled fresh32 execution; original controller will execute all9 current checks again',actual_controlled_rendered=dict(outcome=trial['outcome'],ticks=trial['ticks'],health=5,high_claimed=True,unaccepted_shoot_requests=[],resolution=[1280,720],fps=60,software_renderer_environment=trial['environment'],limits=trial['limits']),unverified=['distinct final independent review/G4','scene composition and aesthetic/audio quality','physical device PC/gamepad/touch feel','subjective fun/player acceptance','final root full31','all possible player strategies/weapons/phases'],orchestration_path_error='Initial ignored helper called nonexistent tools/test_level_formal_receipts.py, exited2 and stopped. Original receipt/log retained; correct existing tests/ discovery commands then both really passed. No test weakened or removed.',scope='Actual current source-bound specialty and protocols; evidence refusal is not content difficulty change or player approval')
(F/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
(F/'README.md').write_text('''# REWARD-R1：入口守卫身份的独立反例返工

原22版、594项便携证据及原独审 REJECT 均保留。当前只修改 Python 验收器：从唯一 challenge→deep_tier 边、真实入口 area 与实际 grounded 入口位置推导期望守卫 ID；再按 Manifest 实际库存决定每帧应有的观测。原生无通用守卫的 reward_top1/reward_high2 合法通过。没有修改生成内容、GD、冻结输入驾驶器、核心规则或标准。

`drill.json` 在哈希核验的同一真实 kill 原件上重演审查操作：原22接受未知ID+连贯删守卫/transition证据，新32拒绝。11真实正例、3真实物理负例原件在新验收器中仍分别接受/拒绝，明确属于同GD的原raw复验。随后实际原专项重新运行，保留原22反例并加入10项入口身份反例；原14敌情、3资源回退、四对旧新路线与存活绕行继续执行。summary/receipt/log记录真实版本与退出码，非无效静态mock。

`current_source.tar.gz` / `source_snapshot.json` 是本轮当前完整689源；旧 sources/ 归档仍是被拒22版，不改名冒充当前。`rejected_r1/` 与 `review_r1/` 保存旧索引、旧源码、独立审查报告及实际逃逸反例。

`controlled_rendered/` 是根任务真实单线程软件GPU控制试验：同Seed/map1/return/kill策略在2287 tick、HP5完成高箱原生领取和异路回营地，1280×720/60FPS影片。旧A教程316电影失败原样保留。控制试验只调整录制线程环境/并行负载，没有改变游戏/输入合同；未逐条注入输入墙钟计时，不能断言旧失败每一输入必为TTL过期，也不签美术、设备、性能或趣味。

scope只请求G0/G1技术复审；不同代理最终审查、场景构图、设备和真人认可保持未验。原15/20/350/64等强回归的历史源与实际退出码保留，本轮不冒称重新运行未受影响的GD套件。

本地 ignored 批运行 helper 首次把协议路径写成不存在的 tools/test_level_formal_receipts.py，实际退出2并停止；这不是协议测试结果。orchestration_path_error.json 及原receipt/log保留。之后通过原 tests/ 目录 discovery 真实运行两项协议并各退出0，没有修改测试或断言。
''',encoding='utf8')
entries=[]
def add(src,relative):
 raw=src.read_bytes();target=NEW/relative
 packed=src.suffix=='.json' and len(raw)>200_000 and 'receipt' not in src.name and 'snapshot' not in src.name
 if packed:target=Path(str(target)+'.gz')
 assert not target.exists(),str(target)
 target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(gzip.compress(raw,mtime=0) if packed else raw)
 entries.append(dict(source=str(src.relative_to(ROOT)),portable=str(target.relative_to(ROOT)),source_sha256=sha(raw),source_bytes=len(raw),portable_sha256=sha(target.read_bytes()),compression='gzip' if packed else 'none'))
for p in sorted(F.rglob('*')):
 if p.is_file() and '__pycache__' not in p.parts:add(p,p.relative_to(F))
for p in sorted(receipt_path.parent.rglob('*')):
 if p.is_file() and 'frozen_v9' not in p.relative_to(receipt_path.parent).parts:add(p,Path('current_encounter')/p.relative_to(receipt_path.parent))
add(movie/'controlled_trial.json','controlled_rendered/controlled_trial.json')
for p in sorted((movie/'current_content_serial_movie').rglob('*')):
 if p.is_file():add(p,Path('controlled_rendered')/p.relative_to(movie/'current_content_serial_movie'))
index['members'].extend(entries);index.update(status='technical_candidate_identity_repaired_awaiting_distinct_review',source=str((NEW/'source_snapshot.json').relative_to(ROOT)),source_archive=str((NEW/'current_source.tar.gz').relative_to(ROOT)),scope=summary['scope'],independent_review='R1 actual REJECT retained; R2 distinct review unverified',identity_repair=dict(summary=str((NEW/'summary.json').relative_to(ROOT)),readme=str((NEW/'README.md').relative_to(ROOT)),old_review=str((NEW/'review_r1/report.md').relative_to(ROOT)),old_reviewed_index=str((NEW/'rejected_r1/index.json').relative_to(ROOT)),preserved_old_members=594,added_members=len(entries)))
(OUT/'index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n');print('portable',len(index['members']),'added',len(entries),'source',len(current),'delta',delta,flush=True)
