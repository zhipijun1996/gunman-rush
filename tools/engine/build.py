#!/usr/bin/env python3
"""Build one frozen patched-engine lane; never install over the game toolchain.

Run inside the image digest in config/godot_build.json. Packaging/installation
is separate: a successful compiler exit is not project or platform acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tarfile
import time
import zipfile

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'tools'))
from setup_environment import download, sha256

RECIPE_PATH = REPO / 'config/godot_build.json'
RECIPE = json.loads(RECIPE_PATH.read_text())


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def extract(archive, destination):
    destination.mkdir(parents=True, exist_ok=True)
    if zipfile.is_zipfile(archive):
        # Linux SDK ZIPs contain real symlinks (NDK r29 has 37). The normal
        # distribution installer only needs regular files, so keep this SDK
        # rule local rather than turning links into executable text files.
        with zipfile.ZipFile(archive) as source:
            links=[]
            for member in source.infolist():
                target=destination/member.filename
                if not target.resolve().is_relative_to(destination.resolve()):
                    raise RuntimeError('Unsafe ZIP member: '+member.filename)
                mode=member.external_attr>>16
                if stat.S_ISLNK(mode):
                    link=source.read(member).decode('utf-8')
                    if Path(link).is_absolute() or not (target.parent/link).resolve().is_relative_to(destination.resolve()):
                        raise RuntimeError('Unsafe ZIP symlink: '+member.filename)
                    links.append((target,link));continue
                if member.is_dir():target.mkdir(parents=True,exist_ok=True);continue
                target.parent.mkdir(parents=True,exist_ok=True)
                with source.open(member) as data,target.open('wb') as output:
                    shutil.copyfileobj(data,output)
                if mode:target.chmod(mode&0o777)
            for target,link in links:
                target.parent.mkdir(parents=True,exist_ok=True)
                target.symlink_to(link)
            for target,_ in links:
                if not target.resolve().is_relative_to(destination.resolve()):
                    raise RuntimeError('Unsafe ZIP symlink chain: '+str(target))
    else:
        with tarfile.open(archive) as source:
            # Verified downloads still may not write outside the build directory.
            for member in source.getmembers():
                if not (destination / member.name).resolve().is_relative_to(destination.resolve()):
                    raise RuntimeError('Unsafe archive member: ' + member.name)
            source.extractall(destination, filter='data')


def dependency(key):
    spec = RECIPE['dependencies'][key]
    return download(spec, 'engine-' + key + '-' + spec['sha256'][:12] + '.archive')


def run(argv, cwd, env, log, timeout=10800):
    started = time.monotonic()
    print('RUN ' + ' '.join(map(str, argv)), flush=True)
    with log.open('wb') as stream:
        process = subprocess.Popen(list(map(str, argv)), cwd=cwd, env=env,
                                   stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            import signal
            os.killpg(process.pid, signal.SIGTERM)
            try: process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            raise
    print(log.read_text(errors='replace')[-5000:], flush=True)
    record = {'argv':list(map(str, argv)), 'seconds':time.monotonic()-started,
              'exit_code':code, 'cwd':str(cwd), 'log':log.name, 'log_sha256':sha256(log)}
    if code: raise RuntimeError(f'Command failed ({code}); full log: {log}')
    return record


def prepare_source(work):
    spec = RECIPE['source']
    archive = download(spec, RECIPE['id'] + '-source.tar.xz')
    extract(archive, work)
    source = work / 'godot-4.7.2-stable'
    if (source / '.git/HEAD').read_text().strip() != spec['source_commit']:
        raise RuntimeError('Archive Git identity differs from the locked source')
    for path, expected in RECIPE['original_source_sha256'].items():
        if sha256(source / path) != expected: raise RuntimeError('Original source mismatch: ' + path)
    for index, patch in enumerate(RECIPE['patches']):
        path = REPO / patch['file']
        if sha256(path) != patch['sha256']: raise RuntimeError('Patch integrity failure: ' + str(path))
        run(['patch','--batch','--forward','--fuzz=0','-p1','--input',path],
            source, os.environ.copy(), work / f'patch-{index}.log', 30)
    for path, expected in RECIPE['patched_source_sha256'].items():
        if sha256(source / path) != expected: raise RuntimeError('Patched source mismatch: ' + path)
    return source


def platform_options(job,work):
    deps=work/'dependencies';platform=job['platform'];options=[]
    if platform in ('linuxbsd','windows'):
        options += ['accesskit=yes','accesskit_sdk_path='+str(deps/'accesskit-c-0.22.3')]
    if platform=='linuxbsd':
        options += ['arch=x86_64','wayland=yes','x11=yes']
    elif platform=='windows':
        options += ['arch=x86_64','use_mingw=yes','use_llvm=yes',
                    'mingw_prefix='+str(deps/'llvm-mingw-20260616-ucrt-ubuntu-22.04-x86_64'),
                    'angle=yes','angle_libs='+str(deps/'angle'),'d3d12=yes',
                    'mesa_libs='+str(deps/'mesa'),'agility_sdk_path='+str(deps/'agility'),
                    'winrt=yes','winrt_path='+str(deps/'winrt')]
    elif platform=='web':
        options += ['arch=wasm32','threads='+('yes' if job['threads'] else 'no'),'dlink_enabled=no']
    elif platform=='android':options += ['arch=arm64','swappy=yes']
    return options


def command_contract(job,work):
    source=work/'godot-4.7.2-stable'
    result=[{'argv':[job['python_executable'],'-m','SCons','platform='+job['platform'],'target='+target,
                     '-j'+str(RECIPE['build_workers']),*RECIPE['common_options'],*platform_options(job,work)],
             'cwd':str(source)} for target in job.get('targets',[job.get('target')])]
    if job['platform']=='android':
        result.append({'argv':[str(work/'dependencies/gradle/gradle-8.11.1/bin/gradle'),'--no-daemon',
                               '--max-workers=2','generateGodotTemplates'],
                       'cwd':str(source/'platform/android/java')})
    return result


def prepare_dependencies(job, source, work, env):
    deps = work / 'dependencies'
    extract(dependency('scons'), deps / 'scons')
    env['PYTHONPATH'] = str(deps / 'scons')
    platform = job['platform']
    if platform in ('linuxbsd','windows'):
        extract(dependency('accesskit'), deps)
    if platform == 'linuxbsd':
        extract(dependency('linux_sdk'), deps)
        sdk = deps / 'x86_64-godot-linux-gnu_sdk-buildroot'
        run(['bash',sdk / 'relocate-sdk.sh'], sdk, env, work / 'relocate-sdk.log', 120)
        scanner = deps / 'wayland-scanner'
        run(['dpkg-deb','--extract',dependency('wayland_scanner'),scanner], work, env, work / 'wayland-scanner.log', 30)
        env['PATH'] = str(sdk / 'bin') + os.pathsep + str(scanner / 'usr/bin') + os.pathsep + env['PATH']
        actual = shutil.which('gcc', path=env['PATH'])
        if not actual or not Path(actual).is_relative_to(sdk):
            raise RuntimeError('Linux SDK did not supply gcc; refusing host compiler fallback')
        run(['gcc','--version'],work,env,work / 'compiler.log',30)
        run(['wayland-scanner','--version'],work,env,work / 'scanner-version.log',30)
    elif platform == 'windows':
        extract(dependency('llvm_mingw'), deps)
        sdk = deps / 'llvm-mingw-20260616-ucrt-ubuntu-22.04-x86_64'
        env['MINGW_PREFIX'] = str(sdk)
        env['PATH'] = str(sdk / 'bin') + os.pathsep + env['PATH']
        for key in ('angle','mesa','agility','winrt'):
            extract(dependency(key), deps / key)
        run(['x86_64-w64-mingw32-clang','--version'],work,env,work/'compiler.log',30)
    elif platform == 'web':
        run(['emcc','--version'],work,env,work/'compiler.log',30)
        if '4.0.20' not in (work/'compiler.log').read_text():
            raise RuntimeError('Pinned Emscripten image/version mismatch')
    elif platform == 'android':
        sdk = deps / 'android-sdk'
        for key,destination in [('ndk_29.0.14206865',sdk/'ndk/29.0.14206865'),
                                ('build-tools_36.1.0',sdk/'build-tools/36.1.0'),
                                ('platforms_android-36',sdk/'platforms/android-36')]:
            temporary = deps / ('unpack-' + key)
            extract(dependency(key), temporary)
            children = [p for p in temporary.iterdir() if p.is_dir()]
            if len(children)!=1: raise RuntimeError('Unexpected SDK archive layout: ' + key)
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.move(str(children[0]), destination)
        # SDK license files come from the pinned SDK image's accepted licenses.
        installed = Path(os.environ['ANDROID_HOME'])
        shutil.copytree(installed/'licenses', sdk/'licenses')
        for key in ('jdk','gradle'):
            extract(dependency(key), deps/key)
        java = next((deps/'jdk').glob('*/bin/java')).parent.parent
        env.update(ANDROID_HOME=str(sdk),ANDROID_SDK_ROOT=str(sdk),JAVA_HOME=str(java),
                   GRADLE_USER_HOME=str(deps/'gradle-user'))
        env['PATH'] = str(java/'bin') + os.pathsep + env['PATH']
        extract(dependency('swappy'), source/'thirdparty/swappy-frame-pacing')
        run([sdk/'ndk/29.0.14206865/toolchains/llvm/prebuilt/linux-x86_64/bin/clang','--version'],
            work,env,work/'compiler.log',30)
        run(['java','-version'],work,env,work/'java.log',30)
    return platform_options(job,work)


def one(paths, label):
    paths = list(paths)
    if len(paths)!=1: raise RuntimeError(f'Expected one {label}, found {paths}')
    return paths[0]


def verify_runtime_payload(path):
    # The wrapper/DLL/ICU/license/source archives are not standalone Godot VMs.
    if path.name.endswith('_console.exe') or path.suffix=='.dll' or path.name in ('icudt_godot.dat','LICENSE.txt','COPYRIGHT.txt','android_source.zip'):
        return
    version=RECIPE['expected_version'].rsplit('.',1)[0].encode()
    commit=RECIPE['source']['source_commit'].encode()
    if path.name.startswith('web_'):
        with zipfile.ZipFile(path) as archive:
            payloads=[archive.read(name) for name in archive.namelist() if name.endswith('.wasm')]
    elif path.suffix=='.apk':
        with zipfile.ZipFile(path) as archive:
            payloads=[archive.read(name) for name in archive.namelist() if name=='lib/arm64-v8a/libgodot_android.so']
    else:
        payloads=[path.read_bytes()]
    if not payloads or any(version not in data or commit not in data for data in payloads):
        raise RuntimeError('Built runtime lacks the exact custom/source identity: '+path.name)


def collect(job, source, output):
    platform,target = job['platform'],job.get('target','')
    if platform=='linuxbsd':
        pairs=[(one((source/'bin').glob('godot.linuxbsd.'+target+'.x86_64'),target),job['outputs'][0])]
        if target=='editor':
            pairs += [(source/'thirdparty/icu4c/icudt_godot.dat','icudt_godot.dat'),
                      (source/'LICENSE.txt','LICENSE.txt'),(source/'COPYRIGHT.txt','COPYRIGHT.txt')]
    elif platform=='windows':
        files=list((source/'bin').glob('godot.windows.'+target+'.x86_64*.exe'))
        console=[p for p in files if 'console' in p.name]
        pairs=[(one((p for p in files if p not in console),'Windows program'),job['outputs'][0]),
               (one(console,'Windows console wrapper'),job['outputs'][1])]
        if target=='template_release':
            pairs += [(source/'bin/D3D12Core.dll','D3D12Core.x86_64.dll'),
                      (source/'bin/d3d12SDKLayers.dll','d3d12SDKLayers.x86_64.dll')]
    elif platform=='web':
        pairs=[(one((source/'bin').glob('godot.web.'+target+'*.zip'),'Web template'),job['outputs'][0])]
    else:
        pairs=[(source/'bin'/name,name) for name in job['outputs']]
    for src,name in pairs:
        if not src.is_file() or not src.stat().st_size: raise RuntimeError('Missing built artifact: '+str(src))
        shutil.copy2(src,output/name)
        verify_runtime_payload(output/name)
    return {name:{'sha256':sha256(output/name),'bytes':(output/name).stat().st_size}
            for name in job['outputs']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lane',choices=RECIPE['jobs'])
    parser.add_argument('--work',type=Path,required=True)
    parser.add_argument('--verify-source-only',action='store_true')
    parser.add_argument('--jobs',type=int,default=2)
    args=parser.parse_args()
    work=args.work.resolve()
    if work.exists() and any(work.iterdir()): raise RuntimeError('Build directory must be empty; retain earlier attempts separately')
    work.mkdir(parents=True,exist_ok=True)
    source=prepare_source(work)
    if args.verify_source_only:
        print('PASS: original archive + exact ordered patches + all four resulting source hashes');return
    if not args.lane: raise RuntimeError('--lane is required for compilation')
    job=RECIPE['jobs'][args.lane]
    if work!=Path(RECIPE['work_directory']) or args.jobs!=RECIPE['build_workers']:
        raise RuntimeError('Production lane requires the canonical work path and worker count in the recipe')
    if os.environ.get('GUNMAN_BUILD_IMAGE')!=job['image']:
        raise RuntimeError('Invoke via the locked container lane; GUNMAN_BUILD_IMAGE must match its exact digest')
    env=os.environ.copy()
    env.update(BUILD_NAME=RECIPE['build_name'],SOURCE_DATE_EPOCH=str(RECIPE['source_date_epoch']),
               TZ='UTC',LC_ALL='C.UTF-8',GIT_CEILING_DIRECTORIES=str(work))
    options=prepare_dependencies(job,source,work,env)
    output=work/'artifacts';output.mkdir()
    record={'recipe_id':RECIPE['id'],'recipe_sha256':sha256(RECIPE_PATH),'lane':args.lane,
            'build_image':job['image'],'source':RECIPE['source'],'patches':RECIPE['patches'],
            'patched_source_sha256':RECIPE['patched_source_sha256'],'build_name':RECIPE['build_name'],
            'common_options':RECIPE['common_options'],'platform_options':options,
            'source_date_epoch':RECIPE['source_date_epoch'],'commands':[],
            'recipe_commit':os.environ.get('GITHUB_SHA','local-uncommitted'),
            'workflow_run':os.environ.get('GITHUB_RUN_ID','local'),'acceptance':'compiler output only'}
    write(output/'provenance.json',record)
    try:
        targets=job.get('targets',[job.get('target')])
        for index,command in enumerate(command_contract(job,work)):
            label=targets[index] if index<len(targets) else 'gradle'
            record['commands'].append(run(command['argv'],Path(command['cwd']),env,work/(label+'.log')))
            text=(work/(label+'.log')).read_text(errors='replace')
            if 'Disabling Wayland' in text or 'Alternatively, disable this driver' in text:
                raise RuntimeError('A required original platform feature was disabled; inspect compiler log')
            shutil.copy2(work/(label+'.log'),output/(label+'.log'))
        record['outputs']=collect(job,source,output)
        if args.lane=='linux-editor':
            result=subprocess.run([str(output/'godot-linux-x86_64'),'--version'],capture_output=True,text=True,timeout=30,env=env)
            record['version']=result.stdout.strip()
            if result.returncode or record['version']!=RECIPE['expected_version']:
                raise RuntimeError('Built binary does not have the exact custom Standard identity')
        record['status']='built'
    except BaseException as error:
        record['status']='failed';record['error']=str(error);raise
    finally:
        write(output/'provenance.json',record)
    print(json.dumps(record,indent=2))


if __name__=='__main__':
    main()
