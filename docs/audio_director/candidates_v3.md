# V3 功能音形候选 · audio-director-v3

遵循[第三轮声音功能规范](style_bible_v3.md)。Mario、动物森友会、Hollow Knight只是用户表达的收集/获得/动作反馈参考，本轮没有复制这些商业游戏的任何音频。主角原起跳、落地等本轮保留项不改；五首用户BGM原文件不动。

本轮为快速真实场景录屏提供三套完整设计，每事件每套1个成品，共14×3=42个WAV。A为清脆获得、B为水铃童话、C为木芯机关；这些是待听的设计假设，不是用户认可或商业品质承诺。单个方向只有1个完整变体，明确不冒称已做多take防疲劳。

| 功能 | 本轮实际处理 |
| --- | --- |
| 金币收集 | 新CC0 Coin01获得声与铃芯/宝石短上扬，约0.14–0.19秒；彻底不使用v2钱币落地素材 |
| 液体回血 | 新CC0 Water40气泡/水流/轻水滴为主体，约0.53秒；尾部仅低比例回复亮点 |
| 宝箱开启 | 锁扣→木盖→宝石余响，约0.57–0.70秒，和普通拾取分开 |
| 长道具获得 | 新CC0获得/升级音色或采样铃音原创时序编排，约1.74–1.81秒，实际有声末尾>1.69秒，不用静音padding冒充长乐句 |
| UI | 细小实体点击/扣锁和低比例确认亮点；拒绝短收拢，避免每次点击长奖励 |
| 动作命中 | 极短刀风/实心接触主体；敌人受伤副层更轻，主角受伤另选，避免同次伤害两段重瞬态 |
| 三武器 | 脉冲枪短空气/簧片；手里剑快速刃风；炸弹物件投出及独立低部冲击/破碎爆炸 |

新素材为wobbleboxx的[Level up, Power up, Coin get 13](https://opengameart.org/content/level-up-power-up-coin-get-13-sounds)及rubberduck的[Water40](https://opengameart.org/content/40-cc0-water-splash-slime-sfx)，均实取原ZIP并核原页面CC0。另使用既有已核Kenney及rubberduck的刃风、木/锁/短碰撞原录音。完整作者、原文件名、来源URL、许可/商业条件/署名要求、下载日期、原ZIP/页面/输入SHA保存在 `config/audio_director/v3/sources.json`；58个选用原件与许可放`assets/audio/director_v3/_sources/.gdignore`，整包未提交运行库。

主要制作素材是上述可商用采样，不生成纯正弦或随机噪声。每层明确记录输入裁剪、半音重采样、滤波、端点包络、增益、延迟，浮点合成后统一最终峰值/RMS约束。上限−5dBFS只防文件削波，不证明混音一定不遮盖、不刺耳或悦耳。

```sh
python3 tools/audio_candidates_v3.py build
python3 tools/audio_candidates_v3.py validate
python3 -m unittest discover -s tests -p 'test_audio_candidates_v3.py' -v
```

校验同时核源/配方/工具/FFmpeg指纹、真实播放路径/变体、recipe事件/方案绑定、来源与summary，并从原素材重算全部DSP trace及输出SHA。金币配方拒绝钱币落地源，回血要求具有足量液体主体，道具获得检查实际非静音尾部≥1.5秒。工程检查只说明输出、来源及音形约束实际成立，最终审美由用户在真实录屏选择。
