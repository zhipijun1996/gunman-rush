"""Build a main1b formal-scene audio A/B diagnostic; never runs Godot/browser.

One derived pack, four fresh-page startup cases. Original main scene, official
engine/worklets and unaffected pack entries stay byte-identical. Production
sources come exclusively from git show at the frozen main commit.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import traceback
from zipfile import ZipFile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_web_bundle import Pack
from build_probe import AUDIO, HELPER, write_pack

COMMIT = '1b29932c5333a9dad50759afc635762163ed79f5'
PACK_SHA = '618eb97114e6715fc33856823c9bf23141e8e51802a886596bc9f223ed7ca691'

# Fixed main1b source/pack protocol; current build_probe consumes a different layout.
MEASURE_COMMIT = "1b29932c5333a9dad50759afc635762163ed79f5"
if MEASURE_COMMIT != COMMIT:
    raise ValueError("Recorded measurement paths require their original source commit")
MEASURE = {
    'scripts/underworld_plains/underworld_foreground.gd': ['_refresh', '_protection', '_sync_residents', '_render_receipt'],
    'scripts/underworld_plains/underworld_presentation.gd': ['refresh'],
    'scripts/underworld_plains/underworld_parallax.gd': ['_update'],
    'scripts/underworld_plains/underworld_home_world.gd': ['update_focus'],
    'scripts/demo/generated_demo_stage.gd': ['_physics_process'],
    'scripts/demo/plains_region_stage.gd': ['_physics_process', 'capture_state', '_update_context_signs'],
    'scripts/enemies/enemy_actor.gd': ['_physics_process'],
    'scripts/demo/home_scene.gd': ['_physics_process', '_process'],
    'scripts/player/player_controller.gd': ['_physics_process'],
    'scripts/demo/demo_app.gd': ['_process', '_physics_process', '_layout_region_hud', '_sync_music'],
    'scripts/ui/demo_ui_01/game_hud.gd': ['_process', '_refresh', 'present_context'],
    'scripts/audio/game_audio.gd': ['_process'],
    'scripts/audio/game_music.gd': ['_process'],
    'scripts/audio/game_ambience.gd': ['_process'],
    'scripts/audio/selected_ambience_runtime.gd': ['_process'],
    'scripts/audio/home_ambience_audition.gd': ['_process'],
}
ENGINE = 'index.d20938d2db49.engine'
CASES = ['original', 'bus_only', 'pause_only', 'ambience_off']
CASE_PATH = 'mobile_formal_audio_case.gd'
PROBE_PATH = 'mobile_perf_probe.gd'
CASE_SCRIPT = '''extends RefCounted
## Diagnostic startup selection only; immutable after first lookup.
const CASES := ["original", "bus_only", "pause_only", "ambience_off"]
static var _case := ""
static func current() -> String:
	if not _case.is_empty(): return _case
	var proposed := "original"
	if OS.has_feature("web"):
		proposed = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('case') || 'original'"))
	else:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--formal-audio-case="): proposed = argument.trim_prefix("--formal-audio-case=")
	if proposed not in CASES:
		push_error("Invalid formal audio diagnostic case: " + proposed)
		proposed = "original"
	_case = proposed
	return _case
'''
CASE_GET = 'load("res://' + CASE_PATH + '").current()'

OBSERVATION_HELPERS = r'''
func _formal_observed_jump(controller_id: int) -> void:
	_formal_jump_total += 1
	var row: Dictionary = _formal_action_counts.get(controller_id, {"jumped":0,"shot_fired":0})
	row["jumped"] = int(row["jumped"]) + 1
	_formal_action_counts[controller_id] = row
	_formal_action_event({"signal":"jumped","controller_id":controller_id})

func _formal_observed_shot(direction: Vector2, shot_id: int, controller_id: int) -> void:
	_formal_shot_total += 1
	var row: Dictionary = _formal_action_counts.get(controller_id, {"jumped":0,"shot_fired":0})
	row["shot_fired"] = int(row["shot_fired"]) + 1
	_formal_action_counts[controller_id] = row
	_formal_action_event({"signal":"shot_fired","controller_id":controller_id,"shot_id":shot_id,"direction":[direction.x,direction.y]})

func _formal_action_event(row: Dictionary) -> void:
	row["process_frame"] = Engine.get_process_frames()
	row["physics_frame"] = Engine.get_physics_frames()
	row["real_usec"] = Time.get_ticks_usec()
	_formal_action_events.append(row)
	if _formal_action_events.size() > 256: _formal_action_events.pop_front()

func _formal_touch_observation() -> Dictionary:
	var overlay: TouchOverlay = app.home_scene.overlay if is_instance_valid(app.home_scene) else app.overlay
	if not is_instance_valid(overlay): return {}
	var transform := overlay.get_global_transform_with_canvas()
	var projected_jump: Vector2 = transform * overlay.jump_center
	var projected_right: Vector2 = transform * overlay.right_center
	var projected_left: Vector2 = transform * overlay.left_center
	var pause: Rect2 = overlay.get("_pause_rect")
	var projected_pause: Rect2 = transform * pause
	var scale := transform.get_scale().abs()
	return {"enabled":overlay.enabled,"visible_in_tree":overlay.is_visible_in_tree(),
		"jump_center":[overlay.jump_center.x,overlay.jump_center.y],
		"right_center":[overlay.right_center.x,overlay.right_center.y],
		"left_center":[overlay.left_center.x,overlay.left_center.y],"radius":overlay.radius,
		"pause_rect":[pause.position.x,pause.position.y,pause.size.x,pause.size.y],
		"global_canvas_transform":{"origin":[transform.origin.x,transform.origin.y],"scale":[scale.x,scale.y]},
		"screen_logical":{"jump_center":[projected_jump.x,projected_jump.y],
			"right_center":[projected_right.x,projected_right.y],"left_center":[projected_left.x,projected_left.y],
			"radius_axes":[overlay.radius*scale.x,overlay.radius*scale.y],
			"pause_rect":[projected_pause.position.x,projected_pause.position.y,projected_pause.size.x,projected_pause.size.y]}}

func _formal_viewport_observation() -> Dictionary:
	var viewport := get_tree().root
	var texture_size := viewport.get_texture().get_size()
	var logical_size := viewport.get_visible_rect().size
	var transform := viewport.get_screen_transform()
	var scale := transform.get_scale()
	return {"texture_size":[texture_size.x,texture_size.y],"logical_size":[logical_size.x,logical_size.y],
		"screen_transform":{"origin":[transform.origin.x,transform.origin.y],"scale":[scale.x,scale.y]},
		"window_size":[viewport.size.x,viewport.size.y]}

func _formal_action_observation() -> Dictionary:
	var controller: PlayerController = app.home_scene.controller if is_instance_valid(app.home_scene) else app.controller
	var controller_id := controller.get_instance_id() if is_instance_valid(controller) else 0
	var serial := controller.shoot_ability._shot_serial if is_instance_valid(controller) else 0
	return {"controller_id":controller_id,"jumped_total":_formal_jump_total,"shot_fired_total":_formal_shot_total,
		"current_controller":_formal_action_counts.get(controller_id,{"jumped":0,"shot_fired":0}).duplicate(),
		"shot_serial":serial,"by_controller":_formal_action_counts.duplicate(true),"events":_formal_action_events.duplicate(true),
		"events_limit":256,"scope":"original signal observers only; no requests, input injection or gameplay writes"}
'''


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_source(path: str) -> bytes:
    return subprocess.check_output(['git', 'show', COMMIT + ':' + path], cwd=ROOT)


class Edits:
    """Every production edit is labelled and independently reversible to main1b."""
    def __init__(self, path: str, original: bytes):
        self.path, self.original = path, original
        self.text = original.decode('utf-8')
        self.steps = []

    def replace(self, old: str, new: str, label: str):
        if self.text.count(old) != 1:
            raise ValueError(f'{self.path}: {label}: expected one match, found {self.text.count(old)}')
        self.text = self.text.replace(old, new, 1)
        self.steps.append({'kind': 'replace', 'label': label, 'before': old, 'after': new})

    def append(self, suffix: str, label: str):
        self.text += suffix
        self.steps.append({'kind': 'append', 'label': label, 'after': suffix})

    def verify_reverse(self):
        restored = self.text
        for step in reversed(self.steps):
            if step['kind'] == 'append':
                if not restored.endswith(step['after']):
                    raise ValueError(f'{self.path}: append inverse failed: {step["label"]}')
                restored = restored[:-len(step['after'])]
            else:
                if restored.count(step['after']) != 1:
                    raise ValueError(f'{self.path}: replacement inverse ambiguous: {step["label"]}')
                restored = restored.replace(step['after'], step['before'], 1)
        if restored.encode() != self.original:
            raise ValueError(f'{self.path}: non-whitelisted production body drift')
        return True


def treatments(edit: Edits):
    if edit.path == 'scripts/audio/game_audio.gd':
        # Original append/name/send path remains intact for every other case.
        original = '\t\tAudioServer.add_bus()\n'
        branch = ('\t\tif ' + CASE_GET + ' == "bus_only":\n'
                  '\t\t\tvar appended_index := AudioServer.bus_count\n'
                  '\t\t\tAudioServer.bus_count = appended_index + 1\n'
                  '\t\t\tAudioServer.set_bus_name(appended_index, bus_name)\n'
                  '\t\t\tAudioServer.set_bus_send(appended_index, &"Master")\n'
                  '\t\t\tcontinue\n')
        edit.replace(original, branch + original, 'case:bus_only:append-count-before-original-add')
    elif edit.path == 'scripts/audio/game_ambience.gd':
        edit.append('\nvar _perf_formal_pause_only := false\n', 'case:pause_only:cached-startup-flag')
        edit.replace('func _ready() -> void:\n',
                     'func _ready() -> void:\n\t_perf_formal_pause_only = ' + CASE_GET + ' == "pause_only"\n',
                     'case:pause_only:initialize-flag')
        original = '\t\t\tfor voice: AudioStreamPlayer in _beds + _details: voice.stream_paused = true\n'
        revised = ('\t\t\tfor voice: AudioStreamPlayer in _beds + _details:\n'
                   '\t\t\t\tif not _perf_formal_pause_only or not voice.stream_paused: voice.stream_paused = true\n')
        edit.replace(original, revised, 'case:pause_only:zero-volume-setter-guard')
        original = ('\tfor voice: AudioStreamPlayer in _beds: voice.stream_paused = is_paused\n'
                    '\tfor voice: AudioStreamPlayer in _details: voice.stream_paused = is_paused\n')
        revised = ('\tif _perf_formal_pause_only:\n'
                   '\t\tvar desired_pause := is_paused or session_volume <= 0.0\n'
                   '\t\tfor voice: AudioStreamPlayer in _beds + _details:\n'
                   '\t\t\tif voice.stream_paused != desired_pause: voice.stream_paused = desired_pause\n'
                   '\telse:\n' + ''.join('\t' + line for line in original.splitlines(True)))
        edit.replace(original, revised, 'case:pause_only:combined-per-frame-state')
        line = '\t\tvoice.stream_paused = session_volume <= 0.0\n'
        if edit.text.count(line) != 2:
            raise ValueError('Expected exactly two later GameAmbience per-frame pause writes')
        # Include unique adjacent lines so the inverse never chooses a wrong site.
        for prefix, label in [
            ('\t\tvoice.volume_db = linear_to_db(maxf(0.00001, linear))\n', 'bed'),
            ('\t\tvoice.volume_db = linear_to_db(maxf(0.00001, session_volume * attenuation * db_to_linear(float(voice.get_meta("gain_db", 0.0)))))\n', 'detail')]:
            edit.replace(prefix + line, prefix + '\t\tif not _perf_formal_pause_only: voice.stream_paused = session_volume <= 0.0\n',
                         'case:pause_only:remove-later-' + label + '-duplicate')
    elif edit.path == 'scripts/audio/selected_ambience_runtime.gd':
        edit.replace('func _ready() -> void:\n',
                     'func _ready() -> void:\n\tif ' + CASE_GET + ' == "ambience_off":\n\t\tset_process(false)\n\t\treturn\n',
                     'case:ambience_off:return-before-any-attachment')


def observe(edit: Edits, methods: list[str]):
    for method in methods:
        match = re.search(r'^func ' + re.escape(method) + r'\(([^\n]*)\) -> void:', edit.text, re.M)
        if not match:
            raise ValueError((edit.path, method, 'missing void function'))
        signature = match.group(0)
        arguments = match.group(1)
        params = [part.strip().split(':')[0].split('=')[0].strip() for part in arguments.split(',') if part.strip()]
        implementation = '_perf_impl_' + hashlib.sha256(edit.path.encode()).hexdigest()[:8] + '_' + method
        edit.replace(signature, signature.replace('func ' + method + '(', 'func ' + implementation + '(', 1),
                     'observe:rename:' + method)
        edit.append(f'\nfunc {method}({arguments}) -> void:\n\tvar _perf_start := Time.get_ticks_usec()\n'
                    f'\t{implementation}({", ".join(params)})\n'
                    f'\t_perf_record("res://{edit.path}:{method}",Time.get_ticks_usec()-_perf_start)\n',
                    'observe:wrapper:' + method)
    if edit.path == 'scripts/audio/game_audio.gd':
        edit.replace('func _play_original(', 'func _perf_impl_play_original(', 'observe:rename-audio-acceptance')
        # Reuse the observer without its separate all-audio knockout feature.
        audio = AUDIO
        start = audio.index('\tif get_tree().root.get_meta("mobile_perf_audio_off",false):\n')
        end = audio.index('\tvar before:=', start)
        audio = audio[:start] + audio[end:]
        edit.append(audio, 'observe:audio-acceptance-without-knockout')
        needle = '\tget_tree().node_added.connect(_observe_button)'
        hook = ('\tvar perf := load("res://' + PROBE_PATH + '").new() as Node\n'
                '\tperf.set_meta("app_ref",weakref(get_parent()))\n'
                '\tget_tree().root.add_child.call_deferred(perf)\n')
        edit.replace(needle, hook + needle, 'observe:defer-root-probe-for-actual-App')
    edit.append(HELPER, 'observe:cost-helper')


def replace_function(source: str, name: str, replacement: str) -> str:
    match = re.search(r'^func ' + re.escape(name) + r'\(', source, re.M)
    if not match:
        raise ValueError('Missing diagnostic probe function ' + name)
    following = re.search(r'^func ', source[match.end():], re.M)
    end = match.end() + following.start() if following else len(source)
    return source[:match.start()] + replacement.rstrip() + '\n\n' + source[end:]


def formal_probe(original: bytes) -> bytes:
    source = original.decode()
    source, count = re.subn(r'^const MODES := .*\n', '', source, count=1, flags=re.M)
    if count != 1:
        raise ValueError('Probe mode list changed')
    source = source.replace('var mode := "baseline"', 'var formal_case := "original"\nvar mode := "original"', 1)
    source = source.replace('\tapp.meta_persistence_enabled=false\n', '')
    needle = '\tapp=get_meta("app_ref").get_ref()\n'
    if source.count(needle) != 1:
        raise ValueError('Probe App binding changed')
    source = source.replace(needle, needle + '\tformal_case = ' + CASE_GET + '\n\tmode = formal_case\n', 1)
    source = source.replace('active=true;mode="baseline";', 'active=true;mode=formal_case;', 1)
    # Observation-only revision: original signals and projected current controls.
    source += '\nvar _formal_jump_total := 0\nvar _formal_shot_total := 0\nvar _formal_action_counts: Dictionary = {}\nvar _formal_action_events: Array[Dictionary] = []\n'
    controller_line = '\tvar controller: PlayerController=app.home_scene.controller if is_instance_valid(app.home_scene) else app.controller\n'
    if source.count(controller_line) != 1:
        raise ValueError('Probe controller cache binding changed')
    signal_hooks = (controller_line +
        '\tif is_instance_valid(controller):\n'
        '\t\tvar jump_observer := _formal_observed_jump.bind(controller.get_instance_id())\n'
        '\t\tvar shot_observer := _formal_observed_shot.bind(controller.get_instance_id())\n'
        '\t\tif not controller.jump_ability.jumped.is_connected(jump_observer): controller.jump_ability.jumped.connect(jump_observer)\n'
        '\t\tif not controller.shoot_ability.shot_fired.is_connected(shot_observer): controller.shoot_ability.shot_fired.connect(shot_observer)\n')
    source = source.replace(controller_line, signal_hooks, 1)
    source = source.replace('return {"context":"home"',
        'return {"touch_observation":_formal_touch_observation(),"viewport_observation":_formal_viewport_observation(),"action_observation":_formal_action_observation(),"context":"home"', 1)
    source += OBSERVATION_HELPERS
    source = replace_function(source, '_restore', '')
    source = replace_function(source, '_apply', '')
    command = '''func _command(command: String) -> void:
	if command == "capture":
		if not _cache(): return
		warm_until = maxi(warm_until,Time.get_ticks_usec()+100000)
		begin_usec=0;last_usec=0;frames.clear();measuring=true;stop_at=0
	elif command == "stop" and measuring: _finish()
	elif command == "plains":
		if measuring: _finish()
		active=false;context_id=0
		app.start_plains("plains-run")
	elif command == "home":
		if measuring: _finish()
		active=false;context_id=0
		app._show_home()
	elif command == "cue_coin" and is_instance_valid(audio):
		# Explicit cue request only, never a claimed natural pickup/resource grant.
		audio.play(&"coin")
	elif command.begins_with("seconds:"):
		capture_seconds=clampf(float(command.trim_prefix("seconds:")),3,60)
	_publish()
'''
    source = replace_function(source, '_command', command)
    source = source.replace('"mode":mode', '"mode":mode,"formal_audio_case":formal_case')
    source = source.replace('instrumented actual public PCK; explicit scene and cue fixtures; not physical phone',
                            'main1b real demo.tscn/App; startup-only independent audio cases, explicit scene/cue fixtures; not physical phone')
    for forbidden in ['MOBILE_PERF_MASTER_ROUTING', 'mobile_perf_audio_pause_guard', 'mobile_perf_audio_off',
                      'mobile_perf_hud_off', '"mode:"', 'DemoApp.new()', 'meta_persistence_enabled=false',
                      'func _apply(', 'func _restore(']:
        if forbidden in source:
            raise ValueError('Unexpected diagnostic control: ' + forbidden)
    if 'if not is_instance_valid(app) or not app.is_inside_tree():' not in source:
        raise ValueError('Root-owned probe lifecycle guard missing')
    return source.encode()


def html() -> bytes:
    return ('''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
<style>body{margin:0;background:black;overflow:hidden;touch-action:none}canvas{display:block;image-rendering:pixelated}</style>
<script>window.MOBILE_GPU_PROBE_ENABLED=false;</script>
<script src="audio_graph_probe.js"></script><script src="audio_probe.js"></script><script src="gpu_probe.js"></script>
</head><body><canvas id="canvas"></canvas><script src="''' + ENGINE + '''.js"></script><script>
(async()=>{try{
 const cases=['original','bus_only','pause_only','ambience_off'];
 const params=new URLSearchParams(location.search), selected=params.get('case')||'original';
 if(!cases.includes(selected))throw new Error('Invalid formal audio case');
 const latency=Number(params.get('latency')||50);
 if(!Number.isSafeInteger(latency)||latency!==50)throw new Error('This four-case A/B fixes audio latency at50ms');
 window.FORMAL_AUDIO_AB_CASE=selected;document.title='main1b audio A/B: '+selected;
 const engine=new Engine({canvasResizePolicy:2,executable:"''' + ENGINE + '''",mainPack:"diagnostic.pck",focusCanvas:true,ensureCrossOriginIsolationHeaders:false});
 await engine.startGame({args:['--audio-output-latency',String(latency)]});window.READY=true;
}catch(error){window.FORMAL_AUDIO_AB_ERROR=String(error);console.error(error);}})();
</script></body></html>''').encode()


def build(args, out: Path, receipt: dict):
    baseline = args.baseline_pack.resolve()
    actual_sha = digest(baseline.read_bytes())
    receipt.update(baseline_pack={'path': str(baseline), 'bytes': baseline.stat().st_size, 'sha256': actual_sha})
    if actual_sha != PACK_SHA:
        raise ValueError('Original main1b PCK fingerprint mismatch')
    pack = Pack(baseline)
    replacement, skip, comparisons = {}, set(), {}
    original_sources, instrumented_sources = {}, {}
    all_edits = {}
    source_directory = out / 'sources-main1b'
    instrumented_directory = out / 'sources-instrumented'
    for path, methods in MEASURE.items():
        original = git_source(path)
        edit = Edits(path, original)
        treatments(edit)
        observe(edit, methods)
        edit.verify_reverse()
        data = edit.text.encode()
        replacement[path] = data
        if path + '.remap' not in pack.entries:
            raise ValueError('Expected original script remap missing: ' + path)
        skip.add(path + '.remap')
        original_sources[path], instrumented_sources[path] = digest(original), digest(data)
        comparisons[path] = {'source_sha256': digest(original), 'instrumented_sha256': digest(data),
                             'reversed_body_exact_main1b': True, 'edit_labels': [e['label'] for e in edit.steps]}
        all_edits[path] = edit.steps
        for folder, payload in [(source_directory, original), (instrumented_directory, data)]:
            destination = folder / (path + '.txt')
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(payload)
    replacement[CASE_PATH] = CASE_SCRIPT.encode()
    probe_source = (ROOT / 'tools/mobile_web_perf/probe.gd').read_bytes()
    replacement[PROBE_PATH] = formal_probe(probe_source)
    target = out / 'diagnostic.pck'
    write_pack(pack, replacement, skip, target)
    result = Pack(target)
    unchanged = set(pack.entries) - skip - set(replacement)
    if set(result.entries) != unchanged | set(replacement):
        raise ValueError('Derived pack entry inventory mismatch')
    for path in unchanged:
        if result.entries[path] != pack.entries[path]:
            raise ValueError('Original payload offset/size/MD5 changed: ' + path)
    for path, data in replacement.items():
        if result.read(path) != data:
            raise ValueError('Instrumented payload mismatch: ' + path)
    reference_directory = ROOT / 'build/mobile_web_perf_01/formal-main-01'
    reference_production_unchanged = None
    if reference_directory.is_dir() and reference_directory.resolve() != out:
        reference_pack = Pack(reference_directory / 'diagnostic.pck')
        for path in MEASURE:
            if result.read(path) != reference_pack.read(path):
                raise ValueError('Observation-only revision changed prior production treatment: ' + path)
        if result.read(CASE_PATH) != reference_pack.read(CASE_PATH):
            raise ValueError('Observation-only revision changed startup case helper')
        reference_production_unchanged = True
    # Real formal main/compiled scene remain exact original entries; no alternate root.
    project = pack.read('project.binary')
    scene_remap = pack.read('scenes/demo/demo.tscn.remap')
    match = re.search(r'path="res://([^"]+)"', scene_remap.decode())
    if not match:
        raise ValueError('Original formal scene remap malformed')
    compiled_scene = match.group(1)
    scene_data = pack.read(compiled_scene)
    for path in ['project.binary', 'scenes/demo/demo.tscn.remap', compiled_scene]:
        if result.read(path) != pack.read(path):
            raise ValueError('Original main scene/settings modified: ' + path)
    if b'scenes/demo/demo.tscn' not in project and b'uid://' not in project:
        raise ValueError('Project main entry cannot be statically identified')
    engine_records = {}
    template = args.template.resolve()
    with ZipFile(template) as archive:
        for member in ['godot.js', 'godot.wasm', 'godot.audio.worklet.js', 'godot.audio.position.worklet.js']:
            name = member.replace('godot', ENGINE, 1)
            source = (args.engine_bundle / name).resolve()
            payload, official = source.read_bytes(), archive.read(member)
            if payload != official:
                raise ValueError('Engine/worklet differs from official nothreads_debug template: ' + name)
            (out / name).write_bytes(payload)
            engine_records[name] = {'path': str(source), 'sha256': digest(payload), 'bytes': len(payload),
                                    'template_member': member, 'official_template_sha256': digest(official)}
    observers = {}
    for name in ['audio_graph_probe.js', 'audio_probe.js', 'pcm_worklet.js', 'gpu_probe.js']:
        source = ROOT / 'tools/mobile_web_perf' / name
        data = source.read_bytes()
        if b'MOBILE_PERF_MASTER_ROUTING' in data:
            raise ValueError('Observer contains forbidden Master routing hook: ' + name)
        (out / name).write_bytes(data)
        observers[name] = {'source': str(source), 'sha256': digest(data), 'bytes': len(data)}
    # Formal action capture requests eight seconds. Keep the original two-second
    # minimal fixture separate so its historical reproduction stays unchanged.
    recorder = ROOT / 'tools/mobile_web_perf/formal_pcm_worklet.js'
    (out / 'minimal_pcm_worklet.js').write_bytes(recorder.read_bytes())
    observers['minimal_pcm_worklet.js'] = {'source': str(recorder),
        'sha256': digest(recorder.read_bytes()), 'bytes': recorder.stat().st_size}
    (out / 'index.html').write_bytes(html())
    diff = ''.join(''.join(difflib.unified_diff(git_source(path).decode().splitlines(True),
                       data.decode().splitlines(True), fromfile=COMMIT + '/' + path,
                       tofile='diagnostic/' + path)) for path, data in replacement.items() if path in MEASURE)
    (out / 'production-source.diff').write_text(diff)
    static = {'scope': 'Pack directory/payload identity and reversible allowlisted source edits; not engine parse/runtime acceptance',
              'original_entry_main_preserved': True, 'original_project_sha256': digest(project),
              'formal_scene_source_sha256': digest(git_source('scenes/demo/demo.tscn')),
              'formal_scene_remap_sha256': digest(scene_remap), 'compiled_formal_scene': compiled_scene,
              'compiled_formal_scene_sha256': digest(scene_data),
              'unchanged_entries_exact_offset_size_md5': len(unchanged), 'replaced_bytes_verified': len(replacement),
              'unlisted_source_body_edits': 0, 'production_sources': comparisons,
              'treatment_guards': {'bus_only': ['GameAudio.ensure_buses append via count'],
                                   'pause_only': ['GameAmbience pause state writes only'],
                                   'ambience_off': ['SelectedAmbienceRuntime._ready early return before deferred attach'],
                                   'original': []},
              'same_pack_for_all_cases': True, 'cases_must_start_in_separate_fresh_pages': True,
              'production_and_case_helper_exact_formal_main_01': reference_production_unchanged,
              'new_observation_only': ['current TouchOverlay local and global-canvas-projected coordinates',
                                      'root texture/viewport/window/screen transform metadata',
                                      'original jumped/shot_fired signal counters with frame/time; shot serial'],
              'audio_point_source_guard_unchanged': 'HomeAmbienceAudition due/visible/global_gap/voice.playing gates and source_anchors snapshot remain main1b body; only common timing wrapper.',
              'latest_device_feedback': 'User reports audio stutters while actions are nearly smooth and pause audio normal; prioritize audio continuity evidence. Frame timing is an independent guard, not a device rendering bottleneck claim.'}
    (out / 'static-source-comparison.json').write_text(json.dumps(static, indent=2) + '\n')
    (out / 'source-edits.json').write_text(json.dumps(all_edits, indent=2) + '\n')
    receipt.update(status='static_pass_runtime_unverified', source_commit=COMMIT, cases=CASES,
                   original_entry_main='unchanged project.binary and scenes/demo/demo.tscn remap/compiled scene',
                   diagnostic_pack={'path': 'diagnostic.pck', 'bytes': target.stat().st_size, 'sha256': digest(target.read_bytes())},
                   replaced=list(replacement), removed_remaps=sorted(skip), source_sha256=original_sources,
                   instrumented_source_sha256=instrumented_sources, measure=MEASURE,
                   official_engine_files=engine_records, official_template={'path': str(template), 'sha256': digest(template.read_bytes())},
                   external_observers=observers, helper_sha256=digest(replacement[CASE_PATH]),
                   root_probe_source_sha256=digest(probe_source), derived_probe_sha256=digest(replacement[PROBE_PATH]),
                   builder_sha256=digest(Path(__file__).read_bytes()), fixed_audio_latency_ms=50,
                   gpu_query_default=False, production_files_written=0,
                   limitations=['No Godot parse/native smoke or browser/PCM A/B executed by this builder.',
                                'Common inclusive script timing and audio acceptance observers add diagnostic overhead in every case.',
                                'Case original is an instrumented baseline, not the byte-identical official package.',
                                'No engine/Worklet/Master routing modification, no altered scene/UI/graphics/physics/RNG/resource/input production body.',
                                'Scene transition and cue_coin commands are explicit fixtures; coin request does not grant currency.',
                                'Each case uses its own new page/process lifecycle; no in-page mode-switch comparison.'])
    (out / 'build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'output': str(out), 'status': receipt['status'], 'diagnostic_pack_sha256': receipt['diagnostic_pack']['sha256']}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/mobile_web_perf_01/formal-main-02')
    parser.add_argument('--baseline-pack', type=Path, default=Path('/workspace/scratch/gunman-audio-diagnosis/index.618eb97114e6.pck'))
    parser.add_argument('--engine-bundle', type=Path, default=ROOT / 'build/web')
    parser.add_argument('--template', type=Path, default=Path('/workspace/toolchains/user-data/godot/export_templates/4.7.2.stable/web_nothreads_debug.zip'))
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    receipt = {'status': 'building', 'source_commit': COMMIT, 'expected_baseline_pack_sha256': PACK_SHA}
    try:
        build(args, out, receipt)
    except Exception as error:
        receipt.update(status='failed_preserved', error=str(error), traceback=traceback.format_exc())
        (out / 'build-failure.json').write_text(json.dumps(receipt, indent=2) + '\n')
        raise


if __name__ == '__main__':
    main()
