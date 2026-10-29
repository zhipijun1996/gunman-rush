#!/usr/bin/env python3
"""Derive separately named Godot 4.7.2 STREAM timing JS/worklet; never patch originals.

Use --engine OFFICIAL.js --wasm OFFICIAL.wasm --worklet OFFICIAL.audio.worklet.js
--output NEW_DIRECTORY [--prefix stream-timing.engine] [--self-test]. Load the copied
stream_timing_observer.js before the derived engine; change only the diagnostic
HTML's executable to PREFIX. The existing underrun diagnostic layer is retained.
All three official input hashes are exact guards. --self-test-only writes nothing.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

JS_SHA256 = "ffc3898b59fba6f5af0c02f76e5ee526cc061e65c7d2d6f4f98186876cea15c4"
WASM_SHA256 = "11ea19645368f8e73cf337b59cfd7ceeb4ebb51f7a3bbf77d1a5c3ddfedbc522"
WORKLET_SHA256 = "5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3"
POSITION_SHA256 = "be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8"
HERE = Path(__file__).resolve().parent

JS_REPLACEMENTS = [
    ('start_no_threads:function(p_out_buf,p_out_size,out_callback,p_in_buf,p_in_size,in_callback){function RingBuffer(){',
     'start_no_threads:function(p_out_buf,p_out_size,out_callback,p_in_buf,p_in_size,in_callback){'
     'function mobileTimingCall(name,...args){try{const observer=globalThis.MOBILE_STREAM_TIMING;'
     'return observer&&typeof observer[name]==="function"?observer[name](...args):null}catch(_){return null}}function RingBuffer(){'),
    ('function send(port){if(pending_samples===0){return}',
     'function send(port,mobileTiming){if(pending_samples===0){return}'),
    ('const tot_sent=pending_samples;out_callback(wpos,pending_samples);',
     'const tot_sent=pending_samples;if(mobileTiming){mobileTiming.mix_wpos=wpos;'
     'mobileTiming.mix_samples=pending_samples;mobileTimingCall("mark",mobileTiming,"mix_start",GodotAudio.ctx)}'
     'let mobileMixOK=false;try{out_callback(wpos,pending_samples);mobileMixOK=true}finally{'
     'if(mobileTiming){mobileTiming.mix_succeeded=mobileMixOK;mobileTimingCall("mark",mobileTiming,"mix_end",GodotAudio.ctx)}}'),
    ('port.postMessage({cmd:"chunk",data:wbuf.subarray(0,tot_sent)});',
     'if(mobileTiming){mobileTiming.chunk_samples=tot_sent;'
     'mobileTimingCall("mark",mobileTiming,"chunk_post_start",GodotAudio.ctx);'
     'let mobilePostOK=false;try{port.postMessage({cmd:"chunk",data:wbuf.subarray(0,tot_sent),'
     'mobile_stream_timing:mobileTiming});mobilePostOK=true}finally{mobileTiming.chunk_post_succeeded=mobilePostOK;'
     'mobileTimingCall("mark",mobileTiming,"chunk_post_end",GodotAudio.ctx)}}else{'
     'port.postMessage({cmd:"chunk",data:wbuf.subarray(0,tot_sent)});}'),
    ('this.consumed=function(size,port){pending_samples+=size;send(port)}',
     'this.consumed=function(size,port,mobileTiming){pending_samples+=size;send(port,mobileTiming)}'),
    ('if(!GodotAudioWorklet.worklet){return}if(event.data["cmd"]==="read"){',
     'if(!GodotAudioWorklet.worklet){return}if(event.data["cmd"]==="mobile_stream_timing"){'
     'mobileTimingCall("ack",event.data["data"],GodotAudio.ctx,node);return}'
     'if(event.data["cmd"]==="read"){'),
    ('const read=event.data["data"];GodotAudioWorklet.ring_buffer.consumed(read,GodotAudioWorklet.worklet.port)',
     'const read=event.data["data"];const mobileTiming=mobileTimingCall("begin",'
     'event.data.mobile_stream_timing,GodotAudio.ctx,node);'
     'GodotAudioWorklet.ring_buffer.consumed(read,GodotAudioWorklet.worklet.port,mobileTiming)'),
]

WORKLET_REPLACEMENTS = [
    ('\t\tthis.input_buffer = new Float32Array();\n',
     '\t\tthis.input_buffer = new Float32Array();\n\t\tthis._mobile_timing_read_seq = 0;\n'),
    ('\t\t\tthis.parse_message(cmd, data);',
     '\t\t\tconst timing = event.data.mobile_stream_timing;\n'
     '\t\t\tif (cmd === "chunk" && timing && timing.version === 1 && Number.isSafeInteger(timing.seq)) {\n'
     '\t\t\t\tconst frame = currentFrame;\n'
     '\t\t\t\tconst before = this.output ? this.output.data_left() : null;\n'
     '\t\t\t\tlet succeeded = false;\n'
     '\t\t\t\ttry { this.parse_message(cmd, data); succeeded = true; } finally {\n'
     '\t\t\t\t\ttry { this.port.postMessage({cmd: "mobile_stream_timing", data: {...timing,\n'
     '\t\t\t\t\t\tchunk_receive_frame: frame, chunk_receive_sample_rate: sampleRate,\n'
     '\t\t\t\t\t\tchunk_ring_before_samples: before,\n'
     '\t\t\t\t\t\tchunk_ring_after_samples: this.output ? this.output.data_left() : null,\n'
     '\t\t\t\t\t\tchunk_write_succeeded: succeeded}}); } catch (_) {}\n'
     '\t\t\t\t}\n\t\t\t} else { this.parse_message(cmd, data); }'),
    ("\t\t\t\t\tthis.port.postMessage({ 'cmd': 'read', 'data': chunk });",
     '\t\t\t\t\tthis._mobile_timing_read_seq++;\n'
     '\t\t\t\t\tif (this._mobile_timing_read_seq % 32 === 1) {\n'
     '\t\t\t\t\t\tthis.port.postMessage({cmd: "read", data: chunk, mobile_stream_timing: {\n'
     '\t\t\t\t\t\t\tversion: 1, seq: this._mobile_timing_read_seq, request_frame: currentFrame,\n'
     '\t\t\t\t\t\t\tsample_rate: sampleRate, request_samples: chunk,\n'
     '\t\t\t\t\t\t\tring_after_read_samples: this.output.data_left()}});\n'
     '\t\t\t\t\t} else { this.port.postMessage({ \'cmd\': \'read\', \'data\': chunk }); }'),
]


def guarded(data: bytes, expected: str, label: str) -> None:
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected:
        raise ValueError(f"Unsupported {label} SHA256: {actual}; expected {expected}")


def replace_layer(source: str, replacements: list[tuple[str, str]]) -> str:
    result = source
    for old, new in replacements:
        if result.count(old) != 1:
            raise ValueError(f"Non-unique/missing timing insertion: {old[:100]!r}")
        result = result.replace(old, new, 1)
    if restore_layer(result, replacements) != source:
        raise ValueError("Timing reverse transformation failed")
    return result


def restore_layer(source: str, replacements: list[tuple[str, str]]) -> str:
    for old, new in reversed(replacements):
        if source.count(new) != 1:
            raise ValueError("Non-unique/missing timing reverse insertion")
        source = source.replace(new, old, 1)
    return source


def derive(engine: bytes, worklet: bytes) -> tuple[bytes, bytes, bytes]:
    guarded(engine, JS_SHA256, "official engine JS")
    guarded(worklet, WORKLET_SHA256, "official worklet")
    # Import the existing exact, independently mock-tested underrun counter layer.
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(HERE))
    import instrument_worklet
    counter = instrument_worklet.diagnostic_bytes(worklet)
    js = replace_layer(engine.decode(), JS_REPLACEMENTS).encode()
    wk = replace_layer(counter.decode(), WORKLET_REPLACEMENTS).encode()
    guarded(restore_layer(js.decode(), JS_REPLACEMENTS).encode(), JS_SHA256, "restored JS")
    if restore_layer(wk.decode(), WORKLET_REPLACEMENTS).encode() != counter:
        raise ValueError("Restored counter layer differs")
    # Existing counter layer itself checks exact reversal to the official bytes.
    return js, wk, counter


def node_tests(engine: bytes, worklet: bytes, js: bytes, wk: bytes) -> dict:
    observer = (HERE / "stream_timing_observer.js").read_text()
    for label, source in [("engine", js), ("worklet", wk), ("observer", observer.encode())]:
        result = subprocess.run(["node", "--check"], input=source, capture_output=True)
        if result.returncode:
            raise ValueError(f"{label} node --check failed: {result.stderr.decode()}")
    payload = {"official_engine": engine.decode(), "official_worklet": worklet.decode(),
               "engine": js.decode(), "worklet": wk.decode(), "observer": observer}
    result = subprocess.run(["node", "--eval", MOCK_TEST], input=json.dumps(payload), text=True,
                            capture_output=True)
    if result.returncode:
        raise ValueError("Node timing mock failed:\n" + result.stdout + result.stderr)
    return json.loads(result.stdout)


# Evaluates only the extracted official start_no_threads function and an in-memory
# AudioWorkletProcessor mock, never the engine/WASM runtime or a real browser.
MOCK_TEST = r"""
const fs=require('fs'), vm=require('vm'), assert=require('assert');
const sources=JSON.parse(fs.readFileSync(0,'utf8'));
const tests=[];
function plain(v) {
  if (ArrayBuffer.isView(v)) return Array.from(v);
  if (Array.isArray(v)) return Array.from(v,plain);
  if(v&&typeof v==='object') return Object.fromEntries(Object.entries(v)
    .filter(([k])=>k!=='mobile_stream_timing').map(([k,x])=>[k,plain(x)]));
  return v;
}
function setup(diagnostic, failure, missingObserver=false) {
  const mainQueue=[], workletQueue=[], trace=[], wire=[], errorToken={original_exception:failure};
  let tick=0, mixed=0, postCount=0, frame=0;
  const heap=new Float32Array(8192);
  for(let i=0;i<1024;i++) heap[i]=i/1024;
  const ctx={sampleRate:48000,currentTime:0,state:'running',destination:{},baseLatency:0.01};
  const main={console,Float32Array,Map,WeakMap,Number,Object,Array,performance:{now:()=>++tick/8},
    requestAnimationFrame:cb=>{if(typeof cb!=='function')throw new TypeError('callback');main.lastRAF=cb;return 17},
    GodotRuntime:{heapSub:(a,p,n)=>a.subarray(p,p+n),heapSlice:(a,p,n)=>a.slice(p,p+n),error:v=>trace.push(['error',plain(v)])},
    HEAPF32:heap,GodotAudio:{ctx}};
  main.PerformanceObserver=class{constructor(callback){main.longTaskCallback=callback}
    observe(options){main.longTaskOptions=options}};
  main.globalThis=main;vm.createContext(main);
  if(diagnostic&&!missingObserver) vm.runInContext(sources.observer,main);
  const node={connect:()=>trace.push(['connect']),port:{postMessage(message){
    postCount++;if(failure==='post'&&message.cmd==='chunk')throw errorToken;
    if(message.cmd==='chunk')wire.push({cmd:'chunk',keys:Object.keys(message),seq:message.mobile_stream_timing?.seq??null});
    trace.push(['main_post',plain(message)]);workletQueue.push(structuredClone(message));
  }}};
  main.GodotAudioWorklet={worklet:node,promise:{then:cb=>cb()}};
  let Processor;
  const wk={console,Float32Array,Int32Array,Atomics,Number,Object,Array,sampleRate:48000,currentFrame:0,
    AudioWorkletProcessor:class{constructor(){this.port={postMessage:message=>{
      if(failure==='request'&&message.cmd==='read')throw errorToken;
      if(message.cmd==='read')wire.push({cmd:'read',keys:Object.keys(message),seq:message.mobile_stream_timing?.seq??null});
      if(!['mobile_perf_stream_stats','mobile_stream_timing'].includes(message.cmd)) trace.push(['worklet_post',plain(message)]);
      mainQueue.push(structuredClone(message));
    }}}},registerProcessor:(name,ctor)=>{Processor=ctor}};
  vm.createContext(wk);vm.runInContext(diagnostic?sources.worklet:sources.official_worklet,wk);
  const processor=new Processor();
  const engine=diagnostic?sources.engine:sources.official_engine;
  const start=engine.indexOf('start_no_threads:function(')+'start_no_threads:'.length;
  const end=engine.indexOf(',get_node:function()',start);
  const fn=vm.runInContext('('+engine.slice(start,end)+')',main);
  fn(0,1024,(pos,count)=>{
    trace.push(['mix',pos,count]);mixed++;if(failure==='mix'&&mixed===1)throw errorToken;
    for(let i=0;i<count;i++)heap[(pos+i)%1024]=(mixed*10+i)/10000;
  },2048,512,(pos,count)=>trace.push(['input',pos,count]));
  function deliverWorklet(){while(workletQueue.length){
    const message=workletQueue.shift();wk.currentFrame=frame;
    if(failure==='write'&&message.cmd==='chunk')processor.output.write=()=>{throw errorToken};
    processor.port.onmessage({data:message});
  }}
  function deliverMain(){while(mainQueue.length){const message=mainQueue.shift();
    // Existing audio_probe stops only the pre-existing counter messages.
    if(message.cmd==='mobile_perf_stream_stats')continue;
    ctx.currentTime=frame/48000+0.002;
    node.port.onmessage({data:message});
  }}
  function step(input=false,mainDelayFrames=0){frame+=128;wk.currentFrame=frame;ctx.currentTime=frame/48000;
    const output=[new Float32Array(128),new Float32Array(128)];
    const result=processor.process(input?[[new Float32Array(128).fill(0.25)] ]:[],[output],{});
    trace.push(['process',result,plain(output)]);frame+=mainDelayFrames;
    deliverMain();deliverWorklet();deliverMain();}
  return {main,wk,processor,trace,wire,errorToken,deliverMain,deliverWorklet,step,
    snapshot:()=>main.MOBILE_STREAM_TIMING?.snapshot(),setFrame:n=>{frame=n;wk.currentFrame=n}};
}
function run(diagnostic,failure,missingObserver=false){const s=setup(diagnostic,failure,missingObserver);let thrown=null;
  try{s.deliverWorklet();for(let i=0;i<100;i++)s.step(i===3)}catch(e){thrown=e}
  return {s,thrown};
}
for(const failure of [null,'mix','post','request','write']) {
  const a=run(false,failure),b=run(true,failure);
  assert.deepStrictEqual(b.s.trace,a.s.trace,'original PCM/message/mix trace '+failure);
  assert.strictEqual(a.thrown===a.s.errorToken,b.thrown===b.s.errorToken,'exception identity '+failure);
  assert.strictEqual(!!b.thrown,!!failure);
  tests.push('original_trace_and_exception_'+(failure||'normal'));
  if(!failure){const stats=b.s.snapshot();assert.equal(stats.begun,4);assert.equal(stats.acknowledged,4);
    assert.deepStrictEqual(Array.from(stats.rows,r=>r.seq),[1,33,65,97]);
    for(const cmd of ['read','chunk']){
      const wire=b.s.wire.filter(row=>row.cmd===cmd);
      assert.equal(wire.length,100);
      for(let i=0;i<wire.length;i++){
        assert.equal(wire[i].seq,i%32===0?i+1:null);
        assert.deepStrictEqual(wire[i].keys,i%32===0?['cmd','data','mobile_stream_timing']:['cmd','data']);
      }
    }
    for(const row of stats.rows){assert.equal(row.chunk_write_succeeded,true);assert.equal(row.mix_samples,256);
      assert(row.mix_end_ms>=row.mix_start_ms);assert(row.chunk_post_end_ms>=row.chunk_post_start_ms);
      assert.equal(row.chunk_receive_frame,row.request_frame);assert(row.chunk_ring_after_samples>row.chunk_ring_before_samples)}
    tests.push('sampled_read_chunk_correlations_and_timestamps');
  }
}
const a=run(false,null),b=run(true,null,true);assert.deepStrictEqual(b.s.trace,a.s.trace);
tests.push('missing_observer_keeps_original_audio');
const delayed=setup(true,null);delayed.deliverWorklet();delayed.step(false,480);
const delayedRow=delayed.snapshot().rows[0];
assert(Math.abs(delayedRow.roundtrip_audio_ms-10)<1e-9);
assert(Math.abs(delayedRow.worklet_to_main_ms_estimate-12)<1e-9);
assert.equal(delayedRow.chunk_receive_frame-delayedRow.request_frame,480);
tests.push('delayed_main_delivery_audio_clock_correlation');
const s=setup(true,null);s.deliverWorklet();for(let i=0;i<9000;i++)s.step();
let snap=s.snapshot();assert.equal(snap.rows.length,256);assert.equal(snap.pending.length,0);
for(let i=0;i<100;i++)s.main.MOBILE_STREAM_TIMING.begin({version:1,seq:1+i*32,request_frame:0,sample_rate:48000},
  {sampleRate:48000,currentTime:1,state:'running'},{});
snap=s.snapshot();assert.equal(snap.pending.length,64);assert.equal(snap.pending_evicted,36);
assert(snap.contexts.length<=16);tests.push('bounded_rows_pending_contexts');
const nativeError={raf:'original'};const receiver={native_receiver:true};let seen=null;
assert.equal(s.main.lastRAF,undefined,'observer does not schedule any own RAF');
assert.equal(s.main.requestAnimationFrame(function(t){seen=[this,t];return 91}),17);
assert.equal(s.main.lastRAF.call(receiver,8),91);assert.equal(seen[0],receiver);assert.equal(seen[1],8);
s.main.requestAnimationFrame(()=>{throw nativeError});assert.throws(()=>s.main.lastRAF(9),e=>e===nativeError);
assert.throws(()=>s.main.requestAnimationFrame(null),TypeError);
for(let i=0;i<1200;i++){s.main.requestAnimationFrame(()=>0);s.main.lastRAF(i)}
assert.equal(s.snapshot().raf.rows.length,1024);tests.push('raf_return_receiver_arguments_exception_and_bounds');
assert.equal(s.main.longTaskOptions.type,'longtask');
s.main.longTaskCallback({getEntries:()=>Array.from({length:300},(_,i)=>({entryType:'longtask',
  startTime:i,duration:75,name:'self'}))});
assert.equal(s.snapshot().long_tasks.total,300);assert.equal(s.snapshot().long_tasks.rows.length,128);
const isolated=s.snapshot();isolated.rows[0].seq=-1;
assert.notEqual(s.snapshot().rows[0].seq,-1);tests.push('longtask_bounds_and_snapshot_isolation');
const broken=setup(true,null);broken.main.MOBILE_STREAM_TIMING={begin(){throw nativeError},
  mark(){throw nativeError},ack(){throw nativeError}};
broken.deliverWorklet();for(let i=0;i<100;i++)broken.step(i===3);
assert.deepStrictEqual(broken.trace,a.s.trace);tests.push('throwing_observer_cannot_interrupt_original_audio');
// Unrelated original unknown-command errors are still reported, not swallowed.
s.main.GodotAudioWorklet.worklet.port.onmessage({data:{cmd:'unexpected',data:7}});
assert.deepStrictEqual(s.trace.at(-1),['error',{cmd:'unexpected',data:7}]);tests.push('unknown_command_path_retained');
process.stdout.write(JSON.stringify({passed:tests.length,failed:0,tests}));
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--wasm", required=True, type=Path)
    parser.add_argument("--worklet", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--prefix", default="stream-timing.engine")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--self-test-only", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*", args.prefix):
        parser.error("prefix must be one safe filename stem")
    engine, wasm, worklet = args.engine.read_bytes(), args.wasm.read_bytes(), args.worklet.read_bytes()
    guarded(wasm, WASM_SHA256, "official WASM")
    js, wk, counter = derive(engine, worklet)
    test = node_tests(engine, worklet, js, wk) if args.self_test or args.self_test_only else None
    receipt = {"version": "stream-timing-v1", "sample_every_successful_read": 32,
               "official_sha256": {"js": JS_SHA256, "wasm": WASM_SHA256, "worklet": WORKLET_SHA256},
               "counter_layer_sha256": hashlib.sha256(counter).hexdigest(),
               "restoration": "Exact reverse of timing insertions restores guarded official JS and pre-existing counter worklet; counter insertion itself reverses to guarded official worklet.",
               "node_tests": test,
               "scope": "Separate diagnostic output only; no PCM/data/read/chunk sizes, gain, graph, queue, playback or scheduling policy changes. 1/32 successful reads carry metadata; unsampled original messages unchanged. Synchronous out_callback span includes mixing/decoding, not isolated decoder cost. AudioContext/main comparisons are quantum-quantized estimates. Bounded observer RAF/LongTasks and pending/completed timing; no real browser/device verification."}
    if args.self_test_only:
        print(json.dumps(receipt, indent=2))
        return
    if args.output is None:
        parser.error("--output required unless --self-test-only")
    position = Path(str(args.worklet).replace(".audio.worklet.js", ".audio.position.worklet.js"))
    if position == args.worklet or not position.is_file():
        raise ValueError("Official adjacent audio.position.worklet.js is required")
    guarded(position.read_bytes(), POSITION_SHA256, "official position worklet")
    receipt["official_adjacent_position_sha256"] = POSITION_SHA256
    files = {args.prefix + ".js": js, args.prefix + ".wasm": wasm,
             args.prefix + ".audio.worklet.js": wk,
             args.prefix + ".audio.position.worklet.js": position.read_bytes(),
             "stream_timing_observer.js": (HERE / "stream_timing_observer.js").read_bytes()}
    args.output.mkdir(parents=True, exist_ok=False)
    for name, data in files.items():
        (args.output / name).write_bytes(data)
    receipt["files_sha256"] = {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}
    receipt["replacements"] = {"js": JS_REPLACEMENTS, "worklet_on_counter_layer": WORKLET_REPLACEMENTS}
    (args.output / "stream-timing-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"output": str(args.output), "node_tests": test,
                      "files_sha256": receipt["files_sha256"]}, indent=2))


if __name__ == "__main__":
    main()
