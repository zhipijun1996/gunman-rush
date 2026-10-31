#!/usr/bin/env python3
"""Validate every engine lane and assemble immutable distribution candidates.

This writes a candidate lock beside artifacts, never config/toolchain.json.
Root publishes reviewed assets before integrating that lock and its installer.
"""
import argparse
import hashlib
import json
from pathlib import Path
import time
import zipfile

REPO=Path(__file__).resolve().parents[2]
RECIPE_PATH=REPO/'config/godot_build.json'
RECIPE=json.loads(RECIPE_PATH.read_text())


def sha(path):
    result=hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda:source.read(1024*1024),b''):result.update(chunk)
    return result.hexdigest()


def write(path,data):
    path.write_text(json.dumps(data,indent=2,sort_keys=True)+'\n')


def archive(path,files):
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as output:
        for name,source in sorted(files.items()):
            info=zipfile.ZipInfo(name,time.gmtime(RECIPE['source_date_epoch'])[:6])
            info.create_system=3
            executable=name=='godot-linux-x86_64' or name.endswith('.x86_64')
            info.external_attr=(0o100755 if executable else 0o100644)<<16
            info.compress_type=zipfile.ZIP_DEFLATED
            output.writestr(info,source.read_bytes())


def package(inputs,output,base_url):
    output.mkdir(parents=True,exist_ok=True)
    files={};receipts={};recipe_hash=sha(RECIPE_PATH)
    for lane,job in RECIPE['jobs'].items():
        root=inputs/('engine-built-'+lane)
        receipt=json.loads((root/'provenance.json').read_text())
        expected={'recipe_id':RECIPE['id'],'recipe_sha256':recipe_hash,'lane':lane,
                  'build_image':job['image'],'source':RECIPE['source'],'patches':RECIPE['patches'],
                  'patched_source_sha256':RECIPE['patched_source_sha256'],
                  'build_name':RECIPE['build_name'],'common_options':RECIPE['common_options'],'status':'built'}
        for key,value in expected.items():
            if receipt.get(key)!=value:raise ValueError('Lane provenance mismatch: '+lane+'/'+key)
        if set(receipt['outputs'])!=set(job['outputs']):raise ValueError('Incomplete/extra lane outputs: '+lane)
        for name in job['outputs']:
            file=root/name;observed={'sha256':sha(file),'bytes':file.stat().st_size}
            if receipt['outputs'][name]!=observed or not observed['bytes']:raise ValueError('Artifact integrity failure: '+lane+'/'+name)
            if name in files:raise ValueError('Duplicate output ownership: '+name)
            files[name]=file
        if lane=='linux-editor' and receipt.get('version')!=RECIPE['expected_version']:
            raise ValueError('Editor smoke did not establish exact custom identity')
        receipts[lane]=receipt
    identity={'id':RECIPE['id'],'version':RECIPE['expected_version'],'edition':RECIPE['edition'],
              'recipe_sha256':recipe_hash,'source':RECIPE['source'],'patches':RECIPE['patches']}
    write(output/'engine-identity.json',identity)
    editor_names={'godot-linux-x86_64','LICENSE.txt','COPYRIGHT.txt'}
    editor={name:files[name] for name in editor_names}
    editor['engine-identity.json']=output/'engine-identity.json'
    editor_archive=output/(RECIPE['id']+'-linux-x86_64.zip');archive(editor_archive,editor)
    (output/'version.txt').write_text(RECIPE['template_version']+'\n')
    templates={name:path for name,path in files.items() if name not in editor_names}
    templates['version.txt']=output/'version.txt';templates['engine-identity.json']=output/'engine-identity.json'
    template_archive=output/(RECIPE['id']+'-export-templates.tpz')
    archive(template_archive,{'templates/'+name:path for name,path in templates.items()})
    write(output/'build-provenance.json',{'identity':identity,'lanes':receipts})
    spec={'version':RECIPE['version'],'edition':RECIPE['edition'],'distribution':'fixed-upstream-backport',
          'build_id':RECIPE['id'],'version_exact':RECIPE['expected_version'],
          'recipe_sha256':recipe_hash,'source':RECIPE['source'],'patches':RECIPE['patches'],
          'data_subdirectory':'user-data/'+RECIPE['id'],
          'linux_x86_64':{'url':base_url+editor_archive.name,'sha256':sha(editor_archive),
                          'binary':'godot-linux-x86_64','binary_sha256':sha(files['godot-linux-x86_64'])},
          'templates':{'url':base_url+template_archive.name,'sha256':sha(template_archive),
                       'version':RECIPE['template_version'],'files':{name:sha(path) for name,path in templates.items()}},
          'provenance':{'url':base_url+'build-provenance.json','sha256':sha(output/'build-provenance.json')}}
    write(output/'godot-lock-candidate.json',spec)
    write(output/'SHA256SUMS.json',{p.name:sha(p) for p in output.iterdir() if p.is_file() and p.name!='SHA256SUMS.json'})
    return spec


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inputs',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--release-base-url',required=True)
    args=parser.parse_args()
    if not args.release_base_url.startswith('https://github.com/zhipijun1996/gunman-rush/releases/download/') or not args.release_base_url.endswith('/'):
        raise SystemExit('Expected an explicit repository release URL ending in /')
    print(json.dumps(package(args.inputs,args.output,args.release_base_url),indent=2))
