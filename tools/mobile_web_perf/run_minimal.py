"""Run fresh single/Multi-bus Web audio reproductions from the original main1b PCK.

No engine patch or export is performed. Each startup owns a new Chromium/Engine.
PCM recording is opt-in, exactly two seconds, and saved as actual mixed WAV.
"""
from __future__ import annotations

import argparse
import array
import asyncio
import base64
import functools
import hashlib
import http.server
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
import traceback
import wave

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/mobile_web_perf"))
from check_web_bundle import Pack
from build_probe import write_pack
from playwright.async_api import async_playwright

PACK_SHA = "618eb97114e6715fc33856823c9bf23141e8e51802a886596bc9f223ed7ca691"
GAME_AUDIO_SHA = "e08004d5fea8ddce976088dc64af43a0b2f3bdb2fb428a8699d25bd66c9e4609"
ENGINE = "index.d20938d2db49.engine"
SCENE = b'''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://minimal_audio_repro.gd" id="1"]
[node name="MinimalAudioRepro" type="Node"]
script = ExtResource("1")
'''

RECORDER_INIT = r"""(() => {
 window.MINIMAL_PCM_TAPS=[];window.MINIMAL_PCM_READY={};window.MINIMAL_PCM_RECORDINGS={};
 window.MINIMAL_REPRO_RESULTS=[];
 window.MOBILE_AUDIO_PROBE_WORKLET_URL=new URL('minimal_pcm_worklet.js',location.href).href;
 const Original=window.AudioWorkletNode;
 window.AudioWorkletNode=new Proxy(Original,{construct(target,args,newTarget){
  const node=Reflect.construct(target,args,newTarget);
  if(args[1]==='mobile-web-perf-pcm'){
   window.MINIMAL_PCM_TAPS.push(node);
   node.port.addEventListener('message',event=>{
    if(event.data?.cmd==='minimal_ready'){
     event.stopImmediatePropagation();window.MINIMAL_PCM_READY[event.data.id]=true;
    }else if(event.data?.cmd==='minimal_recording'){
     event.stopImmediatePropagation();window.MINIMAL_PCM_RECORDINGS[event.data.id]=event.data;
    }
   });node.port.start();
  }return node;
 }});
})();"""


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_bundle(folder: Path, original: Path) -> dict:
    assert digest(original) == PACK_SHA, "Wrong baseline PCK"
    source_audio = subprocess.check_output([
        "git", "show", "1b29932c5333a9dad50759afc635762163ed79f5:game/presentation/audio/game_audio.gd"
    ], cwd=ROOT)
    assert hashlib.sha256(source_audio).hexdigest() == GAME_AUDIO_SHA
    pack = Pack(original)
    folder.mkdir(parents=True)
    replacements = {
        "game/application/demo.tscn": SCENE,
        "scenes/demo/demo.tscn.remap": b'[remap]\n\npath="res://minimal_audio_repro.tscn"\n',
        "minimal_audio_repro.tscn": SCENE,
        "minimal_audio_repro.gd": (ROOT / "tools/mobile_web_perf/minimal_audio_repro.gd").read_bytes(),
    }
    write_pack(pack, replacements, set(), folder / "diagnostic.pck")
    hashes = {}
    for suffix in [".js", ".wasm", ".audio.worklet.js", ".audio.position.worklet.js"]:
        source = ROOT / "build/web" / (ENGINE + suffix)
        target = folder / source.name
        target.symlink_to(source.resolve())
        hashes[source.name] = digest(source)
    for name in ["audio_graph_probe.js", "audio_probe.js", "minimal_pcm_worklet.js"]:
        shutil.copyfile(ROOT / "tools/mobile_web_perf" / name, folder / name)
    (folder / "minimal_audio_repro.gd.source").write_bytes(replacements["minimal_audio_repro.gd"])
    (folder / "index.html").write_text(
        '<!doctype html><meta charset="utf-8"><style>body{margin:0;background:#111}canvas{width:640px;height:360px}</style>'
        '<script src="audio_graph_probe.js"></script><script src="audio_probe.js"></script>'
        '<canvas id="canvas" width="640" height="360"></canvas><script src="' + ENGINE + '.js"></script>'
        '<script>const engine=new Engine({canvasResizePolicy:2,executable:' + json.dumps(ENGINE) +
        ',mainPack:"diagnostic.pck",focusCanvas:true,ensureCrossOriginIsolationHeaders:false});'
        'engine.startGame().then(()=>window.READY=true).catch(e=>console.error(e));</script>'
    )
    receipt = {
        "original_pck": str(original), "original_pck_sha256": PACK_SHA,
        "diagnostic_pck_sha256": digest(folder / "diagnostic.pck"),
        "replacements": {name: hashlib.sha256(raw).hexdigest() for name, raw in replacements.items()},
        "removed_entries": [], "original_game_audio_source_sha256": GAME_AUDIO_SHA,
        "original_game_audio_gdc_sha256": hashlib.sha256(pack.read("scripts/audio/game_audio.gdc")).hexdigest(),
        "engine_original_hashes": hashes,
        "probe_hashes": {name: digest(folder / name) for name in ["audio_graph_probe.js", "audio_probe.js", "minimal_pcm_worklet.js"]},
        "scope": "Only minimal entry scene/remap/script added or replaced; original imported audio and GameAudio.gdc retained; official engine/buses unmodified.",
    }
    (folder / "build-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


def pcm_wav(encoded: str, metadata: dict, path: Path) -> dict:
    raw = base64.b64decode(encoded)
    values = array.array("f")
    values.frombytes(raw)
    if sys.byteorder != "little": values.byteswap()
    channels = metadata["channels"]
    frames = metadata["frames"]
    assert len(values) == channels * frames
    nonzero = [i for i in range(frames) if any(values[i * channels + ch] != 0 for ch in range(channels))]
    peak = max(map(abs, values), default=0)
    pcm = array.array("h", (round(max(-1, min(1, value)) * 32767) for value in values))
    if sys.byteorder != "little": pcm.byteswap()
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(channels); wav.setsampwidth(2); wav.setframerate(metadata["sample_rate"])
        wav.writeframes(pcm.tobytes())
    return {
        **metadata, "wav": str(path), "wav_sha256": digest(path),
        "raw_float32_sha256": hashlib.sha256(raw).hexdigest(),
        "encoding": "PCM16 WAV converted from actual mixed Float32; original destination connection retained",
        "peak_float32": peak, "rms_float32": (sum(value * value for value in values) / max(1, len(values))) ** .5,
        "nonzero_frames": len(nonzero), "nonzero_span_frames": nonzero[-1] - nonzero[0] + 1 if nonzero else 0,
        "first_nonzero_frame": nonzero[0] if nonzero else None,
        "last_nonzero_frame": nonzero[-1] if nonzero else None,
        "clipped_samples": sum(abs(value) >= 1 for value in values),
    }


async def run_startup(playwright, base_url: str, startup: str, folder: Path) -> dict:
    folder.mkdir()
    result = {"startup": startup, "cases": [], "console": [], "page_errors": []}
    browser = await playwright.chromium.launch(executable_path="/usr/bin/chromium", headless=True,
        args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
    result["browser_pid_scope"] = "Fresh independent Chromium launch, closed before next startup"
    try:
        context = await browser.new_context(viewport={"width": 640, "height": 360})
        await context.add_init_script(RECORDER_INIT)
        page = await context.new_page()
        page.on("console", lambda message: result["console"].append(message.type + ": " + message.text))
        page.on("pageerror", lambda error: result["page_errors"].append(str(error)))
        await page.goto(base_url + "/index.html?startup=" + startup, wait_until="domcontentloaded")
        await page.wait_for_function("window.READY && window.MINIMAL_REPRO_READY", timeout=120000)
        await page.locator("canvas").click(position={"x": 100, "y": 100})
        await page.wait_for_function("window.MINIMAL_PCM_TAPS.length>0 && window.MINIMAL_PCM_TAPS[0].context.state==='running'", timeout=30000)
        await page.wait_for_timeout(350)
        result["initial_state"] = await page.evaluate("window.MINIMAL_REPRO_STATE")
        result["initial_audio"] = await page.evaluate("window.MOBILE_AUDIO_PROBE.snapshot()")
        result["initial_graph"] = await page.evaluate("window.MOBILE_AUDIO_GRAPH_PROBE.snapshot()")
        assert len(result["initial_state"]["buses"]) == (1 if startup == "single" else 5)
        await page.screenshot(path=str(folder / "minimal-scene.png"))
        cases = [("sample_once", 2, "none"), ("stream_once", 1, "none")]
        if startup == "single": cases += [("pause_none", 2, "none"),
            ("pause_always_false", 2, "always_false"), ("pause_guard_false", 2, "guard_false")]
        for case_id, playback, policy in cases:
            await page.wait_for_timeout(200)
            before = await page.evaluate("({audio:window.MOBILE_AUDIO_PROBE.snapshot(),graph:window.MOBILE_AUDIO_GRAPH_PROBE.snapshot()})")
            await page.evaluate("id=>window.MINIMAL_PCM_TAPS[0].port.postMessage({cmd:'minimal_begin',id,frames:Math.round(window.MINIMAL_PCM_TAPS[0].context.sampleRate*2)})", case_id)
            await page.wait_for_function("id=>window.MINIMAL_PCM_READY[id]===true", arg=case_id, timeout=5000)
            command = {"action": "play", "id": case_id, "playback_type": playback, "pause_policy": policy}
            await page.evaluate("c=>window.MINIMAL_REPRO_COMMAND=JSON.stringify(c)", command)
            await page.wait_for_function("id=>window.MINIMAL_REPRO_CASE_STARTED===id", arg=case_id, timeout=5000)
            await page.wait_for_function("id=>!!window.MINIMAL_PCM_RECORDINGS[id]", arg=case_id, timeout=10000)
            after = await page.evaluate("({audio:window.MOBILE_AUDIO_PROBE.snapshot(),graph:window.MOBILE_AUDIO_GRAPH_PROBE.snapshot()})")
            captured = await page.evaluate("""id=>{
              const r=window.MINIMAL_PCM_RECORDINGS[id],data=new Uint8Array(r.samples.buffer);
              let text='';for(let i=0;i<data.length;i+=16384)text+=String.fromCharCode(...data.subarray(i,i+16384));
              return {base64:btoa(text),metadata:{sample_rate:r.sample_rate,channels:r.channels,frames:r.frames,start_audio_frame:r.start_audio_frame,end_audio_frame:r.end_audio_frame}};
            }""", case_id)
            pcm = pcm_wav(captured["base64"], captured["metadata"], folder / (case_id + ".wav"))
            await page.evaluate("window.MINIMAL_REPRO_COMMAND=JSON.stringify({action:'finish'})")
            await page.wait_for_function("id=>window.MINIMAL_REPRO_RESULTS.some(r=>r.id===id)", arg=case_id, timeout=5000)
            gd = await page.evaluate("id=>window.MINIMAL_REPRO_RESULTS.find(r=>r.id===id)", case_id)
            row = {"id": case_id, "command": command, "gdscript": gd, "pcm": pcm,
                "audio_before": before["audio"], "audio_after": after["audio"],
                "graph_before": before["graph"], "graph_after": after["graph"],
                "native_delta": {name: after["audio"]["native_" + name + "_total"] - before["audio"]["native_" + name + "_total"] for name in ["created", "starts", "ended", "stops"]}}
            result["cases"].append(row)
            (folder / "report.json").write_text(json.dumps(result, indent=2) + "\n")
            print(json.dumps({"startup": startup, "case": case_id, "native": row["native_delta"],
                "nonzero_frames": pcm["nonzero_frames"], "peak": pcm["peak_float32"],
                "gd_frames": gd["process_frames"], "finished": sum(e["kind"] == "finished" for e in gd["events"])}), flush=True)
        assert not result["page_errors"], result["page_errors"]
        assert not any(any(marker in line for marker in ["SCRIPT ERROR", "Parse Error", "Failed loading resource"]) for line in result["console"]), result["console"]
        result["status"] = "completed"
    except Exception:
        result["status"] = "failed"
        result["failure"] = traceback.format_exc()
        raise
    finally:
        (folder / "report.json").write_text(json.dumps(result, indent=2) + "\n")
        (folder / "browser.log").write_text("\n".join(result["console"]) + "\n")
        await browser.close()
    return result


async def run(args) -> int:
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
    number = 1
    while (output / f"attempt-{number:02}").exists(): number += 1
    attempt = output / f"attempt-{number:02}"; attempt.mkdir()
    report = {"scope": "Original-engine minimal actual Web/PCM reproduction; synthetic coin, not gameplay or physical-device acceptance", "attempt": number}
    server = None
    try:
        report["build"] = build_bundle(attempt / "bundle", args.original.resolve())
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(attempt / "bundle"))
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base_url = f"http://127.0.0.1:{server.server_port}"
        report["startups"] = []
        async with async_playwright() as playwright:
            for startup in ["single", "multi"]:
                report["startups"].append(await run_startup(playwright, base_url, startup, attempt / startup))
        report["status"] = "completed"
        report["engine_hashes_after"] = {name: digest(ROOT / "build/web" / name) for name in report["build"]["engine_original_hashes"]}
        assert report["engine_hashes_after"] == report["build"]["engine_original_hashes"]
    except Exception:
        report["status"] = "failed"; report["failure"] = traceback.format_exc()
    finally:
        if server: server.shutdown(); server.server_close()
        (attempt / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "report": str(attempt / "report.json"), "failure": report.get("failure")}), flush=True)
    return 0 if report["status"] == "completed" else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "build/mobile_web_perf_01/minimal-01")
    parser.add_argument("--original", type=Path, default=Path("/workspace/scratch/gunman-audio-diagnosis/index.618eb97114e6.pck"))
    raise SystemExit(asyncio.run(run(parser.parse_args())))
