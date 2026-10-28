"""Read original captured PNG bytes; no image edits or new rendered claims."""
import hashlib
import json
from pathlib import Path
from PIL import Image

base = Path('build/item_art_01')
regions = {'G05': (236, 276, 404, 444), 'P15': (560, 300, 704, 428),
           'P25': (280, 450, 360, 522), 'P20': (592, 448, 704, 592),
           'P16': (912, 448, 1024, 592)}
folders = ['body-pose-native-01', 'body-pose-native-02', 'body-pose-native-03',
           'body-pose-native-04', 'body-pose-native-05-gpu-control',
           'body-pose-native-06-original-control']
frames = ['g19-overview-trap-crystal-guard.png', 'g19-same-pose-state-0.png',
          'g19-same-pose-state-1.png', 'g19-same-pose-state-2.png',
          'guard-unavailable-existing-morning-scale.png']
results = []
for folder in folders:
    for frame in frames:
        path = base / folder / frame
        with Image.open(path) as original:
            image = original.convert('RGBA')
            background = image.getpixel((4, 4))
            counts = {}
            for key, rectangle in regions.items():
                # These fixture apertures exclude guides/ground lines. Their
                # foreground is the real corresponding renderer's body.
                counts[key] = sum(pixel != background for pixel in image.crop(rectangle).get_flattened_data())
        results.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'background_RGBA8': list(background), 'actual_foreground_pixels': counts,
                        'all_five_bodies_present': all(value > 20 for value in counts.values())})
reference = {Path(row['path']).name: row['sha256'] for row in results
             if Path(row['path']).parent.name == 'body-pose-native-03'}
replay = [row for row in results if Path(row['path']).parent.name == 'body-pose-native-06-original-control']
report = {'scope': 'Read-only native PNG byte/pixel audit. No source pixels or capture files modified. This refutes absence in original PNGs; not natural gameplay/device/visual acceptance.',
          'region_rectangles_xyxy': regions, 'script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'original03_vs_literal_producer_replay06_every_PNG_byte_identical':
              all(row['sha256'] == reference[Path(row['path']).name] for row in replay),
          'all_original_and_control_frames_contain_all_five_lower_bodies': all(row['all_five_bodies_present'] for row in results),
          'production_fix_made': False, 'GPU_source_readback_bug_claim': 'Not established; literal original GPU producer replay is byte-identical and original PNGs already contain bodies.',
          'frames': results}
target = base / 'body-persistence-audit-01.json'
target.write_text(json.dumps(report, indent=2))
print(json.dumps({key: value for key, value in report.items() if key not in ['frames', 'region_rectangles_xyxy']}, indent=2))
