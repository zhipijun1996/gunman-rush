"""Calibrate an AI-painted family against a frozen, hash-bound production spec.

This tool measures and extracts pixels. It never paints, fills transparent holes,
rescales a prop, or treats numerical checks as artistic approval.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import time
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fraction(alpha: Image.Image, level: int = 128) -> float:
    histogram = alpha.histogram()
    return sum(histogram[level:]) / (alpha.width * alpha.height)


def bounds(alpha: Image.Image, level: int) -> list[int] | None:
    box = alpha.point(lambda value: 255 if value >= level else 0).getbbox()
    return list(box) if box else None


def edge_strip(alpha: Image.Image, side: str, width: int) -> Image.Image:
    w, h = alpha.size
    boxes = {'top': (0, 0, w, width), 'right': (w-width, 0, w, h),
             'bottom': (0, h-width, w, h), 'left': (0, 0, width, h)}
    if side not in boxes:
        raise ValueError('Unknown connection side: '+side)
    return alpha.crop(boxes[side])


def calibrate(source: Path, spec_path: Path, output: Path) -> dict:
    source, spec_path, output = map(Path, (source, spec_path, output))
    if output.exists():
        raise ValueError('Use a new output directory; failed attempts are immutable')
    spec = json.loads(spec_path.read_text())
    if spec.get('schema_version') != 1 or spec.get('artifact_kind') != 'frozen_asset_family_spec':
        raise ValueError('Missing frozen asset family spec')
    columns, rows = spec['grid']
    names = [cell['id'] for cell in spec['cells']]
    if (not 1 <= columns <= 16 or not 1 <= rows <= 16 or len(names) != columns*rows
            or len(set(names)) != len(names)):
        raise ValueError('Grid must declare every cell exactly once')
    started = time.monotonic()
    with Image.open(source) as raw:
        if raw.mode != 'RGBA':
            raise ValueError('Expected original RGBA carrier; do not manufacture transparency')
        image = raw.copy()
    output.mkdir(parents=True)
    issues = []
    if image.width % columns or image.height % rows:
        issues.append('carrier_not_exactly_divisible_by_frozen_grid')
    # Preserve fractional cell positions in the report. Refuse to invent a crop.
    cell_width, cell_height = image.width/columns, image.height/rows
    report = {'schema_version': 1, 'artifact_kind': 'measured_asset_family_calibration',
              'family_id': spec['family_id'], 'source': str(source), 'source_sha256': sha(source),
              'spec': str(spec_path), 'spec_sha256': sha(spec_path),
              'source_dimensions': list(image.size), 'cell_dimensions': [cell_width, cell_height],
              'issues': issues, 'cells': [], 'artistic_acceptance': 'unverified',
              'scope': 'Exact original pixel extraction and numeric frozen-spec checks; GPU seams, visual quality and devices require separate evidence.'}
    if not issues:
        cw, ch = int(cell_width), int(cell_height)
        for index, declaration in enumerate(spec['cells']):
            name = declaration['id']
            if not name.replace('_', '').isalnum():
                raise ValueError('Unsafe family cell id')
            x, y = index % columns*cw, index//columns*ch
            tile = image.crop((x, y, x+cw, y+ch))
            alpha = tile.getchannel('A')
            cell = {'id': name, 'region': [x, y, cw, ch],
                    'alpha_bounds': {str(level): bounds(alpha, level) for level in (1, 2, 128, 250)},
                    'alpha_128_fraction': fraction(alpha), 'issues': [], 'connection_coverage': {}}
            if cell['alpha_bounds']['128'] is None:
                cell['issues'].append('no_visible_subject')
            for side in declaration.get('continuous_material', []):
                ratio = fraction(edge_strip(alpha, side, spec['interface_strip_px']))
                cell['connection_coverage'][side] = ratio
                if ratio < spec['interface_min_coverage']:
                    cell['issues'].append('disconnected_material_interface_'+side)
            if 'min_opaque_fraction' in declaration and fraction(alpha) < declaration['min_opaque_fraction']:
                cell['issues'].append('insufficient_opaque_fill')
            if declaration.get('complete_rooted_subject'):
                box = cell['alpha_bounds']['128']
                if box:
                    padding = [box[0], box[1], cw-box[2], ch-box[3]]
                    cell['padding_px'] = padding
                    if min(padding) < spec['subject_min_padding_px']:
                        cell['issues'].append('subject_touches_cell_boundary')
                    root_depth = declaration.get('root_band_px', 12)
                    root_alpha = alpha.crop((0, max(box[1], box[3]-root_depth), cw, box[3]))
                    root_box = bounds(root_alpha, 128)
                    if root_box:
                        cell['root_source_interval'] = [root_box[0], root_box[2]]
                        cell['anchor_px'] = [(root_box[0]+root_box[2])/2, box[3]-1]
                        cell['world_height'] = declaration['world_height']
                        cell['uniform_scale'] = declaration['world_height']/(box[3]-box[1])
                        if cell['uniform_scale'] > declaration['max_uniform_scale']:
                            cell['issues'].append('would_enlarge_small_subject_beyond_frozen_limit')
                    else:
                        cell['issues'].append('no_measurable_root')
            tile_path = output/(name+'.png')
            tile.save(tile_path)
            cell['extracted'] = {'path': str(tile_path), 'sha256': sha(tile_path)}
            issues.extend(name+':'+issue for issue in cell['issues'])
            report['cells'].append(cell)
    report.update(numeric_status='passed' if not issues else 'failed',
                  calibration_seconds=time.monotonic()-started,
                  created_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
    (output/'calibration.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


def calibrate_continuous(source: Path, spec_path: Path, output: Path,
                         sampling_path: Path) -> dict:
    """Measure an unchanged mother painting; never promote an alternate use."""
    source, spec_path, output, sampling_path = map(Path, (source, spec_path, output, sampling_path))
    if output.exists():
        raise ValueError('Use a new output directory; failed attempts are immutable')
    spec = json.loads(spec_path.read_text())
    sampling = json.loads(sampling_path.read_text())
    core = spec.get('normalized_solid_core')
    def finite(value):
        return type(value) in (int, float) and math.isfinite(value)
    if (not isinstance(core, list) or len(core) != 4 or not all(finite(v) for v in core)
            or not 0 <= core[0] < core[2] <= 1 or not 0 <= core[1] < core[3] <= 1):
        raise ValueError('Frozen normalized core must be ordered and inside the source')
    level, minimum = spec.get('core_alpha_min'), spec.get('core_coverage_min')
    if type(level) is not int or not 1 <= level <= 255 or not finite(minimum) or not 0 < minimum <= 1:
        raise ValueError('Invalid frozen alpha or coverage threshold')
    scale, band = sampling.get('uniform_scale'), sampling.get('edge_source_band_px')
    if not finite(scale) or not 0 < scale <= 0.25:
        raise ValueError('Sampling requires one uniform scale, at most the declared 0.25')
    if type(band) is not int or band <= 0:
        raise ValueError('Sampling requires a positive integer source band')
    if 'source_sha256' in spec and spec['source_sha256'] != sha(source):
        raise ValueError('Source differs from the frozen source hash')
    if 'source_sha256' in sampling and sampling['source_sha256'] != sha(source):
        raise ValueError('Source differs from the sampling source hash')
    started = time.monotonic()
    with Image.open(source) as image:
        if image.mode != 'RGBA':
            raise ValueError('Expected original RGBA carrier; do not manufacture transparency')
        alpha = image.getchannel('A')
    w, h = alpha.size
    if band * 2 > min(w, h):
        raise ValueError('Sampling band consumes the source core')
    # Round inward: the report exposes the exact measured rectangle, not an
    # inferred opaque rectangle chosen after seeing the returned image.
    rect = [math.ceil(core[0]*w), math.ceil(core[1]*h),
            math.floor(core[2]*w), math.floor(core[3]*h)]
    if rect[0] >= rect[2] or rect[1] >= rect[3]:
        raise ValueError('Frozen core is empty at the actual source resolution')
    coverage = fraction(alpha.crop(tuple(rect)), level)
    issues = [] if coverage >= minimum else ['frozen_core_insufficient_opaque_coverage']
    regions = {'left': [0, 0, band, h], 'right': [w-band, 0, w, h],
               'top': [0, 0, w, band], 'bottom': [0, h-band, w, h]}
    interfaces = {}
    for side, region in regions.items():
        part = alpha.crop(tuple(region))
        inward = {'left': 'right', 'right': 'left', 'top': 'bottom', 'bottom': 'top'}[side]
        interfaces[side] = {'source_region_xyxy': region,
                            'alpha_128_fraction': fraction(part),
                            'inward_interface_4px_alpha_128_coverage': fraction(edge_strip(part, inward, min(4, band))),
                            'exterior_alpha_bounds': {str(t): bounds(part, t) for t in (1, 2, 128, 250)},
                            'numeric_admission': 'not_assessed_no_frozen_interface_threshold',
                            'gpu_acceptance': 'unverified'}
    report = {'schema_version': 1, 'artifact_kind': 'measured_continuous_source_calibration',
              'family_id': spec.get('family_id'), 'source': str(source), 'source_sha256': sha(source),
              'spec': str(spec_path), 'spec_sha256': sha(spec_path),
              'sampling_spec': str(sampling_path), 'sampling_spec_sha256': sha(sampling_path),
              'source_dimensions': [w, h], 'alpha_bounds': {str(t): bounds(alpha, t) for t in (1, 2, 128, 250)},
              'frozen_core': {'normalized_xyxy': core, 'measured_source_xyxy': rect,
                              'alpha_min': level, 'coverage': coverage, 'minimum_coverage': minimum,
                              'status': 'failed' if issues else 'passed'},
              'declared_sampling_use': {'uniform_scale': scale, 'edge_source_band_px': band,
                                       'internal_material': 'approved_v8_fallback', 'interfaces': interfaces},
              'issues': issues, 'numeric_status': 'failed' if issues else 'passed',
              'artistic_acceptance': 'unverified', 'full_family_acceptance': 'unverified',
              'missing_painted_interfaces': ['dedicated_concave_corners'],
              'scope': 'Unchanged source measurements only. Perimeter sampling cannot rescue frozen-core failure; no full corner matrix, GPU or commercial approval.',
              'calibration_seconds': time.monotonic()-started,
              'created_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
    output.mkdir(parents=True)
    (output/'calibration.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--spec', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--continuous', action='store_true', help='Measure a continuous mother source rather than a grid')
    parser.add_argument('--sampling-spec', type=Path, help='Explicit perimeter sampling declaration; cannot promote the frozen core')
    args = parser.parse_args()
    if args.continuous:
        if not args.sampling_spec:
            parser.error('--continuous requires --sampling-spec')
        report = calibrate_continuous(args.source, args.spec, args.output, args.sampling_spec)
    else:
        if args.sampling_spec:
            parser.error('--sampling-spec requires --continuous')
        report = calibrate(args.source, args.spec, args.output)
    print(json.dumps({key: report[key] for key in ('family_id', 'numeric_status', 'issues', 'calibration_seconds')}))
    return 0 if report['numeric_status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
