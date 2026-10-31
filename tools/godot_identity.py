#!/usr/bin/env python3
"""Single runtime identity/paths contract for the fixed patched distribution."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

REPO=Path(__file__).resolve().parent.parent


def read_config(repo=REPO):
    return json.loads((repo/'config/toolchain.json').read_text())


def sha256(path):
    digest=hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda:source.read(1024*1024),b''):digest.update(block)
    return digest.hexdigest()


def toolchain_root(repo=REPO):
    return Path(os.environ.get('GUNMAN_TOOLCHAIN_ROOT',str(repo.parent/'toolchains')))


def data_root(config=None,repo=REPO):
    config=config or read_config(repo)
    return Path(os.environ.get('GUNMAN_DATA_HOME',str(toolchain_root(repo)/config['godot'].get('data_subdirectory','user-data'))))


def environment(config=None,repo=REPO):
    config=config or read_config(repo);root=toolchain_root(repo)
    env=os.environ.copy()
    env.setdefault('XDG_CONFIG_HOME',str(root/'user-config'))
    env.setdefault('XDG_CACHE_HOME',str(root/'cache'))
    env['XDG_DATA_HOME']=str(data_root(config,repo))
    env.setdefault('ANDROID_HOME',str(root/'android-sdk'))
    env['ANDROID_SDK_ROOT']=env['ANDROID_HOME']
    java=Path(env.get('JAVA_HOME',root/'jdk17'))
    if (java/'bin/java').is_file():
        env['JAVA_HOME']=str(java)
        env['PATH']=str(java/'bin')+os.pathsep+env.get('PATH','')
    return env


def validate_lock(config=None,repo=REPO):
    config=config or read_config(repo);spec=config['godot']
    if spec.get('distribution')!='fixed-upstream-backport':
        raise RuntimeError('Fixed upstream distribution lock has not been activated; use the reviewed release lock')
    recipe_path=repo/'config/godot_build.json';recipe=json.loads(recipe_path.read_text())
    comparisons={'build_id':recipe['id'],'version_exact':recipe['expected_version'],
                 'version':recipe['version'],'edition':'Standard','recipe_sha256':sha256(recipe_path),
                 'source':recipe['source'],'patches':recipe['patches']}
    for key,expected in comparisons.items():
        if spec.get(key)!=expected:raise RuntimeError('Toolchain build/source lock mismatch: '+key)
    for patch in recipe['patches']:
        if sha256(repo/patch['file'])!=patch['sha256']:raise RuntimeError('Locked engine patch changed: '+patch['file'])
    if spec['templates']['version']!=recipe['template_version']:
        raise RuntimeError('Template engine version mismatch')
    expected={name for job in recipe['jobs'].values() for name in job['outputs']}
    expected-= {'godot-linux-x86_64','LICENSE.txt','COPYRIGHT.txt'}
    expected|= {'version.txt','engine-identity.json'}
    if set(spec['templates']['files'])!=expected:raise RuntimeError('Template lock does not cover the complete selected platform set')
    hashes=[spec['linux_x86_64']['sha256'],spec['linux_x86_64']['binary_sha256'],
            spec['templates']['sha256'],spec['provenance']['sha256'],*spec['templates']['files'].values()]
    if not all(isinstance(value,str) and re.fullmatch('[0-9a-f]{64}',value) for value in hashes):
        raise RuntimeError('Missing or malformed immutable artifact hash')
    return spec


def expected_version(repo=REPO):
    # For a generated command/pattern, no executable is run. The runtime path
    # still requires validate_lock and exact byte verification before execution.
    spec=read_config(repo)['godot']
    return spec.get('version_exact') or json.loads((repo/'config/godot_build.json').read_text())['expected_version']


def banner_pattern(repo=REPO):
    return '^Godot Engine v'+re.escape(expected_version(repo))+r'(?:\s|$)'


def engine_directory(config=None,repo=REPO):
    config=config or read_config(repo)
    return toolchain_root(repo)/'godot'/config['godot']['build_id']


def engine_path(config=None,repo=REPO):
    config=config or read_config(repo)
    return Path(os.environ.get('GODOT_BIN',str(engine_directory(config,repo)/config['godot']['linux_x86_64']['binary'])))


def templates_directory(config=None,repo=REPO):
    config=config or read_config(repo)
    return data_root(config,repo)/'godot/export_templates'/config['godot']['templates']['version']


def verify_file(path,expected,label):
    if not path.is_file():raise RuntimeError(label+' is missing: '+str(path))
    if sha256(path)!=expected:raise RuntimeError(label+' SHA256 differs from the fixed toolchain lock: '+str(path))


def verify_provenance(path,config=None,repo=REPO):
    config=config or read_config(repo);spec=validate_lock(config,repo)
    verify_file(path,spec['provenance']['sha256'],'Build provenance')
    value=json.loads(path.read_text());identity=value['identity']
    expected={'id':spec['build_id'],'version':spec['version_exact'],'edition':spec['edition'],
              'recipe_sha256':spec['recipe_sha256'],'source':spec['source'],'patches':spec['patches']}
    if identity!=expected:raise RuntimeError('Build provenance identity differs from installation lock')
    recipe=json.loads((repo/'config/godot_build.json').read_text())
    if set(value['lanes'])!=set(recipe['jobs']):raise RuntimeError('Build provenance is missing platform lanes')
    for lane,job in recipe['jobs'].items():
        row=value['lanes'][lane]
        if (row.get('status')!='built' or row.get('build_image')!=job['image']
                or row.get('recipe_sha256')!=spec['recipe_sha256']
                or row.get('source')!=spec['source'] or row.get('patches')!=spec['patches']
                or row.get('patched_source_sha256')!=recipe['patched_source_sha256']):
            raise RuntimeError('Build provenance has a mixed/unbuilt lane: '+lane)
        if set(row['outputs'])!=set(job['outputs']):raise RuntimeError('Build provenance output set mismatch: '+lane)
        for name,artifact in row['outputs'].items():
            expected_sha=(spec['linux_x86_64']['binary_sha256'] if name=='godot-linux-x86_64'
                          else spec['templates']['files'].get(name))
            if expected_sha is not None and artifact['sha256']!=expected_sha:
                raise RuntimeError('Build provenance artifact differs from installation lock: '+name)
    return value


def verify_templates(config=None,repo=REPO,directory=None):
    config=config or read_config(repo);spec=validate_lock(config,repo)
    folder=directory or templates_directory(config,repo)
    actual={p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()}
    if actual!=set(spec['templates']['files']):raise RuntimeError('Missing, extra or mixed engine template files: '+str(folder))
    for name,digest in spec['templates']['files'].items():
        verify_file(folder/name,digest,'Template '+name)
    if (folder/'version.txt').read_text().strip()!=spec['templates']['version']:
        raise RuntimeError('Template version.txt does not match the frozen distribution')
    identity=json.loads((folder/'engine-identity.json').read_text())
    if identity.get('id')!=spec['build_id'] or identity.get('recipe_sha256')!=spec['recipe_sha256']:
        raise RuntimeError('Template source identity mismatch')
    return folder


def verified_engine(config=None,repo=REPO):
    config=config or read_config(repo);spec=validate_lock(config,repo)
    binary=engine_path(config,repo)
    verify_file(binary,spec['linux_x86_64']['binary_sha256'],'Godot executable')
    if not os.access(binary,os.X_OK):raise RuntimeError('Locked Godot binary is not executable: '+str(binary))
    verify_provenance(engine_directory(config,repo)/'build-provenance.json',config,repo)
    result=subprocess.run([str(binary),'--version'],capture_output=True,text=True,timeout=30,env=environment(config,repo))
    version=result.stdout.strip()
    if result.returncode or version!=spec['version_exact'] or 'mono' in version.lower():
        raise RuntimeError('Wrong exact patched Godot Standard identity: '+version)
    return {'version':version,'binary_sha256':spec['linux_x86_64']['binary_sha256'],
            'bytes':binary.stat().st_size,'binary':str(binary.resolve()),'build_id':spec['build_id'],
            'recipe_sha256':spec['recipe_sha256'],'source_commit':spec['source']['source_commit'],
            'template_archive_sha256':spec['templates']['sha256'],
            'provenance_sha256':spec['provenance']['sha256']}


def main():
    args=sys.argv[1:]
    if args[:1]==['--']:args=args[1:]
    identity=verified_engine()
    if args==['--identity-json']:
        print(json.dumps(identity,sort_keys=True));return
    if args==['--version']:
        print(identity['version']);return
    engine_args=args[:args.index('--')] if '--' in args else args
    if any(value.startswith('--export-') for value in engine_args):
        verify_templates()
    os.execve(identity['binary'],[identity['binary'],*args],environment())


if __name__=='__main__':
    try:main()
    except (OSError,RuntimeError,KeyError,ValueError,subprocess.SubprocessError) as error:
        print('Godot toolchain rejected: '+str(error),file=sys.stderr);sys.exit(1)
