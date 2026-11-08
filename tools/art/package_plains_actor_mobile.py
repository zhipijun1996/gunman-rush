#!/usr/bin/env python3
"""Small, independently playable clips cut from actual 60 Hz combat captures."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'build/plains_actors_142'
OUT = BASE / 'mobile-combat'
LABELS = {'patrol':'巡逻怪','charger':'冲锋怪','hopper':'跳跃怪','sentry':'哨兵','fan_sentry':'扇射哨兵','root_bell':'根铃','diver':'俯冲怪 · 空中死亡落地','bell':'鸣铃巡游机','keeper':'牧风者一阶段','windmill':'牧风者二阶段'}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for folder, master in [('enemy-combat','enemy-combat.avi'),('combat','combat-revision.avi')]:
        rows = json.loads((BASE / folder / 'timeline.json').read_text())
        for row in rows:
            name = row['scene']
            target = OUT / (name + '.mp4')
            start = row['start_frame'] / 60
            duration = (row['end_frame'] - row['start_frame']) / 60
            subprocess.run([
                'ffmpeg', '-v', 'error', '-y', '-ss', str(start), '-i', str(BASE / master),
                '-t', str(duration), '-vf', 'scale=960:540:flags=neighbor,fps=60',
                '-c:v', 'libx264', '-profile:v', 'baseline', '-level', '3.2',
                '-preset', 'fast', '-crf', '25', '-maxrate', '750k', '-bufsize', '1500k',
                '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '64k',
                '-movflags', '+faststart', str(target),
            ], check=True)
            assert target.stat().st_size < 3_000_000, target
            manifest.append({'file':target.name,'label':LABELS[name], 'bytes':target.stat().st_size,
                             'seconds':round(duration,2),'fps':60,'capture':master,'timeline':row})
            print(LABELS[name], target.stat().st_size, flush=True)
    (OUT / 'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    (OUT / 'README.md').write_text(
        '# 平原怪物 · 实际战斗预览\n\n每次只打开一段。独立 MP4，960×540、60fps、游戏原声、faststart，每段小于 3 MB。'
        '正式角色、AI、输入、投射物、伤害和尸体下落在真实地形运行。普通怪为单怪布置；Boss 设置开场站位并使用审查宽镜头保留双方与地面，牧风者二阶段设置生命阈值。'
        '自动操作片段不代表自然通关或全招式覆盖。\n\n'
        + '\n'.join(f'- [{r["label"]}]({r["file"]}?raw=1)（{r["seconds"]:.1f} 秒，{r["bytes"]/1000:.0f} KB）' for r in manifest)
        + '\n\n源码：[PR #144](https://github.com/zhipijun1996/gunman-rush/pull/144)。\n'
    )


if __name__ == '__main__':
    main()
