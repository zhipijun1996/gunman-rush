# 失序之钟 · Audio Director

当前以**V3真实场景录屏**供用户选择：[手机点播](https://clock-audio-director-lab.silkyball18.chatgpt.site/reels-v3/)、[功能声音规范](style_bible_v3.md)、[事件/代码增量](event_catalog_v3.md)、[实际来源与验证](../evidence/audio_director_03/README.md)。42个CC0候选覆盖金币/液体回血/宝箱/长道具/打击/3武器/UI。原起跳/落地和五BGM保留，v1否决与V2未选历史保留；所有V3音色仍待用户，不宣称商业品质。下方v1命令仅作旧原件追溯，以brief.next_command的当前版本为准。

任务 **AUDIO-DIRECTOR-01**，第一阶段候选版本 `audio-director-v1`。目标是持续产出可听、可比、可追溯的游戏SFX。技术验证、用户听感与实体设备分别记录；当前没有商业品质批准。

| 交付 | 入口 |
| --- | --- |
| 原版资源审计（固定main 26e7f2a） | [Audio Inventory](inventory.md) / [逐文件JSON](inventory.json) |
| 事件、调用行与缺口 | [Audio Event Catalog](event_catalog.md) / [JSON](event_catalog.json) |
| 统一声音美学 | [Audio Style Bible](style_bible.md) |
| 原料、商业条件与来源研究 | [Audio Source Library](source_library.md) |
| 可复现加工与版本指纹 | [Sound Design Pipeline](pipeline.md) |
| 共享12声池、事件接口与生命周期 | [Godot运行规范](runtime.md) |
| 第一批16事件、32方向、64 WAV | [manifest](../../assets/audio/director_candidates/manifest.json) |
| 第一阶段范围/所有权 | [Cloud工作线](../worklines/audio_director_01/scope.md) |
| 实际验证与最终试听地址 | [交付证据](../evidence/audio_director_01/README.md) |

A偏木芯钟簧，B偏透明魔法；两方向都是可淘汰的假设。真实Godot默认游戏保留original；Lab显式选择A/B。原五首MP3不生成、不替换、不加工。反冲作为枪声的统一包络，单声recoil候选用于额外比较，不在游戏开火上双重叠加。

## 简短需求直接开始

仓库会自动路由 [.agents/skills/audio-director](../../.agents/skills/audio-director/SKILL.md)。可以直接说“为某敌人设计声音”“优化钩索声音”“为新区域设计环境声音”。执行者必须实际读对应家族、许可库、事件和原消费者，再制作候选；不把上下文路由误称已经完成创作。

```sh
python3 tools/audio_director.py brief '优化钩索声音'
python3 tools/audio_director.py audit
python3 tools/audio_director.py build
python3 tools/audio_director.py validate
python3 tools/audio_director.py lab --output build/audio_director/listen-FRESH --game-url ACTUAL_SAME_SOURCE_GODOT_URL
```

`brief`把既有声音家族和依据SHA写到build；新敌人/新区域还需要实际选材与新配方。`audio_design.py build --event EVENT`可重建单事件，来源/配方/加工器发生漂移时必须全量重建，不能把其他旧候选追认为新版。输出新版本保留失败，当前prototype不是自动批准的素材替换器。

## 试听

手机页面支持A/B/C原版、两变体、单声/循环、五曲BGM、相近响度/实际游戏增益、来源许可、按事件选择/备注与JSON导出。选择保存在本机浏览器，导出后回传；没有伪造远程投票或跨设备同步。原版无持续牵引声，单声工坊对此保留安静；不拿接触踢impact冒充持续声。

真实Godot入口 `res://scenes/dev/audio_director_lab.tscn` 直接复用正式DemoApp与默认角色，支持家园、平原和森林显式开发入口；森林授予沿既有debug API，不能作为自然进度证明。返回完整游戏仍禁用预览存档。新版优先只让已接受动作驱动音频，不改伤害/物理/操作。

## 验证边界

音频指标拒绝损坏、静音、削波或指纹漂移；不能评审悦耳、疲劳或世界观匹配。Dummy音频的引擎测试不能替代听音；桌面Chromium手机尺寸也不能替代手机Safari、蓝牙延迟或实体扬声器。用户选择之后才进入相应事件的正式推广与混音迭代。
