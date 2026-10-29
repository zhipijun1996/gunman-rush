# 两区环境音 · audio-ambience-v1

## quiet-02 · 用户反馈修订（2026-10-29）

用户明确首版环境音太响、盖住BGM，要求微弱衬底。BGM原MUSIC_GAIN=0.16（约−15.9dB），不能只看环境源文件RMS判断混音。quiet-02保原选材与归一，输出末端床声−14dB、四点声−10dB；复现参数`output_gain_db`在配方内，先归一/控峰后衰减，避免峰值限制使降音量无效。原Music及五MP3不变。原版较响交付与此前技术证据保留，用户此反馈判定旧混音不接受；新混音仍待用户试听。


任务AUDIO-AMBIENCE-01。[手机实景试听](https://clock-ambience-lab.zhipijun1996.chatgpt.site/)已发布，包含原版/A/B和BGM混音/环境单听；需拥有者账号。[本轮实际事件/引用](ambience_event_catalog.json)。当前为可淘汰的开发候选，用户听感和实体设备未验证。基于最新main45e98dbb；原Audio Inventory的26e7f2a基线保留，不回写历史审计。

## 已验证的原声音与消费者

| 原声音/缺口 | 代码位置 | 实际用途与边界 |
| --- | --- | --- |
| forest_wind | scripts/presentation/forest_bible_ambience.gd:77；scripts/audio/game_audio.gd的REGIONAL_CUE_PATHS | 正式森林每9秒、首次3秒播放短合成风；原始来源与配方为tools/generate_forest_bible_sfx.py和assets/forest_bible_v2/audio/provenance.json |
| forest_fruit / forest_web | scripts/presentation/forest_bible_ambience.gd:59、69 | 800wu内已接受钩果/蛛网生长事件，0.20/0.45秒限流；不当持续环境床声 |
| 地区加载/退出 | scripts/demo/demo_app.gd；scripts/demo/thorn_forest_region_stage.gd | 正式场景持有ForestBibleAmbience，退出调用GameAudio.stop_region；现有表现与规则保留 |
| 平原风铃机关 | scripts/world/shot_latch.gd:335 | 玩家操作成功的反馈，不能用随机环境铃冒充成功 |
| 持续风草/树冠 | 新开发manifest与GameAudio拥有的GameAmbience | 原正式GameAudio没有连续床声接口；本轮显式试听，正式默认仍original |
| 用户地区BGM | scripts/audio/game_music.gd:5；assets/audio/bgm/provenance.json | 五原MP3逐字节保留，MusicGain0.16、会话0.7作为原运行基线 |

上表为源码事实；原短风是否刺耳、素材是否自然、是否与音乐冲突属于待试听判断。原来源生成事实可验证，其审美不由程序判定。

## 本轮声音方向

延续柔和童话、隐藏悲伤、精巧机械与轻盈魔法。平原以空气、柔软草叶和远处稀疏铜质回应构成开阔感；森林以较暗树冠、叶层和木质空腔体现围合，保持温暖与好奇，避开恐怖低鸣。环境不能持续占据金币、UI和钩索的辨识频段。

A/B必须使用不同真实录音片段/层次与节奏，有可听的材质差别；不以整体变调或加响冒充方案。长床声使用经过接缝加工的Vorbis循环，点声不loop；淡入淡出避免入区突响，定位来自真实listener和声源位置。没有真实宿主的点声只在明确标注的开发fixture出现，不假称全地图已布点。

用户选过的动作SFX与环境音是两项选择：本轮没有用户环境音批准，也不会因上一轮13项选择自动批准A/B。原jump/land与全部原BGM保留。

## 制作、运行与实景交付

实际素材与许可见[来源](ambience_sources.md)，处理参数与输入/输出指纹见`config/audio_director/ambience`、`assets/audio/ambience_v1/manifest.json`。运行接口和预算见[运行规范](ambience_runtime.md)。全量大录音放本地/构建cache，仅使用的加工结果与许可记录入库；加工脚本按原URL和SHA恢复输入。

```sh
python3 tools/audio_director.py brief '优化森林环境音'
python3 tools/audio_ambience_design.py build
python3 tools/audio_ambience_design.py validate
```

真实场景入口`res://scenes/dev/audio_ambience_lab.tscn`复用正式DemoApp与生成地图，固定Seed、禁用保存，森林显式开发入口。MovieMaker原生音轨比较original/A/B，BGM混合与淡出后环境分段；不能把后期配音、旧Web包或静图当新声音实景。最终发布/源码/媒体/测试身份以[本轮证据](../evidence/audio_ambience_01/README.md)为准。

## 验收与后续

可证技术边界：输入与许可指纹、时长/峰值/静音/接缝、播放与有界voice、交叉淡变、暂停、owner失效、死亡/退出、实际场景动作一致和原BGM字节。自动检查不能验证悦耳、录音人声/交通噪声是否违和、区域沉浸与疲劳；这些明确留给真实试听，不宣称商业品质。

后续简短需求会读取本页、两区Bible和已有声音家族；先就一个实际空间制作并对照，再推广树洞、高冠、风车、旧址。Boss环境、全地图空间分区、动态遮挡与水下滤波未在首轮承诺实现。
