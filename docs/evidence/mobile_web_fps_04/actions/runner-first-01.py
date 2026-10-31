"""Bounded real-touch action capture in the formal seeded Plains entry scene.

Run only under the project's single browser/engine lease. This records cloud
Chromium RAF and optional native probe data, not phone FPS or deep-map combat.
The existing frame runner and production scene are never changed by this tool.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
from pathlib import Path
import time

from run_frame_profile import (
    DPR, ROOT, VIEWPORT, FRAME_OBSERVER, async_playwright, browser_summary,
    canvas_state, environment_proxy, fitted_rect, identity, locate_original,
    native_summary, percentile, region_events, surfaces,
)

CAPTURE_SECONDS = 30
ACTION_SECONDS = 22
INPUT_LIMIT_SECONDS = 27
CUE_KEYS = {
    'jump': ('jump', 'director_jump'),
    'shot': ('shot', 'director_shot', 'director_shot_pulse', 'director_shot_shuriken', 'director_shot_bomb'),
    'death': ('death', 'director_death'),
}
DOM_INPUT_OBSERVER = r'''(() => {
    const data = {active:false, events:[], overflow:false};
    window.FPS04_ACTION_INPUT = data;
    for (const type of ['touchstart','touchmove','touchend','touchcancel']) {
        window.addEventListener(type, event => {
            if (!data.active) return;
            if (data.events.length >= 2000) { data.overflow=true; return; }
            data.events.push({type,now_ms:performance.now(),event_timestamp_ms:event.timeStamp,
                trusted:event.isTrusted,touches:Array.from(event.touches,t=>[t.identifier,t.clientX,t.clientY]),
                changed:Array.from(event.changedTouches,t=>[t.identifier,t.clientX,t.clientY])});
        }, {capture:true,passive:true});
    }
})();'''


def controls(rect, profile):
    """Mirror the authored 1280x720 default layout, then map to CSS coordinates."""
    radius = float(profile['touch_radius'])
    jump_hit = float(profile['touch_jump_radius']) + float(profile['touch_jump_hit_padding'])
    inset = float(profile['touch_jump_left_inset'])
    fit = min(1.0, (640 - 24 - 48) / (2 * (radius + jump_hit) + inset),
              (720 - 48) / (2 * max(radius, jump_hit)))
    radius, jump_hit, inset = radius * fit, jump_hit * fit, inset * fit
    y = 720 - max(radius, jump_hit) - 24
    jump_x = 1280 - jump_hit - 24 - inset
    logical = {'move': [radius + 24, y], 'jump': [jump_x, y],
               'aim': [jump_x - jump_hit - radius - 24, y]}

    def css(point):
        x, y = point
        return [(rect[0] + rect[2] * x / 1280) / DPR,
                (rect[1] + rect[3] * y / 720) / DPR]

    return logical, css


def action_plan(rect, profile):
    """Eight alternating short runs, jumps and two aimed releases per cycle.

    End always releases ALL fingers as required by the CDP touchEnd contract.
    During the first gesture, move/jump/aim are genuinely simultaneous fingers.
    """
    centers, css = controls(rect, profile)
    plan = []

    def point(identifier, position):
        x, y = css(position)
        return {'id': identifier, 'x': x, 'y': y, 'radiusX': 3,
                'radiusY': 3, 'force': 1}

    def add(at, label, kind, points):
        plan.append({'at_seconds': round(at, 3), 'label': label,
                     'type': kind, 'touchPoints': points})

    for cycle in range(8):
        begin = .5 + cycle * 2.6
        direction = 1 if cycle % 2 == 0 else -1
        move = point(1, centers['move'])
        moving = point(1, [centers['move'][0] + direction * 65, centers['move'][1]])
        jump = point(2, centers['jump'])
        aim = point(3, centers['aim'])
        aimed = point(3, [centers['aim'][0] + direction * 55, centers['aim'][1] - 28])
        prefix = f'cycle-{cycle}-' + ('right-' if direction > 0 else 'left-')
        add(begin, prefix + 'move-down', 'touchStart', [move])
        add(begin + .10, prefix + 'move-drag', 'touchMove', [moving])
        add(begin + .45, prefix + 'jump-down-with-move', 'touchStart', [moving, jump])
        add(begin + .72, prefix + 'aim-down-with-jump-move', 'touchStart', [moving, jump, aim])
        add(begin + .84, prefix + 'aim-drag-with-jump-move', 'touchMove', [moving, jump, aimed])
        add(begin + 1.12, prefix + 'shoot-release-all', 'touchEnd', [])
        add(begin + 1.70, prefix + 'second-aim-down', 'touchStart', [aim])
        add(begin + 1.82, prefix + 'second-aim-drag', 'touchMove', [aimed])
        add(begin + 2.06, prefix + 'second-shoot-release', 'touchEnd', [])
    return plan


def action_summary(capture):
    result = browser_summary(capture)
    durations = [row[2] for row in capture['frames']]
    result['p99_ms'] = percentile(durations, .99)
    result['over_budget'] = {
        str(budget): {'intervals': sum(value > budget for value in durations),
                      'total_excess_ms': sum(max(0, value - budget) for value in durations)}
        for budget in (1000 / 60, 1000 / 30, 50, 100)
    }
    return result


def native_action_summary(row):
    result = native_summary(row)
    durations = [frame[0] for frame in row['frames']]
    result['frame_p99_ms'] = percentile(durations, .99)
    result['frame_max_ms'] = max(durations, default=None)
    result['frame_over_budget'] = {str(b): sum(t > b for t in durations)
                                   for b in (1000 / 60, 1000 / 30, 50, 100)}
    before = row['initial'].get('audio_played', {})
    after = row['final'].get('audio_played', {})
    result['audio_played_delta'] = {key: after.get(key, 0) - before.get(key, 0)
                                    for key in before.keys() | after.keys()}
    result['accepted_cue_deltas'] = {
        name: sum(after.get(key, 0) - before.get(key, 0) for key in keys)
        for name, keys in CUE_KEYS.items()
    }
    result['cue_scope'] = 'Original GameAudio accepted playback counters, including selected workshop keys; not browser audible-output proof or one-to-one proof of every requested action.'
    samples = row.get('samples', [])
    columns = row.get('sample_columns', [])
    result['sample_rows'] = len(samples)
    result['counter_ranges'] = {}
    for name in ('nodes', 'objects', 'resources', 'player_x', 'player_y', 'health',
                 'jump_cues', 'shot_cues', 'death_cues'):
        if name in columns:
            values = [sample[columns.index(name)] for sample in samples]
            valid = [value for value in values if value is not None]
            result['counter_ranges'][name] = {
                'first': values[0] if values else None, 'last': values[-1] if values else None,
                'min': min(valid, default=None), 'max': max(valid, default=None),
                'missing': len(values) - len(valid),
                'last_minus_first': values[-1] - values[0]
                    if values and values[0] is not None and values[-1] is not None else None,
            }
    costs = row.get('costs_per_frame', [])
    result['per_frame_alignment_valid'] = len(samples) == len(costs) == len(row['frames'])
    slowest = sorted(range(len(row['frames'])), key=lambda i: -row['frames'][i][0])[:20]
    result['slowest_native_frames'] = [{
        'index': i, 'frame': row['frames'][i],
        'sample': samples[i] if i < len(samples) else None,
        'inclusive_costs': costs[i] if i < len(costs) else None,
    } for i in slowest]
    initial_health = row['initial'].get('player_health', {}).get('current')
    health_range = result['counter_ranges'].get('health', {})
    missing_actor = result['counter_ranges'].get('player_y', {}).get('missing', 0) > 0
    minimum = health_range.get('min')
    result['comparison_boundary'] = {
        'death_cue_observed': result['accepted_cue_deltas']['death'] > 0,
        'terminal_at_end': row['final'].get('player_health', {}).get('terminal', False),
        'health_nonpositive_or_actor_missing': minimum is None or minimum <= 0 or missing_actor,
        'health_dropped': initial_health is not None and minimum is not None and minimum < initial_health,
        'scope': 'Retain actual min health and min/max Y. Health loss flags damage/possible fall and invalidates the controlled entry comparison; Y alone does not prove a fall. Initial/final context and manifest are checked separately.'}
    return result


def action_intervals(capture, events):
    """Retain complete RAF intervals crossing the first/last delivered touch."""
    if not events:
        return {'available': False}
    first, last = events[0]['now_ms'], events[-1]['now_ms']
    selected = [(index, frame) for index, frame in enumerate(capture['frames'])
                if frame[1] >= first and frame[0] <= last]
    durations = [frame[2] for _, frame in selected]
    return {'available': True, 'first_input_ms': first, 'last_input_ms': last,
            'raw_frame_indices': [index for index, _ in selected],
            'intervals': len(durations), 'p50_ms': percentile(durations, .5),
            'p95_ms': percentile(durations, .95), 'p99_ms': percentile(durations, .99),
            'max_ms': max(durations, default=None),
            'over_budget': {str(b): sum(t > b for t in durations)
                            for b in (1000 / 60, 1000 / 30, 50, 100)},
            'scope': 'Complete raw RAF intervals intersecting first-through-last actual touch delivery, including boundary-crossing stalls. Distribution only; no partial-window FPS denominator.'}


async def drive_inputs(cdp, plan, report, capture_requested_monotonic):
    start = time.monotonic()
    deadline = capture_requested_monotonic + INPUT_LIMIT_SECONDS
    report['input_epoch_monotonic'] = start
    report['input_epoch_wall_time'] = time.time()
    report['input_complete'] = False
    active = False
    try:
        for item in plan:
            target = start + item['at_seconds']
            if target >= deadline:
                raise RuntimeError('Command pickup consumed the native input safety margin')
            await asyncio.sleep(max(0, target - time.monotonic()))
            sent = time.monotonic()
            if sent >= deadline:
                raise RuntimeError('Input window overran; remaining gestures not dispatched')
            event = dict(item, sent_monotonic=sent, sent_wall_time=time.time(),
                         lateness_ms=1000 * (sent - target))
            report['input_dispatch'].append(event)
            # No engine state writes. Browser delivers native trusted touch events.
            # A failed end delivery must still attempt cancellation in finally.
            if item['type'] != 'touchEnd':
                active = True
            try:
                await asyncio.wait_for(cdp.send('Input.dispatchTouchEvent', {
                    'type': item['type'], 'touchPoints': item['touchPoints'],
                }), timeout=8)
                event['ack_monotonic'] = time.monotonic()
                event['ack_wall_time'] = time.time()
                if item['type'] == 'touchEnd':
                    active = False
            except Exception as error:
                event['error'] = f'{type(error).__name__}: {error}'
                raise
        await asyncio.sleep(max(0, start + ACTION_SECONDS - time.monotonic()))
        if time.monotonic() >= deadline:
            raise RuntimeError('Input sequence exceeded its 27 s native safety bound')
        report['input_complete'] = True
    finally:
        if active:
            event = {'label': 'failure-release-all', 'type': 'touchCancel',
                     'touchPoints': [], 'sent_monotonic': time.monotonic(),
                     'sent_wall_time': time.time()}
            report['input_dispatch'].append(event)
            try:
                await asyncio.wait_for(cdp.send('Input.dispatchTouchEvent', {
                    'type': 'touchCancel', 'touchPoints': []}), timeout=8)
                event['ack_monotonic'] = time.monotonic()
            except Exception as error:
                event['error'] = f'{type(error).__name__}: {error}'
        report['input_end_monotonic'] = time.monotonic()


async def run(args):
    args.output.mkdir(parents=True, exist_ok=False)
    logs, errors = [], []
    report = {'status': 'running', 'label': args.label, 'url': args.url,
              'seed': args.seed, 'viewport_css': VIEWPORT, 'device_scale_factor': DPR,
              'capture_seconds': CAPTURE_SECONDS, 'action_seconds': ACTION_SECONDS,
              'instrumented': args.profile, 'identity': identity(args.identity_json),
              'input_dispatch': [], 'input_complete': False,
              'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'shared_runner_sha256': hashlib.sha256(Path(__file__).with_name('run_frame_profile.py').read_bytes()).hexdigest(),
              'browser_observer_sha256': hashlib.sha256(FRAME_OBSERVER.encode()).hexdigest(),
              'input_observer_sha256': hashlib.sha256(DOM_INPUT_OBSERVER.encode()).hexdigest(),
              'scope': 'Real demo.tscn title/Home/seed/Explore; loaded Plains entry action window. No position/health/scene writes. Cloud SwiftShader, not phone FPS or deep-map combat. Trusted DOM delivery is not proof of game action acceptance; inspect original native counters and initial/final health when available.'}
    started = time.monotonic()

    def save():
        report['logs'] = logs
        report['page_errors'] = errors
        (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
        (args.output / 'browser.log').write_text('\n'.join(logs + errors) + '\n')

    save()
    async with async_playwright() as playwright:
        options = {'proxy': environment_proxy()[0]} if args.proxy_from_environment else {}
        browser = await playwright.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
            args=['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'], **options)
        context = await browser.new_context(viewport=VIEWPORT, device_scale_factor=DPR,
                                            is_mobile=True, has_touch=True)
        await context.add_init_script(FRAME_OBSERVER)
        await context.add_init_script(DOM_INPUT_OBSERVER)
        page = await context.new_page()
        page.set_default_timeout(30000)
        page.on('console', lambda message: logs.append(message.type + ': ' + message.text))
        page.on('pageerror', lambda error: errors.append(str(error)))
        cdp = await context.new_cdp_session(page)

        async def shot(name):
            path = args.output / (name + '.png')
            await page.screenshot(path=str(path), timeout=30000)
            return path

        async def state():
            return await page.evaluate('window.FPS04_STATE ?? null')

        try:
            await page.goto(args.url, wait_until='domcontentloaded', timeout=60000)
            await page.wait_for_function(args.ready_expression, timeout=180000)
            if args.profile:
                await page.wait_for_function('window.FPS04_READY===true', timeout=30000)
            report['served_metadata'] = await page.evaluate('''async () => {
                try { const r=await fetch(new URL('build-info.json',location.href),{cache:'no-store'});
                    return r.ok ? await r.json() : {http_status:r.status};
                } catch(e) {return {error:String(e)};}
            }''')
            await page.wait_for_timeout(1500)
            title = await shot('title')
            buttons = surfaces(title, [(195, 163, 102)])
            assert buttons, 'No actual title Start button'
            box = buttons[0]
            await page.touchscreen.tap((box[0] + box[2] / 2) / DPR,
                                       (box[1] + box[3] / 2) / DPR)
            await page.wait_for_timeout(6000)
            if args.profile:
                await page.wait_for_function("window.FPS04_STATE?.context==='home'", timeout=45000)
            home = await shot('home-entry')
            assert not surfaces(home, [(195, 163, 102)]), 'Still on title'
            rect = fitted_rect(home)
            _, css = controls(rect, json.loads((ROOT / 'config/input_profile.json').read_text()))
            await page.touchscreen.tap(*css([1202, 42]))
            await page.wait_for_timeout(2000)
            await page.mouse.move(540, 180)
            await page.mouse.wheel(0, 1200)
            await page.wait_for_timeout(2000)
            field = locate_original(await shot('seed-field'), 'Optional')
            await page.mouse.click(field[0] / DPR, field[1] / DPR)
            await page.keyboard.press('Control+A')
            await page.keyboard.type(args.seed, delay=40)
            await page.keyboard.press('Tab')
            await page.wait_for_timeout(1000)
            await shot('seed-entered')
            await page.mouse.wheel(0, -1600)
            await page.wait_for_timeout(2000)
            explore = locate_original(await shot('menu-explore'), 'Explore')
            await page.touchscreen.tap(explore[0] / DPR, explore[1] / DPR)
            await page.wait_for_timeout(8000)
            if args.profile:
                await page.wait_for_function("window.FPS04_STATE?.context==='plains'", timeout=90000)
            events = region_events(logs)
            assert events and events[-1]['seed'] == args.seed, events
            assert events[-1].get('debug_entry') is False, events[-1]
            if args.expected_manifest:
                assert events[-1]['manifest_hash'] == args.expected_manifest, events[-1]
            report['region_before'] = events[-1]
            entry = await shot('plains-entry')
            rect = fitted_rect(entry)
            profile_path = ROOT / 'config/input_profile.json'
            profile = json.loads(profile_path.read_text())
            plan = action_plan(rect, profile)
            report['input_plan'] = plan
            report['input_layout'] = {'source_path': str(profile_path),
                                     'source_sha256': hashlib.sha256(profile_path.read_bytes()).hexdigest(),
                                     'logical_centers': controls(rect, profile)[0],
                                     'fitted_physical_rect': rect,
                                     'scope': 'Authored default layout in fresh context; local layout identity retained. No runtime input-profile mutation.'}
            await page.wait_for_timeout(args.warm_seconds * 1000)
            report['canvas_before'] = await canvas_state(page)
            assert report['canvas_before']['dpr'] == DPR and report['canvas_before']['isolated']
            report['state_before'] = await state()
            if args.profile:
                assert report['state_before']['context'] == 'plains'
            save()
            requested = time.monotonic()
            begin = await page.evaluate('''profile => {
                if (profile && window.FPS04_COMMAND) throw new Error('Pending native command');
                window.FPS04_ACTION_INPUT.events=[];window.FPS04_ACTION_INPUT.active=true;
                const browser_begin_ms=window.FPS04_BROWSER.begin();
                const sequence=profile ? window.FPS04_RESULTS.length : null;
                if (profile) { window.FPS04_SECONDS=30;window.FPS04_COMMAND='capture'; }
                return {browser_begin_ms,sequence,wall_epoch_ms:Date.now()};
            }''', args.profile)
            report['capture_begin'] = dict(begin, request_monotonic=requested)
            action_error = None
            try:
                if args.profile:
                    await page.wait_for_function("window.FPS04_COMMAND===''", timeout=5000)
                await drive_inputs(cdp, plan, report, requested)
            except Exception as error:
                action_error = error
                report['input_error'] = f'{type(error).__name__}: {error}'
            # Always preserve the complete browser window, including a pending
            # trailing RAF stall. The native probe is independently capped at30s.
            try:
                if args.profile:
                    await page.wait_for_function('n => window.FPS04_RESULTS.length > n',
                        arg=begin['sequence'], timeout=65000)
                else:
                    await asyncio.sleep(max(0, requested + CAPTURE_SECONDS - time.monotonic()))
            finally:
                report['browser'] = await page.evaluate('window.FPS04_BROWSER.end()')
                report['dom_input'] = await page.evaluate('''() => {
                    window.FPS04_ACTION_INPUT.active=false;
                    return window.FPS04_ACTION_INPUT;
                }''')
                report['browser_summary'] = action_summary(report['browser'])
                save()
            if args.profile:
                native = await page.evaluate('window.FPS04_RESULTS.at(-1)')
                report['native'] = native
                report['native_summary'] = native_action_summary(native)
            report['state_after'] = await state()
            report['canvas_after'] = await canvas_state(page)
            report['region_after'] = region_events(logs)[-1]
            await shot('plains-after-actions')
            # Event receipt clocks are directly comparable with raw browser RAF.
            dom_events = report['dom_input']['events']
            report['action_frame_distribution'] = action_intervals(report['browser'], dom_events)
            end_limit = begin['browser_begin_ms'] + INPUT_LIMIT_SECONDS * 1000
            report['input_boundary'] = {
                'last_dom_input_ms': dom_events[-1]['now_ms'] if dom_events else None,
                'earliest_native_stop_ms': begin['browser_begin_ms'] + 30000 if args.profile else None,
                'inputs_inside_safety_window': bool(dom_events) and dom_events[-1]['now_ms'] < end_limit,
                'planned_events': len(plan), 'dispatched_events': len(report['input_dispatch']),
                'actual_touchstart_events': sum(event['type'] == 'touchstart' for event in dom_events),
                'actual_touchend_events': sum(event['type'] == 'touchend' for event in dom_events),
                'max_dispatch_lateness_ms': max((event.get('lateness_ms', 0) for event in report['input_dispatch']), default=None),
                'scope': 'All planned touch delivery must finish before27s after capture request; native starts after request and runs30s. Late/incomplete input invalidates the comparison; no truncated window acceptance.'}
            save()
            if action_error:
                raise action_error
            assert report['input_complete'] and report['input_boundary']['inputs_inside_safety_window'], report['input_boundary']
            assert dom_events and all(event['trusted'] for event in dom_events), 'Missing/untrusted actual touch delivery'
            assert report['input_boundary']['actual_touchstart_events'] >= 32, 'Some planned touch starts did not reach DOM'
            assert report['input_boundary']['actual_touchend_events'] >= 16, 'Some planned releases did not reach DOM'
            assert not report['dom_input']['overflow']
            assert report['browser']['closed_on_raf'] and not report['browser']['overflow']
            assert len(report['browser']['frames']) >= 2
            assert report['region_before'] == report['region_after'], 'Region transition during action window'
            if args.profile:
                initial, final = report['native']['initial'], report['native']['final']
                assert initial['context'] == final['context'] == 'plains', 'Left Plains during action window'
                assert initial['manifest'] == final['manifest'], 'Manifest changed during action window'
                assert not initial['tree_paused'] and not final['tree_paused'], 'Action capture reached pause/menu'
                health = final.get('player_health', {})
                assert not health.get('terminal', False), 'Player died; not a comparable entry action window'
                summary = report['native_summary']
                assert summary['per_frame_alignment_valid'], 'Native samples/costs/frames are not aligned'
                boundary = summary['comparison_boundary']
                assert not any(boundary[key] for key in (
                    'death_cue_observed', 'terminal_at_end', 'health_nonpositive_or_actor_missing', 'health_dropped'
                )), boundary
                assert summary['accepted_cue_deltas']['jump'] > 0, 'No accepted jump cue observed'
                assert summary['accepted_cue_deltas']['shot'] > 0, 'No accepted shot cue observed'
            assert not errors, errors
            assert not any(any(marker in line for marker in ('SCRIPT ERROR:', 'SHADER ERROR:', 'Parse Error:')) for line in logs)
            report['status'] = 'captured_entry_action_window_no_phone_acceptance'
            print(json.dumps({'browser': report['browser_summary'], 'native': report.get('native_summary'),
                              'input_boundary': report['input_boundary']}), flush=True)
        except Exception as error:
            report['status'] = 'failed'
            report['failure'] = {'type': type(error).__name__, 'message': str(error)}
            try:
                report['failure_state'] = await state()
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
    parser.add_argument('--url', required=True)
    parser.add_argument('--output', type=Path, required=True, help='New evidence directory; never overwritten')
    parser.add_argument('--label', required=True)
    parser.add_argument('--identity-json', type=Path)
    parser.add_argument('--profile', action='store_true')
    parser.add_argument('--seed', default='mobile-fps-04')
    parser.add_argument('--expected-manifest')
    parser.add_argument('--warm-seconds', type=float, default=3)
    parser.add_argument('--proxy-from-environment', action='store_true')
    parser.add_argument('--ready-expression', default='window.PLAYTEST_LOADING_DONE===true || window.READY===true')
    args = parser.parse_args()
    if not 1 <= len(args.seed) <= 80:
        parser.error('seed must contain1–80 characters')
    if not 2 <= args.warm_seconds <= 10:
        parser.error('warm-seconds must be2–10')
    return args


if __name__ == '__main__':
    asyncio.run(run(arguments()))
