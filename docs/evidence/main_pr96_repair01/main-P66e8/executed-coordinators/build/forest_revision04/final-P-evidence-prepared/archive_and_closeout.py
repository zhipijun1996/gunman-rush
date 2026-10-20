"""Root-executed P closeout. No mutation without --apply and all real final receipts.

Prepared only: this file neither runs checks nor supplies fabricated review facts.
All path/pointer bindings come from the final real outputs listed by the root.
"""
from __future__ import annotations
import argparse, hashlib, json, re, shutil, subprocess, sys, zipfile
from pathlib import Path

ROOT = Path('/workspace/gunman-rush')
P = '66e8b912854d6d4cccadb45b9c348a618689f5a1'
AUDIT = 'c47e366e9fbc1e3584a7c7e3eb8b983422156e21eb420a34456a2d8eb7219791'
TARGET = ROOT/'docs/evidence/main_pr96_repair01/main-P66e8'
SCRIPT_HASHES = {
 'verify_action_budget_browser': '6892d970f6272915cf99b2897d140299d41b744ce76379c7d9f286d5284f48ca',
 'verify_studio_click_browser': '8b1b17a7e29d1b01b45db4dc58726dfe901dc049bf12ab1bac488edf890f4825',
 'verify_all_weapon_browser': 'c4f069fb1c5775145dde9b1be2564bd08959ff7c773c108f7ce41e3cc27f7272',
}

def require(ok, why):
    if not ok: raise ValueError(why)

def path(value):
    p=Path(value); p=p if p.is_absolute() else ROOT/p
    p=p.resolve(); require(p.is_relative_to(ROOT), 'Evidence must be inside this repository: '+str(p))
    return p

def sha(p):
    with Path(p).open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()

def read(p): return json.loads(Path(p).read_text())
def save(p,v): p.parent.mkdir(parents=True,exist_ok=True); p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
def git(*argv): return subprocess.check_output(['git',*argv],cwd=ROOT,text=True).strip()

def pointer(value, name):
    if not name: return value
    require(name.startswith('/'), 'Use explicit JSON pointers')
    for key in name[1:].split('/'):
        key=key.replace('~1','/').replace('~0','~')
        value=value[int(key)] if isinstance(value,list) else value[key]
    return value

def harness_report(filename, expected_ids, manifest, release=None, partial=None):
    d=read(filename); require(d['commit']==P and d['status']=='passed' and not d['git_status'].strip(), 'Harness source/status mismatch: '+str(filename))
    require(not d.get('targeted_checks'), 'Targeted checks cannot replace full profiles')
    if release is not None: require(d['release'] is release, 'Fresh release profile required')
    if partial is not None: require(d.get('partial') is partial, 'Wrong complete/phase scope')
    rows=d['checks']; require(len(rows)==len(expected_ids) and {x['id'] for x in rows}==set(expected_ids), 'Full profile IDs/count mismatch')
    for r in rows:
        definition=manifest['checks'][r['id']]
        require(r['status']=='passed' and r['exit_code']==0 and r.get('failure_reason') is None and r.get('reused') is False, 'Nonfresh/failed check: '+r['id'])
        require(r['argv']==definition['argv'] and r['timeout_seconds']==definition['timeout_seconds'], 'Original CLI/cap changed: '+r['id'])
    if 'source_files' in d: require(d['source_files']==d['source_files_after'], 'Harness complete source changed')
    return d

def review_binding(item, role):
    f=path(item['path']); require(f.is_file() and sha(f)==item['sha256'], 'Review bytes not explicitly bound: '+role)
    d=read(f); require(pointer(d,item['source_pointer'])==P, 'Review is not for P: '+role)
    require(str(pointer(d,item['verdict_pointer'])).startswith('ACCEPT'), 'Review did not accept its stated scope: '+role)
    reviewer=pointer(d,item['reviewer_pointer']); require(isinstance(reviewer,str) and reviewer.startswith('/root/') and reviewer not in ['/root','/root/snapshot_perf_repair'], 'Independent reviewer identity required')
    require(item.get('scope') and isinstance(item.get('assertions'),list) and item['assertions'], 'Review scope and actual typed claims required')
    for a in item['assertions']:
        actual=pointer(d,a['pointer'])
        if 'equals' in a: require(actual==a['equals'], 'Review claim mismatch: '+role+' '+a['pointer'])
        elif 'length' in a: require(isinstance(actual,(dict,list)) and len(actual)==a['length'], 'Review coverage count mismatch')
        else: raise ValueError('Review assertion must use equals or length')
    return {'path':f,'document':d,'reviewer':reviewer,'binding':item}

def confirmed_claims(review, names):
    """These pointers address explicit true claims written by the actual reviewer."""
    claims=review['binding'].get('claims',{})
    require(isinstance(claims,dict) and set(names)<=set(claims), 'Required actual independent claims absent')
    for name in names:
        require(isinstance(claims[name],str) and pointer(review['document'],claims[name]) is True,
                'Actual reviewer did not confirm '+name)

def validate(c):
    require(git('rev-parse','HEAD')==P and not git('status','--porcelain'), 'Only execute after final guards while clean exact P is checked out')
    require(sha(ROOT/'docs/quality/level_design_v2_audit.md')==AUDIT, 'Frozen audit bytes changed')
    ci=c['ci']; run=read(path(ci['run_api'])); docsrun=read(path(ci['docs_run_api'])); jobs=read(path(ci['jobs_api']))['jobs']
    for d,name,run_id in [(run,'Godot core',39452164092),(docsrun,'Documentation',39452164153)]:
        require(d['id']==run_id and d['head_sha']==P and d['event']=='push' and d['head_branch']=='main' and d['run_attempt']==1 and d['status']=='completed' and d['conclusion']=='success', 'Final whole actual main workflow not successful: '+name)
    for name in ['prepare','core_checks (serial)','core_checks (parallel)','core','web','windows','deploy_web','verify_public']:
        rows=[j for j in jobs if j['name']==name]; require(len(rows)==1 and rows[0]['status']=='completed' and rows[0]['conclusion']=='success', 'Final required job incomplete: '+name)
    require(all(j['conclusion'] in ('success','skipped') for j in jobs), 'Unexpected failed/cancelled job')
    require(all(j['name']=='android' for j in jobs if j['conclusion']=='skipped'), 'Unexpected skipped check')
    manifest=read(ROOT/'tools/harness/profiles.json')
    ids=list(dict.fromkeys(n for profile in ['gameplay','art'] for n in manifest['profiles'][profile])); require(len(ids)==120,'Expected original full120 manifest')
    merged=harness_report(path(ci['merged_report']),ids,manifest,True,False)
    serial=read(path(ci['serial_report'])); parallel=read(path(ci['parallel_report']))
    sid=[x['id'] for x in serial['checks']]; pid=[x['id'] for x in parallel['checks']]
    require(len(sid)==39 and len(pid)==81 and not set(sid)&set(pid) and set(sid+pid)==set(ids), 'Original39/81 phase union incomplete')
    harness_report(path(ci['serial_report']),sid,manifest,True,True); harness_report(path(ci['parallel_report']),pid,manifest,True,True)
    require({x['id']:x for x in merged['checks']}=={x['id']:x for x in serial['checks']+parallel['checks']}, 'Merged rows differ from actual phase rows')
    web=harness_report(path(ci['web_report']),manifest['profiles']['web'],manifest,True)
    docs=harness_report(path(ci['docs_report']),manifest['profiles']['docs'],manifest)
    require(len(web['checks'])==41 and len(docs['checks'])==26,'Original Web41/Docs26 coverage changed')
    forest=read(path(ci['forest_receipt'])); require(forest['source_head']==P and forest['status']=='passed' and forest['source_stable'] and len(forest['requested_cases'])==80 and len(forest['runs'])==80 and forest['not_executed_case_indices']==[], 'Original complete strict80 not accepted')
    require(all(r['status']=='passed' and r['exit_code']==0 and r['errors']==[] for r in forest['runs']), 'Actual forest strict native failure')
    fcheck=next(r for r in merged['checks'] if r['id']=='forest-depth-region'); require(fcheck['timeout_seconds']==600 and fcheck['duration_seconds']<600,'Original forest80/600 failed')
    browser=path(c['browser']); outer=read(browser/'outer.json'); original=read(browser/'original/receipt.json')
    require(outer['status']=='passed' and outer['execution_head']==P and outer['source_stable'] and original['status']=='passed' and original['source_commit']==P,'Actual CI three-browser output incomplete')
    require(outer['original_consumer_caps_seconds_each']==300 and outer['extra_combined_timer'] is None,'Original independent browser caps changed')
    require(outer['source_before']==outer['source_after'] and original['web_inventory_before']==original['web_inventory_after'],'Browser source/bundle changed')
    api=read(path(ci['artifact_api'])); inventory=read(path(ci['artifacts_api']))['artifacts']; hits=[x for x in inventory if x['name']=='gunman-rush-web-playtest' and not x.get('expired',False)]
    require(len(hits)==1 and hits[0]==api and api['workflow_run']['id']==run['id'] and api['workflow_run']['head_sha']==P,'CI artifact not unique/exact P')
    a=original['artifact_receipt']; require(api['digest']=='sha256:'+a['zip_sha256'] and api['size_in_bytes']==a['zip_bytes'] and api['id']==a['artifact_id'],'CI API ZIP identity mismatch')
    actual_zip=path(a['path']); require(actual_zip.is_file() and actual_zip.stat().st_size==a['zip_bytes'] and sha(actual_zip)==a['zip_sha256'],'Actual downloaded ZIP bytes no longer match unique CI API')
    with zipfile.ZipFile(actual_zip) as z:
        original_zip_reference={'path':str(actual_zip.relative_to(ROOT)),'bytes':a['zip_bytes'],'sha256':a['zip_sha256'],'artifact_id':api['id'],'api_digest':api['digest'],'source_commit':P,'original_retained_locally':True,'CRC_validation_scope':'Original successful coordinator extracted every member with ZipExtFile CRC verification; this closeout reads directory CRC metadata, without repeating browser/consumer execution.','members':[{'name':i.filename,'bytes':i.file_size,'compressed_bytes':i.compress_size,'crc32':f'{i.CRC:08x}'} for i in z.infolist()]}
    require(a['digest_source']=='unique run artifact API digest' and original['run_api_sha256']==sha(path(ci['run_api'])) and original['artifact_api_sha256']==sha(path(ci['artifact_api'])),'API-bound original receipt mismatch')
    results=original['browser_results']; require(len(results)==3,'Not all original three consumers ran')
    report_names=['action_budget','studio_input','weapons']; counts=[25,40,8]
    for (name,expected_hash),r,folder,count in zip(SCRIPT_HASHES.items(),results,report_names,counts):
        require(r['status']=='passed' and r['exit_code']==0 and r['script_sha256']==expected_hash and r['command'][1].endswith('/'+name+'.py'),'Original browser CLI/result mismatch')
        d=read(browser/'original/browser-cwd/build'/folder/'browser/report.json'); require(len(d['checks'])==count and all(d['checks'].values()) and d['failed'] in (0,[]) and not d.get('errors',d.get('browser_errors',[])),'Final original browser assertions failed')
    public=path(c['public']); u=read(public/'outer.json'); full=read(public/'public-bytes.json'); gui=read(public/'forest-GUI/report.json'); selector=read(public/'selector/report.json')
    require(u['status']=='passed' and u['execution_head']==P and u['source_before']==u['source_after'] and len(u['commands'])==3 and all(x['exit_code']==0 for x in u['commands']),'Actual public coordinator incomplete')
    require(u['original_consumer_caps_seconds']=={'forest_GUI':480,'selector_supplement':120,'combined':None} and all(x['source_after']==u['source_before'] for x in u['commands']),'Public source or original consumer cap changed')
    require(full['status']=='passed' and full['source_commit']==P and full['pack_sha256']==a['pack_sha256'] and full['pack_bytes']==a['pack_bytes'],'Full public PCK differs from actual CI pack')
    require(full['contract']=='official-tools-build-web-six-sidecars-v1' and len(full['license_files'])==6 and full['source_stable'] and full['source_before']==full['source_after'], 'Actual official six-sidecar public contract/source guard incomplete')
    require(full['old_failure_reference']['status']=='failed' and full['style_license_contract']['present_in_actual_CI'] is False and len(full['complete_CI_build_report_artifacts'])==359, 'Wrong official export contract or old failure rebound')
    public_pack=public/'public_bytes'/original['build_info']['pack']; require(public_pack.is_file() and public_pack.stat().st_size==a['pack_bytes'] and sha(public_pack)==a['pack_sha256'],'Locally retained full downloaded public PCK changed')
    if c.get('public_contract_failure'):
        failed=path(c['public_contract_failure']); old=read(failed/'outer.json'); diagnosis=read(path(c['public_contract_diagnosis'])/'diagnosis.json')
        require(old['status']=='failed' and old['execution_head']==P and len(old['commands'])==1 and old['commands'][0]['exit_code']==1, 'Original wrong-contract public failure must remain failed')
        require(diagnosis['original_status']=='failed' and diagnosis['source_commit']==P and diagnosis['original_outer_sha256']==sha(failed/'outer.json') and diagnosis['original_log_sha256']==sha(failed/'full-public-bytes.log'), 'Original public failure bytes/diagnosis mismatch')
        require(diagnosis['source_after']==old['source_before'] and diagnosis['source_equal_to_original_before'] is True and diagnosis['retained_downloaded_pack']['sha256']==a['pack_sha256'], 'Post-failure source/fullPCK audit mismatch')
    require(gui['status']=='passed' and gui['source_commit']==P and gui['pack_sha256']==a['pack_sha256'] and len(gui['checks'])==20 and len(gui['identities'])==8 and not gui['errors'],'Original public20/8 GUI incomplete')
    require(selector['status']=='pixels_pending_independent_review' and selector['expected_commit']==P and selector['source_stable'] and selector['functional_identity_guards']=='passed' and not selector['errors'],'Selector functional evidence incomplete')
    movies=path(c['movies']); m=read(movies/'receipt.json'); derivatives=path(c['derivatives']); derived=read(derivatives/'summary.json')
    require(m['status']=='passed' and m['execution_head']==P and m['source_stable'] and len(m['maps'])==2,'Fresh P native2 films incomplete')
    require(m['caps']=={'import_per_map_seconds':90,'native_per_map_seconds':240,'extra_combined_outer_timer':None},'Original per-map native caps changed')
    require(derived['status']=='derived_pixels_pending_independent_review' and derived['execution_head']==P and derived['source_stable'] and len(derived['maps'])==2,'Actual AVI derivatives incomplete')
    frames=[]; references=[]
    for index,legs in [(1,24),(2,29)]:
        native=read(movies/f'map{index}/receipt.json'); require(native['status']=='passed' and native['source_head']==P and native['source_stable'] and len(native['runs'])==1,'Wrong native source/case')
        row=native['runs'][0]; require(row['status']=='passed' and row['exit_code']==0 and not row['errors'] and not row['movie']['errors'],'Native strict movie failure')
        require(1<=row['software_render_threads']<=4 and '--layout' not in row['argv'],'Movie-only thread bound or original layout changed')
        require(native['import']['timeout_seconds']==90 and native['import']['exit_code']==0 and not native['import']['errors'],'Original native import failed')
        frame_index=read(derivatives/f'map{index}/event-frame-index.json'); require(frame_index['execution_head']==P and frame_index['map']==index and frame_index['completed_legs']==legs and frame_index['fps']=='60/1' and len(frame_index['frames'])==16,'Wrong movie/frame coverage')
        require(frame_index['avi_sha256']==row['movie']['sha256'] and frame_index['video_frames']==row['movie']['frames'],'AVI provenance mismatch')
        for r in frame_index['frames']:
            f=path(r['png']); require(f.is_file() and sha(f)==r['sha256'],'Direct AVI PNG changed'); frames.append(str(f.relative_to(ROOT)))
        avi=path(frame_index['avi']); require(avi.is_file() and avi.stat().st_size==frame_index['avi_bytes'] and sha(avi)==frame_index['avi_sha256'],'Original raw AVI must remain locally available with exact full payload hash')
        mp4=path(frame_index['mp4']); require(mp4.is_file() and mp4.stat().st_size==frame_index['mp4_bytes'] and sha(mp4)==frame_index['mp4_sha256'],'Actual movie MP4 derivative changed')
        references.append({'path':str(avi.relative_to(ROOT)),'bytes':frame_index['avi_bytes'],'sha256':frame_index['avi_sha256'],'source_commit':P})
    require(set(c['reviews'])=={'ci','movies','public'},'Require independent actual CI,32 PNG,and public/browser reviews')
    reviews={role:review_binding(binding,role) for role,binding in c['reviews'].items()}
    reviewed_frames=pointer(reviews['movies']['document'],c['reviews']['movies']['viewed_pngs_pointer'])
    require(isinstance(reviewed_frames,list) and all(isinstance(f,str) for f in reviewed_frames) and len(reviewed_frames)==32 and {str(path(f).relative_to(ROOT)) for f in reviewed_frames}==set(frames),'Independent review must list exactly all32 actual P PNG paths')
    confirmed_claims(reviews['ci'],['gpu7205','translation15','audio4','fresh120_web41_docs26','forest80','windows_deploy'])
    confirmed_claims(reviews['public'],['original3_25_40_8','public_full_sha','forest20_context8','selector_cjk3'])
    branches=read(path(c['branches'])); require(branches['actual_main']==P,'Branch audit source differs')
    return {'run_id':run['id'],'docs_run_id':docsrun['id'],'artifact':a,'zip_reference':original_zip_reference,'build_info':original['build_info'],'browser_counts':counts,'forest80_seconds':fcheck['duration_seconds'],'branches':branches,'reviews':reviews,'raw_avi':references,'frames':frames}

def archive(out, name, folders, omit):
    out.mkdir(parents=True,exist_ok=False); zpath=out/name; entries=[]; excluded=[]
    with zipfile.ZipFile(zpath,'x',zipfile.ZIP_DEFLATED,compresslevel=1) as z:
        for prefix,folder in folders:
            require(folder.is_dir(),'Missing archive input: '+str(folder))
            for f in sorted(folder.rglob('*')):
                if not f.is_file() or '__pycache__' in f.parts or '.git' in f.parts: continue
                require(not f.is_symlink(),'No archival symlink substitution')
                rel=f.relative_to(folder); record={'path':prefix+'/'+rel.as_posix(),'original_path':str(f.relative_to(ROOT)),'bytes':f.stat().st_size,'sha256':sha(f)}
                if omit(prefix,rel,f): excluded.append(record);continue
                z.write(f,record['path']); require(sha(f)==record['sha256'],'Input changed during archive');entries.append(record)
    require(zpath.stat().st_size<100_000_000,'Split archive before ordinary Git commit: >=100MB')
    with zipfile.ZipFile(zpath) as z: require(z.testzip() is None and len(z.infolist())==len(entries),'Archive CRC/member count failed')
    save(out/'file-index.json',entries); save(out/'omitted-binary-reference-index.json',excluded)
    receipt={'archive':str(zpath.relative_to(ROOT)),'sha256':sha(zpath),'bytes':zpath.stat().st_size,'members':len(entries),'full_crc_test':'passed','source_commit':P,'omitted_original_bytes_remain_local':True}
    save(out/'archive-receipt.json',receipt);return receipt

def update_docs(result, receipts, copied_reviews):
    branches=result['branches']; a=result['artifact']; build=result['build_info']['build_id']
    text=f'''精确运行源码P `{P}`，PR96、99、100均已普通合入main。Godot{result['run_id']}与Documentation{result['docs_run_id']}均完整成功；120核心/艺术、41Web、26Docs全部fresh，当前森林原80/80在原600秒内通过（{result['forest80_seconds']:.3f}s），Windows、实际GPU/audio、Pages及公开验证通过。实际唯一CI artifact ID {a['artifact_id']}、ZIP完整SHA `{a['zip_sha256']}`；原三浏览器25/40/8全部通过。公网build `{build}`的完整PCK {a['pack_bytes']}B/SHA `{a['pack_sha256']}` 与该实际CI包一致；原20项/8上下文GUI及选择器CJK三图已独审。\n\n同源P双图正常60fps连续影片24/29段、32张直接AVI原帧限定独审通过。仅抽查起跳/长链、落地与可见宿主，不代表整图艺术、完整音画体验、HUD遮挡修复、真人设备或FUN最终认可。旧八房间专属30文件退休、55路径净减149325源码字节；正式双图、quick3、Lab/Foundry和旧存档保留。推荐/可选技巧/恢复点职责区分，两个已消融证明冗余的rest删除，恢复点保留。\n\n分支实查时共{branches['remote_head_count']}个远端head，{branches['heads_included_in_main']}个被P包含，{branches['remaining_unmerged_count']}个旧美术/UI候选或部署快照仍未盲合/批删。历史M/N失败保持原来源；P完整结果不改签为后续文档提交的运行验证。后续最终R只更新普通Git证据和文档，公开运行仍为P。'''
    (TARGET/'README.md').write_text('# P主线精确交付证据\n\n'+text+'\n\nCI效率问题与产品失败分开：N文档契约曾在原60秒超时，公网job曾在完整仓库检出阶段耗尽原8分钟；P改流式并行完整SHA读取和仅检出所需验证脚本，原时间预算、完整manifest和断言保持。N在本地原60秒内也通过，因此没有把远端超时原因完全归结为一个已经复现的代码故障。两movie只在录制模式允许最多4个软件渲染线程，headless80和import保持1。菜单裁字、RootBell根部位移等真实游戏失败另有修复与原件。完整发布仍为两组串行核心检查；此处不宣称日常CI分层已全部重构或今后不会失败。\n\n公网首次使用样式探索专用underworld public-bytes时，完整PCK已相符但style-licenses/index.json返回404，原消费者整体FAIL、后两项未执行，原件与后验source closure保留。正式CI实际没有该专属索引；后续独立正式包验证按实际build_report对完整PCK和6个font/audio许可及来源文件逐字节核对。新consumer有独立执行源码/身份，不将旧FAIL追认为通过；原20/8GUI、selector原限额和6个原生产消费者未改。\n\nCI、影片、Web三个分包各有完整SHA、成员索引与CRC；省略的大二进制只保留完整引用哈希，原文件仍在本地。设备/FUN/全区构图与用户最终认可保持review。\n')
    checkpoint='## 2026-10-20：PR96整合与CI修复完成精确P技术交付\n\n'+text+' [完整原件](evidence/main_pr96_repair01/main-P66e8/README.md)。\n\n'
    for name in ['docs/current_state.md','docs/handoff.md']:
        p=ROOT/name;p.write_text(checkpoint+p.read_text())
    p=ROOT/'docs/evidence/main_pr96_repair01/README.md';p.write_text('## P最终技术交付检查点\n\n'+text+' [本轮原件](main-P66e8/README.md)。\n\n'+p.read_text())
    p=ROOT/'docs/design/forest_fruit_routes_v14.md';p.write_text('## 2026-10-20：精确P森林技术验证闭合，整体构图仍review\n\n原当前80/80、同源双图24/29段及32张直接AVI原帧限定独审通过；推荐/可选/恢复职责、果实枝干依附与仅两rest退休保持。起跳/长攀升/落地只签实际抽样，未独立签全森林挂点、HUD遮裁或整体风格、设备/FUN与用户最终审美。[精确P交付原件](../evidence/main_pr96_repair01/main-P66e8/README.md)。以下各时点待测及失败保持历史来源。\n\n'+p.read_text())
    taskfile=ROOT/'docs/tasks.md';old=taskfile.read_text();lines=[]
    for line in old.splitlines():
        if line.startswith('| MAIN-PR96-REPAIR-01 |'): line='| MAIN-PR96-REPAIR-01 | main CI修复／PR96整合／稳定镜头／旧八房瘦身 | PARALLEL-INTEGRATION-01 | review | [P精确技术交付](evidence/main_pr96_repair01/main-P66e8/README.md)、[质量记录](quality/records/MAIN-PR96-REPAIR-01.json)；P完整freshCI、原三浏览器、公网完整SHA与同源影片通过；全区审美/设备/FUN另验 |'
        elif line.startswith('| FOREST-FRUIT-ROUTES-04 |'): line='| FOREST-FRUIT-ROUTES-04 | 森林果实目标与推荐／可选／恢复点位梳理 | FOREST-FOCUS-ROUTES-03 | review | [新版设计](design/forest_fruit_routes_v14.md)、[P精确交付](evidence/main_pr96_repair01/main-P66e8/README.md)；v14候选及v13旧存档保留，P当前80/80、双图24/29段与32原帧限定独审通过；整体构图/HUD、设备/FUN和用户认可仍review |'
        lines.append(line)
    taskfile.write_text('\n'.join(lines)+'\n')
    artifact_paths=[p for p in TARGET.rglob('*') if p.is_file()]
    for task in ['MAIN-PR96-REPAIR-01','FOREST-FRUIT-ROUTES-04']:
        p=ROOT/f'docs/quality/records/{task}.json';d=read(p);d['reviewed_commit']=P;d['workflow']='review'
        ids=[]
        for label,r in receipts.items():
            zp=ROOT/r['archive']; eid='P-actual-'+label;ids.append(eid)
            d['evidence'].append({'id':eid,'path':r['archive'],'sha256':sha(zp),'kind':'command','producer':'GitHub Actions' if label=='CI' else '/root','source_commit':P,'content_version':d['content_version'],'method':'Actual exact-P completed original receipts and raw artifacts; API/full-byte/source/cap identities retained.','observed':'Complete accepted finite technical scope only; no physical-device, whole-forest or player acceptance.','command':'Exact P final '+label+' evidence; see original commands and receipts inside archive','exit_code':0,'environment':'Godot4.7.2 / official Python3.12 CI / actual Chromium or native GL according to each original receipt.'})
        review_ids=[]
        for role,info in copied_reviews.items():
            f=info['path'];eid='P-independent-'+role;review_ids.append(eid)
            d['evidence'].append({'id':eid,'path':str(f.relative_to(ROOT)),'sha256':sha(f),'kind':'review','producer':info['reviewer'],'source_commit':P,'content_version':d['content_version'],'method':'Separate read-only independent exact-P review; original report and explicit accepted scope retained.','observed':info['scope'],'reviewer':info['reviewer'],'implementers':['/root','/root/snapshot_perf_repair'],'independent':True,'independence_basis':'Reviewer did not edit the reviewed production/runtime/test/workflow implementation; wrote separate proof/review artifacts.','verdict':'ACCEPT'})
        d['dimensions']['technical']={'status':'passed','reason':'Exact P complete fresh officialCI120/41/26, original80/600, Windows/GPU/audio/deploy, API-bound actualCI ZIP original3, full public PCK/20/8GUI and same-source2movies passed. Scope remains finite technical delivery.','evidence':ids}
        d['dimensions']['independent_review']={'status':'passed','reason':'Separate exact-P accepted CI, actual32PNG/movie and public/browser/CJK reviews only; no whole-region/device/player acceptance.','evidence':review_ids}
        # Other nine dimensions, all gates, and consumer_coverage remain as they were.
        # Resolve only this precise pending technical item after validate() accepts real P; retain all N failure evidence and other limitations.
        resolved_pending='Fresh efficiency candidate docs26/fullmainCI/APIboundactualCI ZIP original3/publicfullSHA and same-source2movies still pending; Nactualfailures preserved.'
        d['unverified_items']=[item for item in d['unverified_items'] if item!=resolved_pending]
        d['test_change_justification']+=' Exact P completed official fresh120/41/26, strict80 within original600, GPU/audio/Windows/deploy and original API-bound actualCI ZIP three-browser25/40/8 plus full public PCK/20/8GUI and two same-source films. Actual independent limited reviews are separately bound. This closes only current technical delivery; all historical source-specific failures and unknown Q hook cause remain, without weakening original consumers or signing full-region/device/FUN acceptance.'
        for f in artifact_paths:
            n=str(f.relative_to(ROOT))
            if n not in d['affected_paths']:d['affected_paths'].append(n)
        for limit in ['Full uninterrupted movie/audio playback and whole-region animation/audio quality remain unverified; the actual32-frame independent review does not certify complete playback.','Selector raw console retains one generic HTTP404 without a URL; its resource and cause remain unknown. This does not change original functional/CJK accepted scope or sign all console events clean.']:
            if limit not in d['unverified_items']: d['unverified_items'].append(limit)
        p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--config',required=True,type=Path);ap.add_argument('--apply',action='store_true');a=ap.parse_args();c=read(a.config)
    result=validate(c)
    if not a.apply:
        print(json.dumps({'status':'VALIDATED_NO_MUTATION','actual_source':P,'target':str(TARGET),'next':'Review inputs, then explicitly rerun --apply after every live guard is terminal.'}));return
    require(not TARGET.exists(),'Preserve prior archive; target already exists')
    TARGET.mkdir(parents=True)
    save(TARGET/'validated-input-bindings.json',c)
    for value in c.get('prepared_sources',[]):
        src=path(value);require(src.is_file(),'Missing actual coordinator source')
        dst=TARGET/'executed-coordinators'/src.relative_to(ROOT);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    reviews={}
    for role,r in result['reviews'].items():
        dst=TARGET/'review'/str(role+'.json');dst.parent.mkdir(exist_ok=True);shutil.copyfile(r['path'],dst)
        reviews[role]={'path':dst,'reviewer':r['reviewer'],'scope':r['binding']['scope']}
    ci_root=path(c['ci']['archive_root']);movies=path(c['movies']);derivatives=path(c['derivatives']);browser=path(c['browser']);public=path(c['public'])
    receipts={}
    ci_folders=[('actual-CI',ci_root),('merge-source',path(c['merge_source'])),('independent-CI',result['reviews']['ci']['path'].parent)]
    if c.get('raw_avi_dedup_audit'): ci_folders.append(('raw-AVI-exact-byte-dedup',path(c['raw_avi_dedup_audit'])))
    receipts['CI']=archive(TARGET/'CI','P-CI-selected.zip',ci_folders,lambda pre,rel,f:f.suffix.lower() in {'.zip','.pck','.wasm','.avi'} or '__pycache__' in rel.parts)
    receipts['movies']=archive(TARGET/'movies','P-movies-selected.zip',[('native',movies),('derivatives',derivatives),('independent-movies',result['reviews']['movies']['path'].parent)],lambda pre,rel,f:f.suffix.lower()=='.avi')
    web_folders=[('CI-browser',browser),('public',public),('independent-public',result['reviews']['public']['path'].parent)]
    if c.get('public_contract_failure'): web_folders.append(('public-first-failed',path(c['public_contract_failure'])))
    if c.get('public_contract_diagnosis'): web_folders.append(('public-contract-diagnosis',path(c['public_contract_diagnosis'])))
    receipts['web']=archive(TARGET/'web','P-web-selected.zip',web_folders,lambda pre,rel,f:(pre=='CI-browser' and rel.parts[:2]==('original','web')) or (pre in {'public','public-first-failed'} and rel.parts[:1]==('public_bytes',) and f.suffix=='.pck'))
    save(TARGET/'CI/actual-web-ZIP-reference.json',result['zip_reference'])
    save(TARGET/'movies/raw-AVI-reference-index.json',result['raw_avi'])
    save(TARGET/'technical-identity-summary.json',{'status':'passed','source_commit':P,'Godot_run':result['run_id'],'Docs_run':result['docs_run_id'],'artifact':result['artifact'],'build_info':result['build_info'],'original_browser_checks':result['browser_counts'],'forest80_seconds':result['forest80_seconds'],'branch_audit':result['branches'],'scope':'Finite exact-P technical delivery only; all subjective/device/full-region limits retained.'})
    closeout={'actual_source':P,'status':'ARCHIVES_COMPLETE_DOCS_UPDATE_PENDING','driver_sha256':sha(Path(__file__)),'config_sha256':sha(a.config),'next':'Root: check_docs, check_quality, check_quality_diff --base dbc6ba081321637a3eef71979ecf2cf564eb6064; verify frozen audit; docs-only commit [skip ci]; check_release_evidence --commit HEAD; normal push. Runtime remains P.'}
    save(TARGET/'closeout-execution.json',closeout)
    update_docs(result,receipts,reviews)
    closeout['status']='ARCHIVED_AND_DOCS_UPDATED_NOT_COMMITTED';save(TARGET/'closeout-execution.json',closeout)
    print(json.dumps({'status':'ARCHIVED_AND_DOCS_UPDATED_NOT_COMMITTED','source_commit':P,'target':str(TARGET)}))

if __name__=='__main__':main()
