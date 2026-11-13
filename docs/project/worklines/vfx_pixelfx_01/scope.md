# VFX-PIXELFX-01 当前交接

目标与授权：用户要求先迁移pixelfx Skills，再优化全部特效。覆盖正式固定世界及仍有实际消费者的开发武器／道具表现；历史无消费者素材不作优化完成计数。

分支：`feat/pixelfx-vfx-overhaul`；基线main `4f2bb5e41573e930603789c64b52a0c15a6a3dc4`。进度唯一归[任务表](../../tasks.md)。

## 写集与职责

- `.agents/skills/animation-vfx/`、`tools/vfx/`：适配制作流程，固定pixelfx `5294518ce7c72e48b6100a744596e0acf57f2826`，保留MIT和NOTICE；正式运行不引入JS。
- Visual Bible与模块导航：统一像素特效的造型、可读性、制作与验证入口。
- 运行表现与对应素材：枪口／命中／弹道、冰弹、光束／回刃／雷／奇点、人物起落／钩索／保护、受击／死亡、共鸣／充电、敌人与Boss预告及攻击、拾取／机关／环境和道具效果。沿现有事件、资源及生命周期，不更改伤害、运动、冷却、世界几何或存档规则。
- 检查、临时截图和短片写入build/vfx/；完整覆盖以最终消费者清单及实际检查为准。

## 当前结果

Skill及固定版本制作工具已先提交为 `db51334`；运行表现、素材和专项随本分支交付。制作规则归 [animation-vfx](../../../../.agents/skills/animation-vfx/SKILL.md) 与 [Visual Bible](../../../bible/visual_bible.md)，实现入口归 [模块导航](../../module_map.md)。

12种项目原创源稿覆盖枪口、命中、尘浪、反冲气流、冰晶碎裂、冷雾、拾取、共鸣释放、蓄力、余烬、消散和电流。经历三轮实际渲染修改：校准初稿形状，修正烟气透明度／冰晶轮廓，再将反冲闭环改为开放气流并收敛尘土颜色。保留最终源稿和可重建PNG、JSON、SpriteFrames、锚点及递归源码SHA256。正式运行只加载Godot资源；12张图集解码共6,807,040字节，原PNG与元数据约560KiB。

| 现有消费者 | 本次结果 |
| --- | --- |
| UnderworldProjectileVisual、WeaponFeel/V2、WeaponProjectile | 方向性枪火／材质命中、真实轨迹亮芯与反冲气流；消除正式弹丸与V2重复绘制同一命中的问题 |
| IceCastVisual、WeaponVfxV2、WeaponActionRuntime、WeaponEntity | 蓝色短蓄势、分面冰晶、真实路径冷光、冰碎；光束端点、爆炸、奇点及雷的层次与像素边缘；保留回刃原图 |
| MotionVisual、UnderworldPlayer、PlayerFeedback、WorldRecoilGuardVisual | 贴脚起落尘浪、细碎屑、真实钩索与保护拖尾；无枪阶段也正常画起落尘；拖尾不延长保护 |
| EnemyFeedback01Particles、EnemyHitTemplate、WorldDamageSequence、DamageReturnEcho | 材质碎屑、实际减速期稀疏冷色分面、受伤射线及死亡消散；不改变原身体、倒地及停顿时序 |
| WorldFocusHeal、WorldChargingStation | 向内集气与成功后向外释放分开；保留黄铜站体和原恢复／保存事务 |
| PlainsBossEffects、WindkeeperPressure/PhaseScreen、PlainsWindField、BossArrival、DefeatBurst | 保留已绘制Boss图集，补细风压、落点、到场及击败碎屑；减弱满屏阶段光，保留预告和伤害范围 |
| Thorn/ForestSeedProjectile、ThornQueenWeaveBand/Knot、ForestBossDuel | 分面风籽、实际矩形范围内的疏荆棘、像素织线与反击弧；不改碰撞、技能或房间几何 |
| ItemEffectView、ItemV5Entity | 保留登记道具原图和身份；修整实际投递光束、护盾、治疗、弧线及已有回退表现；命中反馈仍要求实际收据 |
| PlainsStageVisual、ShotLatch、WorldShotLatch、Flag/Checkpoint/RechargePoint/ChallengeGoal | 拾取与机关成功提示、细光点及状态轮廓；不变更奖励与状态提交 |
| PlainsRoomArt、ForestBibleAmbience | 本地细风点／叶片；世界格缓存最多64格，消除遮挡剔除改变下一颗风点以及每帧创建随机数器的问题 |

正式入口与旧Demo入口把现有“减弱特效”设置传到表现层；降低装饰亮度并省去尘浪／反冲／余烬图集，必要危险形状仍保留。原有宿主继续拥有时钟、暂停、取消、上限及清理。

## 实际验证

使用锁定工具链 `4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf`。本轮日志及录制位于被忽略的 `build/vfx/`，不把媒体提交到源码。

| 实际检查 | 结果与范围 |
| --- | --- |
| `python3 tools/ci.py` | project／import／smoke／contracts四项通过，见 `ci-complete.log` |
| `python3 tools/check_docs.py`、`git diff --check` | 文档与差异格式通过 |
| `python3 tools/harness.py --check vfx-source --check vfx-export --check vfx-runtime` | 三项通过；12种源稿0失败0警告、2项真实导出测试、42项运行契约。导出检查重建一致、分层、来源与拒绝演示身体；运行检查纹理预算、动态设置、缓存及不消耗全局随机流 |
| 武器与地面射击专项 | 全15种武器2450项、手感1230项、正式弹丸43项、地面射击1343项均0失败；修正旧测试仍用瞄准代替现行R1攻击的夹具，未改输入规则 |
| 表现／状态专项 | 敌人受击393项、玩家伤害26项、共鸣29项、道具核心79项、道具美术1194项均0失败；冰弹、充电站专项0失败；V2真实生命周期281采样／868检查0错误。道具美术检查包含故意损坏输入的拒绝用例，不将负例日志误称运行错误 |
| 相同输入的基线对比 | 本分支与基线各4781采样／14455检查、0错误；15武器／6技能的23项玩法字段逐采样完全一致，含位置、速度、HP、资源、阶段、弹丸、实体及目标。见 `gameplay-equivalence.json`。这是显式Home训练夹具，不是主线获取流程 |
| Godot原生合屏 | 正式P10真实射击／冰弹减速、P01受伤／共鸣成功、P14入战／早期招式均录制且夹具0失败；真实音画的 `review/shot.mp4`、`heal.mp4`、`boss.mp4` 均小于3MB。另检查combat／world／items三页消费者在暗底和亮天空的逐帧及正常速度结果；这三页是绘制快照，不代替真实战斗 |

真实场景录制可恢复：在有显示服务的环境执行下列命令，将 `shot` 改为 `heal`／`boss` 得到另两段。媒体夹具使用隔离试玩存档，显式给定起点与资源；共鸣段跳过小站教学对白，Boss段未覆盖完整击杀。

```sh
bash tools/godot.sh --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --write-movie build/vfx/shot.avi --path . --script tests/vfx/world_capture.gd -- --case=shot --output=res://build/vfx/world-media/shot
ffmpeg -i build/vfx/shot.avi -c:v libx264 -crf 23 -pix_fmt yuv420p -c:a aac -b:a 96k -movflags +faststart build/vfx/review/shot.mp4
```

## 已知限制与下一动作

`python3 tools/run_world_loop.py` 在本分支及同一基线都停在相同的房间检查：648项中P-R20、M-R02各一处“downward exit is an unobstructed hole”失败。已分别复跑确认，见 `test-world.log`、`baseline-world.log`；本次未改世界几何，不声明整世界回归通过。其前置状态、服务、金币、重启、通行及空间检查通过。

本轮为Codex的实际技术和视觉审查；软件渲染录像不代表实体手机性能、用户审美认可、新档完整探索或完整Boss战通过。下一动作是按PR审阅源码与这三段原生短片；合并、更新公开试玩和发布按后续授权执行。
