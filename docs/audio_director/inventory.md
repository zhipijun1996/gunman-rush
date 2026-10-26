# Audio Inventory（基线审计）

任务 AUDIO-DIRECTOR-01；固定源码 `26e7f2a4459623f35613a857da8a75e89daa3e62`。由 `python3 tools/audio_inventory.py` 重建。

该报告是第一阶段改动前的事实快照。完整逐文件媒体格式、SHA256、来源/作者/许可/原文件、引用行、生成器和节点清单在 [inventory.json](inventory.json)。不跟随工作区变化覆盖基线；要审计后续提交请显式传 `--ref <sha>` 和新输出目录。

`verified` 只证明字节/静态代码；`subjective_pending` 是待用户听音；`unknown` 表示没有依据。静态正式接入不等于已听到该声音。

共 113 个受Git跟踪的独立音频：已读取/ffprobe 110 个，默认3个稀疏历史评审媒体只核Git对象（大小/媒体元数据未知）；另列Freedoom原始ZIP的 13 个声音成员。没有删除任何资源。

## 声部、混音与正式消费者

正式 `DemoApp` 在 `scripts/demo/demo_app.gd:111` 创建 `PlayerWeaponFeelAudioV2`，继承 `PlayerWeaponFeelAudio → PlayerMotionAudio → GameAudio`；`scripts/art/player_presentation_runtime.gd:55` 将新版动作和武器反馈接入真实角色。`scripts/dev/` 路径下这些组件是正式共享消费者，不能按目录判作测试。经典外观保留旧跳跃/落地回调。

`GameAudio` 12个非空间AudioStreamPlayer，默认volume=0.7；基础cue限流为55ms，step/denied/armour为160ms，按全局cue而非origin。基础声满池直接丢弃；Motion可抢占step/旧动作，Weapon可抢占step/动作/contact，V2最多8个weapon voice为其他声保留4槽。没有通用数值优先级。

`scripts/audio/game_audio.gd:78` 和继承组件定义暂停准入：UI click/confirm/denied在暂停中仍播放，世界声pausable；stop_motion/stop_weapon按owner清理，持续声随phase取消。shutdown用实际playback弱引用和1000ms墙钟等待。GameAudio非循环区域声随卸载停止。

没有受跟踪的专用Audio Bus Layout，也未发现SFX/Music/UI独立总线。默认音效走Master；`scripts/audio/game_music.gd:36`显式Master。主菜单静音直接mute Master。多数音效无距离/声像；`shot_latch.gd:54`后备铃为AudioStreamPlayer2D、-10dB、1200wu、1 polyphony；森林事件先做800wu门限但播放仍非空间。

基础衰减：step 18dB，shot/land/jump/click 10dB，其他7dB；forest_wind 16dB、其他regional 11dB。Motion jump12dB，land按strength从16到11dB，heavy9dB。Weapon通常profile shot12dB、sustained24dB，hit10dB、wall17dB、blast9dB等由实际调用给定。

GameMusic另有2个流式voice，900ms交叉淡化；原MP3文件不加工，MUSIC_GAIN=0.16再乘同一session volume，暂停增益0.5；Web等待真实用户gesture。音乐和转换用除以Engine.time_scale后的真实时间。五曲混音/掩蔽听感均待验。

## 资源家族与当前用途

| 家族 | 文件数 | 当前结论 |
| --- | ---: | --- |
| bgm | 5 | 用户提供5原MP3；作者/独立商业许可未知，只记录当前项目授权 |
| enemy_death | 1 | Kenney加工+原合成；旧helper保留preload，当前默认没有配置它（legacy_fixture_only） |
| central_sfx | 25 | 25 Kenney CC0原OGG；集中加载，部分被正式新表现委派为后备 |
| legacy_synthesis | 5 | 旧纯模态WAV；未找到运行引用，仅保留生成器/历史 |
| regional | 3 | 森林3个噪声/模态合成；正式非循环区域事件，原听音状态unverified |
| motion | 9 | Kenney加工3×3；新版正式主角使用 |
| timer | 2 | CC0录音HQ预览原MP3缓存+85ms加工WAV；后者正式地雷使用 |
| weapon_v1 | 18 | 5家族Kenney加工及1纯合成beam，各3变体；父类默认/开发对照，V2正式映射覆盖 |
| weapon_v2 | 42 | Freedoom BSD-3-Clause 14×3；其中mine_beep映射被V3录音覆盖 |
| evidence | 3 | 3历史评审WAV；不是运行时素材库 |

## 来源与授权缺口

Kenney保存原许可、原文件名和SHA；README记录2026-10-11下载。Feel/Weapon V1记录加工配方。Freedoom的COPYING、CREDITS、固定upstream commit及原ZIP齐备，商业使用须随分发保留BSD声明且不得暗示背书；不能称CC0。Timer是Freesound公开HQ MP3预览，并非原WAV，作者Rudmer_Rotteveel，CC0页面/法律原文均保留。旧记录未写下载日期的逐项维持unknown。

五首BGM的SHA/原附件名/授权边界保留在原provenance；作者和超出本游戏/试玩的再分发许可未提供。本轮不生成、不替换、不加工它们。程序合成资源只能称项目脚本生成，无凭据不能补称外部CC0。

## 重复与冗余

已读取的独立音频没有完全相同的SHA256；这不排除近似音色、重复语义或未读取历史文件重复。

V1父类bank、V2旧mine_beep和5个旧纯合成WAV属于可追踪冗余候选；仍有父类加载、测试/历史消费者，不能仅凭本报告删除。确认语义重复与多层冲突见 [Audio Event Catalog](event_catalog.md)。

## 逐文件可查清单

| 文件 | 用途 | 来源/许可记录 |
| --- | --- | --- |
| `assets/audio/bgm/across_the_wooden_sails.mp3` | formal_bgm | `assets/audio/bgm/provenance.json` / project_specific_user_authorization |
| `assets/audio/bgm/beyond_the_knotted_vines.mp3` | formal_bgm | `assets/audio/bgm/provenance.json` / project_specific_user_authorization |
| `assets/audio/bgm/the_kindred_hearth.mp3` | formal_bgm | `assets/audio/bgm/provenance.json` / project_specific_user_authorization |
| `assets/audio/bgm/vines_beneath_the_canopy.mp3` | formal_bgm | `assets/audio/bgm/provenance.json` / project_specific_user_authorization |
| `assets/audio/bgm/where_the_path_bends.mp3` | formal_bgm | `assets/audio/bgm/provenance.json` / project_specific_user_authorization |
| `assets/audio/enemy_feedback_01/death_burst.wav` | dormant_legacy_death_helper_not_default | `assets/audio/enemy_feedback_01/provenance.json` / CC0-1.0 source derivatives + original project synthesis |
| `assets/audio/kenney/armour.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/bell.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/boss_impact.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/click.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/coin.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/confirm.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/core.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/death.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/denied.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/door.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/enemy_defeat.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/enemy_shot.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/focus_end.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/focus_start.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/heal.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/hurt.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/impact.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/jump.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/land.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/note.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/roar.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/shot.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/step.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/victory.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/kenney/warning.ogg` | formal_shared_or_fallback | `assets/audio/kenney/sources.json` / CC0-1.0 |
| `assets/audio/plains_armour.wav` | retained_legacy_synthesis_no_runtime_reference | `tools/generate_plains_combat_audio.py` / project_generated_no_external_samples |
| `assets/audio/plains_core.wav` | retained_legacy_synthesis_no_runtime_reference | `tools/generate_plains_combat_audio.py` / project_generated_no_external_samples |
| `assets/audio/plains_shot.wav` | retained_legacy_synthesis_no_runtime_reference | `tools/generate_plains_combat_audio.py` / project_generated_no_external_samples |
| `assets/audio/windchime_open.wav` | retained_legacy_synthesis_no_runtime_reference | `tools/generate_windchime_audio.py` / project_generated_no_external_samples |
| `assets/audio/windkeeper_roar.wav` | retained_legacy_synthesis_no_runtime_reference | `tools/generate_plains_combat_audio.py` / project_generated_no_external_samples |
| `assets/forest_bible_v2/audio/forest_fruit.wav` | formal_regional_synthesis | `assets/forest_bible_v2/audio/provenance.json` / project_generated_no_third_party_sample_claim |
| `assets/forest_bible_v2/audio/forest_web.wav` | formal_regional_synthesis | `assets/forest_bible_v2/audio/provenance.json` / project_generated_no_third_party_sample_claim |
| `assets/forest_bible_v2/audio/forest_wind.wav` | formal_regional_synthesis | `assets/forest_bible_v2/audio/provenance.json` / project_generated_no_third_party_sample_claim |
| `assets/player_presentation_01/feel_audio_v1/heavy_0.wav` | formal_motion | `docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/feel_audio_v1/heavy_1.wav` | formal_motion | `docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/feel_audio_v1/heavy_2.wav` | formal_motion | `docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/feel_audio_v1/jump_0.wav` | formal_motion | `docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/feel_audio_v1/jump_1.wav` | formal_motion | `docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/feel_audio_v1/jump_2.wav` | formal_motion | `docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/feel_audio_v1/land_0.wav` | formal_motion | `docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/feel_audio_v1/land_1.wav` | formal_motion | `docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/feel_audio_v1/land_2.wav` | formal_motion | `docs/worklines/PLAYER-PRESENTATION-01/feel-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/mine_beep_v3/sources/electronic-timer-536420-hq.mp3` | source_cache_not_runtime | `assets/player_presentation_01/mine_beep_v3/provenance.json` / CC0-1.0 |
| `assets/player_presentation_01/mine_beep_v3/timer_beep.wav` | formal_timer | `assets/player_presentation_01/mine_beep_v3/provenance.json` / CC0-1.0 |
| `assets/player_presentation_01/weapon_audio_v1/beam_0.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / project_generated_no_external_samples |
| `assets/player_presentation_01/weapon_audio_v1/beam_1.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / project_generated_no_external_samples |
| `assets/player_presentation_01/weapon_audio_v1/beam_2.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / project_generated_no_external_samples |
| `assets/player_presentation_01/weapon_audio_v1/blade_0.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/blade_1.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/blade_2.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/blast_0.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/blast_1.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/blast_2.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/contact_0.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/contact_1.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/contact_2.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/machine_0.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/machine_1.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/machine_2.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/pulse_0.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/pulse_1.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v1/pulse_2.wav` | dormant_parent_default_and_dev_bank | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-provenance.json` / CC0-1.0 source derivatives |
| `assets/player_presentation_01/weapon_audio_v2/blackhole_burst_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blackhole_burst_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blackhole_burst_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blackhole_loop_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blackhole_loop_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blackhole_loop_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blackhole_start_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blackhole_start_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blackhole_start_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blade_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blade_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blade_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blast_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blast_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/blast_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/boomerang_return_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/boomerang_return_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/boomerang_return_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/hit_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/hit_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/hit_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/ion_loop_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/ion_loop_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/ion_loop_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/ion_start_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/ion_start_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/ion_start_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/ion_tail_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/ion_tail_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/ion_tail_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/machine_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/machine_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/machine_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/mine_beep_0.wav` | loaded_but_replaced_by_timer_v3 | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/mine_beep_1.wav` | loaded_but_replaced_by_timer_v3 | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/mine_beep_2.wav` | loaded_but_replaced_by_timer_v3 | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/pulse_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/pulse_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/pulse_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/wall_0.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/wall_1.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `assets/player_presentation_01/weapon_audio_v2/wall_2.wav` | formal_weapon | `docs/worklines/PLAYER-PRESENTATION-01/weapon-audio-v2-provenance.json` / BSD-3-Clause |
| `docs/evidence/enemy_feedback_01/audio-comparison-25s.wav` | historical_review_media | `docs/evidence/enemy_feedback_01` / unknown_not_a_runtime_source |
| `docs/evidence/enemy_feedback_01/shot-a-compact-mechanical.wav` | historical_review_media | `docs/evidence/enemy_feedback_01` / unknown_not_a_runtime_source |
| `docs/evidence/enemy_feedback_01/shot-b-weighted-mechanical.wav` | historical_review_media | `docs/evidence/enemy_feedback_01` / unknown_not_a_runtime_source |

## 生成和加工入口（静态扫描）

- `tests/player_presentation_01/build_feel_audio.py`：`tests/player_presentation_01/build_feel_audio.py:11`、`tests/player_presentation_01/build_feel_audio.py:40`、`tests/player_presentation_01/build_feel_audio.py:43`
- `tests/player_presentation_01/build_weapon_audio.py`：`tests/player_presentation_01/build_weapon_audio.py:20`、`tests/player_presentation_01/build_weapon_audio.py:25`
- `tests/player_presentation_01/build_weapon_audio_v2.py`：`tests/player_presentation_01/build_weapon_audio_v2.py:60`、`tests/player_presentation_01/build_weapon_audio_v2.py:105`
- `tools/build_enemy_feedback_01_death_audio.py`：`tools/build_enemy_feedback_01_death_audio.py:31`、`tools/build_enemy_feedback_01_death_audio.py:45`、`tools/build_enemy_feedback_01_death_audio.py:105`
- `tools/enemy_feedback_01_audio_candidates.py`：`tools/enemy_feedback_01_audio_candidates.py:23`、`tools/enemy_feedback_01_audio_candidates.py:24`、`tools/enemy_feedback_01_audio_candidates.py:60`
- `tools/generate_forest_bible_sfx.py`：`tools/generate_forest_bible_sfx.py:4`、`tools/generate_forest_bible_sfx.py:19`、`tools/generate_forest_bible_sfx.py:34`
- `tools/generate_plains_combat_audio.py`：`tools/generate_plains_combat_audio.py:8`、`tools/generate_plains_combat_audio.py:19`、`tools/generate_plains_combat_audio.py:21`
- `tools/generate_windchime_audio.py`：`tools/generate_windchime_audio.py:9`、`tools/generate_windchime_audio.py:20`、`tools/generate_windchime_audio.py:23`

## 未验证边界

- Static reachability is not an observed play session; per-event audible coverage awaits Godot/browser evidence
- Historical evidence archive internals beyond the tracked audio files are not runtime sources and are not expanded
- Source download dates missing from old provenance remain unknown
- BGM author/broader commercial redistribution license is not supplied; retain project authorization boundary
- No subjective quality, real device latency or loudness balance has been accepted
