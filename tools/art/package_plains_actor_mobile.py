#!/usr/bin/env python3
"""Phone-sized, independently playable review clips; keeps native masters intact."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'build/plains_actors_142'
OUT = BASE / 'mobile'
GROUPS = {
    'normal-enemies': ('七类普通怪', ['01-meadow', '02-junction']),
    'bellstrider': ('鸣铃巡游机', ['04-bellstrider']),
    'windkeeper': ('牧风者一／二阶段', ['05-keeper-one', '06-keeper-two']),
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for name, (label, ids) in GROUPS.items():
        listing = BASE / (name + '-mobile-concat.txt')
        listing.write_text(''.join("file '" + str(BASE / 'context' / (i + '.mp4')) + "'\n" for i in ids))
        target = OUT / (name + '.mp4')
        subprocess.run([
            'ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(listing),
            '-vf', 'scale=960:540:flags=neighbor,fps=30', '-c:v', 'libx264',
            '-profile:v', 'baseline', '-level', '3.1', '-preset', 'fast', '-crf', '27',
            '-maxrate', '400k', '-bufsize', '800k', '-pix_fmt', 'yuv420p', '-an',
            '-movflags', '+faststart', str(target),
        ], check=True)
        assert target.stat().st_size < 1_000_000, target
        manifest.append({'file': target.name, 'label': label, 'bytes': target.stat().st_size})
        print(label, target.stat().st_size, flush=True)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    (OUT / 'README.md').write_text(
        '# 平原动画 · 手机预览\n\n每次只打开一段。独立 MP4，540p、30fps、无声，每段不足 1 MB。'
        '内容为正式地形、主角与光照下的定点动作检视，不是自然战斗录像。'
        '为减少传输而压缩；原生像素素材见主工作分支。\n\n'
        + '\n'.join(f'- [{r["label"]}]({r["file"]}?raw=1)（{r["bytes"] / 1000:.0f} KB）' for r in manifest)
        + '\n\n源码：[PR #144](https://github.com/zhipijun1996/gunman-rush/pull/144)。\n'
    )


if __name__ == '__main__':
    main()
