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
    assert before['source_commit'] and before['pack_sha256'].startswith(before['build_id']), before
    assert after['build_id'] != before['build_id'], after
    size = sum(p.stat().st_size for p in args.output.rglob('*') if p.is_file())
    assert size < 1024 ** 3, ('Pages maximum unpacked site size exceeded', size)
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>声音修复对照</title><style>body{background:#111b22;color:#eee5cf;font:18px/1.7 system-ui;max-width:680px;margin:6vh auto;padding:20px}a{display:block;background:#314549;color:#ffe1a0;padding:18px;margin:16px 0;border-radius:8px}small{color:#bdc8c4}</style>
<h1>声音修复对照</h1><p>新版已将独立音频线程接入普通试玩，保留画质和已选工坊音效，并关闭瞄准减速的附加提示音、调整机关风铃声。</p>
<a href="./?v=AFTER_ID">进入修复版 · AFTER_ID</a>
<a href="audio-before/?audio_compare=before">原普通版 · BEFORE_ID</a>
<a href="audio-before/audio-threaded/?latency=50&amp;audio_probe=1">原独立线程测试 · 用户已反馈声音正常</a>
<p>下面保留原游戏包的主线程供音对照，不包含本次瞄准和机关声音调整。</p>
<a href="audio-before/audio-stream-test.html?latency=50&amp;audio_probe=1&amp;diag=timing-v1">原主线程 · 50ms</a>
<a href="audio-before/audio-stream-test.html?latency=200&amp;audio_probe=1&amp;diag=timing-v1">原主线程 · 200ms</a>
<small>每次关闭上一个游戏标签，再打开另一版。新版长期真机连续性仍须以实际试玩为准。</small></html>'''.replace('AFTER_ID', after['build_id']).replace('BEFORE_ID', before['build_id'])
    # Preserve already-shared diagnostic URLs, with query options intact.
    for path, target in [('audio-threaded/index.html', '../audio-before/audio-threaded/'),
                         ('audio-stream-test.html', 'audio-before/audio-stream-test.html')]:
        dest = args.output / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text('<!doctype html><meta charset="utf-8"><script>location.replace(' +
                        json.dumps(target) + ' + location.search + location.hash);</script>')
    (args.output / 'audio-compare.html').write_text(page)
    receipt = {'scope': 'Same accepted UI/art; frozen ordinary single-thread baseline and its original diagnostics versus production threaded audio and requested cue changes; new full-session phone continuity unverified',
        'after': after, 'before': before, 'unpacked_site_bytes': size,
        'comparison_path': 'audio-compare.html', 'raw_packs_verified_then_removed_for_git_transport': True}
    (args.output / 'audio-comparison.json').write_text(json.dumps(receipt, indent=2) + '\n')
    for root in (args.output, args.output / 'audio-before'):
        for pack in root.glob('*.pck'):
            pack.unlink()
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
