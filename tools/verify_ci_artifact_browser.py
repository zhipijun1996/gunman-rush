"""Verify exact CI artifact bytes with the existing real browser input scripts."""
import argparse, hashlib, json, os, pathlib, re, stat, subprocess, sys, time, zipfile
from functools import partial
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from threading import Thread
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import publish_playtest
import harness

def require(ok, message):
    if not ok:
        raise ValueError(message)

def sha(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        while (b := f.read(1024 * 1024)):
            h.update(b)
    return h.hexdigest()

def inventory(root):
    return {str(p.relative_to(root)): sha(p) for p in sorted(root.rglob('*')) if p.is_file()}

# One reviewed consumer-tool revision, not a general tools/tests exemption.
# Locator-only consumer migrations must also reverse to the complete reference Git bytes.
CONSUMER_REFERENCE_COMMIT = '37950e0896a91c6b812a11c323ec3d5fd1800bb0'
REVIEWED_TOOL_FILES = {'tools/studio_gui_pointer.py': 'aaeeb2fea8d96c329689560a3bbf67e1e82fe97f26519686963441f2be9ed129',
 'tools/verify_four_line_browser.py': 'ea641b56e1d2e6020211273157c3f6a6f51a3c0724d3e44241ad80c46cc2f29f',
 'tools/test_studio_gui_pointer.py': '2f1f7ff5975fa32a28020d6bc307f351391e5b899e4fb17f039de9d636bb7087',
 'tests/fixtures/studio_gui_pointer/title_37950_current.png': 'cc90b463b98b79e66e703a720fbd644c5de277e52ee2d4d5601894cccb321ff9',
 'tests/fixtures/studio_gui_pointer/title_37950_current.json': '570a8e2eb2a63dac2cc4785d44df0b0ae6ca4517e6d7d6d560e23eafc38fc5fa',
 'tools/verify_action_budget_browser.py': 'f95db7d7691231e82e72530553e02a3b4a5c5809f9eda4f9d4c1ec3e7ac372d3',
 'tools/verify_studio_click_browser.py': '675b97ec54e961492c770fa068bd478ad78cbd3a65faef0917588929a367cc71',
 'tools/verify_all_weapon_browser.py': '7905cc12f0224b8512f3268aac14abc0de9b4a99eea609dd1c0f88d72eb0fd10',
 'tests/fixtures/studio_gui_pointer/current_navigation_37950.json': 'a1ed617cbc56089e4b5f0d90871a67d02305a8a89f3a74c8db77ae3c74338b45',
 'tests/fixtures/studio_gui_pointer/navigation_touch_title_37950.png': '0858bb644054a9c46df4e5572f7a17ae53eee45cba6cb490102b1bf2a2dfa92e',
 'tests/fixtures/studio_gui_pointer/navigation_touch_actions_37950.png': '0f3ddd31c61e1f57762ffa7f0c14d30ebe506c4885fd3ff0ccaca80852763215',
 'tests/fixtures/studio_gui_pointer/controls_37950_desktop.png': 'cf6a5454814a4b01263ba895da9ccfe641e5085e4bb8e80ce5c0711f317c1285',
 'tests/fixtures/studio_gui_pointer/controls_37950_touch.png': '77f9f6cee7c56516a23822051557397460f44dbd24124f28d298adafb9645004',
 'tests/fixtures/studio_gui_pointer/popup_37950_desktop.png': '818c096cf86d089fe99c19c703bf8fc1453270aaa89cfba89aee24021b6334f2',
 'tests/fixtures/studio_gui_pointer/controls_37950_touch_mixed_derived.png': '3c89a4d0555e4803d15fed4c61cde88a75eb292bb1d771478b5992be079d04b3'}
REVIEWED_VISUAL_INPUTS = {'game/combat/weapons/weapon_catalog.gd': 'efd5300898afb95bc8e1d93f060db940b04d4ba75b52f7fe7dee6ea0023dd3b4',
 'scripts/combat/weapon_definition.gd': '5c4d8be2021279e1eb4f6e981116ba80e49811a8318681c15e6e241b2c70ec1b',
 'assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf': 'db40edf0cc1e446bfe1ce75d5abb4d7c499ace96379b8a0f5f761bd3de8335eb',
 'game/presentation/ui/demo_ui_01/clockwork_theme.gd': '37d1f71e185b9c4374d86d5fb8ac15da6e2e73031e1faacf9e88e47625532dd9',
 'game/presentation/ui/demo_ui_01/game_typography.gd': 'd1f317206cc7bbab5b262153e032ff4bfd323f829450a571c78e437f553a17e7',
 'experiments/motion/action_studio.gd': '1b7657046a4aad2e90d56ecce8c6024df7fede7ea344b9267b58de51e66195dc',
 'resources/weapons/pulse_gun.tres': 'd9c7341e1ae5bacb74740996215fac8e1173a1053a6d492333a8593adddb5b6a',
 'resources/weapons/shadow_shuriken.tres': 'daa39868c480f9750eb692d7a86a922e7900c42fffd1143f4923e113859f6272',
 'resources/weapons/recoil_bomb.tres': '7aac77c9cc7e455c2eb3900e9f7eace3b8c4c8532cc36fb448c2100d23d29407',
 'resources/weapons/triple_machine_gun.tres': '61c6ff329059a3d7fc3aefb8c466664fef81705f8a05635dc0e3959e787b5958',
 'resources/weapons/sustained_laser.tres': '6a63ac28c26f3271c602fb0ea41d7fa935c9d2818e48b6c4ce5f6648c0321641',
 'resources/weapons/fan_shuriken.tres': '00aaa1d562856d9dc5088a2f5a8683079f389e1eb567719b794bad2e83b5b22c',
 'resources/weapons/remote_boomerang.tres': '0bcd5f6088fc70a53e75af43161e7916f262b140ce27566d8d96601397898e41',
 'resources/weapons/magnetic_mine.tres': 'aa25a81862e2fc1d19ac766a28b947f259e5933092a6a790eaa242da8825a897',
 'resources/weapons/collapse_singularity.tres': '7b39a71b017ad0810ed54b09b3a96d6405174ddf38a7edf55ac64284b34fe3fc',
 'resources/weapons/machine_storm.tres': 'daf62fe0acdc0a52886140d4bc4eab1f5caa63e7efca4464f8b74fe91f81ce2e',
 'resources/weapons/laser_cannon.tres': 'b529bbdf56cbc9e9a5a854ec99b684262405711d6735ae2e892ed6e4118b12c6',
 'resources/weapons/blade_bloom.tres': 'ffb4be5302daeba74674d8556dcfd253e7402dba1fe68248db422249c19f7d18',
 'resources/weapons/moon_boomerang.tres': '56cbdba1f68adbe9a4fbe6b4b1f051993d867d132412194baca34c3ad49bbbc0',
 'resources/weapons/magnetic_storm.tres': 'e83da8ec575f745017d9fce0bca590860341e39dc1b89936c23c477bfc46037f',
 'resources/weapons/star_collapse.tres': '6246dc3bd4f47690c2b0dc0ef8b82c575c0e3290cd3d9cc0ec3fd55774a52c36',
 'game/presentation/ui/demo_menu.gd': '35f27a52f675fd3227b16d5231b8f4ad6c6220a3a09f756f7deb7b8c4e85991f',
 'game/presentation/ui/underworld_ui.gd': '0a6d717ef7a9f02e40b003a8f40850b4007634485b1f7ca6882086b43ec378ce',
 'game/presentation/ui/menu_theme.gd': '59e7d3012fca992901c2088f3965d0be54969c07b112fdce75e4776a349cb5b3',
 'game/player/actions/traversal_ability.gd': '36aae4b822563f6b2e391af2da1948564c934ab8e73f26578a9545b5b2eab369'}
REFERENCE_CONSUMER_SHA256 = {'tools/verify_action_budget_browser.py': '6892d970f6272915cf99b2897d140299d41b744ce76379c7d9f286d5284f48ca',
 'tools/verify_all_weapon_browser.py': 'c4f069fb1c5775145dde9b1be2564bd08959ff7c773c108f7ce41e3cc27f7272',
 'tools/verify_studio_click_browser.py': '8b1b17a7e29d1b01b45db4dc58726dfe901dc049bf12ab1bac488edf890f4825'}
CONSUMER_MIGRATIONS = {'tools/verify_action_budget_browser.py': [['from studio_gui_pointer import '
                                            'select_weapon,weapon_row_y,enter_action_studio',
                                            'from studio_gui_pointer import '
                                            'select_weapon,studio_control_point,enter_action_studio',
                                            1],
                                           ['await page.mouse.click(710,await weapon_row_y(page))',
                                            'await page.mouse.click(*(await '
                                            "studio_control_point(page,'training')))",
                                            1],
                                           ['await page.mouse.click(330,await weapon_row_y(page))',
                                            'await page.mouse.click(*(await '
                                            "studio_control_point(page,'practice')))",
                                            1],
                                           ['await page.mouse.click(500,100)',
                                            'await page.mouse.click(*(await '
                                            "studio_control_point(page,'hook_practice')))",
                                            2],
                                           ['from studio_gui_pointer import '
                                            'select_weapon,studio_control_point,enter_action_studio',
                                            'from studio_gui_pointer import '
                                            'select_weapon,studio_control_point,enter_action_studio,studio_hook_reference_point',
                                            1],
                                           ["await page.mouse.click(560,245,button='right')",
                                            'await '
                                            "page.mouse.click(*studio_hook_reference_point(page,'oblique'),button='right')",
                                            1],
                                           ["await page.mouse.click(432,230,button='right')",
                                            'await '
                                            "page.mouse.click(*studio_hook_reference_point(page,'vertical'),button='right')",
                                            1],
                                           ['studio_hook_reference_point', 'studio_reference_aim_point', 3],
                                           ['await page.mouse.move(790,250)',
                                            'await '
                                            "page.mouse.move(*studio_reference_aim_point(page,'air_blade_focus'))",
                                            1]],
 'tools/verify_all_weapon_browser.py': [['from studio_gui_pointer import select_weapon, weapon_row_y, '
                                         'enter_action_studio',
                                         'from studio_gui_pointer import select_weapon, '
                                         'studio_control_point, enter_action_studio',
                                         1],
                                        ['await page.mouse.click(710,150)',
                                         'await page.mouse.click(*(await '
                                         "studio_control_point(page,'training')))",
                                         1],
                                        ['await page.mouse.click(330,await weapon_row_y(page))',
                                         'await page.mouse.click(*(await '
                                         "studio_control_point(page,'practice')))",
                                         1],
                                        ['await page.touchscreen.tap(350,54)',
                                         'await page.touchscreen.tap(*(await '
                                         "studio_control_point(page,'hook_practice')))",
                                         1]],
 'tools/verify_studio_click_browser.py': [['from studio_gui_pointer import weapon_row_y, select_weapon, '
                                           'open_weapon_picker, enter_action_studio',
                                           'from studio_gui_pointer import studio_control_point, '
                                           'select_weapon, open_weapon_picker, enter_action_studio',
                                           1],
                                          ['y=await weapon_row_y(page);n=len(events);await '
                                           'click(pad+710*scale,y)',
                                           'point=await '
                                           "studio_control_point(page,'training');n=len(events);await "
                                           'click(*point)',
                                           2]]}
COORDINATOR_FILES = {'tools/verify_ci_artifact_browser.py', 'tools/test_verify_ci_artifact_browser.py'}
CONSUMERS = ('verify_action_budget_browser', 'verify_studio_click_browser', 'verify_all_weapon_browser')


def git(root, *args):
    return subprocess.check_output(['git', *args], cwd=root, timeout=30)


def tree(root, commit):
    result = {}
    for row in git(root, 'ls-tree', '-rz', '--full-tree', commit).split(b'\0'):
        if row:
            metadata, name = row.split(b'\t', 1)
            mode, kind, oid = metadata.decode().split()
            require(kind == 'blob' and mode in ('100644', '100755'), 'Unsupported source entry')
            result[name.decode()] = (mode, oid)
    return result


def file_identity(path, oid, object_format, mode):
    # Verify actual bytes against Git even when skip-worktree hides a local edit.
    require(not path.is_symlink(), f'Symlink source: {path}')
    if not path.exists():
        return 'deleted'
    before = path.stat()
    key = harness.SourceHashCache._key
    require(bool(before.st_mode & 0o111) == (mode == '100755'), f'Source mode differs from Git: {path}')
    require(stat.S_ISREG(before.st_mode), f'Non-regular source: {path}')
    for parent in path.parents:
        require(not parent.is_symlink(), f'Symlink source parent: {parent}')
    sha256 = hashlib.sha256()
    blob = hashlib.new(object_format)
    blob.update(f'blob {before.st_size}\0'.encode())
    with path.open('rb') as source:
        require(key(os.fstat(source.fileno())) == key(before), f'Source replaced: {path}')
        while chunk := source.read(1024 * 1024):
            sha256.update(chunk)
            blob.update(chunk)
        require(key(os.fstat(source.fileno())) == key(before), f'Source changed: {path}')
    require(key(path.stat()) == key(before), f'Source replaced: {path}')
    require(blob.hexdigest() == oid, f'Actual source differs from Git blob: {path}')
    return sha256.hexdigest()


class SourceRoot:
    def __init__(self, path, commit):
        self.path = pathlib.Path(path).absolute()
        self.resolved = self.path.resolve(strict=True)
        self.commit = commit
        require(len(commit) in (40, 64) and all(c in '0123456789abcdef' for c in commit), 'Exact commit required')
        self.location = self._location()

    def _location(self):
        root = self.path.resolve(strict=True)
        common = pathlib.Path(git(root, 'rev-parse', '--path-format=absolute', '--git-common-dir').decode().strip())
        git_dir = pathlib.Path(git(root, 'rev-parse', '--absolute-git-dir').decode().strip())
        return (str(root), root.stat().st_dev, root.stat().st_ino,
                str(common), common.stat().st_dev, common.stat().st_ino,
                str(git_dir), git_dir.stat().st_dev, git_dir.stat().st_ino)

    def snapshot(self):
        require(self._location() == self.location, 'Source root replaced')
        require(git(self.resolved, 'rev-parse', 'HEAD').decode().strip() == self.commit, 'Source HEAD differs from expected commit')
        require(not git(self.resolved, 'status', '--porcelain').strip(), 'source worktree changed')
        entries = tree(self.resolved, self.commit)
        require(set(harness.source_files(self.resolved)) == set(entries), 'Source index/working input list differs from commit')
        object_format = git(self.resolved, 'rev-parse', '--show-object-format').decode().strip()
        files = {name: file_identity(self.resolved / name, entry[1], object_format, entry[0])
                 for name, entry in entries.items()}
        return {'root': str(self.resolved), 'commit': self.commit, 'location': self.location,
                'git_entries': entries, 'source_sha256': files}


def verify_consumer_migrations(production, consumer):
    """Only approved locator/import edits; never normalize business assertions."""
    expected = {f'tools/{name}.py' for name in CONSUMERS}
    require(set(CONSUMER_MIGRATIONS) == expected == set(REFERENCE_CONSUMER_SHA256),
            'Incomplete consumer migration contract')
    for name in sorted(expected):
        original = pathlib.Path(production['root']) / name
        current = pathlib.Path(consumer['root']) / name
        require(production['source_sha256'].get(name) == REFERENCE_CONSUMER_SHA256[name],
                f'Production consumer differs from reference Git bytes: {name}')
        restored = current.read_bytes()
        for old, new, count in reversed(CONSUMER_MIGRATIONS[name]):
            old, new = old.encode('utf-8'), new.encode('utf-8')
            require(restored.count(new) == count, f'Consumer migration occurrence mismatch: {name}')
            restored = restored.replace(new, old)
        require(restored == original.read_bytes(), f'Consumer inverse differs from reference: {name}')
        require(hashlib.sha256(restored).hexdigest() == REFERENCE_CONSUMER_SHA256[name],
                f'Consumer reference hash mismatch: {name}')


def validate_tool_pair(production, consumer, executing_file):
    game_tree, tool_tree = production['git_entries'], consumer['git_entries']
    allowed = set(REVIEWED_TOOL_FILES) | COORDINATOR_FILES
    changed = {name for name in game_tree.keys() | tool_tree.keys() if game_tree.get(name) != tool_tree.get(name)}
    require(changed <= allowed, f'Unreviewed tool-root changes: {sorted(changed - allowed)}')
    tool_root = pathlib.Path(consumer['root'])
    require(pathlib.Path(executing_file).resolve() == tool_root / 'tools/verify_ci_artifact_browser.py',
            'Coordinator must execute from the frozen consumer tool root')
    for name, digest in REVIEWED_TOOL_FILES.items():
        require(consumer['source_sha256'].get(name) == digest, f'Unreviewed tool bytes: {name}')
    for name, digest in REVIEWED_VISUAL_INPUTS.items():
        require(production['source_sha256'].get(name) == digest == consumer['source_sha256'].get(name),
                f'Incompatible actual visual input: {name}')
    verify_consumer_migrations(production, consumer)
    required = [f'tools/{name}.py' for name in CONSUMERS] + [
        'tools/harness.py', 'tools/publish_playtest.py', 'tools/verify_ci_artifact_browser.py',
        'resources/player/traversal.tres']
    traversal = tool_root / 'resources/player/traversal.tres'
    require(traversal.is_file(), 'Missing actual traversal Resource')
    if not re.search(r'^hook_vertical_kick_deadzone = ([\d.]+)$', traversal.read_text(), re.M):
        required.append('scripts/player/traversal_definition.gd')
    for name in required:
        require(consumer['source_sha256'].get(name) not in (None, 'deleted'), f'Missing consumer input: {name}')
        if name not in allowed:
            require(production['source_sha256'].get(name) == consumer['source_sha256'].get(name),
                    f'Prepared consumer inputs differ: {name}')
    # Other tracked files were compared by Git blob above; every materialized file
    # in either root was independently checked against that blob by snapshot().
    # The reference commit dates the screenshots/consumer source, not the game API identity.
    # Sparse absences are recorded, never claimed to be browser-read inputs.
    return sorted(changed)


def require_unchanged_files(before):
    for name, digest in before.items():
        require(sha(pathlib.Path(name)) == digest, f'Artifact/API bytes changed: {name}')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--run-api', type=pathlib.Path, required=True)
    p.add_argument('--artifact-api', type=pathlib.Path, required=True)
    p.add_argument('--artifact-zip', type=pathlib.Path, required=True)
    p.add_argument('--commit', required=True)
    p.add_argument('--run-id', type=int, required=True)
    p.add_argument('--attempt', type=int, default=1)
    p.add_argument('--output', type=pathlib.Path, required=True)
    p.add_argument('--production-source-root', type=pathlib.Path)
    p.add_argument('--consumer-tool-root', type=pathlib.Path)
    p.add_argument('--consumer-tool-commit')
    a = p.parse_args()
    explicit = (a.production_source_root, a.consumer_tool_root, a.consumer_tool_commit)
    require(all(x is not None for x in explicit) or all(x is None for x in explicit), 'Supply all three explicit tool-version arguments together')
    dual = all(x is not None for x in explicit)
    production_root = (a.production_source_root if dual else ROOT).resolve(strict=True)
    consumer_root = (a.consumer_tool_root if dual else ROOT).resolve(strict=True)
    require(consumer_root == ROOT, 'Run the coordinator from the selected consumer tool root')
    if dual:
        require(not os.environ.get('PYTHONPATH'), 'Explicit tool roots do not use PYTHONPATH')
    a.output = a.output.resolve()
    require(a.output.is_relative_to(production_root / 'build'), 'Use a new directory under build')
    require(a.attempt > 0, 'CI artifact/browser identity requirement failed')
    a.output.mkdir(parents=True, exist_ok=False)
    report = {'status': 'failed', 'source_commit': a.commit, 'run_id': a.run_id, 'started_at_unix': time.time(), 'browser_results': [], 'scope': 'Real desktop canvas and Chromium CDP touch against unchanged exact CI artifact bytes; not native movie or physical device approval'}
    server = None
    guarded = []
    fixed_files = {}
    try:
        production = SourceRoot(a.production_source_root if dual else ROOT, a.commit)
        before_game = production.snapshot()
        guarded.append((production, before_game))
        if dual:
            consumer = SourceRoot(a.consumer_tool_root, a.consumer_tool_commit)
            before_tool = consumer.snapshot()
            guarded.append((consumer, before_tool))
            changes = validate_tool_pair(before_game, before_tool, __file__)
            for module in (harness, publish_playtest):
                require(pathlib.Path(module.__file__).resolve().parent == consumer_root / 'tools', 'Imported helper outside frozen tool root')
        else:
            before_tool, changes = before_game, []
        report.update(production_source=before_game, consumer_tools=before_tool, reviewed_tool_changes=changes,
                      consumer_tool_commit=before_tool['commit'], dual_root_mode=dual)
        if dual:
            report.update(consumer_reference_commit=CONSUMER_REFERENCE_COMMIT,
                          reference_consumer_sha256=REFERENCE_CONSUMER_SHA256,
                          visual_compatibility_sha256=REVIEWED_VISUAL_INPUTS,
                          consumer_migrations_verified=True)
        fixed_files = {str(path.resolve()): sha(path) for path in (a.run_api, a.artifact_api, a.artifact_zip)}
        report['fixed_artifact_inputs'] = dict(fixed_files)
        if dual:
            prefix = os.environ.get('TESSDATA_PREFIX')
            require(bool(prefix), 'Explicit tool mode requires an attributable TESSDATA_PREFIX')
            tessdata = pathlib.Path(prefix).resolve(strict=True)
            models = {str(tessdata / (name + '.traineddata')): sha(tessdata / (name + '.traineddata'))
                      for name in ('eng', 'chi_sim', 'osd')}
            models[str(tessdata / 'configs/tsv')] = sha(tessdata / 'configs/tsv')
            fixed_files.update(models)
            report['ocr_environment'] = {'TESSDATA_PREFIX': prefix, 'resolved_root': str(tessdata), 'input_sha256': models}
        run = json.loads(a.run_api.read_text())
        require(run['id'] == a.run_id and run['head_sha'] == a.commit and (run['run_attempt'] == a.attempt), 'CI artifact/browser identity requirement failed')
        report.update(attempt=run['run_attempt'], run_api_sha256=sha(a.run_api), artifact_api_sha256=sha(a.artifact_api), coordinator_sha256=sha(pathlib.Path(__file__)))
        api = json.loads(a.artifact_api.read_text())
        require(api['workflow_run']['id'] == a.run_id and api['workflow_run']['head_sha'] == a.commit, 'CI artifact/browser identity requirement failed')
        events = []
        info, receipt = publish_playtest.verify_artifact_zip(a.artifact_zip.resolve(), api, a.commit, events)
        report.update(build_info=info, artifact_receipt=receipt, artifact_validation_events=events)
        web = a.output / 'web'
        web.mkdir()
        with zipfile.ZipFile(a.artifact_zip) as z:
            require(sum((i.file_size for i in z.infolist())) <= 2 * 1024 ** 3, 'CI artifact/browser identity requirement failed')
            for i in z.infolist():
                target = (web / i.filename).resolve()
                require(target.is_relative_to(web), 'CI artifact/browser identity requirement failed')
                if i.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with z.open(i) as source, target.open('xb') as dest:
                    while (b := source.read(1024 * 1024)):
                        dest.write(b)
        roots = list(web.rglob('build-info.json'))
        require(len(roots) == 1, 'CI artifact/browser identity requirement failed')
        web = roots[0].parent
        report['served_directory'] = str(web)
        before = inventory(web)
        report['web_inventory_before'] = before
        require(sha(web / info['pack']) == receipt['pack_sha256'], 'CI artifact/browser identity requirement failed')

        class Quiet(SimpleHTTPRequestHandler):

            def log_message(self, *args):
                pass
        server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Quiet, directory=str(web)))
        Thread(target=server.serve_forever, daemon=True).start()
        url = f'http://127.0.0.1:{server.server_port}/'
        report['url'] = url
        cwd = a.output / 'browser-cwd'
        cwd.mkdir()
        for name in CONSUMERS:
            script = consumer_root / 'tools' / f'{name}.py'
            cmd = [sys.executable, str(script), url]
            started = time.time()
            log = a.output / f'{name}.log'
            pattern = '"failed": \\[\\]' if name == 'verify_action_budget_browser' else '"failed": 0'
            result = harness.run_check({'argv': cmd, 'timeout_seconds': 300, 'success_pattern': pattern}, log, root=cwd)
            item = {'command': cmd, 'cwd': str(cwd), 'script_sha256': sha(script), 'log': str(log), 'log_sha256': sha(log), **result}
            report['browser_results'].append(item)
            require(result['status'] == 'passed', f'{name} failed; original preserved')
        after = inventory(web)
        report['web_inventory_after'] = after
        require(after == before, 'served artifact changed during browser validation')
        report['status'] = 'passed'
        return 0
    except BaseException as e:
        report['error'] = str(e)
        raise
    finally:
        if server:
            server.shutdown()
            server.server_close()
        guard_errors = []
        try:
            require_unchanged_files(fixed_files)
            for guard, before_source in guarded:
                require(guard.snapshot() == before_source, 'Source changed during browser validation')
        except BaseException as error:
            guard_errors.append(str(error))
            report['status'] = 'failed'
            report['guard_errors'] = guard_errors
        report['ended_at_unix'] = time.time()
        report['duration_seconds'] = report['ended_at_unix'] - report['started_at_unix']
        (a.output / 'receipt.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({k: report.get(k) for k in ['status', 'source_commit', 'consumer_tool_commit', 'run_id', 'duration_seconds', 'error']}, ensure_ascii=False), flush=True)
        require(not guard_errors, '; '.join(guard_errors))
if __name__ == '__main__':
    sys.exit(main())
