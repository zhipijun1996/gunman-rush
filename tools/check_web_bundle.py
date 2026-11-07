"""Verify cached bytes and the runtime resource closure inside the actual Web PCK."""
import ast
import gzip
import fnmatch
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

# Reuse the installer's locked upstream inventory; do not maintain a second
# addon/hash registry in the export checker.
sys.path.insert(0, str(Path(__file__).resolve().parent))

REPO = Path(__file__).resolve().parents[1]
SPACES = 'assets/region_production_v3/spaces/'
LANDSCAPE = 'game/presentation/world/art/plains_semantic_landscape.gd'
ROOT_BELL = 'game/enemies/presentation/root_bell_presentation.gd'
TERRAIN = 'game/presentation/world/art/plains_terrain_family_sampler.gd'
BACKGROUND = 'game/presentation/world/art/plains_background.gd'
CONNECTED = 'game/presentation/world/art/plains_connected_landscape.gd'
CONNECTED_ROOT = 'assets/production_repair/'
MAPGEN_FROZEN_SOURCE = 'experiments/generation/runtime_map_frozen_source.gd'
MAPGEN_FROZEN_ROOT = 'resources/levels/mapgen_host_v2_01/'
MAPGEN_FROZEN_MEMBERS = ('map.json', 'bindings.json', 'selection.json',
                         'content/M16.json', 'content/M18.json', 'content/M21.json')
MAPGEN_CANDIDATE_CONFIG = 'config/mapgen_candidate.json'
MAPGEN_MODULE_ZIP = 'resources/mapgen/module-pack-1.1.0.zip'
MAPGEN_REQUEST = 'resources/mapgen/conformance_request.json'
MAPGEN_GENERATOR_CONFIG = 'resources/mapgen/generator_config.json'
MAPGEN_GEARS_REQUEST = 'resources/mapgen/gears_request_930007.json'
MAPGEN_GENERATED_SOURCE = 'experiments/generation/runtime_map_generated_slice.gd'
MAPGEN_DEFAULT_BINDINGS = 'resources/levels/mapgen_host_v4/bindings.json'
MAPGEN_M35_SOURCE = 'experiments/generation/runtime_map_m35_slice.gd'
MAPGEN_M35_BINDINGS = 'resources/levels/mapgen_host_v4_gears/bindings.json'
MAPGEN_WINDCHIME_SOURCE = 'experiments/generation/runtime_map_windchime_slice.gd'
MAPGEN_WINDCHIME_BINDINGS = 'resources/levels/mapgen_host_041_windchime/bindings.json'
EVIDENCE_ONLY_FAMILIES = tuple(SPACES + 'boss_open_tuning_court_v' + str(version) + '/'
                               for version in (1, 2)) + (SPACES + 'woodland_two_depth_ridges_v2/',
                                                        SPACES + 'supported_overhang_limestone_bank_v1/',
                                                        CONNECTED_ROOT + 'connected_cliff_v1/',
                                                        CONNECTED_ROOT + 'connected_cliff_v2/')


def verify_delivery_metadata(root, commit):
    """Check transported metadata after full Harness output custody verification.

    This does not replace the original PCK/runtime-closure check; the full
    release proof must already bind every transported byte, including metadata.
    """
    root = Path(root)
    metadata = json.loads((root / "build-info.json").read_text())
    if not re.fullmatch(r"[0-9a-f]{40}", commit) or metadata.get("source_commit") != commit:
        raise ValueError("Transferred Web metadata belongs to a different source commit")
    name = metadata.get("pack")
    if (not isinstance(name, str) or not name or name != Path(name).name
            or "\\" in name or not name.endswith(".pck")):
        raise ValueError("Invalid transferred Web pack path")
    pack = root / name
    if pack.is_symlink() or not pack.is_file():
        raise ValueError("Missing/linked transferred Web pack")
    with pack.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if (metadata.get("build_id") != digest[:12]
            or type(metadata.get("pack_bytes")) is not int
            or metadata["pack_bytes"] != pack.stat().st_size):
        raise ValueError("Transferred Web pack bytes disagree with metadata")
    return metadata


def excluded_evidence_families(repo):
    """Removal from every preset is required before adding a runtime consumer."""
    preset = Path(repo) / 'export_presets.cfg'
    if not preset.is_file():
        return EVIDENCE_ONLY_FAMILIES
    filters = re.findall(r'^exclude_filter="([^"\n]*)"', preset.read_text(), re.MULTILINE)
    return tuple(family for family in EVIDENCE_ONLY_FAMILIES
                 if any(fnmatch.fnmatchcase(family + 'source.png', pattern)
                        for value in filters for pattern in value.split(',')))


def check_excluded_consumers(repo):
    families = excluded_evidence_families(repo)
    suffixes = {'.gd', '.tscn', '.tres', '.json', '.gdshader', '.gdshaderinc', '.cfg',
                '.gdextension', '.cs', '.glsl', '.shader', '.res', '.scn'}
    for directory in ('scripts', 'scenes', 'resources', 'config', 'game', 'experiments'):
        for source in (Path(repo) / directory).rglob('*'):
            if source.is_file() and source.suffix in suffixes:
                data = source.read_bytes()
                for family in families:
                    # Also catches a family ID joined to FAMILY_ROOT at runtime.
                    if Path(family).name.encode() in data:
                        raise ValueError('Runtime consumer references excluded evidence-only family; '
                                         'remove its export exclusion first: ' + str(source))
    return families


def resource_path(value):
    """Pack and contract paths must stay inside the project, without aliases."""
    if not isinstance(value, str):
        raise ValueError('Runtime resource path must be a string')
    value = value.removeprefix('res://')
    if not value or '\\' in value or '\0' in value or any(p in ('', '.', '..') for p in value.split('/')) or ':' in value:
        raise ValueError('Invalid runtime resource path: ' + value)
    return value


class Pack:
    """Standalone, unencrypted Godot format 4; read the real directory, not strings."""
    def __init__(self, path):
        self.path = Path(path)
        length = self.path.stat().st_size
        self.entries = {}
        with self.path.open('rb') as stream:
            def read(size):
                value = stream.read(size)
                if len(value) != size:
                    raise ValueError('Truncated PCK directory/header')
                return value
            header = read(112)
            if header[:4] != b'GDPC' or struct.unpack_from('<I', header, 4)[0] != 4:
                raise ValueError('Expected standalone Godot PCK format 4')
            flags = struct.unpack_from('<I', header, 20)[0]
            if flags != 2:
                raise ValueError('Unsupported/encrypted PCK flags')
            self.file_base, directory = struct.unpack_from('<QQ', header, 24)
            if not 112 <= self.file_base <= directory < length:
                raise ValueError('Invalid PCK file/directory bounds')
            stream.seek(directory)
            count = struct.unpack('<I', read(4))[0]
            if count > (length - directory - 4) // 40:
                raise ValueError('Invalid PCK entry count')
            for _ in range(count):
                size = struct.unpack('<I', read(4))[0]
                if not 0 < size <= 65536:
                    raise ValueError('Invalid PCK path length')
                name = resource_path(read(size).rstrip(b'\0').decode('utf-8'))
                offset, amount = struct.unpack('<QQ', read(16))
                md5 = read(16)
                entry_flags = struct.unpack('<I', read(4))[0]
                offset += self.file_base
                if entry_flags or name in self.entries or not self.file_base <= offset <= directory or amount > directory - offset:
                    raise ValueError('Invalid/duplicate/flagged PCK entry: ' + name)
                self.entries[name] = (offset, amount, md5)
            if stream.tell() != length:
                raise ValueError('PCK directory does not end at EOF')

    def read(self, name):
        name = resource_path(name)
        if name not in self.entries:
            raise ValueError('PCK missing runtime resource: ' + name)
        offset, size, expected = self.entries[name]
        with self.path.open('rb') as stream:
            stream.seek(offset)
            data = stream.read(size)
        if len(data) != size or hashlib.md5(data).digest() != expected:
            raise ValueError('PCK resource bytes/MD5 changed: ' + name)
        return data


def mapgen_candidate_contract(repo):
    """The installed config owns paths; original installer pins own revisions."""
    repo = Path(repo).resolve()
    config_path = repo / MAPGEN_CANDIDATE_CONFIG
    if not config_path.is_file():
        if (repo / 'experiments/generation/runtime_map_generated_slice.gd').is_file():
            raise ValueError('Generated mapgen consumer lacks its installed config lock')
        return None
    import install_mapgen_candidate as mapgen_install
    # The original installer owns every approved byte, including the complete
    # config lock. Config edits cannot bless a new addon or ZIP revision.
    hashes = mapgen_install.installed_hashes()
    mapgen_install.preflight(repo, hashes, True)
    config = json.loads(config_path.read_text())
    addons = config['addon_files']
    paths = [config['module_package']['path']]
    for profile in ('conformance', 'gears_conformance'):
        paths += [config[profile]['request']['path'], config[profile]['config']['path']]
    data = {resource_path(path): hashes[resource_path(path)] for path in paths}
    return {'config': MAPGEN_CANDIDATE_CONFIG, 'addons': addons, 'data': data}


def check_mapgen_payload(pack, repo):
    contract = mapgen_candidate_contract(repo)
    # Normal resource conversion remains permitted; raw ZIP admission is exact.
    for name in pack.entries:
        lower = name.lower()
        if (lower.endswith(('.py', '.pyc', '.pyo'))
                or lower.split('/')[0] in ('docs', 'tests', 'tools')
                or 'evidence' in lower.split('/')):
            raise ValueError('PCK contains a development-only payload: ' + name)
        if lower.endswith('.zip') and (contract is None or name != MAPGEN_MODULE_ZIP):
            raise ValueError('PCK contains an unadmitted ZIP: ' + name)
    if contract is None:
        return None
    for name, digest in contract['data'].items():
        if hashlib.sha256(pack.read(name)).hexdigest() != digest:
            raise ValueError('PCK mapgen data differs from its installed SHA: ' + name)
    converted_targets = set()
    for name, digest in contract['addons'].items():
        present = False
        if name in pack.entries:
            if hashlib.sha256(pack.read(name)).hexdigest() != digest:
                raise ValueError('PCK raw mapgen addon differs from its original SHA: ' + name)
            present = True
        if name + '.remap' in pack.entries:
            mapping = pack.read(name + '.remap').decode('utf-8')
            matches = re.findall(r'^path="(res://[^"\n]+)"$', mapping, re.MULTILINE)
            if len(matches) != 1:
                raise ValueError('Mapgen addon needs one normal export remap: ' + name)
            target = resource_path(matches[0])
            if not target.endswith(('.gdc', '.gd')) or not pack.read(target):
                raise ValueError('Mapgen addon lacks its converted script: ' + name)
            if target.endswith('.gd') and hashlib.sha256(pack.read(target)).hexdigest() != digest:
                raise ValueError('PCK remapped mapgen source differs from its original SHA: ' + name)
            if target.startswith('addons/mapgen/') and target not in (name, name[:-3] + '.gdc'):
                raise ValueError('Mapgen addon remap targets an unadmitted addon member: ' + name)
            converted_targets.add(target)
            present = True
        if not present:
            raise ValueError('PCK lacks installed mapgen addon: ' + name)
    allowed_addons = set(contract['addons'])
    allowed_addons |= {name + suffix for name in contract['addons'] for suffix in ('.remap', '.uid')}
    allowed_addons |= converted_targets
    allowed_data = set(contract['data'])
    allowed_data |= {name + suffix for name in contract['data'] if name.endswith('.json')
                     for suffix in ('.import', '.remap')}
    for name in pack.entries:
        if name.startswith('addons/mapgen/') and name not in allowed_addons:
            raise ValueError('PCK contains an unadmitted mapgen addon member: ' + name)
        if name.startswith('resources/mapgen/') and name not in allowed_data:
            raise ValueError('PCK contains an unadmitted mapgen data member: ' + name)
    return {'addon_scripts': sorted(contract['addons']), 'data_sha256': contract['data'],
            'scope': 'Exact installed dependencies and actual PCK bytes; no runtime generation/rendering claim'}


def runtime_contract(repo):
    """Finite adapters for integrated consumers; absent child consumers stay pending."""
    repo = Path(repo).resolve()
    manifests, textures, pending = {}, {}, []

    def local(name):
        name = resource_path(name)
        path = (repo / name).resolve()
        if not path.is_relative_to(repo) or not path.is_file():
            raise ValueError('Integrated consumer lacks source resource: ' + name)
        return path.read_bytes()

    def texture(name, expected, raw):
        name = resource_path(name)
        if not re.fullmatch(r'[0-9a-f]{64}', str(expected)) or hashlib.sha256(local(name)).hexdigest() != expected:
            raise ValueError('Runtime source PNG differs from its contract: ' + name)
        previous = textures.get(name, {})
        textures[name] = {'sha256': expected, 'raw': raw or previous.get('raw', False)}

    def manifest(name):
        name = resource_path(name)
        data = json.loads(local(name))
        if not isinstance(data, dict):
            raise ValueError('Runtime JSON must be an object: ' + name)
        manifests[name] = data
        return data

    generated = mapgen_candidate_contract(repo)
    if generated is not None:
        manifest(generated['config'])
        for name in generated['data']:
            if name.endswith('.json'):
                manifest(name)

    for consumer, prefix, binding in (
            (MAPGEN_GENERATED_SOURCE, 'DEFAULT_BINDINGS', MAPGEN_DEFAULT_BINDINGS),
            (MAPGEN_M35_SOURCE, 'BINDINGS', MAPGEN_M35_BINDINGS),
            (MAPGEN_WINDCHIME_SOURCE, 'BINDINGS', MAPGEN_WINDCHIME_BINDINGS)):
        if not (repo / consumer).is_file():
            continue
        # Host bindings are independent of the upstream config lock. Each
        # actual consumer owns its SHA; no second hash registry is introduced.
        source = (repo / consumer).read_text()
        declarations = {}
        for key in (prefix + '_PATH', prefix + '_SHA256'):
            values = re.findall(r'^const ' + key + r'\s*(?::\s*String)?\s*:?=\s*"([^"\n]+)"\s*$',
                                source, re.MULTILINE)
            if len(values) != 1:
                raise ValueError('Mapgen host consumer needs one finite ' + key + ' declaration: ' + consumer)
            declarations[key] = values[0]
        name = resource_path(declarations[prefix + '_PATH'])
        if declarations[prefix + '_PATH'] != 'res://' + binding:
            raise ValueError('Mapgen host consumer bindings path changed; review finite export adapter: ' + consumer)
        expected = declarations[prefix + '_SHA256']
        if not re.fullmatch(r'[0-9a-f]{64}', expected) or hashlib.sha256(local(name)).hexdigest() != expected:
            raise ValueError('Mapgen host bindings differ from their actual consumer SHA: ' + name)
        manifest(name)

    frozen_source = repo / MAPGEN_FROZEN_SOURCE
    if frozen_source.is_file():
        root = re.search(r'const ROOT\s*:?=\s*"res://([^"\n]+)"', frozen_source.read_text())
        if not root or root.group(1) != MAPGEN_FROZEN_ROOT:
            raise ValueError('Frozen v2 consumer root changed; review finite export adapter')
        lock = manifest(MAPGEN_FROZEN_ROOT + 'input-lock.json')
        if lock.get('schema') != 'gunman-rush/mapgen-frozen-input/v1' or set(lock.get('files', {})) != set(MAPGEN_FROZEN_MEMBERS):
            raise ValueError('Frozen v2 input lock differs from its finite runtime members')
        for name in MAPGEN_FROZEN_MEMBERS:
            expected = lock['files'][name]
            if not re.fullmatch(r'[0-9a-f]{64}', str(expected)) or hashlib.sha256(local(MAPGEN_FROZEN_ROOT + name)).hexdigest() != expected:
                raise ValueError('Frozen v2 JSON differs from its runtime SHA: ' + name)
            manifest(MAPGEN_FROZEN_ROOT + name)

    landscape = repo / LANDSCAPE
    if landscape.is_file():
        text = landscape.read_text()
        # Keep quoted strings intact while discarding actual GDScript comments.
        # Literal read_family calls outside PILOT_FAMILIES are real FileAccess
        # consumers too, even when their candidate is environment-gated.
        text = re.sub(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\#[^\n]*''',
                      lambda match: '' if match.group().startswith('#') else match.group(), text)
        match = re.search(r'const PILOT_FAMILIES\s*:?=\s*(\[[^\]]*\])', text)
        if not match:
            raise ValueError('Landscape family declaration changed; update export contract adapter')
        families = json.loads(match.group(1))
        if not isinstance(families, list) or not families or any(not isinstance(f, str) for f in families):
            raise ValueError('Invalid landscape family declaration')
        families += re.findall(r'const FAMILY_ID\s*:?=\s*"([^"\n]+)"', text)
        quoted = [(match.start(), match.end()) for match in re.finditer(
            r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*' ''', text, re.VERBOSE)]
        for call in re.finditer(r'\bread_family\s*\(', text):
            if any(start <= call.start() < end for start, end in quoted):
                continue
            prefix = text[:call.start()].rsplit('\n', 1)[-1]
            if re.search(r'\bfunc\s*$', prefix):
                continue
            closing = text.find(')', call.end())
            if closing < 0:
                raise ValueError('Landscape read_family call lacks closing delimiter')
            argument = text[call.end():closing].strip()
            literal = re.fullmatch(r'''["']([a-z0-9_]+)["']''', argument)
            if literal:
                families.append(literal.group(1))
            elif argument != 'family_id':
                raise ValueError('Landscape read_family call is not a finite known family; update export contract adapter')
        for family in dict.fromkeys(families):
            if not re.fullmatch(r'[a-z0-9_]+', family):
                raise ValueError('Invalid landscape family ID')
            name = SPACES + family + '/family.json'
            data = manifest(name)
            source = resource_path(data.get('path'))
            if not source.startswith(SPACES + family + '/'):
                raise ValueError('Landscape source outside its family: ' + source)
            texture(source, data.get('sha256'), True)
    else:
        pending.append(LANDSCAPE)

    connected = repo / CONNECTED
    if connected.is_file():
        text = connected.read_text()
        root = re.search(r'const ROOT\s*:?=\s*"res://([^"\n]+)"', text)
        if not root or root.group(1) != CONNECTED_ROOT:
            raise ValueError('Connected family root changed; update export adapter')
        # Only literal, delivered families are permitted by this finite consumer.
        calls = re.findall(r'(?<!func )\bread_family\(\s*"([a-z0-9_]+)"\s*\)', text)
        if not calls or any(family not in ('rooted_plants_v1',) for family in calls):
            raise ValueError('Connected family calls changed; update export adapter')
        for family in dict.fromkeys(calls):
            name = CONNECTED_ROOT + family + '/family.json'
            data = manifest(name)
            source = resource_path(data.get('path'))
            if source != CONNECTED_ROOT + family + '/raw.png':
                raise ValueError('Connected source outside explicit delivered family: ' + source)
            texture(source, data.get('sha256'), True)

    presentation = repo / ROOT_BELL
    text = presentation.read_text() if presentation.is_file() else ''
    for family in ('root_bell', 'root_bell_burst'):
        name = 'assets/region_production_v3/enemies/' + family + '/manifest.json'
        if 'res://' + name not in text:
            pending.append(name + ' (consumer not integrated)')
            continue
        data = manifest(name)
        source = resource_path(str(Path(name).parent / data['texture']))
        texture(source, data.get('sha256'), False)

    sampler = repo / TERRAIN
    if sampler.is_file():
        text = sampler.read_text()
        def constant(name):
            match = re.search(r'const ' + name + r'\s*:?=\s*"([^"\n]+)"', text)
            if not match:
                raise ValueError('Terrain export contract constant missing: ' + name)
            return match.group(1)
        name = resource_path(constant('CONTRACT_PATH'))
        manifest(name)
        if hashlib.sha256(local(name)).hexdigest() != constant('CONTRACT_SHA'):
            raise ValueError('Terrain sampling JSON differs from its runtime SHA')
        for kind in ('CLIFF', 'PANEL'):
            match = re.search(r'const ' + kind + r'\s*:?=\s*preload\("([^"\n]+)"\)', text)
            if not match:
                raise ValueError('Terrain texture declaration changed: ' + kind)
            texture(match.group(1), constant(kind + '_SHA'), True)
    else:
        pending.append(TERRAIN)
    background = repo / BACKGROUND
    if background.is_file():
        text = background.read_text()
        # These are Texture2D preloads, not FileAccess PNG/JSON consumers.
        # Family metadata is provenance only and is intentionally not required.
        for source in re.findall(r'preload\("(res://[^"\n]+\.png)"\)', text):
            texture(source, hashlib.sha256(local(source)).hexdigest(), False)
        if 'distant_limestone_ridge_v1' in text and not re.search(
                r'const RIDGE\s*:?=\s*preload\("res://assets/region_production_v3/spaces/distant_limestone_ridge_v1/source\.png"\)', text):
            raise ValueError('Background ridge declaration changed; update export contract adapter')
    return manifests, textures, pending


def texture_import_targets(text):
    sections = list(re.finditer(r'^[ \t]*\[remap\][ \t]*$', text, re.MULTILINE))
    if len(sections) > 1:
        raise ValueError('Duplicate texture remap section')
    if not sections:
        return {}
    rest = text[sections[0].end():]
    section = re.split(r'^[ \t]*\[', rest, maxsplit=1, flags=re.MULTILINE)[0]
    targets = {}
    for line in section.splitlines():
        if not re.match(r'^[ \t]*path(?:\.[A-Za-z0-9_]+)?[ \t]*=', line):
            continue
        match = re.fullmatch(r'[ \t]*(path(?:\.[A-Za-z0-9_]+)?)[ \t]*=[ \t]*"res://([^"\n]+)"[ \t]*', line)
        if match is None:
            raise ValueError('Malformed texture import target')
        key, target = match.groups()
        if key in targets:
            raise ValueError('Duplicate texture import target key: ' + key)
        targets[key] = resource_path(target)
    return targets


def recorded_enemy_contract(repo):
    """Read only the finite revision maps in the actual construction registry.

    Resource paths/hashes remain owned by BEHAVIORS, shared with the raw-export
    addon. Unsupported expressions fail closed instead of omitting a revision.
    """
    registry = Path(repo) / 'game/enemies/enemy_behavior_registry.gd'
    if not registry.is_file():
        return {}  # Small unrelated asset fixtures have no enemy consumer.
    source = registry.read_text()
    # Canonicalize both legal quote forms before reading finite dictionaries.
    # Single-quoted revision keys must not silently become an empty contract.
    strings_or_comments = re.compile(r"&?\"(?:\\.|[^\"\\])*\"|&?'(?:\\.|[^'\\])*'|\#[^\n]*")
    def normalized(match):
        token = match.group()
        if token.startswith('#'):
            return ''
        try:
            return json.dumps(ast.literal_eval(token.removeprefix("&")))
        except (ValueError, SyntaxError) as error:
            raise ValueError('Recorded enemy registry has unsupported string syntax') from error
    source = strings_or_comments.sub(normalized, source)
    body = re.search(r'(?ms)^const BEHAVIORS\s*:?=\s*({.*?})\s*^const CANDIDATES\b', source)
    if not body:
        raise ValueError('Recorded enemy registry needs finite BEHAVIORS dictionary')
    declarations = re.findall(r'(?m)^const ([A-Z][A-Z0-9_]*)\s*:?=\s*("(?:\\.|[^"\\])*")\s*$', source)
    if len({name for name, _ in declarations}) != len(declarations):
        raise ValueError('Duplicate recorded enemy registry constant')
    constants = {name: json.loads(value) for name, value in declarations}

    def finite(node):
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return node.value
        if isinstance(node, ast.Name) and node.id in constants:
            return constants[node.id]
        if isinstance(node, ast.Dict):
            result = {}
            for key, value in zip(node.keys, node.values):
                name = finite(key)
                if not isinstance(name, str) or name in result:
                    raise ValueError('Unknown/duplicate recorded enemy registry key')
                result[name] = finite(value)
            return result
        raise ValueError('Recorded enemy registry must remain a finite literal dictionary')

    try:
        behaviors = finite(ast.parse(body.group(1), mode='eval').body)
    except SyntaxError as error:
        raise ValueError('Recorded enemy registry must remain a finite literal dictionary') from error
    if not isinstance(behaviors, dict):
        raise ValueError('Recorded enemy registry needs finite BEHAVIORS dictionary')
    result = {}
    for behavior in behaviors.values():
        if not isinstance(behavior, dict) or not isinstance(behavior.get('revisions', {}), dict):
            raise ValueError('Recorded enemy revision map must be a finite literal dictionary')
        for digest, path in behavior.get('revisions', {}).items():
            if not re.fullmatch(r'[0-9a-f]{64}', digest):
                raise ValueError('Unknown/duplicate recorded enemy revision SHA')
            name = resource_path(path)
            if not name.endswith('.tres') or (name in result and result[name] != digest):
                raise ValueError('Invalid/conflicting recorded enemy resource')
            local = Path(repo) / name
            if not local.resolve().is_relative_to(Path(repo).resolve()) or not local.is_file():
                raise ValueError('Missing/unsafe recorded enemy source: ' + name)
            if hashlib.sha256(local.read_bytes()).hexdigest() != digest:
                raise ValueError('Recorded enemy source SHA changed: ' + name)
            result[name] = digest
    return result


def check_recorded_enemy_resources(pack, repo):
    contract = recorded_enemy_contract(repo)
    for name, digest in contract.items():
        raw = pack.read(name)
        if raw != (Path(repo) / name).read_bytes() or hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError('PCK raw enemy Definition differs from registered revision: ' + name)
        mapping = pack.read(name + '.remap').decode('utf-8')
        matches = re.findall(r'^path="(res://[^"\n]+)"$', mapping, re.MULTILINE)
        if len(matches) != 1:
            raise ValueError('Recorded enemy Definition needs normal ResourceLoader remap: ' + name)
        target = resource_path(matches[0])
        if not target.endswith('.res') or not pack.read(target):
            raise ValueError('Recorded enemy Definition lacks converted resource: ' + name)
    return sorted(contract)


def check_fixed_world_payload(pack, repo):
    """Current world bytes and authored scene closure, independent of docs in the pack."""
    from world.build import build
    _, expected = build(repo)
    actual = json.loads(pack.read('build/world/runtime.json'))
    if actual != expected:
        raise ValueError('PCK fixed world differs from current source and scene hashes')
    if any(name.startswith(('docs/','config/world/')) for name in pack.entries):
        raise ValueError('PCK fixed world must not include docs or manual world sources')
    for room in actual['rooms'].values():
        name = resource_path(room['scene_ref'])
        if name in pack.entries:
            pack.read(name)
        else:
            remap = pack.read(name + '.remap').decode()
            target = re.search(r'^path="res://([^"\n]+)"$', remap, re.M)
            if target is None:
                raise ValueError('PCK fixed world scene remap missing: ' + name)
            pack.read(target[1])
    return {'content_version': actual['content_version'], 'rooms': sorted(actual['rooms'])}


def check_runtime_closure(path, repo=REPO):
    excluded = check_excluded_consumers(repo)
    pack = Pack(path)
    generated = check_mapgen_payload(pack, repo)
    fixed_world = check_fixed_world_payload(pack, repo) if (Path(repo)/"config/world/world.json").is_file() else None
    for family in excluded:
        if any(name.startswith(family) for name in pack.entries):
            raise ValueError('PCK contains excluded evidence-only family: ' + family)
        # Imported derivatives live outside the source directory. Consult the
        # actual local import mappings generated by this export when available.
        for source in (Path(repo) / family).rglob('*.png.import'):
            targets = re.findall(r'^path(?:\.[A-Za-z0-9_]+)?="res://([^"]+)"$',
                                 source.read_text(), re.MULTILINE)
            if any(target in pack.entries for target in targets):
                raise ValueError('PCK contains excluded evidence-only imported texture: ' + str(source))
    recorded_definitions = check_recorded_enemy_resources(pack, repo)
    manifests, textures, pending = runtime_contract(repo)
    for name, expected in manifests.items():
        data = pack.read(name)
        if data != (Path(repo) / name).read_bytes() or json.loads(data) != expected:
            raise ValueError('PCK JSON differs from integrated runtime source: ' + name)
    for name, expected in textures.items():
        if expected['raw'] and hashlib.sha256(pack.read(name)).hexdigest() != expected['sha256']:
            raise ValueError('PCK raw PNG differs from runtime FileAccess SHA contract: ' + name)
        # An imported texture does not substitute for FileAccess-readable PNG bytes.
        remap = pack.read(name + '.import').decode('utf-8')
        if not re.search(r'^importer="texture"$', remap, re.MULTILINE):
            raise ValueError('PCK has no texture import mapping: ' + name)
        targets = texture_import_targets(remap)
        if not targets:
            raise ValueError('PCK texture mapping has no import target: ' + name)
        source_import = Path(repo) / (name + '.import')
        if not source_import.is_file():
            raise ValueError('Runtime texture lacks local import mapping: ' + name)
        local_targets = texture_import_targets(source_import.read_text())
        for key, target in targets.items():
            if local_targets.get(key) != target:
                raise ValueError('PCK texture import target differs from source mapping: ' + name)
            derivative = (Path(repo) / target).resolve()
            if not derivative.is_relative_to(Path(repo).resolve()) or not derivative.is_file():
                raise ValueError('Runtime texture lacks local imported target: ' + target)
            if pack.read(target) != derivative.read_bytes():
                raise ValueError('PCK imported texture bytes differ from local target: ' + name)
    return {'json': sorted(manifests), 'raw_png': sorted(n for n, t in textures.items() if t['raw']),
            'textures': sorted(textures), 'pending_consumers': pending,
            'recorded_enemy_definitions': recorded_definitions,
            'fixed_world': fixed_world,
            'mapgen_generated_dependencies': generated,
            'excluded_evidence_families': list(excluded),
            'scope': 'Actual PCK closure for integrated consumers only; no rendering/device/content acceptance'}


def check(root, repo=REPO):
    worker = (root / 'index.cache-sw.js').read_text()
    resources = json.loads(re.search(r'const RESOURCE_MAP = (.*);', worker).group(1))
    total = 0
    for name, info in resources.items():
        if 'chunks' not in info:
            continue
        parts = []
        for part in info['chunks']:
            compressed = (root / part['url']).read_bytes()
            assert len(compressed) == part['gzip_bytes'], part['url']
            block = gzip.decompress(compressed)
            assert len(block) == part['bytes'] and hashlib.sha256(block).hexdigest() == part['sha256'], part['url']
            assert len(block) <= 512 * 1024
            parts.append(block); total += len(compressed)
        complete = b''.join(parts)
        assert complete == (root / name).read_bytes(), name
        assert hashlib.sha256(complete).hexdigest() == info['sha256']
    metadata = json.loads((root / 'build-info.json').read_text())
    assert metadata['download_bytes'] == total
    assert metadata['cache_schema'] == 2
    assert metadata['build_id'] == hashlib.sha256((root / metadata['pack']).read_bytes()).hexdigest()[:12]
    closure = check_runtime_closure(root / metadata['pack'], repo)
    # Excluded candidates have no runtime consumer. New consumers must revisit this export policy.
    for directory in ('scripts', 'scenes', 'resources', 'config', 'game', 'experiments'):
        for source in (repo / directory).rglob('*'):
            if source.suffix in ('.gd', '.tscn', '.tres', '.json'):
                assert 'assets/painterly_v2/' not in source.read_text(), str(source)
    print(json.dumps({'checked_resources': len([r for r in resources.values() if 'chunks' in r]),
                      'download_bytes': total, 'pack_runtime_closure': closure, 'failed': 0}))

if __name__ == '__main__':
    check(Path(sys.argv[1]) if len(sys.argv) > 1 else Path('build/web'))
