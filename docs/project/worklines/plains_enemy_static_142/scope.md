# 平原怪物与 Boss 动作交付

## 目标与输入

七类小怪已获用户确认。本轮接续 PR144，处理巡游机铃体附近异常白色、冲锋缺少轮子滚动、牧风者切招突然变大变小。整身图像插值方法被用户实际观察否定，不能继续沿用上一轮“连续性通过”的结论。

沿用 PR142 地形背景和批准 B/C 的象牙白、青绿、铜色身份。分支 `art/plains-enemy-static-pr142`，本轮基线 `2df378be53b6c827ea46b628d901c85ffeec2609`，PR144 面向 main。运行源码与素材为 `7e6e4db39f33d1198312c01a698e4cd157be9d4c`，后续提交只更新本交接和任务状态。十张 `a5668a4` 批准静态保留原字节；普通怪运行图集、AI、俯冲方向、死亡落地及原视频不变。

## 当前制作方法

两位 Boss 改为固定分层素材、真实 Skeleton2D／Bone2D 层级和战斗时钟驱动的关节姿势。主动作由既有 Encounter／Rig 的进入、持续、退出和受伤／死亡时钟采样；可编辑骨骼场景保留休止姿势，AnimationPlayer 内的布料曲线只增加附件摆动。表现不启动另一套招式或累计计时器。旋转部件连续转动，原生像素 nearest 采样。

巡游机车体、悬架、钟架、铃体、后置炮管、披布和两轮分别绑定铰点。钟架内使用固定深色遮挡底，铃体独立摆动，不再从天空透明孔洞与黑底的不同整身图之间插值。车轮角度直接取有符号行程／21wu 半径，停车停止，反向行驶反转；不再重播整身冲锋循环。炮管口和实际弹体出射点对齐；原独立铜铃弹、地波与命中特效保留。

牧风者两个阶段、待机／行走／预备／攻击／收势／受伤／死亡共享躯干、头部和四肢部件。四足目标沿真实行程与支撑面驱动关节，核心与攻击肢体使用同一姿势计算碰撞。二阶段只展开头顶支架和独立旋转风车；风车发射点取同一轴心。主动接近、连招节奏、身前上中下宽风场、两次风籽齐射继续沿原实际规则。金币从倒地承重躯干中心弹出，避免新胸口位置越过窄平台边缘而将掉落带入空洞；没有改金币数量、拾取、幂等或安全返回机制。

转身补充正面车壳／轮胎、巨兽躯干／头部视图；骨架转向位置投影和正面深度共同保持体积。只有转身视角的部件宽度变化，切招与阶段转换不缩放身体。弱点、炮口与转身绘制共用纯姿势计算；巡游机完成换向前捕获已显示姿势，防止逻辑方向改变后重复镜像。

旧 Boss 整身动作图集、源补帧、光流数据、形变 shader、旧采样器、旧炮管矩形裁片与无消费者锚点生成代码已删除。历史留 Git；批准静态与普通怪完整保留。

## 素材与复现

`assets/plains_boss_rigs_142/` 含 25 张原生部件、清单，以及 `source/` 中三张 image_gen 原图、完整提示词和参考。源图由 `.gdignore` 隔离。脚本只做透明分割、外部连通背景边缘清理、裁切与一次 nearest 尺寸校准，不绘制角色像素；封闭的金色高光不按背景颜色误删。清单记录源与输出 SHA256。

- 部件重建：`python tools/art/build_plains_boss_rigs.py`。
- 骨骼场景：`game/presentation/actors/art/bellstrider_rig.tscn`、`windkeeper_rig.tscn`。
- 共同姿势／视角／发射轴心：`game/bosses/encounter/plains_boss_view_pose.gd`；动作主采样仍在两 Boss 的 Rig／Encounter。
- 小怪素材检视与完整 ZIP：`python tools/art/package_plains_actor_animations.py`。网页的小怪动作不变，Boss 入口指向实战；不再把废弃图集作为当前动画。
- 实战录制：`DISPLAY=:96 bash tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 --write-movie build/plains_actors_142/combat-skeleton-delivery.avi --script tools/art/capture_plains_actor_combat.gd`。
- 手机编码：`python tools/art/package_plains_actor_mobile.py --skip-enemies --boss-master combat-skeleton-delivery.avi --reuse-manifest build/plains_actors_142/unchanged-enemies.json`。

## 检查与交付

技术检查覆盖固定部件、恒定躯干尺寸、按位移转轮、正面转身体积、真实弱点／炮口／风车轴心、前方宽风场、实际战斗与暂停／快照／死亡／奖励。正常速度实战另核动作接合、透明边缘、脚底与关节遮挡。本轮 CI 四项、文档与空间美术引用检查通过；骨骼／连续性／风场506项、小怪帧绑定165项、Boss行为25项、巡游机战斗281／武器88项、牧风者时钟1198／几何97／支撑76／正式App63／奖励139／音频130项通过。武器回归在并行录制负载下曾有一次音频／世界回收超时；结束录制后串行复跑88项通过，没有放宽断言。

25张部件的源／输出哈希与二值alpha通过；十张批准静态逐字节对齐a5668a4，七类小怪的所有源图与运行图集逐字节对齐本轮基线。最终四段实战均在浏览器1×完整播放；小怪检视页56个动作选择和11个视频入口无脚本错误。正常速度片段与关键帧检查可见轮辐随行程旋转、稳定深色钟腔、固定躯干与关节踏地、头顶风车和前方宽风场；这些是本轮观察，不代签用户的审美认可。浏览器软件解码有少量丢帧，60fps编码不能作为目标手机60fps性能证明。

四段新视频为约20.82／18.00／20.93／15.95秒，H.264 Constrained Baseline、AAC、540p60、faststart，约2.23／1.93／2.24／1.72MB。七段普通怪沿用原片和原源提交；11段公网HTTP与SHA256均核对。预览分支 `preview/plains-boss-skeleton-20261109`，不可变产物提交 `51a2a811d4b6e52a4049268932a6e31f651e10e2`，清单记录运行源码身份。

录像沿 P-R11／P-R14 正式 AI、Router 输入、投射物、伤害与地形。仅开场站位、二阶段生命阈值和标注的固定倍率审查镜头为夹具；四段使用相同的固定倍率与画布缩放，只平移取景，不随招式／阶段缩放，避免镜头造成体量变化错觉。不代表自然通关或全部随机招组覆盖。软件渲染录制耗时不等于目标手机帧率，没有真机性能结论。交付到 PR144 与只存视频／清单的预览分支；不合并、不部署游戏。


- [巡游机：滚轮、冲锋与转身](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/51a2a811d4b6e52a4049268932a6e31f651e10e2/bell.mp4)
- [巡游机：抛铃与地波](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/51a2a811d4b6e52a4049268932a6e31f651e10e2/bell_wave.mp4)
- [牧风者一阶段：移动与攻击](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/51a2a811d4b6e52a4049268932a6e31f651e10e2/keeper.mp4)
- [牧风者二阶段：风车与广域吹风](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/51a2a811d4b6e52a4049268932a6e31f651e10e2/windmill.mp4)
