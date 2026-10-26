# 第二轮现成素材候选 · audio-director-v2

用户已拒绝第一轮A/B。此轮只制作UI、拾取、命中与受伤三套候选；已获正面反馈的原起跳/落地，以及枪、死亡、钩索等本轮未要求替换的事件保持原版。三套均为等待真实场景试听的假设，不能以CC0、文件数或自动指标签悦耳。

| 套装 | UI原声族 | 拾取原声族 | 战斗原声族 |
| --- | --- | --- | --- |
| A · 实体轻触 | Kenney clicks与switches | RPG金币/宝石原录音 | 新75 Hit中的短碰撞录音 |
| B · 轻响拾取 | Kenney rollover/switches | RPG另一组金币、魔法/物件原录音 | 100 Metal/Wood木质命中，主角受伤单独短撞 |
| C · 短机械 | Kenney另一组click/switches | RPG物件与翻书式普通物品动作 | 100 Metal/Wood金属命中及75 Hit另一组短撞 |

这些名称只描述筛选意图。没有声称已通过人工听感验收。金币/宝石/书页是素材原语义，具体游戏事件是否匹配需在同画面/BGM/操作中比较；主角受伤不用怪物嗓音，命中与受伤是分开的事件，不以单个木撞代表所有角色。

机器权威：`assets/audio/director_v2/manifest.json`、`config/audio_director/v2/{recipes,sources,runtime}.json`。9事件为 `click/confirm/denied/coin/heal/reward/enemy_hit/enemy_hurt/hurt`，每套每事件2个不同原始take，合计54个不同WAV。没有音高复制冒充第二变体。主要选用Kenney UI原WAV、rubberduck RPG80、100 Metal/Wood、75 Breaking/Falling/Hit；Kenney OGA早期UI包与官方UI Audio为同一来源族，未计作两种独立作者。

每个输出只有一个原录音。处理为：44.1kHz单声道PCM解码；按首/末超过−55dBFS样本定位外部静音并留2ms缓冲，不删除中间安静间隔；只对长尾设置事件时长上限；短淡入淡出与有界增益。不叠层、不合成、不改变pitch，不把所有素材硬裁为相同长度。峰值上限−6dBFS，事件RMS目标只作电平参考；峰值约束优先，不能把低RMS等同不合格或夸大为LUFS。

```sh
python3 tools/audio_candidates_v2.py build
python3 tools/audio_candidates_v2.py build --event coin
python3 tools/audio_candidates_v2.py validate
python3 -m unittest discover -s tests -p 'test_audio_candidates_v2.py' -v
```

原文件、作者、URL、下载日期、原ZIP与页面SHA、许可、商业条件与署名要求都在sources注册表，原名少量原件/来源页面/CC0文本放 `_sources/.gdignore`，未用整包仅在workspace缓存。所有候选为CC0，可商用/修改且无强制署名；本项目保留作者与许可用于溯源。BGM原五MP3字节不动。

验证拒绝配方、注册表、加工器、FFmpeg版本、原录音与输出漂移；单事件重建前先验证旧版本，不能给未重建条目冠新指纹。输出54个SHA全不同；真实首轮与全量重建逐字节相同。10项临时副本反例覆盖配方/来源/工具漂移、原件修改、来源快照伪造、输出篡改、重复take、未漂移partial重建，以及播放path/variants重定向和profile/source/summary/preserve元数据篡改。它们只验证制作完整性，听感需由用户在新版真实场景确认。

工程失败保留：首次使用FFmpeg持续/反转静音门限时，稀疏按钮瞬态被过度裁切；诊断后改为PCM首末样本定位保留全部内部间隔，未放宽8ms/非静音/峰值门槛。原失败与修复在 `build/audio_director_v2/`，不把技术故障误写成用户审美拒绝。

独审修复：校验器原先未闭环实际播放器读取的candidate.path/variants。现逐项核对recipe事件/候选顺序与ID/profile/source、确定输出路径、renders顺序、第一变体summary，并核profiles/version/preserve/default政策；重定向到v1旧音频、交换变体或伪造summary均拒绝。当前54个音频字节没有改变，旧校验缺口不改签为过去已覆盖。
