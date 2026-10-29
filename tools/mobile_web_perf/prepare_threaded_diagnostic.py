#!/usr/bin/env python3
"""Prepare a separate official Godot 4.7.2 threaded audio diagnostic.

No engine invocation/browser/deployment. Only creates BUNDLE/audio-threaded/;
the original entry, cache worker and PCK are never changed. The parent PCK must
exist when served (the normal deployment reconstruction step can restore it).
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
from zipfile import ZipFile

from instrument_worklet import diagnostic_bytes, self_test as counter_self_test

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TEMPLATE = Path('/workspace/toolchains/user-data/godot/export_templates/4.7.2.stable/web_debug.zip')
OFFICIAL = {
    'godot.js': 'd33389d55f0af0cddee0b8495cbb3a6cad6beadd005fc52e39864019feb79657',
    'godot.wasm': 'fcce8c3ae3a7277199985e8b50610bbc267f88386bf31ab4a69885c160ec9cc8',
    'godot.audio.worklet.js': '5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3',
    'godot.audio.position.worklet.js': 'be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8',
    'godot.html': '3a5f265e788646513c32494fc0faead64c6b7f92ef005bf475da0c622bd481f4',
    'godot.service.worker.js': 'c72e9a688cd06978be343fd8481130e89dd81439267e1cfd8aef8343ea9f4139',
    'godot.offline.html': 'b0a5d443e78f58717adac780bac91c1431bfa3b801c41f4707d507fb5ad2e47f',
}

# This separate observer only describes start-message views after the native
# post succeeds. It never reads/writes ring memory or retains shared views.
SHARED_OBSERVER = r'''(() => {
  "use strict";
  const records = [], errors = [];
  const Native = window.AudioWorkletNode;
  function shared(view) {
    return typeof SharedArrayBuffer !== "undefined" && ArrayBuffer.isView(view) &&
      view.buffer instanceof SharedArrayBuffer;
  }
  function describe(view) {
    return {type: Object.prototype.toString.call(view), shared: shared(view),
      byte_length: Number(view?.byteLength || 0), length: Number(view?.length || 0)};
  }
  window.AudioWorkletNode = new Proxy(Native, {
    construct(target, args, newTarget) {
      const node = Reflect.construct(target, args, newTarget);
      if (args[1] !== "godot-processor") return node;
      const post = node.port.postMessage;
      node.port.postMessage = function (...messages) {
        const result = post.apply(this, messages);
        try {
          const message = messages[0];
          if (message?.cmd === "start" || message?.cmd === "start_nothreads") {
            records.push({cmd: message.cmd, threads: message.cmd === "start",
              performance_ms: performance.now(), audio_seconds: node.context.currentTime,
              views: Array.isArray(message.data) ? message.data.map(describe) : [],
              shared_ring_observed: message.cmd === "start" &&
                message.data?.length === 3 && message.data.every(shared)});
            if (records.length > 16) records.shift();
          }
        } catch (err) {
          errors.push(String(err?.name || "Error"));
          if (errors.length > 16) errors.shift();
        }
        return result;
      };
      return node;
    }
  });
  window.MOBILE_THREADED_DIAGNOSTIC = Object.freeze({snapshot() {
    const audio = window.MOBILE_AUDIO_PROBE.snapshot();
    return {version: "official-threaded-audio-v1", timestamp: new Date().toISOString(),
      cross_origin_isolated: window.crossOriginIsolated === true,
      shared_array_buffer_available: typeof SharedArrayBuffer !== "undefined",
      controller_script: navigator.serviceWorker?.controller?.scriptURL || null,
      expected_service_worker_scope: new URL("./", location.href).href,
      threads: records.some(row => row.threads),
      shared_ring_observed: records.some(row => row.shared_ring_observed),
      start_messages: records.map(row => ({...row, views: row.views.map(v => ({...v}))})),
      observer_errors: errors.slice(), audio,
      timing: window.MOBILE_STREAM_TIMING?.snapshot() || null,
      timing_mode: "raf_and_longtask_only_no_threaded_audio_callback_hooks",
      selected_sfx: window.SELECTED_SFX_SNAPSHOT || null,
      selected_ambience: window.SELECTED_AMBIENCE_SNAPSHOT || null,
      scope: "Diagnostic threaded official engine; separate counter-only worklet. Mixed destination PCM is not cue attribution or speaker/phone acceptance."};
  }});
})();
'''

# Preserve official COI detection and Engine.installServiceWorker(). Registration
# completion is not activation: wait before navigation, with the original2s
# bootstrap deadline and a per-tab/per-build maximum of two automatic reloads.
ACTIVATED_BOOTSTRAP = r'''
			const isolationOnly = missing.every(feature =>
				feature.startsWith('Cross-Origin Isolation') || feature.startsWith('SharedArrayBuffer'));
			if (!isolationOnly) {
				displayFailureNotice(new Error('Missing features cannot be repaired by isolation:\n' + missing.join('\n')));
				return;
			}
			let attempts;
			try {
				attempts = Number(sessionStorage.getItem(diagnosticIsolationKey) || 0);
				if (!Number.isSafeInteger(attempts) || attempts < 0) attempts = 0;
			} catch (err) {
				displayFailureNotice(new Error('Cannot safely bound isolation reloads: session storage unavailable.'));
				return;
			}
			if (attempts >= 2) {
				displayFailureNotice(new Error('Isolation unavailable after2 automatic reloads:\n' + missing.join('\n')));
				return;
			}
			let activationTimer;
			const activated = Promise.resolve().then(() => engine.installServiceWorker()).then(registration => {
				if (!registration || registration.scope !== new URL('./', location.href).href) {
					throw new Error('Unexpected isolation service worker scope.');
				}
				const expectedScript = new URL(GODOT_CONFIG.serviceWorker, location.href).href;
				return new Promise((resolve, reject) => {
					const worker = registration.active || registration.installing || registration.waiting;
					if (!worker || worker.scriptURL !== expectedScript) {
						reject(new Error('Expected isolation worker is unavailable.'));
						return;
					}
					function changed() {
						if (worker.state === 'activated') {
							worker.removeEventListener('statechange', changed);
							resolve(registration);
						} else if (worker.state === 'redundant') {
							worker.removeEventListener('statechange', changed);
							reject(new Error('Isolation worker became redundant.'));
						}
					}
					worker.addEventListener('statechange', changed);
					changed();
				});
			});
			Promise.race([
				activated,
				new Promise((resolve, reject) => {
					activationTimer = setTimeout(() => reject(new Error('Isolation worker activation exceeded2000ms.')), 2000);
				}),
			]).then(() => {
				sessionStorage.setItem(diagnosticIsolationKey, String(attempts + 1));
				window.location.reload();
			}).catch(displayFailureNotice).finally(() => clearTimeout(activationTimer));
'''


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_record(path: Path) -> dict:
    return {'path': str(path), 'bytes': path.stat().st_size, 'sha256': digest(path.read_bytes())}


def replace_once(text: str, needle: str, replacement: str) -> str:
    if text.count(needle) != 1:
        raise ValueError('Expected unique template replacement: ' + needle[:90])
    return text.replace(needle, replacement, 1)


def preserve_presentation(html: str, standard: str, config: dict) -> tuple[str, dict]:
    """Copy actual standard canvas, viewport and all CSS, with byte parity guards."""
    patterns = {
        'viewport': r'<meta\b[^>]*name="viewport"[^>]*>',
        'canvas': r'<canvas\b[^>]*>[\s\S]*?</canvas>',
        'styles': r'<style\b[^>]*>[\s\S]*?</style>',
    }
    evidence = {}
    for key, pattern in patterns.items():
        original = re.findall(pattern, standard)
        current = re.findall(pattern, html)
        if not original or not current or (key != 'styles' and (len(original) != 1 or len(current) != 1)):
            raise ValueError('Ambiguous standard/template presentation element: ' + key)
        # At this point the official page has only its one base style block.
        if key == 'styles' and len(current) != 1:
            raise ValueError('Unexpected official style additions')
        html = replace_once(html, current[0], '\n'.join(original))
        if re.findall(pattern, html) != original:
            raise ValueError('Standard presentation byte parity failed: ' + key)
        evidence[key] = {'count': len(original), 'identical_to_standard': True,
                         'sha256': [digest(value.encode()) for value in original]}
    evidence['viewport']['html'] = re.findall(patterns['viewport'], standard)[0]
    evidence['engine_canvas_config_inherited_unchanged'] = {
        key: config[key] for key in ['canvasResizePolicy', 'focusCanvas', 'experimentalVK']}
    evidence['internal_resolution_and_HiDPI'] = 'Same exact parent PCK/project.godot; no project override, canvas width/height override or DPR override added.'
    evidence['scope'] = 'Static parity only; actual threaded browser rendering/phone presentation still requires verification.'
    return html, evidence


def diagnostic_panel(info: dict, diagnostic_sha: str) -> str:
    metadata = {'version': 1, 'build_info': info,
                'official_threaded_engine_js_sha256': OFFICIAL['godot.js'],
                'official_threaded_wasm_sha256': OFFICIAL['godot.wasm'],
                'official_worklet_sha256': OFFICIAL['godot.audio.worklet.js'],
                'diagnostic_worklet_sha256': diagnostic_sha,
                'scope': 'Manual real game/menu observations; no automatic gameplay/menu changes. Diagnostic threaded engine, not a confirmed phone/BGM fix.'}
    return '''<div id="threaded-audio-panel" style="position:fixed;left:4px;bottom:30px;z-index:100;color:#fff;background:#15222be8;padding:6px;font:12px sans-serif">
<span id="threaded-audio-label"></span><button id="threaded-record-game">记录游戏中</button><button id="threaded-record-menu">记录菜单中</button><button id="threaded-audio-save">下载检测记录</button></div>
<script>
window.THREADED_AUDIO_RECORDING = Object.assign(METADATA, {latency_ms:diagnosticLatency,observations:[]});
const threadedLabel=document.getElementById('threaded-audio-label');
threadedLabel.textContent='音频线程检测 '+diagnosticLatency+'ms ';
function threadedSnapshot(phase){return {phase,performance_ms:performance.now(),diagnostic:window.MOBILE_THREADED_DIAGNOSTIC.snapshot()};}
async function threadedRecord(phase){
 const controls=['threaded-record-game','threaded-record-menu'].map(id=>document.getElementById(id));
 controls.forEach(button=>button.disabled=true);
 try {
  const row={phase,before:threadedSnapshot(phase)};
  const rows=window.THREADED_AUDIO_RECORDING.observations;rows.push(row);if(rows.length>8)rows.shift();
  threadedLabel.textContent='记录中，请保持当前状态10秒 ';
  await new Promise(resolve=>setTimeout(resolve,10000));
  row.after=threadedSnapshot(phase);threadedLabel.textContent='已记录 '+(phase==='game'?'游戏中':'菜单中')+' · '+diagnosticLatency+'ms ';
 } catch(error){threadedLabel.textContent='记录失败：'+String(error?.name||'Error');}
 finally{controls.forEach(button=>button.disabled=false);}
}
document.getElementById('threaded-record-game').onclick=()=>threadedRecord('game');
document.getElementById('threaded-record-menu').onclick=()=>threadedRecord('menu');
document.getElementById('threaded-audio-save').onclick=()=>{
 const data=JSON.stringify(window.THREADED_AUDIO_RECORDING,null,2);
 const url=URL.createObjectURL(new Blob([data],{type:'application/json'}));
 const a=document.createElement('a');a.href=url;a.download='audio-threaded-'+diagnosticLatency+'ms.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
};
</script>'''.replace('METADATA', json.dumps(metadata, ensure_ascii=False))


def verify_parent_pack(bundle: Path, info: dict) -> dict:
    name = info['pack']
    if not re.fullmatch(r'index\.[0-9a-f]{12}\.pck', name) or name != 'index.' + info['build_id'] + '.pck':
        raise ValueError('Unexpected parent pack content address')
    worker = (bundle / 'index.cache-sw.js').read_text()
    match = re.search(r'^const RESOURCE_MAP = (.*);$', worker, re.M)
    if not match:
        raise ValueError('Missing standard bundle resource contract')
    contract = json.loads(match[1])[name]
    expected, amount = contract['sha256'], contract['bytes']
    if not re.fullmatch('[0-9a-f]{64}', expected) or expected[:12] != info['build_id'] or amount != info['pack_bytes']:
        raise ValueError('Parent pack identity contract disagrees')
    pack = bundle / name
    checksum = hashlib.sha256()
    total = 0
    if pack.exists():
        with pack.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                checksum.update(chunk)
                total += len(chunk)
    else:
        # Validate chunk-only Git transport without materializing or copying PCK.
        for chunk in contract['chunks']:
            if chunk['url'] != 'chunks/' + chunk['sha256'] + '.gz':
                raise ValueError('Unsafe parent chunk URL')
            compressed = (bundle / chunk['url']).read_bytes()
            raw = gzip.decompress(compressed)
            if len(compressed) != chunk['gzip_bytes'] or len(raw) != chunk['bytes'] or digest(raw) != chunk['sha256']:
                raise ValueError('Parent pack chunk fingerprint rejected')
            checksum.update(raw)
            total += len(raw)
    if checksum.hexdigest() != expected or total != amount:
        raise ValueError('Actual parent pack bytes disagree with content address')
    return {'url': '../' + name, 'bytes': total, 'sha256': expected, 'copied': False,
            'present_on_disk': pack.exists(), 'verification': 'full_raw_pack' if pack.exists() else 'full_decompressed_chunk_stream',
            'serve_requirement': 'Parent content-addressed PCK must exist; run existing standard reconstruction before local/static serving if absent.'}


def site_size(root: Path) -> dict:
    files = [p for p in root.rglob('*') if p.is_file() and '.git' not in p.relative_to(root).parts]
    stored = sum(p.stat().st_size for p in files)
    missing = []
    for path in files:
        if path.name != 'build-info.json':
            continue
        info = json.loads(path.read_text())
        if 'pack' in info and not (path.parent / info['pack']).is_file():
            missing.append({'path': str((path.parent / info['pack']).relative_to(root)), 'bytes': info['pack_bytes']})
    return {'stored_static_bytes_excluding_git': stored, 'missing_standard_packs_reconstructed_at_deploy': missing,
            'projected_served_bytes': stored + sum(row['bytes'] for row in missing), 'limit_bytes': 1024 ** 3}


def make_files(bundle: Path, template: Path, self_test: bool) -> tuple[dict, dict]:
    info = json.loads((bundle / 'build-info.json').read_text())
    standard_html = (bundle / 'index.html').read_text()
    match = re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', standard_html)
    if not match:
        raise ValueError('Missing standard exported Godot configuration')
    config = json.loads(match[1])
    if config.get('emscriptenPoolSize') != 8 or config.get('godotPoolSize') != 4 or config.get('gdextensionLibs') != []:
        raise ValueError('Expected official exporter default pools8/4 and no GDExtensions')
    parent_pack = verify_parent_pack(bundle, info)
    with ZipFile(template) as archive:
        source = {name: archive.read(name) for name in OFFICIAL}
    if any(digest(source[name]) != checksum for name, checksum in OFFICIAL.items()):
        raise ValueError('Official 4.7.2 threaded template fingerprint rejected; never mix engine versions')
    diagnostic = diagnostic_bytes(source['godot.audio.worklet.js'])
    tests = {'self_test': 'not_run'}
    if self_test:
        with tempfile.TemporaryDirectory(prefix='threaded-audio-mock-') as tmp:
            original = Path(tmp) / 'official.worklet.js'
            original.write_bytes(source['godot.audio.worklet.js'])
            tests = {'self_test': 'passed', 'worklet_equivalence_output': counter_self_test(original, diagnostic),
                     'shared_observer_output': test_observer()}
    base = 'official-threaded'
    files = {base + '.js': source['godot.js'], base + '.wasm': source['godot.wasm'],
             base + '.audio.worklet.js': diagnostic,
             base + '.audio.position.worklet.js': source['godot.audio.position.worklet.js'],
             'official.audio.worklet.js': source['godot.audio.worklet.js'],
             'offline.html': source['godot.offline.html'],
             'shared-observer.js': SHARED_OBSERVER.encode()}
    for name in ['audio_probe.js', 'pcm_worklet.js', 'stream_timing_observer.js']:
        files[name] = (ROOT / 'tools/mobile_web_perf' / name).read_bytes()
    config.update({'executable': base, 'mainPack': parent_pack['url'],
                   'ensureCrossOriginIsolationHeaders': True, 'serviceWorker': 'diagnostic.service.worker.js',
                   'fileSizes': {base + '.wasm': len(source['godot.wasm']), parent_pack['url']: parent_pack['bytes']}})
    html = source['godot.html'].decode()
    substitutions = {'$GODOT_PROJECT_NAME': 'Gunman Rush · threaded audio diagnostic', '$GODOT_SPLASH_COLOR': '#242424',
                     '$GODOT_HEAD_INCLUDE': '<script src="audio_probe.js"></script><script src="shared-observer.js"></script><script src="stream_timing_observer.js"></script>',
                     '$GODOT_SPLASH_CLASSES': 'show-image--false', '$GODOT_SPLASH': 'data:,',
                     '$GODOT_URL': base + '.js', '$GODOT_CONFIG': json.dumps(config, separators=(',', ':')),
                     '$GODOT_THREADS_ENABLED': 'true'}
    for token, value in substitutions.items():
        html = html.replace(token, value)
    if '$GODOT_' in html:
        raise ValueError('Unresolved official HTML export token')
    html, presentation = preserve_presentation(html, standard_html, config)
    html = replace_once(html, 'const engine = new Engine(GODOT_CONFIG);', '''const diagnosticLatency = Number(new URLSearchParams(location.search).get('latency') || 50);
if (![50, 200].includes(diagnosticLatency)) throw new Error('Only50/200ms diagnostic cases allowed');
GODOT_CONFIG.args = GODOT_CONFIG.args.concat(['--audio-output-latency', String(diagnosticLatency)]);
const diagnosticIsolationKey = 'mobile-audio-threaded-coi:' + new URL('./', location.href).href + ':' + BUILD_ID;
const engine = new Engine(GODOT_CONFIG);'''.replace('BUILD_ID', json.dumps(info['build_id'])))
    original_registration = re.search(r'\t\t\tlet serviceWorkerRegistrationPromise;[\s\S]+?\t\t\t\}\);', html)
    if original_registration is None:
        raise ValueError('Missing exact official registration bootstrap')
    html = replace_once(html, original_registration[0], ACTIVATED_BOOTSTRAP.strip('\n'))
    html = replace_once(html, "\t\tsetStatusMode('progress');", "\t\ttry { sessionStorage.removeItem(diagnosticIsolationKey); } catch (_) {}\n\t\tsetStatusMode('progress');")
    html = replace_once(html, "setStatusMode('hidden');", "window.THREADED_DIAGNOSTIC_READY = true;\n\t\t\tsetStatusMode('hidden');")
    html = replace_once(html, '</body>', diagnostic_panel(info, digest(diagnostic)) + '\n</body>')
    files['index.html'] = html.encode()
    # Identity includes the generated bootstrap and exact observer bytes, not
    # just the unchanged PCK. Exclude SW/receipt to avoid a hash dependency cycle.
    static_digest = digest(b''.join(name.encode() + b'\0' + digest(files[name]).encode() + b'\0'
                                   for name in sorted(files)))
    cache_version = info['build_id'] + '-diagnostic-' + static_digest[:16]
    sw = source['godot.service.worker.js'].decode()
    sw_tokens = {'___GODOT_VERSION___': cache_version,
                 '___GODOT_NAME___': 'gunman-rush-audio-threaded-diagnostic',
                 '___GODOT_OFFLINE_PAGE___': 'offline.html',
                 '___GODOT_ENSURE_CROSSORIGIN_ISOLATION_HEADERS___': 'true',
                 '___GODOT_CACHE___': json.dumps(['index.html', 'offline.html']),
                 '___GODOT_OPT_CACHE___': json.dumps([name for name in files if name not in ['index.html', 'offline.html']])}
    for token, value in sw_tokens.items():
        sw = replace_once(sw, token, value)
    if '___GODOT_' in sw:
        raise ValueError('Unresolved official worker export token')
    files['diagnostic.service.worker.js'] = sw.encode()
    if self_test:
        tests['official_service_worker_output'] = test_service_worker(sw)
        tests['bootstrap_output'] = test_bootstrap(html)
    receipt = {'status': 'prepared_not_browser_verified', 'build_info': info, 'parent_pack': parent_pack,
               'scope': 'Independent diagnostic only; actual formal PCK/scene and official matched threaded JS/WASM. No production or ordinary entry edits; no phone/FPS/BGM acceptance.',
               'template': file_record(template), 'official_members_sha256': OFFICIAL,
               'engine_js_wasm_position_worklet_unchanged': True, 'instrumented_worklet': True,
               'worklet': {'official_sha256': OFFICIAL['godot.audio.worklet.js'], 'diagnostic_sha256': digest(diagnostic),
                           'official_copy': 'official.audio.worklet.js', 'runtime_copy': base + '.audio.worklet.js',
                           'scope': 'Counter-only guarded ready read/underflow branches; not official baseline; supports threads and nonthreads.'},
               'godot_config': config, 'presentation_parity': presentation,
               'latency_comparison': {'query_values_ms': [50, 200], 'default_ms': 50,
                 'startup_args_only': True, 'manual_recording_seconds': 10, 'observation_limit': 8,
                 'menu_state': 'User opens actual game menu manually; diagnostic buttons only snapshot and wait.'},
               'service_worker': {'scope': './audio-threaded/', 'registration': 'official Engine.installServiceWorker with default script-directory scope',
                 'cache_prefix': 'gunman-rush-audio-threaded-diagnostic-sw-cache-', 'coi_headers': True,
                 'parent_pack_fetch': 'Official noncacheable fetch branch also inserts COOP/COEP; same-origin parent URL is supported.',
                 'html_adaptation': 'Official feature detection/COI gate and Engine.installServiceWorker retained. Wait for expected exact-scope/script worker activated before reload; existing active worker on a nonCOI page may reload. Original2000ms activation deadline; at most2 automatic reloads per tab/build. Persistent failure is displayed; no isolation bypass.',
                 'cache_version': cache_version, 'static_files_sha256_before_SW': static_digest,
                 'cache_version_inputs': 'Sorted generated filenames + complete file SHA256, excluding SW and receipt; includes HTML/bootstrap and all observers.',
                 'bootstrap_timeout_ms': 2000, 'automatic_reload_limit': 2,
                 'ordinary_root_worker_touched': False},
               'observer': {'api': 'window.MOBILE_THREADED_DIAGNOSTIC.snapshot()', 'records_limit': 16,
                 'shared_memory': 'Descriptors of actual start state/input/output typed-array backing buffers, after successful native post; no ring memory read/write or retained views.',
                 'timing': 'Exact same stream_timing_observer.js bytes as no-thread diagnostic, before engine: RAF callback envelopes and LongTask only. Official threaded engine has no instrumented chunk callbacks; begun/acknowledged remain0 and do not measure producer latency.',
                 'required_runtime_guards': ['cross_origin_isolated===true', 'threads===true', 'shared_ring_observed===true', 'audio.streams[].underrun_stats.threads===true', 'audio.destinations[].status ready with actual mixed PCM'],
                 'unverified_until_browser_run': True},
               'files': {name: {'bytes': len(data), 'sha256': digest(data)} for name, data in files.items()}, **tests}
    return files, receipt


def test_observer() -> str:
    script = r'''
const vm=require('vm'),assert=require('assert');
let calls=0;
class Node {constructor(context,name){this.context=context;this.port={postMessage(message){calls++;if(message.fail)throw new RangeError('original');return 42;}}}}
const sandbox={window:null,AudioWorkletNode:Node,SharedArrayBuffer,ArrayBuffer,performance:{now:()=>1},
Date,URL,location:{href:'https://example.test/game/audio-threaded/'},navigator:{serviceWorker:{controller:{scriptURL:'https://example.test/game/audio-threaded/diagnostic.service.worker.js'}}},
crossOriginIsolated:true,MOBILE_AUDIO_PROBE:{snapshot:()=>({streams:[],destinations:[]})}};
sandbox.window=sandbox;vm.createContext(sandbox);vm.runInContext(SOURCE,sandbox);
const node=new sandbox.AudioWorkletNode({currentTime:2},'godot-processor');
const data=[new Int32Array(new SharedArrayBuffer(16)),new Float32Array(new SharedArrayBuffer(32)),new Float32Array(new SharedArrayBuffer(32))];
assert.equal(node.port.postMessage({cmd:'start',data}),42);
assert.equal(sandbox.MOBILE_THREADED_DIAGNOSTIC.snapshot().shared_ring_observed,true);
assert.equal(sandbox.MOBILE_THREADED_DIAGNOSTIC.snapshot().threads,true);
assert.throws(()=>node.port.postMessage({fail:true}),RangeError);
for(let i=0;i<20;i++)node.port.postMessage({cmd:'start_nothreads',data:[new Float32Array(8)]});
const result=sandbox.MOBILE_THREADED_DIAGNOSTIC.snapshot();
assert.equal(result.start_messages.length,16);assert.equal(result.shared_ring_observed,false);
assert.equal(result.start_messages[0].views[0].shared,false);assert.equal(calls,22);
assert.equal(result.observer_errors.length,0);assert.doesNotThrow(()=>JSON.stringify(result));
console.log('PASS shared/native-result/exception/nothread/bounded16/no-ring-write observer');
'''.replace('SOURCE', json.dumps(SHARED_OBSERVER))
    result = subprocess.run(['node', '-e', script], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise ValueError(result.stdout + result.stderr)
    return result.stdout


def test_service_worker(source: str) -> str:
    """Run the actual parameterized official fetch handler, without a browser."""
    script = r'''
const vm=require('vm'),assert=require('assert');
const listeners={},deleted=[],fetched=[];
const sandbox={Headers,Response,Promise,console,caches:{keys:async()=>[
 'gunman-rush-runtime-v1','gunman-rush-audio-threaded-diagnostic-sw-cache-obsolete'],
 delete:async name=>deleted.push(name)},self:{
 addEventListener:(name,fn)=>listeners[name]=fn,
 registration:{},fetch:async request=>{fetched.push(request.url);return new Response('parent-pck',{status:200,headers:{'Content-Type':'application/octet-stream'}});}
},fetch:async request=>{fetched.push(request.url);return new Response('parent-pck',{status:200,headers:{'Content-Type':'application/octet-stream'}});}};
vm.createContext(sandbox);vm.runInContext(SOURCE,sandbox);
(async()=>{
 let reply;
 listeners.fetch({request:{mode:'cors',url:'https://example.test/game/index.abc.pck',referrer:'https://example.test/game/audio-threaded/'},respondWith:p=>reply=p});
 assert.ok(reply,'uncacheable parent PCK is handled for COI');
 const response=await reply;
 assert.equal(response.headers.get('Cross-Origin-Opener-Policy'),'same-origin');
 assert.equal(response.headers.get('Cross-Origin-Embedder-Policy'),'require-corp');
 assert.equal(await response.text(),'parent-pck');assert.equal(fetched.length,1);
 let activation;listeners.activate({waitUntil:p=>activation=p});await activation;
 assert.equal(deleted.length,1);assert.ok(deleted[0].startsWith('gunman-rush-audio-threaded-diagnostic-sw-cache-'));
 assert.ok(!deleted.includes('gunman-rush-runtime-v1'));
 console.log('PASS actual officialSW parentPCK body/COOP/COEP; activation keeps ordinary root cache');
})().catch(error=>{console.error(error);process.exitCode=1});
'''.replace('SOURCE', json.dumps(source))
    result = subprocess.run(['node', '-e', script], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise ValueError(result.stdout + result.stderr)
    return result.stdout


def test_bootstrap(html: str) -> str:
    """Execute the generated bootstrap with deterministic activation/navigation."""
    inline = re.findall(r'<script\b[^>]*>([\s\S]*?)</script>', html)
    bootstrap = next(value for value in inline if 'const GODOT_CONFIG' in value)
    script = r'''
const vm=require('vm'),assert=require('assert');
const url='https://example.test/game/audio-threaded/';
const scriptURL=url+'diagnostic.service.worker.js';
const storage=new Map();
function worker(state='installing',script=scriptURL){
 const listeners=new Set();
 return {state,scriptURL:script,addEventListener:(name,fn)=>listeners.add(fn),
  removeEventListener:(name,fn)=>listeners.delete(fn),change(next){this.state=next;for(const fn of [...listeners])fn();}};
}
const flush=()=>new Promise(setImmediate);
async function navigation(options={}){
 const seen={reloads:0,starts:0,errors:[],installs:0,delays:[]},timers=new Map();let nextTimer=0;
 const w=options.worker||worker('activated');
 const reg={scope:options.scope||url,active:w.state==='activated'?w:null,installing:w.state==='activated'?null:w,waiting:null};
 class Engine{
  constructor(config){this.config=config}
  static getMissingFeatures(options){assert.equal(options.threads,true);return options.missing||[]}
  installServiceWorker(){seen.installs++;return options.stall?new Promise(()=>{}):Promise.resolve(reg)}
  startGame(){seen.starts++;return Promise.resolve()}
 }
 Engine.getMissingFeatures=arg=>{assert.equal(arg.threads,true);return options.missing===undefined?['Cross-Origin Isolation','SharedArrayBuffer']:options.missing;};
 const nodes=new Map(),element=id=>{if(!nodes.has(id))nodes.set(id,{style:{},remove(){},removeAttribute(){},appendChild(){},lastChild:null});return nodes.get(id)};
 const sandbox={Engine,URL,URLSearchParams,Promise,Error,Number,
  console:{error:error=>seen.errors.push(String(error))},
  setTimeout:(fn,delay)=>{seen.delays.push(delay);timers.set(++nextTimer,fn);return nextTimer},clearTimeout:id=>timers.delete(id),
  location:{href:url+'?latency=50&audio_probe=1',search:'?latency=50&audio_probe=1',reload:()=>seen.reloads++},
  sessionStorage:{getItem:key=>{if(options.storageBlocked)throw Error('blocked');return storage.get(key)||null},
   setItem:(key,value)=>storage.set(key,value),removeItem:key=>storage.delete(key)},
  navigator:{serviceWorker:{}},document:{getElementById:element,createTextNode:()=>({}),createElement:()=>({})}};
 sandbox.window=sandbox;vm.createContext(sandbox);vm.runInContext(BOOTSTRAP,sandbox);await flush();
 return {seen,w,sandbox,timeout:async()=>{for(const fn of [...timers.values()])fn();await flush();}};
}
(async()=>{
 storage.clear();const initial=await navigation({worker:worker()});
 assert.equal(initial.seen.reloads,0);assert.equal(initial.seen.starts,0);
 initial.w.change('activating');await flush();assert.equal(initial.seen.reloads,0);
 initial.w.change('activated');await flush();assert.equal(initial.seen.reloads,1);
 assert.deepEqual(initial.seen.delays,[2000]);console.log('PASS register/installing/activating wait; reload only after activated; deadline2000');
 const recovery=await navigation();assert.equal(recovery.seen.reloads,1);assert.equal(recovery.seen.starts,0);
 const exhausted=await navigation();assert.equal(exhausted.seen.reloads,0);assert.equal(exhausted.seen.starts,0);
 assert.ok(exhausted.seen.errors.some(v=>v.includes('after2 automatic reloads')));console.log('PASS existing activated/nonCOI recovery; hard2reload bound, no start without isolation');
 const isolated=await navigation({missing:[]});assert.equal(isolated.seen.starts,1);assert.equal(isolated.seen.reloads,0);
 assert.equal(isolated.sandbox.THREADED_DIAGNOSTIC_READY,true);assert.equal(storage.size,0);console.log('PASS genuine missing-features empty starts exactly once, clears reload bound');
 storage.clear();const wrongScope=await navigation({scope:'https://example.test/game/'});
 assert.equal(wrongScope.seen.reloads,0);assert.ok(wrongScope.seen.errors.some(v=>v.includes('scope')));
 const wrongScript=await navigation({worker:worker('activated',url+'other.js')});
 assert.equal(wrongScript.seen.reloads,0);assert.ok(wrongScript.seen.errors.some(v=>v.includes('unavailable')));
 const redundant=await navigation({worker:worker()});redundant.w.change('redundant');await flush();
 assert.equal(redundant.seen.reloads,0);assert.ok(redundant.seen.errors.some(v=>v.includes('redundant')));
 const timedOut=await navigation({stall:true});await timedOut.timeout();assert.equal(timedOut.seen.reloads,0);
 assert.ok(timedOut.seen.errors.some(v=>v.includes('2000ms')));
 const blocked=await navigation({storageBlocked:true});assert.equal(blocked.seen.installs,0);assert.equal(blocked.seen.reloads,0);
 const webgl=await navigation({missing:['WebGL2 - unavailable']});assert.equal(webgl.seen.installs,0);assert.equal(webgl.seen.reloads,0);
 console.log('PASS wrongscope/wrongscript/redundant/timeout/storageblocked/WebGL negative controls; failures visible, no unbounded reload');
})().catch(error=>{console.error(error);process.exitCode=1});
'''.replace('BOOTSTRAP', json.dumps(bootstrap))
    result = subprocess.run(['node', '-e', script], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise ValueError(result.stdout + result.stderr)
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', required=True, type=Path)
    parser.add_argument('--template', type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument('--site-root', type=Path, help='Count full prepared comparison site, defaults to bundle')
    parser.add_argument('--self-test', action='store_true', help='Pure Node output-equivalence/shared-memory observer mocks')
    parser.add_argument('--check-only', action='store_true', help='Validate and calculate exact prospective bytes; create no directory')
    args = parser.parse_args()
    try:
        bundle = args.bundle.resolve(strict=True)
        site = (args.site_root or bundle).resolve(strict=True)
        output = bundle / 'audio-threaded'
        if not bundle.is_relative_to(site) or output.exists() or output.is_symlink():
            raise ValueError('Output must be a new audio-threaded subdirectory inside the counted site')
        files, receipt = make_files(bundle, args.template.resolve(strict=True), args.self_test)
        size = site_size(site)
        receipt['site_size_before'] = size
        receipt['output_directory'] = str(output)
        receipt['entry'] = 'audio-threaded/?audio_probe=1'
        # Include the receipt itself in exact static size. Iterate to settle digit lengths.
        receipt['new_directory_bytes'] = 0
        receipt['projected_served_site_bytes'] = 0
        for unused in range(8):
            receipt_data = (json.dumps(receipt, ensure_ascii=False, indent=2) + '\n').encode()
            added = sum(len(data) for data in files.values()) + len(receipt_data)
            receipt['new_directory_bytes'] = added
            receipt['projected_served_site_bytes'] = size['projected_served_bytes'] + added
        receipt_data = (json.dumps(receipt, ensure_ascii=False, indent=2) + '\n').encode()
        if receipt['new_directory_bytes'] != sum(map(len, files.values())) + len(receipt_data):
            raise ValueError('Static size accounting did not converge')
        if receipt['projected_served_site_bytes'] >= 1024 ** 3:
            raise ValueError('Projected full reconstructed site exceeds strict <1GiB bound: ' + str(receipt['projected_served_site_bytes']))
        if not args.check_only:
            output.mkdir()
            for name, data in files.items():
                (output / name).write_bytes(data)
            (output / 'threaded-diagnostic.json').write_bytes(receipt_data)
        print(json.dumps({'status': 'checked_only' if args.check_only else 'generated',
                          'output': str(output), 'entry': receipt['entry'],
                          'new_directory_bytes': receipt['new_directory_bytes'],
                          'projected_served_site_bytes': receipt['projected_served_site_bytes'],
                          'headroom_bytes': 1024 ** 3 - receipt['projected_served_site_bytes'],
                          'parent_pack': receipt['parent_pack'], 'self_test': receipt['self_test'],
                          'runtime_verified': False}, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(json.dumps({'status': 'failed', 'error': str(error)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
