"""Build review media and observed evidence from actual Godot captures."""
import hashlib
import json
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/kit-reuse'
config = json.loads((ROOT / 'config/art/kit_reuse.json').read_text())
freeze = json.loads((OUT / 'freeze.json').read_text())
changed = [p for p, sha in freeze['frozen'].items()
           if not (ROOT / p).is_file() or hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != sha]
assert not changed, changed
capture = json.loads((OUT / 'capture.json').read_text())
assert len(capture['frames']) == 288
controller = json.loads((OUT / 'controller.json').read_text())
assert len(controller['trace']) == 96
font_path = subprocess.check_output(['fc-match', 'Noto Sans CJK SC', '-f', '%{file}'], text=True)
font = ImageFont.truetype(font_path, 18)
sheet = Image.new('RGB', (1280, 1200), '#111b29')
draw = ImageDraw.Draw(sheet)
for col, title in enumerate(['A：重复中景＋原亮度', 'B：同素材，移除中景＋共享层次参数']):
    draw.text((col * 640 + 12, 6), title, font=font, fill='#e0e9ed')
metrics = {}
for index, (id, label) in enumerate([('passage', '横向通道'), ('shaft', '竖井'), ('hall', '宽厅')]):
    y = 36 + index * 388
    draw.text((12, y), label + ' · Godot实帧50%缩图；本轮美术未通过', font=font, fill='#e7c78f')
    for col, profile in enumerate(['flat', 'depth']):
        im = Image.open(OUT / f'{id}-{profile}.png').convert('RGB')
        sheet.paste(im.resize((640, 360), Image.Resampling.NEAREST), (col * 640, y + 27))
    lit = np.array(Image.open(OUT / f'{id}-depth.png').convert('RGB')).astype(int)
    unlit = np.array(Image.open(OUT / f'{id}-light-off.png').convert('RGB')).astype(int)
    difference = np.any(lit != unlit, axis=2)
    yy, xx = np.mgrid[:720, :1280]
    point = np.array(config['rooms'][id]['bell']) - np.array(config['rooms'][id]['camera']) + [640, 360]
    outside = (xx - point[0])**2 + (yy - point[1])**2 > (config['light']['radius'] + 3)**2
    outside_count = int(np.sum(difference & outside))
    assert outside_count == 0, (id, outside_count)
    frames = OUT / f'{id}-frames'
    # An interrupted old capture may leave excess frames; never mix generations.
    for p in frames.glob('*.png'):
        if int(p.stem) >= 96:
            p.unlink()
    assert len(list(frames.glob('*.png'))) == 96
    metrics[id] = {'tour_frames': 96, 'light_changed_pixels': int(np.sum(difference)),
                   'changed_outside_light_radius': outside_count,
                   'new_room_specific_generated_art': 0}
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '12', '-i', str(frames / '%04d.png'),
                    '-frames:v', '96', '-c:v', 'libx264', '-crf', '23', '-pix_fmt', 'yuv420p',
                    '-movflags', '+faststart', str(OUT / f'{id}.mp4')], check=True)
sheet.save(OUT / 'comparison.png')
control_sheet = Image.new('RGB', (1280, 806), '#111b29')
dc = ImageDraw.Draw(control_sheet)
for col, (name, title) in enumerate([('control-fixed', '固定画面原位'), ('control-forced-parallax', '强行错开背景96px：出现未补全区域')]):
    dc.text((col * 640 + 12, 8), title, font=font, fill='#e7c78f')
    im = Image.open(OUT / f'{name}.png').convert('RGB')
    control_sheet.paste(im.resize((640, 360), Image.Resampling.NEAREST), (col * 640, 38))
for col, (name, title) in enumerate([('control-moved-camera', '原固定画面：相机移动240/120px'), ('controller-35', '正式Motor＋WorldCamera，1.6倍镜头')]):
    dc.text((col * 640 + 12, 405), title, font=font, fill='#e7c78f')
    im = Image.open(OUT / f'{name}.png').convert('RGB')
    control_sheet.paste(im.resize((640, 360), Image.Resampling.NEAREST), (col * 640, 435))
control_sheet.save(OUT / 'control-comparison.png')
ablation = Image.new('RGB', (1920, 394), '#111b29')
da = ImageDraw.Draw(ablation)
for col, (profile, label) in enumerate([('flat', 'A：原亮度＋重复中景'), ('flat-no-middle', 'B：只移除重复中景'), ('depth', 'C：再统一调整明暗与光强')]):
    da.text((col*640+12, 6), label, font=font, fill='#e7c78f')
    im = Image.open(OUT / f'passage-{profile}.png').convert('RGB')
    ablation.paste(im.resize((640,360), Image.Resampling.NEAREST), (col*640,34))
ablation.save(OUT / 'ablation.png')
strip = Image.new('RGB', (1920, 720), '#111b29')
ds = ImageDraw.Draw(strip)
for row, id in enumerate(config['rooms']):
    for col, frame in enumerate([0,24,48,72,95]):
        ds.text((col*384+8,row*240), f'{id} · frame {frame}', font=font, fill='#e7c78f')
        im = Image.open(OUT / f'{id}-frames/{frame:04d}.png').convert('RGB')
        strip.paste(im.resize((384,216),Image.Resampling.NEAREST),(col*384,row*240+24))
strip.save(OUT / 'tour-strip.png')
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '12', '-i', str(OUT / 'controller-frames/%04d.png'),
                '-frames:v', '96', '-c:v', 'libx264', '-crf', '23', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', str(OUT / 'controller.mp4')], check=True)
report = {
    'baseline': freeze['baseline'], 'frozen_files_checked': len(freeze['frozen']), 'frozen_changed': changed,
    'new_unique_paintings': 1, 'new_room_specific_paintings': 0,
    'derived_textures': ['arch.png', 'arch-half.png', 'pier.png'],
    'reuse_scope': 'three experimental layouts share the same input paths and hashes; not registered formal rooms or editor integration',
    'camera_tours': metrics,
    'controller_scope': 'production PlayerMotor/controller, UnderworldPlayer, WorldCamera on left bank only',
    'controller_grounded_frames': sum(t['on_floor'] for t in controller['trace']),
    'controller_x_range': [min(t['position'][0] for t in controller['trace']), max(t['position'][0] for t in controller['trace'])],
    'cost_evidence': 'one image generation, no per-layout repaint or mask; shared renderer/config setup. Per-room human time not measured, so reduced production cost is unproven.',
    'visual_verdict': 'FAILED for production expansion: repetition, vertically inappropriate screen-fixed horizon, material family mismatch, modular joints and mismatched platform end treatment.',
    'scope_limit': 'complete arch and full opaque far plate are separate; this is not an independently moving full regional depth kit. Depth profile removes the optional middle row.',
    'generation_geometry': 'FAILED exact silhouette; painting native pier ~90 instead of64; no production collision changed.',
    'assets': json.loads((ROOT / 'assets/kit_reuse/manifest.json').read_text()),
}
(OUT / 'evidence.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ['frozen_files_checked', 'frozen_changed', 'new_unique_paintings', 'controller_grounded_frames', 'visual_verdict']}, ensure_ascii=False))
