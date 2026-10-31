"""Bounded, real-GUI Web frame captures for MOBILE-WEB-FPS-04.

Run only one browser/engine measurement at a time. The same ordinary title,
Home navigation RUN SEED field and Explore button are used for vanilla and
instrumented packages. No game-state writes, audio taps or GPU readbacks run
during a timing window. Cloud SwiftShader measurements are not phone FPS.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
from pathlib import Path
import statistics
import sys
import time

from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from verify_mobile_ui_clarity_browser import fitted_rect, surfaces
from verify_forest_browser import environment_proxy, locate_original

VIEWPORT = {'width': 853, 'height': 290}
DPR = 2.5
FRAME_OBSERVER = r'''(() => {
    let active = false, previous = null, first = null, begin = null, frames = [], tasks = [];
    let callbacks = 0, closeRequested = null, closeResolve = null, closeTimer = null;
    let overflow = false;
    const limit = 50000;
    const takeTasks = entries => {
        if (!active) return;
        for (const e of entries) {
            if (e.startTime >= begin) {
                if (tasks.length < limit) tasks.push([e.startTime, e.duration]);
                else overflow = true;
            }
        }
    };
    let observer = null, observerError = null;
    try {
        observer = new PerformanceObserver(list => takeTasks(list.getEntries()));
        observer.observe({entryTypes: ['longtask']});
    } catch (e) { observerError = String(e); }
    function finish(closedOnRaf) {
        if (!active || closeResolve === null) return;
        if (observer) takeTasks(observer.takeRecords());
        const end = performance.now();
        const result = {observer_schema:3,begin_ms:begin,end_requested_ms:closeRequested,end_ms:end,
            elapsed_ms:end-begin,first_raf_ms:first,last_raf_ms:previous,
            raf_callback_count:callbacks,closed_on_raf:closedOnRaf,
            close_timeout_ms:30000,frames,long_tasks:tasks,overflow,
            long_task_observer_error:observerError,
            scope:'RAF closure requested after the observation window and resolved by this observer only after recording a RAF timestamp at or after that request. Already-queued stale RAF timestamps do not close the window. Wall time, RAF-covered span and boundary gaps are separate. LongTasks are browser main-thread tasks, not GPU time.'};
        active = false;
        if (closeTimer !== null) clearTimeout(closeTimer);
        const resolve = closeResolve;
        closeResolve = null; closeTimer = null;
        resolve(result);
    }
    function frame(now) {
        if (active && now >= begin) {
            if (previous !== null) {
                if (frames.length < limit) frames.push([previous, now, now - previous]);
                else overflow = true;
            } else first = now;
            previous = now;
            callbacks += 1;
            // A queued callback delivered after a stall can still carry the
            // pre-stall RAF timestamp. Keep it, then wait for a timestamp at
            // or after the close request so the pending long interval lands
            // in the sample. A separate end RAF has ordering ambiguity too.
            if (closeRequested !== null && now >= closeRequested) finish(true);
        }
        requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
    window.FPS04_BROWSER = {
        begin() {
            if (active) throw new Error('Overlapping browser measurement');
            if (observer) observer.takeRecords();
            previous = null; first = null; callbacks = 0;
            closeRequested = null; closeResolve = null; closeTimer = null;
            frames = []; tasks = []; overflow = false;
            begin = performance.now(); active = true;
            return begin;
        },
        end() {
            if (!active) throw new Error('No active browser measurement');
            if (closeRequested !== null) throw new Error('Browser closure already requested');
            closeRequested = performance.now();
            return new Promise(resolve => {
                closeResolve = resolve;
                // Preserve incomplete samples rather than silently dropping a
                // pending interval if RAF stops. Python rejects this outcome.
                closeTimer = setTimeout(() => finish(false), 30000);
            });
        }
    };
})();'''


def percentile(values, quantile):
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * quantile)] if ordered else None


def browser_summary(capture):
    frames = capture['frames']
    durations = [row[2] for row in frames]
    measured_ms = frames[-1][1] - frames[0][0] if frames else 0.0
    elapsed = capture['elapsed_ms']
    callbacks = capture.get('raf_callback_count', len(frames) + 1 if frames else 0)
    first = capture.get('first_raf_ms', frames[0][0] if frames else None)
    last = capture.get('last_raf_ms', frames[-1][1] if frames else None)
    begin = capture.get('begin_ms')
    end = capture.get('end_ms')
    first_offset = first - begin if first is not None and begin is not None else None
    initial_gap = max(0.0, first - begin) if first is not None and begin is not None else None
    final_gap = max(0.0, end - last) if last is not None and end is not None else None
    covered_within_window = max(0.0, min(last, end) - max(first, begin)) \
        if all(value is not None for value in (first, last, begin, end)) else measured_ms
    return {
        'intervals': len(frames), 'sampled_interval_ms': measured_ms,
        'wall_capture_ms': elapsed, 'raf_callbacks': callbacks,
        'raf_callback_count_source': 'recorded' if 'raf_callback_count' in capture else
            ('legacy_n_plus_one_inferred_from_nonempty_interval_list' if frames else 'unknown_no_intervals'),
        'observed_window_fps': callbacks * 1000 / elapsed if elapsed else None,
        'completed_interval_fps': len(frames) * 1000 / measured_ms if measured_ms else None,
        'interval_span_within_window_ms': covered_within_window,
        'interval_coverage_fraction': covered_within_window / elapsed if elapsed else None,
        'first_raf_minus_begin_ms': first_offset,
        'prewindow_raf_timestamp_overlap_ms': max(0.0, -first_offset) if first_offset is not None else None,
        'initial_uncovered_ms': initial_gap, 'final_uncovered_ms': final_gap,
        'total_uncovered_ms': max(0.0, elapsed - covered_within_window),
        'closed_on_raf': capture.get('closed_on_raf', False),
        'close_raf_minus_request_ms': last - capture['end_requested_ms']
            if last is not None and capture.get('end_requested_ms') is not None else None,
        'closure_after_request_ms': end - capture['end_requested_ms']
            if end is not None and capture.get('end_requested_ms') is not None else None,
        'p50_ms': percentile(durations, .50), 'p95_ms': percentile(durations, .95),
        'max_ms': max(durations, default=None),
        'long_task_count': len(capture['long_tasks']),
        'long_task_total_ms': sum(row[1] for row in capture['long_tasks']),
        'long_task_max_ms': max((row[1] for row in capture['long_tasks']), default=0),
        'rate_formulas': {
            'observed_window_fps': 'RAF callbacks observed / full actual wall capture duration; callback throughput, not proof of GPU presentation',
            'completed_interval_fps': 'complete consecutive RAF intervals / their covered RAF timestamp span; must be read with coverage and uncovered boundary gaps',
        },
    }


def native_summary(row):
    frames = row['frames']
    count = len(frames)
    elapsed = row['elapsed_msec']
    result = {'frames': count, 'elapsed_ms': elapsed,
              'fps': count * 1000 / elapsed if elapsed else None,
              'frame_p50_ms': percentile([f[0] for f in frames], .5),
              'frame_p95_ms': percentile([f[0] for f in frames], .95)}
    for name, column in [('process', 1), ('physics', 2)]:
        result[name + '_p50_ms'] = percentile([f[column] for f in frames], .5)
        result[name + '_p95_ms'] = percentile([f[column] for f in frames], .95)
    for name, column in [('draw_calls', 3), ('objects', 4), ('primitives', 5)]:
        result[name + '_mean'] = statistics.mean(f[column] for f in frames) if frames else None
    result['inclusive_costs'] = sorted([
        {'method': key, 'calls': value[1], 'total_ms': value[0] / 1000,
         'ms_per_frame': value[0] / 1000 / count if count else None,
         'ms_per_call': value[0] / 1000 / value[1] if value[1] else None,
         'max_ms': value[2] / 1000}
        for key, value in row.get('costs', {}).items()
    ], key=lambda item: -item['total_ms'])
    result['scope'] = 'Godot monitors and instrumented inclusive wrappers; nested costs must not be added. Native capture is a separately timestamped subset of the encompassing browser window.'
    return result


def identity(path):
    if path is None:
        return None
    data = path.read_bytes()
    return {'path': str(path.resolve()), 'sha256': hashlib.sha256(data).hexdigest(),
            'contents': json.loads(data)}


def region_events(logs):
    events = []
    for line in logs:
        if 'FOREST_UI_EVENT ' in line:
            event = json.loads(line.split('FOREST_UI_EVENT ', 1)[1])
            if event.get('event') == 'region_assembled':
                events.append(event)
    return events


async def canvas_state(page):
    # The renderer query is outside all timing windows; no timer/readback/finish.
    return await page.locator('canvas').evaluate('''c => {
        const r = c.getBoundingClientRect(), gl = c.getContext('webgl2');
        const ext = gl ? gl.getExtension('WEBGL_debug_renderer_info') : null;
        return {width:c.width,height:c.height,css:{x:r.x,y:r.y,width:r.width,height:r.height},
            dpr:devicePixelRatio,isolated:crossOriginIsolated,
            renderer:gl ? gl.getParameter(ext ? ext.UNMASKED_RENDERER_WEBGL : gl.RENDERER) : null,
            gpu_time_ms:null,gpu_time_scope:'Not measured; FPS is not GPU time.'};
    }''')


async def run(args):
    args.output.mkdir(parents=True, exist_ok=False)
    logs, errors, rows = [], [], []
    report = {
        'status': 'running', 'label': args.label, 'url': args.url,
        'identity': identity(args.identity_json), 'seed': args.seed,
        'instrumented': args.profile, 'viewport_css': VIEWPORT, 'device_scale_factor': DPR,
        'seconds_requested': args.seconds, 'warm_seconds': args.warm_seconds,
        'repeats_per_scene': args.repeats, 'rows': rows,
        'scope': 'Cloud Chromium SwiftShader; actual exported demo GUI and native RUN SEED input. No phone FPS, hardware-GPU timing, complete gameplay or audio-output acceptance.',
        'browser_observer': {'script_sha256': hashlib.sha256(FRAME_OBSERVER.encode()).hexdigest(),
            'overhead': 'One RAF callback; array append only while active; LongTask observer. Same in vanilla and instrumented groups; not zero-overhead.'},
        'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    }

    def save():
        report['logs'] = list(logs)
        report['page_errors'] = list(errors)
        (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        (args.output / 'browser.log').write_text('\n'.join(logs + errors) + '\n')

    def log(value):
        logs.append(value)
        (args.output / 'browser.log').write_text('\n'.join(logs + errors) + '\n')

    save()
    async with async_playwright() as playwright:
        options = {'proxy': environment_proxy()[0]} if args.proxy_from_environment else {}
        browser = await playwright.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'], **options)
        context = await browser.new_context(viewport=VIEWPORT, device_scale_factor=DPR,
                                            is_mobile=True, has_touch=True)
        await context.add_init_script(FRAME_OBSERVER)
        page = await context.new_page()
        page.set_default_timeout(30000)
        page.on('console', lambda message: log(message.type + ': ' + message.text))
        page.on('pageerror', lambda error: errors.append('PAGE ERROR: ' + str(error)))
        started = time.monotonic()

        async def shot(name):
            path = args.output / (name + '.png')
            await page.screenshot(path=str(path), timeout=30000)
            return path

        async def profile_state():
            return await page.evaluate('window.FPS04_STATE ?? null') if args.profile else None

        try:
            await page.goto(args.url, wait_until='domcontentloaded', timeout=60000)
            await page.wait_for_function(args.ready_expression, timeout=180000)
            if args.profile:
                await page.wait_for_function('window.FPS04_READY===true', timeout=30000)
            report['served_metadata'] = await page.evaluate('''async () => {
                try { const r = await fetch(new URL('build-info.json',location.href), {cache:'no-store'});
                    return r.ok ? await r.json() : {unavailable_http_status:r.status};
                } catch(e) {return {unavailable_error:String(e)};}
            }''')
            await page.wait_for_timeout(1500)
            title = await shot('title')
            buttons = surfaces(title, [(195, 163, 102)])
            assert buttons, 'No real title Start button surface'
            button = buttons[0]
            await page.touchscreen.tap((button[0]+button[2]/2)/DPR, (button[1]+button[3]/2)/DPR)
            await page.wait_for_timeout(6000)
            if args.profile:
                await page.wait_for_function("window.FPS04_STATE?.context==='home'", timeout=45000)
            home_shot = await shot('home-entry')
            assert not surfaces(home_shot, [(195, 163, 102)]), 'Start did not leave title'
            rect = fitted_rect(home_shot)

            def point(x, y):
                return (rect[0] + rect[2]*x/1280)/DPR, (rect[1] + rect[3]*y/720)/DPR

            async def measure(scene, repeat):
                await page.wait_for_timeout(args.warm_seconds * 1000)
                before = await profile_state()
                if args.profile:
                    assert before['context'] == scene, before
                canvas = await canvas_state(page)
                assert canvas['dpr'] == DPR and canvas['isolated'], canvas
                native = None
                if args.profile:
                    sequence = await page.evaluate('''seconds => {
                        if (window.FPS04_COMMAND) throw new Error('Pending native command');
                        const n=window.FPS04_RESULTS.length;
                        window.FPS04_SECONDS=seconds;
                        window.FPS04_BROWSER.begin();
                        window.FPS04_COMMAND='capture';
                        return n;
                    }''', args.seconds)
                    await page.wait_for_function("window.FPS04_COMMAND===''", timeout=20000)
                    await page.wait_for_function('n => window.FPS04_RESULTS.length > n', arg=sequence,
                                                 timeout=int((args.seconds+30)*1000))
                    capture = await page.evaluate('window.FPS04_BROWSER.end()')
                    native = await page.evaluate('window.FPS04_RESULTS.at(-1)')
                    assert native['initial']['context'] == native['final']['context'] == scene, native
                    assert native['frames'] and native['elapsed_msec'] > 0, native
                else:
                    await page.evaluate('window.FPS04_BROWSER.begin()')
                    await page.wait_for_timeout(args.seconds * 1000)
                    capture = await page.evaluate('window.FPS04_BROWSER.end()')
                row = {'scene': scene, 'repeat': repeat, 'canvas': canvas,
                       'profile_before': before, 'profile_after': await profile_state(),
                       'browser': capture, 'browser_summary': browser_summary(capture),
                       'native': native, 'native_summary': native_summary(native) if native else None,
                       'input': 'Idle at real entry spawn; no movement, teleport, pause or injected cue during capture.'}
                rows.append(row)
                save()
                assert capture['closed_on_raf'], 'Capture did not close on RAF; incomplete raw sample retained'
                assert not capture['overflow'] and len(capture['frames']) >= 2, capture
                await shot(f'{scene}-{repeat}-after')
                print(json.dumps({'scene': scene, 'repeat': repeat,
                                  'browser': row['browser_summary'], 'native': row['native_summary']}), flush=True)

            for repeat in range(args.repeats):
                await measure('home', repeat)

            if 'plains' in args.scenes:
                await page.touchscreen.tap(*point(1202, 42))
                await page.wait_for_timeout(2000)
                await shot('home-menu')
                # Existing actual Home navigation input. Scroll and type through
                # normal input; no scene/RNG mutation or direct field setter.
                await page.mouse.move(540, 180)
                await page.mouse.wheel(0, 1200)
                await page.wait_for_timeout(2000)
                field_shot = await shot('seed-field')
                field = locate_original(field_shot, 'Optional')
                await page.mouse.click(field[0]/DPR, field[1]/DPR)
                await page.keyboard.press('Control+A')
                await page.keyboard.type(args.seed, delay=40)
                await page.keyboard.press('Tab')
                await page.wait_for_timeout(1000)
                await shot('seed-entered')
                await page.mouse.wheel(0, -1600)
                await page.wait_for_timeout(2000)
                menu_shot = await shot('menu-explore')
                explore = locate_original(menu_shot, 'Explore')
                await page.touchscreen.tap(explore[0]/DPR, explore[1]/DPR)
                await page.wait_for_timeout(8000)
                if args.profile:
                    await page.wait_for_function("window.FPS04_STATE?.context==='plains'", timeout=90000)
                events = region_events(logs)
                assert events and events[-1]['seed'] == args.seed, events
                event = events[-1]
                assert event.get('debug_entry') is False, event
                if args.expected_manifest:
                    assert event['manifest_hash'] == args.expected_manifest, event
                report['plains_region_event'] = event
                await shot('plains-entry')
                save()
                for repeat in range(args.repeats):
                    await measure('plains', repeat)

            assert not errors, errors
            assert not any(any(marker in line for marker in ('SCRIPT ERROR:', 'SHADER ERROR:', 'Parse Error:')) for line in logs), logs
            report['status'] = 'captured_cloud_frame_samples_no_phone_acceptance'
        except Exception as error:
            report['status'] = 'failed'
            report['failure'] = {'type': type(error).__name__, 'message': str(error)}
            try:
                report['failure_state'] = {'native': await profile_state(), 'canvas': await canvas_state(page)}
                await shot('failure')
            except Exception as artifact_error:
                report['failure_artifact_error'] = str(artifact_error)
            raise
        finally:
            report['session_wall_seconds'] = time.monotonic() - started
            save()
            await browser.close()


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True, help='Exact entry URL, including index filename when needed')
    parser.add_argument('--output', type=Path, required=True, help='New directory; existing evidence is never overwritten')
    parser.add_argument('--label', required=True)
    parser.add_argument('--identity-json', type=Path, help='Exact local bundle metadata/diagnostic receipt retained with SHA')
    parser.add_argument('--profile', action='store_true')
    parser.add_argument('--seconds', type=float, default=10)
    parser.add_argument('--warm-seconds', type=float, default=5)
    parser.add_argument('--repeats', type=int, default=2)
    parser.add_argument('--seed', default='mobile-fps-04')
    parser.add_argument('--expected-manifest')
    parser.add_argument('--scenes', choices=['home', 'home,plains'], default='home,plains')
    parser.add_argument('--proxy-from-environment', action='store_true')
    parser.add_argument('--ready-expression', default='window.PLAYTEST_LOADING_DONE===true || window.READY===true')
    args = parser.parse_args()
    if not 3 <= args.seconds <= 30:
        parser.error('seconds must be in [3, 30]')
    if not 2 <= args.warm_seconds <= 30:
        parser.error('warm-seconds must be in [2, 30]')
    if not 1 <= args.repeats <= 5:
        parser.error('repeats must be in [1, 5]')
    if not 1 <= len(args.seed) <= 80:
        parser.error('seed must be 1–80 characters')
    return args


if __name__ == '__main__':
    asyncio.run(run(arguments()))
