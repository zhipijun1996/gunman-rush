from pathlib import Path
import json,hashlib,subprocess
E=Path('/tmp/mapgen-v4-actual-coverage-8ms');I=Path('/tmp/mapgen-v4-actual-inputs-8ms');O=Path('/tmp/mapgen-v4-actual-coverage');OI=Path('/tmp/mapgen-v4-actual-inputs');W=Path('/tmp/map-edit-runtime-audit-v04');H=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();J=lambda p:json.loads(p.read_text());head='f6b61ee7026bc4c696d15fa26b09de5ff03be903'
def diff(a,b,path=''):
 if type(a)!=type(b):return [{'path':path,'old':a,'new':b}]
 if isinstance(a,dict):
  out=[]
  for k in sorted(a.keys()|b.keys()):
   if k not in a or k not in b:out.append({'path':path+'/'+k,'old':a.get(k),'new':b.get(k)})
   else:out+=diff(a[k],b[k],path+'/'+k)
  return out
 if isinstance(a,list):
  if len(a)!=len(b):return [{'path':path,'old_length':len(a),'new_length':len(b)}]
  return [row for i,(x,y)in enumerate(zip(a,b))for row in diff(x,y,path+'/'+str(i))]
 return []if a==b else[{'path':path,'old':a,'new':b}]
snapshot=J(I/'common/source_snapshot.json');assert snapshot['commit']==head and snapshot['before']==snapshot['after'] and len(snapshot['before'])==35466
provider=subprocess.check_output(['git','show',head+':game/world/levels/providers/runtime_map_v2_provider.gd'],cwd='/tmp/gunman-rush-mapgen-04');assert provider==(I/'common/runtime_map_v2_provider.gd').read_bytes()
validation=J(I/'common/validation.json');assert len(validation['harness_report']['checks'])==12 and validation['native_receipt']['exit_code']==0
summaries={};changes={};locks={}
for name in ['default','gears']:
 profile=J(I/(name+'-profile.json'));locks[name]={'profile_sha256':H(I/(name+'-profile.json')),'profile':profile}
 for row in profile['files'].values():assert H(I/row['path'])==row['sha256']
 old=J(O/(name+'-output')/'mechanism-coverage.json');new=J(E/(name+'-output')/'mechanism-coverage.json');raw=J(I/name/'result.json');oldraw=J(OI/name/'result.json')
 assert all(r['hostStatus']=='UNVERIFIED_CURRENT_HOST'for g in new['groups'].values()for r in g)
 invariant=['moduleIndex','groups','interfaceCoverage','hostBindings','generationInputFingerprint','modulePackageVersion','mapGenCommit','source']
 assert all(old[k]==new[k]for k in invariant)
 assert raw['map']==oldraw['map']and raw['content_store']==oldraw['content_store']
 changes[name]={'result_leaf_diff':diff(oldraw,raw),'table_changed_top_level_keys':[k for k in old if old[k]!=new[k]],'table_leaf_diff':diff(old,new),'unchanged_table_sections':invariant,'input_role_diff':{role:{'old_sha256':J(OI/(name+'-profile.json'))['files'][role]['sha256'],'new_sha256':record['sha256'],'equal_bytes':(I/record['path']).read_bytes()==(OI/J(OI/(name+'-profile.json'))['files'][role]['path']).read_bytes()}for role,record in profile['files'].items()}}
 summaries[name]={'seed':raw['map']['seed'],'instances':len(raw['map']['instances']),'connections':len(raw['map']['connections']),'groups':len(new['groups']),'objects':sum(len(g)for g in new['groups'].values()),'output_sha256':H(E/(name+'-output')/'mechanism-coverage.json'),'geometry_content_and_identity_equal_d4e':True,'all_rows':'UNVERIFIED_CURRENT_HOST'}
(E/'d4e-to-f6-diff.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2)+'\n')
positive=J(E/'positive-summary.json');assert all(H(O/p)==sha for p,sha in positive['old_d4e_files'].items());assert all(H(I/p)==sha for p,sha in positive['input_files'].items())
negative=J(E/'negative-summary.json');assert len(negative['cases'])==38 and all(r['exit_code']!=0 and r['expected_error_seen']and r['no_output']for r in negative['cases'])
oldscript=(O/'run_negatives.py').read_text();newscript=(E/'run_negatives.py').read_text();assert newscript.replace("Path('/tmp/mapgen-v4-actual-coverage-8ms')","Path('/tmp/mapgen-v4-actual-coverage')").replace("Path('/tmp/mapgen-v4-actual-inputs-8ms')","Path('/tmp/mapgen-v4-actual-inputs')")==oldscript
refs=[O/'freeze.json',O/'next-mechanisms.json',O/'next-mechanisms.md',Path('/tmp/mapgen-v4-actual-coverage-independent-review.json'),Path('/tmp/mapgen-v4-old-replay/comparison.json'),Path('/tmp/mapgen-v4-old-replay/negative-replay.json'),Path('/tmp/mapgen-v4-coverage-producer-candidate/candidate.patch')];assert all(p.exists()for p in refs)
report={'status':'ACTUAL_8MS_EXTRACTION_AND_38_NEGATIVES_PASS_NOT_PLAYABILITY','host_commit':head,'producer_base':'812e89050e062c866a5dd7e8c258e47d3897bc4d','producer_sha256':H(W/'tools/runtime_audit/check_930001.py'),'inputs':locks,'outputs':summaries,'d4e_old_files_unchanged':True,'negative_cases':38,'negative_script_only_root_paths_changed':True,'native_evidence':{'scope':validation['scope'],'receipt':validation['native_receipt'],'source_vectors_equal_independently':True,'provider_equal_git':True,'snapshot_context':snapshot['context']},'web_status':'NOT_ACCEPTED_BY_THIS_REPORT; prior 4ms REJECT retained; 8ms actual Web pending separately','planning_reuse':'d4e next-mechanisms report remains applicable because both actual map/content/identity/host bindings and every inventory row equal f6; recommendations only, no candidate mechanism implemented.','external_references':{str(p):H(p)for p in refs},'boundaries':['No game repository writes, engine/browser or generation executed.','Existing producer used with explicit actual-profile; not upstream accepted.','No numerical geometry equivalence guard for caller-relocked edits; permissions only endpoint existence.','12 native checks are limited slices, not full-map coverage.','Do not read 8ms soft target as a measured hard-frame guarantee.']}
(E/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
(E/'README.md').write_text('''# 0.4 / 8ms 实际覆盖重新提取

源 f6b61ee7026bc4c696d15fa26b09de5ff03be903。两个新的七角色锁使用本次 producing artifacts；同一已审 map-edit producer 原 --actual-profile 重新执行，未改旧表 SHA 冒充新提取。精确命令见两份 positive-receipt.json；复跑须新不存在目录。

- default：seed930001，46实例/58连接/13组/109对象。
- gears：seed930007，43实例/55连接/14组/110对象。
- 两次成功；同38个真实负例全部拒绝且无输出；负例脚本仅更换输入/输出根。
- 原d4e freeze、表、报告保持逐字不变；旧43输入/10输出重放证明引用原件，不重复跑、不复制大快照。
- d4e-to-f6-diff.json 列每个 result/table 变化字段与七输入来源 SHA。两图完整 map、content_store、所有机制行、接口、hostBindings 和 fingerprint 全等；变化为运行度量和实际源/验证来源。13/14 vs旧0.3的17是完整布局变化，不是删字段。

本次独核35466项源向量 before/after 完全相等，Provider与Git f6逐字相同；原12native报告222.429秒通过。d4e当时35586含未跟踪docs，与本次clean提交来源分开保留，不借用旧快照。稀疏缺失历史文档由原快照如实记录。

全部行仍 UNVERIFIED_CURRENT_HOST。下一批候选复用 d4e 的 next-mechanisms.md/json（SHA见report）：完整单钟门优先，邻居可能混敌人/其他机制，不授权删机制或换seed；其两份actual内容/邻域与f6已逐项核同。未执行任何新宿主机制。

本报告不签Web：原4ms实际失败保留REJECT，8ms Web另由真实测试报告决定；也不签整图可玩、权限语义、几何重锁正确或硬8ms帧预算。无游戏仓库写入，无Godot/浏览器/推送。
''')
paths=[p for p in E.iterdir()if p.is_file()and p.name!='freeze.json']+list((E/'negative-logs').glob('*.log'))+[E/(n+'-output')/'mechanism-coverage.json'for n in ['default','gears']]
freeze={'status':report['status'],'host_commit':head,'files':{str(p.relative_to(E)):H(p)for p in sorted(paths)},'producer':{'path':str(W/'tools/runtime_audit/check_930001.py'),'sha256':report['producer_sha256']},'input_root':str(I),'input_locks':locks,'references':report['external_references']};(E/'freeze.json').write_text(json.dumps(freeze,indent=2)+'\n');print('FREEZE',H(E/'freeze.json'));print(json.dumps(summaries,indent=2));print('result diffs', {n:len(d['result_leaf_diff'])for n,d in changes.items()})
