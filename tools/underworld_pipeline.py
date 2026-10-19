#!/usr/bin/env python3
"""Audit the Underworld production manifests actually read by runtime consumers.

This is a source/assembly contract, not a beauty, gameplay or device approval.
The audit never imports Godot, writes source assets, or paints pixels.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import re
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = 'assets/underworld_plains/production_manifest.json'
BITS = {'N': 1, 'NE': 2, 'E': 4, 'SE': 8, 'S': 16, 'SW': 32, 'W': 64, 'NW': 128}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_mask(mask: int) -> int:
    for diagonal, a, b in [('NE','N','E'),('SE','S','E'),('SW','S','W'),('NW','N','W')]:
        if not (mask & BITS[a] and mask & BITS[b]):
            mask &= ~BITS[diagonal]
    return mask


class Audit:
    def __init__(self, root: Path, json_overrides: dict | None = None):
        self.root = root.resolve()
        self.json_overrides = json_overrides or {}
        self.image_cache: dict[str, Image.Image] = {}
        self.checks: list[dict] = []
        self.measurements: dict = {'files': {}}

    def check(self, condition, code: str, detail: str):
        self.checks.append({'code': code, 'passed': bool(condition), 'detail': detail})
        return bool(condition)

    def path(self, value, code: str) -> Path | None:
        if isinstance(value, dict):
            value = value.get('path', value.get('image'))
        if not self.check(isinstance(value, str) and bool(value), code, str(value)):
            return None
        raw = value.removeprefix('res://')
        path = (self.root / raw).resolve()
        if not self.check(path.is_relative_to(self.root), code + '.inside_repo', raw):
            return None
        if not self.check(path.is_file() and path.stat().st_size > 0, code + '.exists', raw):
            return None
        self.measurements['files'][str(path.relative_to(self.root))] = {'sha256': digest(path), 'bytes': path.stat().st_size}
        return path

    def hashed(self, spec, code: str) -> Path | None:
        path = self.path(spec, code)
        if path and isinstance(spec, dict):
            self.check(spec.get('sha256') == digest(path), code + '.sha256', str(path.relative_to(self.root)))
        return path

    def image(self, spec, code: str) -> Image.Image | None:
        path = self.hashed(spec, code)
        if path is None:
            return None
        if str(path) in self.image_cache:
            return self.image_cache[str(path)]
        try:
            image = Image.open(path).convert('RGBA')
            image.load()
            self.image_cache[str(path)] = image
            return image
        except (OSError, ValueError) as exc:
            self.check(False, code + '.decode', str(exc))
            return None

    def json(self, value, code: str) -> dict:
        path = self.path(value, code)
        if path:
            try:
                result = copy.deepcopy(self.json_overrides[str(path.relative_to(self.root))]) if str(path.relative_to(self.root)) in self.json_overrides else json.loads(path.read_text())
                self.check(isinstance(result, dict), code + '.object', str(path))
                return result if isinstance(result, dict) else {}
            except (OSError, ValueError) as exc:
                self.check(False, code + '.decode', str(exc))
        return {}

    def consumption(self, fragment_path, consumer, code):
        consumers = consumer if isinstance(consumer, list) else [consumer]
        scripts = [self.path(value, code + '.consumer') for value in consumers]
        raw = fragment_path.get('path') if isinstance(fragment_path, dict) else fragment_path
        matched = isinstance(raw, str) and any(script and Path(raw).name in script.read_text() and 'JSON.parse_string' in script.read_text() and 'FileAccess.get_file_as_string' in script.read_text() for script in scripts)
        self.check(matched, code + '.read_by_runtime', str(raw))

    def result(self):
        failures = [c for c in self.checks if not c['passed']]
        return {'schema': 'underworld-pipeline-audit-v1', 'scope': 'Source provenance and production-manifest assembly contract only; GPU, Motor, visual quality and device acceptance are separate.',
                'passed': not failures, 'check_count': len(self.checks), 'failure_count': len(failures), 'checks': self.checks, 'measurements': self.measurements}



def audit_generation(a: Audit, value, code: str, consumed_image=None):
    record = a.json(value, code)
    original = record.get('original_generation', {})
    prompt = record.get('prompt', original.get('props_prompt'))
    a.check(isinstance(prompt, str) and bool(prompt.strip()), code + '.prompt', 'Actual nonempty generation prompt')
    a.check(record.get('tool') == 'image_gen.imagegen', code + '.tool', str(record.get('tool')))
    a.check(bool(record.get('model', record.get('model_status'))), code + '.model_disclosure', 'not_exposed / unknown is valid; invented model names are not required')
    for source_key in ('source', 'reference', 'image', 'atlas'):
        if source_key in record and source_key + '_sha256' in record:
            path = a.path(record[source_key], code + '.' + source_key)
            if path:
                a.check(digest(path) == record[source_key + '_sha256'], code + '.' + source_key + '_sha256', 'Recorded lineage agrees with real source bytes')
    recorded_output = record.get('image', record.get('atlas'))
    if recorded_output and consumed_image:
        consumed = consumed_image.get('path') if isinstance(consumed_image, dict) else consumed_image
        a.check(str(recorded_output).removeprefix('res://') == str(consumed).removeprefix('res://'), code + '.consumed_output', 'Generation record describes the actual runtime image')
    return record


def audit_reference(a: Audit, terrain: dict):
    # The immutable source recipe already distinguishes 47 coordinates from
    # 47 different paintings, and records true quarter-tile inner corners.
    recipe_path = terrain.get('reference_recipe', 'assets/style_exploration/anchors.json')
    recipes = a.json(recipe_path, 'reference.recipe')
    styles = recipes.get('styles', {})
    source_spec = styles.get('underworld', {})
    masks = sorted({canonical_mask(i) for i in range(256)})
    a.check(recipes.get('bits') == BITS, 'reference.bits', 'Project clockwise neighbour order')
    a.check(recipes.get('masks') == masks and len(masks) == 47, 'reference.47_masks', 'All canonical masks, including missing-diagonal inner corners')
    source_path = a.path(terrain.get('source_texture'), 'reference.source')
    if source_path:
        a.check(digest(source_path) == source_spec.get('source_sha256'), 'reference.source_sha256', 'Frozen licensed Underworld source bytes')
        a.check(terrain.get('source_sha256') == digest(source_path), 'terrain.declared_source_sha256', 'Runtime provenance agrees with actual copied source')
    evidence = a.path(terrain.get('license_evidence', 'assets/style_exploration/underworld/source/licenses/publisher_page.txt'), 'reference.license')
    if evidence:
        text = evidence.read_text().lower()
        a.check('feel free to use it however you want' in text, 'reference.permission', 'Custom publisher permission; not CC0')
    a.check(terrain.get('license', 'custom-publisher-permission') != 'CC0', 'reference.no_false_cc0', 'Underworld has a custom permission statement')
    px = terrain.get('tile_px')
    a.check(isinstance(px, int) and px == source_spec.get('px'), 'terrain.native_pixel_scale', str(px))
    a.check(isinstance(terrain.get('world_tile_wu'), (int, float)) and terrain['world_tile_wu'] > 0, 'terrain.world_scale', str(terrain.get('world_tile_wu')))
    mapping = terrain.get('mask_to_atlas', {})
    a.check(mapping == source_spec.get('mask_to_atlas'), 'terrain.mask_mapping', 'Runtime mask coordinates equal immutable crop recipe')
    a.check(terrain.get('source_regions') == source_spec.get('recipes') and bool(source_spec.get('recipes')), 'terrain.source_regions', 'Runtime boundary source regions match the original quarter-crop recipe')
    atlas = a.image(terrain.get('atlas'), 'terrain.atlas')
    atlas_path = a.path(terrain.get('atlas'), 'terrain.declared_atlas')
    if atlas_path:
        a.check(terrain.get('atlas_sha256') == digest(atlas_path), 'terrain.declared_atlas_sha256', 'Runtime provenance agrees with actual atlas')
    if atlas and source_path and isinstance(px, int) and px > 0:
        source = Image.open(source_path).convert('RGBA')
        expected = Image.new('RGBA', (8 * px, 6 * px))
        valid = True
        hashes = []
        for i, mask in enumerate(masks):
            tile = Image.new('RGBA', (px, px))
            covered = Image.new('1', (px, px))
            for patch in source_spec.get('recipes', {}).get(str(mask), []):
                src, dst = patch['source'], patch['destination']
                x1,y1,x2,y2 = dst
                legal = (0 <= src[0] < src[2] <= source.width and 0 <= src[1] < src[3] <= source.height and 0 <= x1 < x2 <= px and 0 <= y1 < y2 <= px and (src[2]-src[0],src[3]-src[1]) == (x2-x1,y2-y1))
                if not legal or covered.crop(dst).getbbox():
                    valid = False
                    continue
                crop = source.crop(src)
                if patch.get('horizontal_flip'):
                    crop = crop.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                tile.paste(crop, (x1,y1)); covered.paste(1, dst)
            valid &= covered.histogram()[0] == 0
            hashes.append(hashlib.sha256(tile.tobytes()).hexdigest())
            expected.paste(tile, ((i % 8)*px, (i//8)*px))
        a.check(valid, 'terrain.crop_coverage', 'All pixels covered exactly once by bounded unscaled original-source crops')
        a.check(atlas.size == expected.size and atlas.tobytes() == expected.tobytes(), 'terrain.source_reconstruction', 'Runtime atlas RGBA exactly equals source crop replay')
        a.measurements['terrain'] = {'native_tile_px': px, 'world_tile_wu': terrain.get('world_tile_wu'), 'canonical_masks': len(masks), 'unique_tile_pixels': len(set(hashes))}
    tileset = a.path(terrain.get('tileset'), 'terrain.tileset')
    if tileset:
        content = tileset.read_text()
        a.check('TileSetAtlasSource' in content, 'terrain.real_tileset', 'Godot TileSetAtlasSource resource')
        atlas_path = terrain.get('atlas')
        atlas_path = atlas_path.get('path') if isinstance(atlas_path, dict) else atlas_path
        a.check(isinstance(atlas_path, str) and atlas_path.removeprefix('res://') in content, 'terrain.tileset_consumes_atlas', str(atlas_path))
    a.check(terrain.get('mode') == 'blob47_core_with_exact_boundary_adapter', 'terrain.honest_geometry_mode', 'Formal non-grid boundaries remain exact; only interior cells use Blob47 TileMapLayer')


def audit_scenery(a: Audit, scenery: dict):
    layers = scenery.get('backgrounds', [])
    a.check(isinstance(layers, list) and len(layers) == 3, 'background.three_layers', 'Sky base excluded')
    factors, images, rows = [], [], []
    for index, spec in enumerate(layers if isinstance(layers, list) else []):
        prefix = f'background.{index}'
        image = a.image(spec.get('image'), prefix + '.image')
        factor = spec.get('camera_factor')
        pair = factor if isinstance(factor, list) else [factor, factor]
        a.check(len(pair) == 2 and all(isinstance(v,(int,float)) and 0 < v < 1 for v in pair), prefix + '.factor', str(factor))
        factors.append(pair)
        a.check(bool(spec.get('role')), prefix + '.role', str(spec.get('role')))
        if image:
            lo, hi = image.getchannel('A').getextrema()
            a.check(hi > 0 and (index == 0 or lo < 255), prefix + '.transparent_depth', 'Far may contain sky; middle and near require transparent empty space')
            images.append(hashlib.sha256(image.tobytes()).hexdigest())
            rows.append({'size': list(image.size), 'alpha_range':[lo,hi], 'factor':factor})
        generation = spec.get('generation_record')
        audit_generation(a, generation, prefix + '.generation_record', spec.get('image'))
    a.check(len(images) == 3 and len(set(images)) == 3, 'background.independent_pixels', 'Three different source images, not one panorama copied three times')
    valid = all(len(pair) == 2 and all(isinstance(v,(int,float)) for v in pair) for pair in factors)
    a.check(valid and len(factors) == 3 and all(factors[0][axis] < factors[1][axis] < factors[2][axis] for axis in (0,1)), 'background.ordered_factors', str(factors))
    a.measurements['backgrounds'] = rows
    decor = scenery.get('decor', {})
    a.check(decor.get('independent_seed') is True, 'decor.independent_seed', 'Does not consume gameplay RNG')
    a.check(bool(decor.get('keepout_policy')), 'decor.keepout', str(decor.get('keepout_policy')))
    a.check(bool(decor.get('support_policy')), 'decor.support', str(decor.get('support_policy')))
    a.check(decor.get('collision') is False, 'decor.no_collision', 'Presentation-only supported props')
    a.image(decor.get('atlas'), 'decor.atlas')
    audit_generation(a, decor.get('generation_record'), 'decor.generation_record', decor.get('atlas'))
    audit_extended_decor(a, scenery)
    audit_local_composition(a, scenery)



def audit_extended_decor(a: Audit, scenery: dict):
    """Audit the additional source-native grass and whole identity objects."""
    decor = scenery.get('decor', {})
    metadata = a.json(decor.get('regions_metadata'), 'decor.regions_metadata')
    regions = metadata.get('regions', {})
    provenance = a.json(decor.get('generation_record'), 'decor.extended_provenance')
    native = provenance.get('native_grass', {})
    native_image = a.image({'path':native.get('source'), 'sha256':native.get('source_sha256')}, 'decor.grass.source')
    a.check(bool(native.get('processing')), 'decor.grass.processing', 'Original-source crop processing disclosure')
    license_file = a.path(native.get('license_record'), 'decor.grass.license')
    if license_file:
        a.check('feel free to use it however you want' in license_file.read_text().lower(), 'decor.grass.permission', 'Original publisher custom permission retained')
    reference = a.path('assets/style_exploration/underworld/source/TileSet.png','decor.grass.reference')
    native_path = a.path(native.get('source'), 'decor.grass.actual_source')
    if reference and native_path:
        a.check(digest(reference)==digest(native_path), 'decor.grass.same_publisher_bytes', 'Native grass atlas is the byte-identical original Underworld sheet')
    grass = regions.get('grass', {})
    a.check(grass.get('atlas')==native.get('source') and grass.get('region')==native.get('region'), 'decor.grass.runtime_recipe', 'Runtime grass override agrees with its actual source record')
    identities = audit_generation(a, decor.get('identity_generation_record'), 'decor.identity_generation')
    recorded = {entry.get('kind'):entry for entry in identities.get('regions',[])}
    expected={'well','clock_arch','repair_shelter'}
    a.check(set(recorded)==expected, 'decor.identity.complete_objects', 'Three actual complete-object regions with preserved original source')
    a.check(set(decor.get('identity_landmarks',{}))=={'windmill_plateau','creek_well','clock_court','repair_gallery'}, 'decor.identity.four_roles', 'Four current Plains identity roles; not sixteen-region production')
    for kind in ['grass','well','clock_arch','repair_shelter']:
        spec=regions.get(kind,{})
        prefix='decor.region.'+kind
        image=a.image(spec.get('atlas'),prefix+'.atlas')
        rect=spec.get('region',[])
        legal=(isinstance(rect,list) and len(rect)==4 and all(isinstance(v,int) for v in rect) and image is not None and 0<=rect[0]<rect[0]+rect[2]<=image.width and 0<=rect[1]<rect[1]+rect[3]<=image.height)
        a.check(legal,prefix+'.bounds','Actual x/y/width/height entirely inside source PNG')
        foot=spec.get('foot',[])
        foot_legal=(legal and isinstance(foot,list) and len(foot)==2 and all(isinstance(v,(int,float)) for v in foot) and 0<=foot[0]<=rect[2] and 0<=foot[1]<=rect[3])
        a.check(foot_legal,prefix+'.foot_bounds',str(foot))
        a.check(bool(spec.get('source_semantics')),prefix+'.source_semantics','Source role and no repaint/native versus generated lineage are explicit')
        if legal and foot_legal:
            x,y,w,h=rect
            alpha=image.crop((x,y,x+w,y+h)).getchannel('A')
            bbox=alpha.point(lambda value:255 if value>=128 else 0).getbbox()
            a.check(bbox is not None and foot[1]==bbox[3],prefix+'.actual_opaque_foot','Declared foot equals actual alpha>=128 lower edge; no cut root or floating bottom padding')
        if kind in expected:
            record=recorded.get(kind,{})
            a.check(all(record.get(field)==spec.get(field) for field in ('atlas','region','foot','world_height')),prefix+'.generation_recipe','Runtime crop/foot/scale agrees with actual generated-source extraction record')
            a.check(spec.get('atlas')==identities.get('image'),prefix+'.actual_generated_atlas','Runtime region samples the recorded original image')


def audit_local_composition(a: Audit, scenery: dict):
    """Use the same explicit background semantics as the actual consumer."""
    spec=scenery.get('decor',{}).get('local_composition',{})
    a.check(bool(spec),'local.spec_present','New distant architectural consumer must have an explicit runtime spec')
    a.check(spec.get('identity')=='creek_well' and spec.get('asset_id')=='well','local.identity_asset','The source-painted well is the current creek background identity')
    a.check(spec.get('depth')=='distant_local_architecture','local.depth','Background architecture is not a grounded gameplay landmark')
    for name in ('collision','standing_edge','physical_support'):
        a.check(spec.get(name) is False,'local.'+name,'No collider, standable edge or physical-root claim')
    z=spec.get('z_index')
    a.check(isinstance(z,int) and z<0,'local.background_z','Consumer remains behind the gameplay plane')
    a.check(isinstance(spec.get('target_height'),(int,float)) and spec['target_height']>0,'local.positive_height','Actual source/foot scale has positive height')
    a.check(bool(spec.get('functional_keepout')),'local.functional_keepout','Original functional keepouts remain declared')
    opacity=spec.get('opacity')
    a.check(isinstance(opacity,(int,float)) and 0<opacity<=1,'local.visible_opacity','Actual material opacity is declared and nonzero, not an invisible identity label')
    total=spec.get('total_visibility_samples')
    hidden=spec.get('maximum_solid_hidden_samples')
    a.check(isinstance(total,int) and isinstance(hidden,int) and total>0 and 0<=hidden<total,'local.visibility_budget','Declared visibility sample budget cannot accept a fully hidden source base')
    for axis in ('offset_x','offset_y'):
        values=spec.get(axis)
        a.check(isinstance(values,list) and bool(values) and all(isinstance(v,(int,float)) for v in values),'local.'+axis,'Actual source-consumed local background sockets')
    base=spec.get('painted_base',{})
    source=a.path(base.get('source'),'local.painted_base.source')
    a.check(bool(base.get('description')),'local.painted_base.description','Original painted footing is the declared base, not physical solid support')
    metadata=a.json(scenery.get('decor',{}).get('regions_metadata'),'local.source_regions')
    well=metadata.get('regions',{}).get('well',{})
    a.check(base.get('source')==well.get('atlas'),'local.same_painted_base','Virtual base belongs to the exact consumed well image')
    limits=spec.get('readability_limits',{})
    a.check(all(isinstance(limits.get(k),(int,float)) for k in ('max_r','max_g','max_b')) and limits.get('red_not_above_blue') is True,'local.readability_contract','Actual runtime cold atmospheric material limits; no separate pipeline shadow rules')
    for key in ('fog_shadow','fog_highlight'):
        value=spec.get(key)
        valid=isinstance(value,str) and bool(re.fullmatch('[0-9a-fA-F]{6}',value))
        a.check(valid,'local.'+key+'.rgb','Explicit six-digit source-consumed fog color')
        if valid and all(isinstance(limits.get(k),(int,float)) for k in ('max_r','max_g','max_b')):
            rgb=[int(value[i:i+2],16)/255.0 for i in (0,2,4)]
            a.check(all(rgb[i]<=limits['max_'+channel] for i,channel in enumerate('rgb')) and (not limits.get('red_not_above_blue') or rgb[0]<=rgb[2]),'local.'+key+'.runtime_readability','Matches the same declared limits checked by UnderworldLocalComposition.actual_issues')
    script=a.path(spec.get('consumer_script'),'local.consumer')
    direct='' if script is None else script.read_text()
    callers=[]
    for caller in scenery.get('consumer_scripts',[]):
        path=a.path(caller,'local.caller')
        if path:callers.append(path.read_text())
    linked=any('scenery_build.json' in text and 'JSON.parse_string' in text and 'UnderworldLocalComposition.new()' in text and '_spec.local_composition' in text for text in callers)
    a.check(linked and 'class_name UnderworldLocalComposition' in direct and 'spec.painted_base.source' in direct,'local.read_by_runtime','Actual JSON-reading scenery passes local_composition into the real child configure()')
    a.check('_spec.readability_limits' in direct and 'spec.fog_shadow' in direct and 'spec.fog_highlight' in direct,'local.same_runtime_readability_spec','The actual material and runtime rejection read these same production values')


def audit_hazards(a: Audit, hazards: dict):
    a.hashed(hazards.get('source_image'), 'hazards.source')
    generated = hazards.get('generated_reference', {})
    if generated:
        a.hashed(generated, 'hazards.generated_reference')
        audit_generation(a, generated.get('prompt_record'), 'hazards.generation_record')
        a.check(bool(generated.get('model_status')), 'hazards.model_status', 'Unknown model is allowed when not exposed')
    atlas_spec = hazards.get('atlas', {})
    image = a.image(atlas_spec, 'hazards.atlas')
    a.check(atlas_spec.get('tile_size_px') == [16,16], 'hazards.native_scale', str(atlas_spec.get('tile_size_px')))
    a.check(atlas_spec.get('columns') == ['start','middle','end','single'], 'hazards.transitions', 'Start, repeat, end and single-span material variants')
    if image:
        a.check(image.size == (64,16), 'hazards.atlas_size', str(image.size))
        if image.size == (64,16):
            root = int(atlas_spec.get('embedded_root_px', 0))
            outer = int(atlas_spec.get('external_depth_px', 0))
            a.check(root > 0 and outer > 0 and root + outer == 16, 'hazards.root_and_tip', f'{root}+{outer}')
            a.check(image.getchannel('A').crop((0,0,64,outer)).getbbox() is not None and image.getchannel('A').crop((0,outer,64,16)).getbbox() is not None, 'hazards.material_continuity', 'Visible tips and embedded root pixels, not an empty overlay')
    semantics = hazards.get('semantics', {})
    a.check(semantics.get('damage_source') == 'PlatformThornDefinition.danger', 'hazards.damage_source', 'Existing authoritative damage definition')
    a.check(set(semantics.get('orientation', [])) == {'top','left','right','bottom'}, 'hazards.orientations', str(semantics.get('orientation')))
    a.check(semantics.get('collision_mutation') is False, 'hazards.preserve_collision', 'No additional solid base or changed hazard extent')
    connection = hazards.get('connection', {})
    a.check(connection.get('floating_base') is False, 'hazards.no_floating_base', 'Danger material uses the supporting platform boundary')
    a.check(bool(connection.get('material_family')), 'hazards.material_family', str(connection.get('material_family')))


def audit(root: Path = ROOT, manifest_path: str = DEFAULT_MANIFEST, overrides: dict | None = None, json_overrides: dict | None = None) -> dict:
    a = Audit(root, json_overrides=json_overrides)
    manifest = a.json(manifest_path, 'production.manifest')
    a.check(manifest.get('schema') == 'underworld-production-v1', 'production.schema', str(manifest.get('schema')))
    consumers = manifest.get('consumers', {})
    handlers = {'terrain': audit_reference, 'scenery': audit_scenery, 'hazards': audit_hazards}
    for key, handler in handlers.items():
        path = manifest.get(key + '_manifest', manifest.get(key))
        fragment = a.json(path, key + '.manifest')
        if overrides and key in overrides:
            fragment = copy.deepcopy(overrides[key])
        consumer = fragment.get('consumer_scripts', fragment.get('consumer_script', consumers.get(key)))
        a.consumption(path, consumer, key)
        try:
            handler(a, fragment)
        except (OSError, ValueError, TypeError, KeyError, AttributeError) as exc:
            a.check(False, key + '.invalid_data', f'{type(exc).__name__}: {exc}')
    return a.result()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['audit', 'runtime'])
    parser.add_argument('--suite', choices=['scenery', 'hazards'])
    parser.add_argument('--manifest', default=DEFAULT_MANIFEST)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.command == 'runtime':
        if not args.suite:
            parser.error('runtime requires --suite')
        from run_tests import run_engine
        suites = {
            'scenery': ('tests/underworld_plains/test_underworld_scenery.gd', r'^Underworld scenery: [0-9]+ checks, 0 failures$'),
            'hazards': ('tests/underworld_plains/test_underworld_hazards.gd', r'^UNDERWORLD HAZARD TESTS: [0-9]+ assertions, 0 failures$'),
        }
        script, marker = suites[args.suite]
        output = run_engine(['--headless', '--audio-driver', 'Dummy', '--path', '.', '--script', script], 120)
        if not re.search(marker, output, re.MULTILINE):
            raise RuntimeError('Missing Underworld runtime completion: ' + args.suite)
        print('PASS: Underworld ' + args.suite + ' runtime; strict engine teardown')
        return 0
    report = audit(manifest_path=args.manifest)
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    print(encoded, end='')
    if report['passed']:
        print(f"PASS: Underworld production pipeline; {report['check_count']} source and assembly checks")
        return 0
    print(f"FAIL: Underworld production pipeline; {report['failure_count']} failures", file=sys.stderr)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
