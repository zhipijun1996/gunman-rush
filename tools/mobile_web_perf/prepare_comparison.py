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
<small>每次关闭上一个游戏标签，再打开另一版。声音修复仅处理总线创建及环境细节音反复重启；手机效果与背景音乐连续性等待实测。</small></html>'''.replace('AFTER_ID', after['build_id'])
    (args.output / 'audio-compare.html').write_text(page)
    receipt = {'scope': 'Same accepted UI/art, frozen original versus two audio-only fixes; physical outcome unverified',
        'after': after, 'before': before, 'unpacked_site_bytes': size,
        'comparison_path': 'audio-compare.html', 'raw_packs_verified_then_removed_for_git_transport': True}
    (args.output / 'audio-comparison.json').write_text(json.dumps(receipt, indent=2) + '\n')
    for root in (args.output, args.output / 'audio-before'):
        for pack in root.glob('*.pck'):
            pack.unlink()
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
