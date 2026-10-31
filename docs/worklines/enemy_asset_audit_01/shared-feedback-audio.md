# 共享特效与声音：文件、配置、实际调用分开

快照310c0421；本轮为静态追踪，没有新听审或引擎录制。以下区分“有素材”“有配置”“有调用”，不推定画面／听感质量。

## 受伤与死亡反馈

| 层 | 现有资料／素材 | 当前消费边界 |
| --- | --- | --- |
| 专用受伤／死亡姿态 | [frames_v8 manifest](../../../assets/enemy_feedback_01/frames_v8/manifest.json)、[反馈帧说明](../../enemy_feedback_01_frames.md)、[美术方向](../../enemy_feedback_01_art_direction.md) | [EnemyFeedback01.PROFILES](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/enemies/enemy_feedback_01.gd)只登记charger／diver专属配置；两skin各4H／4D，live复用H3 |
| 通用受伤状态与闪色／形变 | [EnemyHitTemplate](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/enemies/enemy_hit_template.gd)、[feedback状态](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/enemies/enemy_feedback_01.gd)、[参数](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/resources/damage/feedback.tres) | 大量普通怪与Boss共用；它们不是每只怪独有的受伤动画素材 |
| 接触扇与碎屑 | [EnemyFeedback01Particles](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/enemies/enemy_feedback_01_particles.gd) | 代码绘制奶白／黄铜射线及碎屑，无逐怪专用PNG特效页；受accepted事件驱动，不能据此断言表现到位 |
| charger／diver身体材质 | [body](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/enemies/enemy_feedback_01_body.gd)、[flash shader](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/enemies/enemy_feedback_01_flash.gdshader) | 专用身体绘制与材质处理；不等于其他物种也有同套H/D资源 |
| 各怪专有预告／机关表现 | 各Presentation和Encounter里的盾面线、落点、蛛线／网带、绳、铃、波纹、胸心等 | 多为程序绘制与共享机关；每只怪的具体入口在三份逐怪JSON，不重复记成独有美术资产包 |

## 声音文件与选择配置

- [GameAudio](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/audio/game_audio.gd)维护共享cue和12声部池；初始化`audio_profile="original"`，原cue按`assets/audio/kenney/<cue>.ogg`加载。EnemyActor现有受伤与死亡调用见[Actor](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/enemies/enemy_actor.gd)。
- [已选配置](../../../config/audio_director/selected/selected.json)确有用户选择的`enemy_hit_b`／`enemy_hurt_b`；对应[命中WAV](../../../assets/audio/director_v3/enemy_hit_b.wav)与[受伤WAV](../../../assets/audio/director_v3/enemy_hurt_b.wav)实际存在。它是全局事件选择，不是每个物种的独立声音包。
- **是否在当前默认游戏中播放，不能从选择单推定。** 本次Git完整树搜索`configure_selected_profiles`／`selected.json`，定位到GameAudio定义和[scripts/dev/audio_director_reels.gd](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/dev/audio_director_reels.gd)开发消费，未在所检生产源找到安装该选择单的调用。未重新启动游戏核动态注入，因此这里不声称当前正式影片实际使用了这两条已选声。
- 库里还有[专用death_burst.wav](../../../assets/audio/enemy_feedback_01/death_burst.wav)、[来源／处理](../../../assets/audio/enemy_feedback_01/provenance.json)、[历史音色接口说明](../../enemy_feedback_01_audio_interface.md)及[helper](https://github.com/zhipijun1996/gunman-rush/blob/310c0421e18829088a4d2208c5f1b6cba3db35dc/scripts/enemies/enemy_feedback_01_death_audio.gd)。**当前生产源只检索到helper自身声明与内部引用，没有找到外部configure调用**；不能沿历史文档称它现在已对冲锋／俯冲生效。测试或历史说明不等于当前接线。
- `forest_wind`／`forest_fruit`／`forest_web`有[区域WAV](../../../assets/forest_bible_v2/audio/)和GameAudio路径；蛛extend的Stage调用与区域音色共用关系见森林原始审计。甲虫盾面视觉订阅不等于有独有盾声。
- Boss的warning／armour／core／boss_impact／roar等大多共享cue。资料中出现windkeeper_roar等命名文件，不代表当前Boss脚本直接加载它；完整原图／声音目录与个体声景设计仍需分开看。

来源目录：[事件目录](../../audio_director/event_catalog_v3.md)、[来源库](../../audio_director/source_library.md)、[候选与runtime说明](../../audio_director/runtime.md)。本页不覆盖既有用户选择、不替换声音，也不对未听声音作好坏评价。
