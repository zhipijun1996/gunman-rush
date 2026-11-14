# VFX-PIXELFX-01 当前交接

目标与授权：先迁移pixelfx Skill，再优化现有特效。用户已明确否定攻击、共鸣回血、Boss入场、宝箱喷金币、怪物掉金币的既有特效和声音，要求按库的实际参考重新设计，不以旧稿限制质量。五组主体及声音已重制；用户进一步指定牧风者入场必须是全屏咆哮，当前取消小跳／落地式主体，按伏身吸气、仰头长吼、全屏风压和余势消退重做。

分支 `feat/pixelfx-vfx-overhaul`；main基线 `4f2bb5e41573e930603789c64b52a0c15a6a3dc4`；当前Boss咆哮修订起点 `2d2a9980edee5c935af7c674ab165892c3fff73c`；[PR160](https://github.com/zhipijun1996/gunman-rush/pull/160)。进度唯一归[任务表](../../tasks.md)。迁移依赖为本分支 `db51334`，固定pixelfx `5294518ce7c72e48b6100a744596e0acf57f2826`，MIT及NOTICE随源保留。

## 结果与实际消费者

制作标准归[Visual Bible](../../../bible/visual_bible.md#像素特效)及[声音设计](../../../data/audio.md)，Skill明确用户否定后必须替换主体而非叠装饰；入口归[模块导航](../../module_map.md)。

| 组别 | 实渲染参考 | 当前运行结果与入口 |
| --- | --- | --- |
| 攻击 | projectiles/muzzle-pistol、impacts/hit-spark | 替换原枪口／命中／冰弹主体源稿，以上游flash/cloud和hit-spark配方改编不对称炽白焰、橙黄火层、弯卷烟及方向裂痕，冰矛分面及掠过高光，拖尾仍由实际历史路径绘制；UnderworldProjectileVisual按真实接受事件采样。声音替换正式PlayerWeaponFeelAudioV2的pulse／machine／hit资源，并同步旧V1回退和显式SelectedSfx消费者；不把后者误当成固定世界声音入口 |
| 共鸣 | arcane/spell-charge、holy/heal | 删除旧高气流、粗射线及八向释放主体；WorldFocusHeal采用交错收束弧、胸前亮核、脚底光瓣与上掠扁光带；保留真实人物姿态。新的空气／玻璃集气与恢复落点／双音经GameAudio.FOCUS_CUES进入原声部池；旧共鸣WAV及重复生成段已移除 |
| Boss入场 | arcane/mana-burst、nature/leaf-storm的聚散／外扩波／风线技法 | 正式WindkeeperPressurePresentation安装BossArrivalPresentation；非滚轮巨兽入场根节点不再跳动，PressureRig的胸颈、头部、披风沿intro钟蓄势和咆哮，四足固定。BossRoarScreen在HUD下方绘制世界画面震颤、折射、三道扩至全屏的风压及放射风线；HUD保持稳定。BossRoarTimeline提供共享释放拍点，GameAudio触发一次吸气和1.65秒持续咆哮，不再发牧风者入场落地声。暂停冻结，暂停中取消、跳过和换房都清理音画与现有镜头接管；减弱设置收敛强度。原intro时长、伤害和移动主人保留 |
| 宝箱金币 | pickups/chest-open | WorldRoomInteraction接受提交后以箱口扇光、亮尘和箱体短回弹替换旧通用collection_burst；锁扣／开盖／散币声音分层，不再叠item_get。PlainsLootMotion以不同速度与高度喷出真实面额金币；仍沿真实碰撞落地、回收和账本 |
| 怪物金币 | spawn/coin-drop、pickups/coin-spin | WorldCoinDrops仅在新接受的死亡奖励源出现时画短尘团、金屑并发轻散币声，首次读档同步不重播。PlainsStageVisual使用厚边／浮雕／窄边旋转图集及真实位置短尾、首次真实弹地闪光与轻金属音；成功入账才发新短叮。共享stage材质、面额、单位数量、拾取延迟、奖励及保存主人保留 |

新增六张图集并重制枪口／命中；全18张解码15,786,496字节，受16MiB契约约束。新形状以30fps保存，枪口／命中60fps；正式宿主拥有进度、取消、暂停与寿命。另有仅在咆哮时显示的屏幕采样Shader，不新增运行图集或逐帧粒子节点。所有声音仍复用十二声部池，不引入另一套播放服务或运行JS。来源及重建见[图集说明](../../../../assets/vfx/SOURCES.md)、[15个原创声音](../../../../assets/audio/vfx_renewal/README.md)。

制作证据位于被忽略的 `build/vfx/rework/`：九项上游参考实渲染，三轮源稿修改，枪口／集气另有三种方向、声音另有三组可听音色。修正内容包括色值转换、原生画布与帧率预算、脚底光瓣体量、合并尘云、无网点洞的箱口光扇及金币分轨。保留最终源稿，不提交临时媒体。

## 实际验证

锁定引擎 `4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf`；以下结论只对应本轮实际结果。

| 检查 | 本轮证据 |
| --- | --- |
| 日常CI及文档 | `ci-final.log`：project／import／smoke／contracts四项通过；`docs.log`及git差异格式通过 |
| 特效源／导出／运行 | `delivery-harness.log`：18种源稿、真实导出重建／分层／来源检查通过；68项运行检查0失败，含有色主轮廓、预算、设置、缓存和随机流 |
| 真实音频接线 | `audio-harness.log`及`audio-contracts-final.log`：正式V2开枪实际加载新WAV、新cue覆盖旧缓存、暂停拒绝新事件、暂停时来源卸载清尾、十二声部均通过。单测不以文件存在代替真实播放路径 |
| 动作与资源 | `weapon-loot-final.log`中all-weapons、weapon-feel分别通过；`focus-final.log`29项、`economy-final.log`8项、`ice-final.log`、`owners-final.log`84项均0失败。共鸣取消、写失败、死亡优先和金币幂等／读档沿原契约 |
| Boss | `final-harness.log`的windkeeper-pressure-01通过：实际几何、组件时钟、正式App、支撑、奖励及音频；全屏咆哮修订后重新通过；原生媒体另检查一次吸气／咆哮、零入场落地声及镜头归还 |
| 五段正式原生音画 | `native-shot/heal/boss/chest/drop.log`均0失败，实际控制器／事务触发，非离线绘制拼贴；源录制保留实际游戏音轨。压缩短片在 `review/`，每段小于3MB |

媒体使用隔离逐房试玩，不写正式存档。射击段显式给靶怪生存HP和技能资源，共鸣段显式受伤／资源并跳教学对白；宝箱以真实交互打开20金币箱并拾取，怪物段声明致死伤害后等待真实掉落／拾取。Boss取真实入口往内240wu的较近起点，便于在固定缩放下同时审看完整身体与尘浪；不冒充从门外连续进入或完整击杀。

```sh
# 需要显示服务；case可选shot、heal、boss、chest、drop。
bash tools/godot.sh --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --write-movie build/vfx/rework/boss.avi --path . --script tests/vfx/world_capture.gd -- --case=boss --output=res://build/vfx/rework/native-boss
python3 tools/harness.py --check vfx-source --check vfx-export --check vfx-runtime --check vfx-audio
```

## 全屏咆哮的当前验证与媒体

当前证据位于 `build/vfx/roar/`，替换旧Boss跳跃／落地片段作为本次评审入口。`ci.log`四项CI、`harness-final.log`的windkeeper-pressure-01与vfx-audio、`contracts-final.log`的专用咆哮检查通过。新 `vfx-boss-roar`检查正式接线、扎地／不跳、完整逻辑视口与HUD层次、减弱设置、暂停冻结及暂停中取消、提前跳过和换房清理。普通／减弱原生录像均0失败，源为 `final.avi`、`reduced.avi`，压缩入口为 `boss-roar.mp4`、`boss-roar-reduced.mp4`，每段小于3MB。三轮原生渲染修正了全屏外扩波、边缘压暗、持续风压的声脉冲与收尾；音效制作源同步提供三组可听音色，正式采用现行方向，不代签用户听感认可。

全屏生产者为BossArrivalPresentation，直接消费者为BossRoarScreen／BossRoarTimeline、PressureRig的纯姿态采样及GameAudio既有有界声部。数值沿现有intro钟归一化，不增加计时器或新相机控制器；取消只归还自己的镜头令牌，世界震颤在Shader中执行，不修改Camera2D.offset。素材与普通攻击／金币／共鸣改动保持前述来源，旧媒体和其测试仍保留在build供复现，不将其代作本轮咆哮验收。

## 失败边界与恢复

`plains-motion-loot-02`：当前598项中仅“underworld diver observes actual frame source and motion”失败，同main基线实跑相同失败，见 `baseline-loot.log`；本次金币共享材质／释放等断言通过，不声明该整组通过。`camera_arena.gd`在P14两种尺寸的墙位、缩放、摇晃边界断言通过，随后旧P11夹具返回空房并中止，基线实跑相同，见 `baseline-camera.log`；不声明整组通过。此前整世界回归的P-R20、M-R02下口两项失败及其基线证据仍保留，本轮未改世界几何，不以旧结果代替本轮验收。

本轮为实际技术检查及Codex视觉审看，未代签用户听感／审美、实体手机性能、新档完整探索或完整Boss战。下一动作是从PR审阅当前五段原声媒体；源码合并、公开试玩更新及发布按后续授权。源码提交与媒体清单绑定，恢复时先核HEAD和日志，再按上述命令重录。
