"""Verify the actual official CI export's public-byte contract, not an isolated style export.

Original underworld_delivery.py and its failed receipt remain untouched. All
downloads are new curl executions; original per-request limits are retained.
"""
from __future__ import annotations
import argparse, hashlib, json, subprocess, sys, time
from pathlib import Path, PurePosixPath
from urllib.parse import quote, urljoin
from common import ROOT, state, sha, write, bound

P='66e8b912854d6d4cccadb45b9c348a618689f5a1'

def require(value, message):
    if not value: raise ValueError(message)

def load(p): return json.loads(Path(p).read_text())

def within(base, name):
    require(isinstance(name,str) and name and '\\' not in name, 'Unsafe artifact name')
    parts=PurePosixPath(name)
    require(not parts.is_absolute() and '..' not in parts.parts, 'Unsafe relative artifact name')
    p=(base/name).resolve();require(p.is_relative_to(base.resolve()),'Artifact escaped its root')
    return p

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-commit',required=True)
    parser.add_argument('--ci-receipt',required=True,type=Path)
    parser.add_argument('--url',required=True)
    parser.add_argument('--output',required=True,type=Path)
    a=parser.parse_args();require(a.expected_commit==P,'Explicit full final P SHA required')
    before=state(P);output=a.output.resolve()
    require(output.is_relative_to(ROOT/'build') and not output.exists(),'New ignored output JSON required')
    destination=output.parent/'public_bytes'
    require(not destination.exists(),'Fresh download directory required; never reuse prior PCK')
    output.parent.mkdir(parents=True,exist_ok=True);destination.mkdir()
    old=ROOT/'build/forest_revision04/main-public-P66e8/outer.json'
    require(old.is_file(),'Preserve and reference the actual old contract failure')
    old_data=load(old);require(old_data['status']=='failed','Old public failure identity changed')
    report={'status':'running','source_commit':P,'source_before':before,
            'contract':'official-tools-build-web-six-sidecars-v1',
            'contract_source':bound(ROOT/'tools/build.py',P),
            'isolated_style_contract_source':bound(ROOT/'tools/style_exploration_delivery.py',P),
            'unchanged_original_consumer_source':bound(ROOT/'tools/underworld_delivery.py',P),
            'old_failure_reference':{'path':str(old.relative_to(ROOT)),'sha256':sha(old),'status':old_data['status'],
              'scope':'Original consumer requested isolated-style style-licenses/index.json, absent from this official CI export. Original failure is retained, not retrospectively passed.'},
            'ci_receipt':str(a.ci_receipt.resolve()),'ci_receipt_sha256':sha(a.ci_receipt),
            'entry_code_sha256':sha(Path(__file__)),'common_sha256':sha(Path(__file__).with_name('common.py')),
            'entry_argv':[sys.executable,*sys.argv],'url':a.url,'actual_commands':[],
            'limits':{'curl_max_time_seconds':240,'subprocess_timeout_seconds':260,'combined_timeout':None},
            'license_files':[],'scope':'Exact actual CI export public metadata, full PCK and every official six-sidecar byte; optional actual style index and all rows. No browser/device/player/whole-forest approval.'}
    write(output,report)

    def download(name):
        target=within(destination,name);require(not target.exists(),'No reused download: '+name)
        target.parent.mkdir(parents=True,exist_ok=True)
        cmd=['curl','--ipv4','--fail','--silent','--show-error','--location',
             '--retry','3','--max-time','240',urljoin(a.url,quote(name)),'--output',str(target)]
        record={'name':name,'argv':cmd,'started_at_unix':time.time(),'timeout_seconds':260,'status':'running'}
        report['actual_commands'].append(record);write(output,report);start=time.monotonic()
        try:
            result=subprocess.run(cmd,check=False,timeout=260)
            record.update(exit_code=result.returncode,seconds=time.monotonic()-start,
                          status='passed' if result.returncode==0 else 'failed')
            require(result.returncode==0,'Actual public download failed: '+name)
            record.update(bytes=target.stat().st_size,sha256=sha(target));return target
        except BaseException as e:
            record.update(status='failed',error=type(e).__name__+': '+str(e));raise
        finally: write(output,report)

    try:
        ci=load(a.ci_receipt)
        require(ci['status']=='passed' and ci['source_commit']==P and ci['run_id']==39452164092 and ci['attempt']==1,'Require exact actual P original CI browser receipt')
        require(len(ci['browser_results'])==3 and all(x['status']=='passed' and x['exit_code']==0 for x in ci['browser_results']),'Original three CI consumers incomplete')
        outer_path=a.ci_receipt.resolve().parent.parent/'outer.json';outer=load(outer_path)
        require(outer['status']=='passed' and outer['execution_head']==P and outer['source_stable'],'CI wrapper source proof failed')
        argv=outer['argv'];run_path=Path(argv[argv.index('--run-api')+1]);api_path=Path(argv[argv.index('--artifact-api')+1])
        require(sha(run_path)==ci['run_api_sha256'] and sha(api_path)==ci['artifact_api_sha256'],'Actual original API receipt hashes changed')
        run=load(run_path);api=load(api_path);identity=ci['artifact_receipt'];zip_path=Path(identity['path'])
        require(run['head_sha']==P and run['id']==39452164092 and run['status']=='completed' and run['conclusion']=='success' and run['run_attempt']==1,'Actual P full CI is not successful')
        require(api['workflow_run']['id']==run['id'] and api['workflow_run']['head_sha']==P and api['id']==identity['artifact_id'] and not api.get('expired',False),'Wrong actual CI artifact API identity')
        require(identity['digest_source']=='unique run artifact API digest' and api['digest']=='sha256:'+identity['zip_sha256'] and api['size_in_bytes']==identity['zip_bytes'],'Exact unique API ZIP digest/size binding missing')
        require(zip_path.is_file() and zip_path.stat().st_size==identity['zip_bytes'] and sha(zip_path)==identity['zip_sha256'],'Actual API-bound downloaded ZIP changed')
        bundle=Path(ci['served_directory']).resolve();require(bundle.is_relative_to(ROOT/'build') and bundle.is_dir(),'Actual extracted CI bundle required')
        actual_inventory={p.relative_to(bundle).as_posix():sha(p) for p in sorted(bundle.rglob('*')) if p.is_file()}
        require(actual_inventory==ci['web_inventory_before']==ci['web_inventory_after'],'Actual complete served CI export differs from original browser evidence')
        info=load(bundle/'build-info.json');build_report=load(bundle/'build_report.json')
        require(info==ci['build_info'] and info['source_commit']==P,'Actual CI build-info identity mismatch')
        require(build_report['platform']=='web' and build_report['export_exit_code']==0,'Official successful Web build report required')
        entries={};full_inventory=[]
        for item in build_report['artifacts']:
            require(item['path'].startswith('build/web/'),'Unexpected official report path')
            name=item['path'][len('build/web/'):];require(name not in entries,'Duplicate official artifact')
            f=within(bundle,name)
            require(f.is_file() and f.stat().st_size==item['bytes'] and actual_inventory.get(name)==item['sha256'],'Complete local build_report artifact mismatch: '+name)
            entries[name]=item;full_inventory.append({'path':name,'bytes':item['bytes'],'sha256':item['sha256']})
        # Godot's index.png icon is an incidental ZIP member absent from the
        # official build.py report. Bind it to the original complete API-ZIP
        # inventory; do not invent an extra public-sidecar contract for it.
        unreported=set(actual_inventory)-set(entries)-{'build_report.json'}
        require(entries and all(n=='index.png' or n.startswith('style-licenses/') for n in unreported),'Unexpected files outside the official complete build_report')
        pack=within(bundle,info['pack'])
        require(info['pack'] in entries and pack.stat().st_size==info['pack_bytes']==identity['pack_bytes'] and actual_inventory[info['pack']]==identity['pack_sha256'],'Complete CI PCK size/SHA identity differs')
        sidecars={'NotoSansSC-OFL.txt':'assets/fonts/OFL.txt','Kenney-audio-sources.json':'assets/audio/kenney/sources.json'}
        audio=sorted((ROOT/'assets/audio/kenney').glob('*-LICENSE.txt'));require(len(audio)==4,'Expected all four tracked Kenney licenses')
        sidecars.update({'Kenney-'+p.name:str(p.relative_to(ROOT)) for p in audio});require(len(sidecars)==6,'Official six-sidecar inventory changed')
        sources={}
        for name,source in sidecars.items():
            require(name in entries,'Official sidecar omitted from build_report: '+name)
            data=subprocess.check_output(['git','show',P+':'+source],cwd=ROOT)
            h=hashlib.sha256(data).hexdigest();f=within(bundle,name)
            require(sha(ROOT/source)==h and actual_inventory[name]==h and f.stat().st_size==len(data)==entries[name]['bytes'],'Official sidecar differs from exact tracked P source: '+name)
            sources[name]={'source_path':source,'source_commit':P,'sha256':h,'bytes':len(data)}
        report.update(build_id=info['build_id'],pack_sha256=identity['pack_sha256'],pack_bytes=identity['pack_bytes'],
                      artifact_identity=identity,run_api={'path':str(run_path),'sha256':sha(run_path)},artifact_api={'path':str(api_path),'sha256':sha(api_path)},
                      expected_build_report_sha256=actual_inventory['build_report.json'],complete_CI_build_report_artifacts=full_inventory,
                      actual_CI_files_outside_build_report=[{'path':n,'sha256':actual_inventory[n],'bytes':within(bundle,n).stat().st_size} for n in sorted(unreported)],
                      official_sidecar_sources=sources,source_files_stable=True)
        write(output,report)
        for name in ['build-info.json','build_report.json']:
            downloaded=download(name)
            require(sha(downloaded)==actual_inventory[name] and downloaded.stat().st_size==(bundle/name).stat().st_size,'Actual public metadata/report bytes differ: '+name)
        public_pack=download(info['pack'])
        require(public_pack.stat().st_size==identity['pack_bytes'] and sha(public_pack)==identity['pack_sha256'],'Full actual public PCK size/SHA differs from exact CI')
        for name,source in sources.items():
            downloaded=download(name)
            require(downloaded.stat().st_size==source['bytes'] and sha(downloaded)==source['sha256']==actual_inventory[name],'Actual public official sidecar bytes differ: '+name)
            report['license_files'].append({'path':name,**source})
        style_index=bundle/'style-licenses/index.json'
        if style_index.exists():
            downloaded=download('style-licenses/index.json')
            require(sha(downloaded)==actual_inventory['style-licenses/index.json'],'Actual public optional style index differs')
            rows=load(style_index);require(isinstance(rows,list),'Style index rows must be a list');names=set()
            for item in rows:
                name=item['path'];require(name.startswith('style-licenses/') and name not in names,'Unsafe/duplicate style row');names.add(name)
                f=within(bundle,name);require(f.is_file() and f.stat().st_size==item['bytes'] and actual_inventory[name]==item['sha256'],'Actual CI style license row mismatch')
                downloaded=download(name)
                require(downloaded.stat().st_size==item['bytes'] and sha(downloaded)==item['sha256'],'Actual public style license row differs')
                report['license_files'].append(item)
            require(names|{'style-licenses/index.json'}=={n for n in actual_inventory if n.startswith('style-licenses/')},'Actual style index incomplete')
            report['style_license_contract']={'present_in_actual_CI':True,'checked_rows':len(rows),'index_sha256':actual_inventory['style-licenses/index.json']}
        else:
            require(not any(n.startswith('style-licenses/') for n in actual_inventory),'Unindexed actual CI style licenses cannot be ignored')
            report['style_license_contract']={'present_in_actual_CI':False,'reason':'Official tools/build.py exports the six checked sidecars; style_exploration_delivery.copy_licenses belongs to isolated style export.'}
        after=state(P);report.update(source_after=after,source_stable=after==before)
        require(after==before,'Source inventory changed during actual public-byte verification')
        require(sha(a.ci_receipt)==report['ci_receipt_sha256'] and sha(old)==report['old_failure_reference']['sha256'],'Bound evidence changed during verification')
        report['status']='passed'
    except BaseException as e:
        report.update(status='failed',error=type(e).__name__+': '+str(e));raise
    finally: write(output,report)
    print(json.dumps({k:report[k] for k in ['status','source_commit','build_id','pack_sha256','pack_bytes','contract']},ensure_ascii=False))

if __name__=='__main__': main()
