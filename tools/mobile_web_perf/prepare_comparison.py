"""Prepare verified before/after bundles for the existing Pages deployment.

The frozen before folder keeps its own original metadata, worker, resources and
engine. The dispatch workflow reconstructs both exact PCKs from their own chunks.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from style_exploration_delivery import reconstruct_pack


def copy_bundle(source, target):
    # Neither Git history nor a >100MiB raw PCK belongs in the prepared branch.
    shutil.copytree(source, target, ignore=shutil.ignore_patterns('.git', '*.pck'))
    return reconstruct_pack(target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--after', required=True, type=Path)
    parser.add_argument('--before', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    assert not args.output.exists(), 'Keep prior prepared attempts intact'
    after = copy_bundle(args.after, args.output)
    before = copy_bundle(args.before, args.output / 'audio-before')
    assert before['build_id'] == '2caa023125bd', before
    assert before['source_commit'] == '4707b9ef15fa7e89b09d3e33ef8206c0b12f64af', before
    assert after['build_id'] != before['build_id'], after
    size = sum(p.stat().st_size for p in args.output.rglob('*') if p.is_file())
    assert size < 1024 ** 3, ('Pages maximum unpacked site size exceeded', size)
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>声音修复对照</title><style>body{background:#111b22;color:#eee5cf;font:18px/1.7 system-ui;max-width:680px;margin:6vh auto;padding:20px}a{display:block;background:#314549;color:#ffe1a0;padding:18px;margin:16px 0;border-radius:8px}small{color:#bdc8c4}</style>
<h1>声音修复对照</h1><p>两个版本保留相同的 UI、画面和声音素材。请分别进入家园和关卡，比较跳跃、射击、拾取音效，以及播放中与打开菜单后的声音。</p>
<a href="./?audio_compare=after">进入声音修复版 · AFTER_ID</a>
<a href="audio-before/?audio_compare=before">进入修复前版本 · 2caa023125bd</a>
<p>持续声音断续：以下两组使用同一个新版游戏和已选音效，仅改变流式音频缓冲。进入家园／关卡后点击“记录游戏中”，打开游戏菜单后点击“记录菜单中”，最后下载检测记录。</p>
<a href="audio-stream-test.html?latency=50&amp;audio_probe=1&amp;diag=timing-v1">主线程供音 · 50ms</a>
<a href="audio-stream-test.html?latency=200&amp;audio_probe=1&amp;diag=timing-v1">主线程供音 · 200ms</a>
<a href="audio-threaded/?latency=50&amp;audio_probe=1">独立音频线程 · 50ms</a>
<p>独立线程版保持同一游戏包、画面和声音，用于核验供音是否受主线程阻塞。首次打开会自动重载以启用浏览器隔离。家园普通菜单与关卡暂停请分别记录。</p>
<small>每次关闭上一个游戏标签，再打开另一版。新版启用你已选定的工坊音效；手机上的持续断续仍待实际对照确认。</small></html>'''.replace('AFTER_ID', after['build_id'])
    (args.output / 'audio-compare.html').write_text(page)
    receipt = {'scope': 'Same accepted UI/art, frozen original versus audio fixes and selected SFX integration; physical continuity unverified',
        'after': after, 'before': before, 'unpacked_site_bytes': size,
        'comparison_path': 'audio-compare.html', 'raw_packs_verified_then_removed_for_git_transport': True}
    (args.output / 'audio-comparison.json').write_text(json.dumps(receipt, indent=2) + '\n')
    for root in (args.output, args.output / 'audio-before'):
        for pack in root.glob('*.pck'):
            pack.unlink()
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
