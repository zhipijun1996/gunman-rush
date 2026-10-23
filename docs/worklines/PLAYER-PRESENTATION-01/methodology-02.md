# 动作第二样板：静止、下落围巾、步态和脚底反馈

用户本轮指出静态帧不足、下落围巾可以上扬、走路违和、跳跃落地缺少特效。本候选将这些作为可操作的局部比较，不据帧数或工程绿灯签审美完成。

## 查阅的方法与取舍

- [SLYNYRD：Intro to Animation](https://www.slynyrd.com/blog/2018/8/19/pixelblog-8-intro-to-animation)：关键姿态和时值比补间数量更重要。用于把idle扩到六帧的慢节奏小幅循环；不让呼吸改变身体整体缩放或碰撞。
- [SLYNYRD：Side View Run’N Gun](https://www.slynyrd.com/blog/2026/1/26/side-view-run-n-gun)：用接触、下压、经过、上升建立步态，身体与武器分层，起跳响应保持即时。新跑步图连续两版的相反腿支撑读不清，停止采用；保留旧八帧，先用位移积分试验帧相位，步态像素返工仍未完成。
- [SLYNYRD：Wind Effects](https://www.slynyrd.com/blog/2021/7/16/pixelblog-33-wind-effects)：风的形变从根传到末端，节奏连贯。下落试六帧围巾向上／向后延迟摆动，替换旧两帧非循环末帧停住；不添加改变下落速度的风力。
- [Thomas Vasseur：Dead Cells 动画制作](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-)：先关键姿态和可信时值，再做插帧和反馈。这里只借制作顺序，不替换现有像素项目的生产管线。
- [Steve Swink：Game Feel](https://www.gamedeveloper.com/design/game-feel-the-secret-ingredient)：反馈与玩家驱动的运动协调。起跳、落地尘效消费已接受事件，不等动画完成才执行动作，不加输入延迟。
- [Nathan Lovato：Squeezing More Juice](https://www.gamedeveloper.com/design/squeezing-more-juice-out-of-your-game-design-)：用与行为有关的局部反馈、控制密度。脚底小簇尘效按真实落速调整，世界锚点留在起落位置，避免跟角色飘走；本轮不加全屏辉光、相机震动、hitstop或通用音效。

以上为实际读取页面后的简短转述与本项目实验映射，非原作者对本项目背书。Toon Boom教程请求403，未当成已读证据。

## 实际接入与可证伪目标

新 `scenes/dev/player_presentation_01/motion_candidate.tscn` 继承真实DemoApp。在正常正式平原完成组装后，只将 `PixelPlainsActor` 视觉叶节点换为UnderworldPlayer的任务子类，继续用真实PlayerMotor、Controller、Courier枪口、地图、敌人和镜头。未改正式场景／DemoApp／共享四件body绑定。HOME / FULL GAME回旧完整入口，RESTART SAMPLE回独立固定Seed样板。

同一Seed、输入和镜头录两片；OFF完整调用原绘制，ON加六帧idle／fall循环、旧run位移相位与accepted跳落地尘效。可配置项在 `resources/player_presentation_01/motion_v1.tres`：idle/fall速率、步幅距离、尘效时长／数量／硬上限／颜色；非法范围回退旧表现。

失败条件：任何Motor位置／速度／碰撞／HP／精力／枪口／Manifest差异；拒绝请求产新尘效；暂停中活跃尘效推进；开关重播旧事件；快速重启或等待中回HOME产生旧协程；新帧身体尺寸／脚底／手枪衔接跳动；下落循环出现明显复位；脚底特效遮住落点。最后三项必须看实际游戏像素与正常速度连续画面，不能用JSON判定。

## 限定与后继

六帧新图的许可与用户艺术认可均未知，只是开发候选。原始生成PNG完整保留、没有改像素；只采上两行，下面两行失败跑步图不消费。第二版失败跑步原图在motion-v1证据内保留，两次后停止该方向扩产。

未解决原始M1的枪口权威恢复协调、受伤→恢复→死亡整链、全十五装备／九mode／六技能、三外观完整动作及正式Home角色切换衔接。共享替换仍须总控合并既有M1、版本化影响分析／独审／显式重绑，再做受影响完整Integration。本候选无权更新旧style SHA，也不声称整线完成。用户审美／手感、连续听音和真机性能保持未验。

## 实际第一轮与局部返工

source `9c693787b201a655d9e8589d3bb1e1350ae64e29` 两片各18.2秒／1092媒体帧，1080观察样本，16个玩法／枪口／镜头字段零差异、accepted事件一致；六帧idle和fall都实际绘制。独审查看全部60张原尺寸视频抽帧，确认fall围巾向上，但握持衔接仍REWORK，原尘效太弱。未全速播放／听音，不签连续观感。

第二轮只修尘效：配置化lift/spread/size，暖浅土色、更明确上扬扩散；不改PNG、body元数据、枪口或玩法。保留原1080完整驱动和断言，新增严格600样本的10秒局部取证选项，仍覆盖两个accepted jump与land，不能替代原长fall／返回覆盖。失败反例与第一轮影片保留各自源码SHA，新的GPU对照另录，不能给旧证据改签。

原Web包e6e862c1fd90完整导出/PCK已核，实际本地Chromium键盘跳跃移动、鼠标开关／重启／HOME返回完整游戏可用。新独立站部署被现有900MiB容量守门拒绝，保留全部旧入口；临时Cloudflare入口的API直连被网络拒绝，未部署。没有将旧站或本地localhost说成公网新Preview。总控须安排独立站容量或其他长期托管；本线保留已验证本地包和可恢复命令。
