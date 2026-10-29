"""Real exported game, ordinary touch input and browser-only PCM observation.

No GDScript patches, debug scene routing or playback-policy overrides. Cloud
SwiftShader output is not physical-device or long-duration music acceptance.
"""
import argparse
import asyncio
import hashlib
import json
from math import gcd
from pathlib import Path
import sys
import urllib.request

from playwright.async_api import async_playwright
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from verify_mobile_ui_clarity_browser import fitted_rect, surfaces
from verify_forest_browser import environment_proxy, locate_original
from run_minimal import RECORDER_INIT, pcm_wav
from analyze_formal_pcm import matched_filter, read_wav, template_path


async def run(args):
    args.output.mkdir(parents=True, exist_ok=False)
    with urllib.request.urlopen(args.root_url + 'build-info.json', timeout=90) as response:
        info = json.load(response)
    assert info['build_id'] == args.expected_build, info
    assert info['source_commit'] == args.expected_source, info
    report = {'build_info': info, 'url': args.root_url, 'results': [],
        'scope': 'Unchanged official PCK with browser-only observation; native touch jump/shoot and actual Home menu Explore. No FPS/device/complete BGM continuity acceptance.'}
    logs = []
    def save():
        (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        (args.output / 'browser.log').write_text('\n'.join(logs))
    async with async_playwright() as playwright:
        options = {'proxy': environment_proxy()[0]} if args.proxy_from_environment else {}
        browser = await playwright.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'], **options)
        context = await browser.new_context(viewport={'width':853,'height':290}, device_scale_factor=2.5,
            is_mobile=True, has_touch=True)
        # One ordered init script. A worker fetch can bypass Playwright routing
        # once the real cache worker controls this page, so use an opt-in blob
        # for the observer alone; official engine worklets remain unmodified.
        recorder = (ROOT / 'tools/mobile_web_perf/formal_pcm_worklet.js').read_text()
        init = RECORDER_INIT + '\nwindow.MOBILE_AUDIO_PROBE_WORKLET_URL=URL.createObjectURL(new Blob([' + json.dumps(recorder) + '],{type:"application/javascript"}));\n'
        init += (ROOT / 'tools/mobile_web_perf/audio_graph_probe.js').read_text()
        init += '\n' + (ROOT / 'tools/mobile_web_perf/audio_probe.js').read_text()
        if args.expect_threaded_root:
            from prepare_threaded_diagnostic import SHARED_OBSERVER
            init += '\n' + SHARED_OBSERVER
        await context.add_init_script(init)
        page = await context.new_page()
        def log(value):
            logs.append(value)
            (args.output / 'browser.log').write_text('\n'.join(logs))
        page.on('console', lambda message: log(message.type + ': ' + message.text))
        page.on('pageerror', lambda error: log('PAGE ERROR: ' + str(error)))
        cdp = await context.new_cdp_session(page)
        try:
            entry='audio-threaded/' if args.threaded else ''
            await page.goto(args.root_url + entry + ('?audio_probe=1' if args.selected_sfx else ''), wait_until='domcontentloaded')
            ready='window.THREADED_DIAGNOSTIC_READY===true' if args.threaded else 'window.PLAYTEST_LOADING_DONE===true'
            await page.wait_for_function(ready, timeout=180000)
            await page.wait_for_timeout(2000)
            await page.screenshot(path=str(args.output / 'title.png'))
            primary = surfaces(args.output / 'title.png', [(195,163,102)])[0]
            await page.touchscreen.tap((primary[0]+primary[2]/2)/2.5, (primary[1]+primary[3]/2)/2.5)
            await page.wait_for_timeout(6000)
            await page.wait_for_function("window.MINIMAL_PCM_TAPS.length>0 && window.MINIMAL_PCM_TAPS[0].context.state==='running'", timeout=30000)
            if args.threaded or args.expect_threaded_root:
                threaded=await page.evaluate('window.MOBILE_THREADED_DIAGNOSTIC.snapshot()')
                assert threaded['cross_origin_isolated'] and threaded['threads'] and threaded['shared_ring_observed'],threaded
                report['threaded_start']=threaded
            if args.selected_sfx:
                await page.wait_for_function("window.SELECTED_SFX_SNAPSHOT?.validation_ok===true", timeout=15000)
                selection = await page.evaluate('window.SELECTED_SFX_SNAPSHOT')
                expected = json.loads((ROOT/'config/audio_director/selected/selected.json').read_text())['event_profiles']
                assert selection['audio_profile']=='selected' and selection['event_profiles']==expected, selection
                report['selected_sfx_start'] = selection
            for scene in ('home', 'plains'):
                if scene == 'plains':
                    await page.touchscreen.tap(*point(1202,42))
                    await page.wait_for_timeout(2000)
                    await page.screenshot(path=str(args.output / 'home-menu.png'))
                    explore = locate_original(args.output / 'home-menu.png', 'Explore')
                    await page.touchscreen.tap(explore[0]/2.5, explore[1]/2.5)
                    await page.wait_for_timeout(8000)
                await page.screenshot(path=str(args.output / (scene + '.png')))
                rect = fitted_rect(args.output / (scene + '.png'))
                def point(x,y):
                    return ((rect[0]+rect[2]*x/1280)/2.5, (rect[1]+rect[3]*y/720)/2.5)
                jump = point(1140,606)
                right = point(950,606)
                drag = point(1004,606)
                before = await page.evaluate('({audio:window.MOBILE_AUDIO_PROBE.snapshot(),graph:window.MOBILE_AUDIO_GRAPH_PROBE.snapshot()})')
                await page.evaluate("id=>window.MINIMAL_PCM_TAPS[0].port.postMessage({cmd:'minimal_begin',id,frames:Math.round(window.MINIMAL_PCM_TAPS[0].context.sampleRate*8)})", scene)
                await page.wait_for_function('id=>window.MINIMAL_PCM_READY[id]===true', arg=scene, timeout=8000)
                await page.touchscreen.tap(*jump)
                await page.wait_for_timeout(650)
                await cdp.send('Input.dispatchTouchEvent', {'type':'touchStart','touchPoints':[{'id':11,'x':right[0],'y':right[1]}]})
                await cdp.send('Input.dispatchTouchEvent', {'type':'touchMove','touchPoints':[{'id':11,'x':drag[0],'y':drag[1]}]})
                await page.wait_for_timeout(450)
                await cdp.send('Input.dispatchTouchEvent', {'type':'touchEnd','touchPoints':[]})
                await page.wait_for_function('id=>!!window.MINIMAL_PCM_RECORDINGS[id]', arg=scene, timeout=20000)
                raw = await page.evaluate("""id=>{const r=window.MINIMAL_PCM_RECORDINGS[id],data=new Uint8Array(r.samples.buffer);let text='';for(let i=0;i<data.length;i+=32768)text+=String.fromCharCode(...data.subarray(i,i+32768));return {base64:btoa(text),metadata:{sample_rate:r.sample_rate,channels:r.channels,frames:r.frames,begin_audio_frame:r.start_audio_frame,end_audio_frame:r.end_audio_frame}}}""", scene)
                wav = pcm_wav(raw['base64'], raw['metadata'], args.output / (scene + '-actions.wav'))
                after = await page.evaluate('({audio:window.MOBILE_AUDIO_PROBE.snapshot(),graph:window.MOBILE_AUDIO_GRAPH_PROBE.snapshot()})')
                rate, audio = read_wav(args.output / (scene + '-actions.wav'))
                matches = []
                for kind in ('jump', 'pulse'):
                    variants = [0] if args.selected_sfx and kind=='pulse' else range(3)
                    for variant in variants:
                        path = ROOT/'assets/audio/director_v3/shot_pulse_a.wav' if args.selected_sfx and kind=='pulse' else template_path(kind,variant)
                        sr, source = read_wav(path)
                        divisor = gcd(rate,sr)
                        template = resample_poly(source,rate//divisor,sr//divisor)
                        fit = matched_filter(audio, template, rate)['best_positive_gain_match']
                        fit.update(kind=kind, variant=variant, source_path=str(path.relative_to(ROOT)), source_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
                        fit['absolute_audio_seconds'] = (wav['begin_audio_frame']+fit['offset_frames'])/rate
                        fit['closest_native_start_delta_ms'] = min(abs(fit['absolute_audio_seconds']-s['audio_seconds'])*1000 for s in after['audio']['native_starts'])
                        matches.append(fit)
                row = {'scene':scene,'before':before,'after':after,'pcm':wav,'matches':matches,
                    'input':{'jump':jump,'right':right,'drag_to':drag},
                    'scope':'full-template matches must also align with native source time; mixed PCM alone is not asset identification'}
                if args.selected_sfx:
                    row['selected_sfx_after'] = await page.evaluate('window.SELECTED_SFX_SNAPSHOT')
                    assert any(e.get('candidate')=='shot_pulse_a' for e in row['selected_sfx_after']['director_events']), row['selected_sfx_after']
                report['results'].append(row)
                save()
                print(json.dumps({'scene':scene,'best':{kind:max((m for m in matches if m['kind']==kind),key=lambda m:m['rho']) for kind in ('jump','pulse')}}), flush=True)
            assert not any(any(error in line for error in ('SCRIPT ERROR:', 'SHADER ERROR:', 'PAGE ERROR:', 'Parse Error:')) for line in logs), logs
            report['status'] = 'captured_review_matches_separately'
        finally:
            save()
            await browser.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root-url', required=True)
    parser.add_argument('--expected-build', required=True)
    parser.add_argument('--expected-source', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--proxy-from-environment', action='store_true')
    parser.add_argument('--selected-sfx', action='store_true')
    parser.add_argument('--threaded', action='store_true')
    parser.add_argument('--expect-threaded-root', action='store_true', help='Observe shared audio ring in ordinary production entry without changing its worklet')
    asyncio.run(run(parser.parse_args()))
