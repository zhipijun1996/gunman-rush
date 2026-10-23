# ENEMY-FEEDBACK-01：方法参考与声音返工输入

2026-10-22，用户补充可参考网络提升高级感、手感、打击感的方法，并指出「现在射枪的音效，击中怪物的音效都有点奇怪」；进一步选择「太电子／像提示音，缺少实体感」。这是实际返工依据，不是对本版声音的认可。

## 已查原始来源与适用范围

| 来源 | 原作者观点（简述） | 本线采用或暂缓 |
| --- | --- | --- |
| [Christopher Totten：12 principles for game animation](https://www.gamedeveloper.com/game-platforms/12-principles-for-game-animation) | 形变强度会传达材料软硬；动作同时要服务响应与碰撞读图。 | 采用两物种分别配置、较小形变、原轮廓与地面锚不变；不会为演出改变碰撞。金属感不能靠把所有身体都拉成橡皮。 |
| [343 Audio Team：Inside Infinite, March 2021](https://www.halowaypoint.com/en-us/news/inside-infinite-march-2021) | 过多同时发声会遮蔽重要战斗信息；先建立清楚的声音优先级。 | 检查开火/接触/HP提交/回能提示的实际叠加，避免把一个命中混成数个无关提示。素材替换与混音须在真实场景试听，不靠峰值或文件名签好听。 |
| [Kenney：Must see videos for indie developers](https://kenney.nl/knowledge-base/learning/must-see-videos-for-indie-developers) | 推荐Jonasson/Purho、Nijman、Berbece等关于动作反馈和死亡演出的原始演讲。 | 作为继续研究入口；本轮没有完整观看这些演讲，不将二手清单冒称原作者完整结论。 |

推导给本项目的评判方式：命中先清楚、反馈再有层次；短促起势与有界恢复应与真实结果同拍；实体材料各有反应。暂缓顿帧、全局慢放、屏幕震动、额外击退：这些会扩大共享时钟/相机/玩法边界，本线不自行推广。没有一个统一特效量、分贝或帧数可以代签“高级”。

## 当前声音的事实与假设

原素材映射在 assets/audio/kenney/sources.json：shot来自digital-audio的laser2.ogg，impact是impactWood_light_000.ogg，hurt是impactPunch_medium_000.ogg。以上是可核对的源事实，不是听音结论。

正式射击经PlayerFeedback播shot；projectile_impacted接触播impact（包括碰墙，并不代表接受HP）；非致死HP提交另由EnemyActor播hurt。正式ShotEnergyPolicy的命中回能还会经energy_recovered触发confirm。需要测实际接受时刻与voice，不能只看到四个调用就断言每次一定同时发声。

设计候选是去掉现有激光扫频的主体，改为短发射瞬态、克制机械细节和较干的实体命中，减少回能/UI色彩抢占。先制作独立A/B试听及真实事件音轨诊断，继续保留原CC0来源、原音频、原事件和声音池/暂停守门。

## 总控接口／写集请求

本线不替换共享音频或改PlayerFeedback/GameAudio。若试听方向获选，请总控分配以下最小写集，并核对主角线消费者：shot/hurt/impact候选素材及sources.json/许可；GameAudio中武器、材质、回能提示的映射与混音；PlayerFeedback中接触、HP与回能提示的职责。不得把合法接触改成假HP命中，也不取消真实回能、伤害或奖励。先两个代表与默认武器，未获授权不扩为全武器/全怪物音频重制。

声音候选与实际测得事件见本任务audio-audit；用户试听、正式音频替换、听音审查与设备测试分别保持未验。


## v4：参考《空洞骑士》，不照抄画风或未经证实的参数

2026-10-22再次查询一手资料。[Team Cherry：Introducing Hollow Knight](https://www.teamcherry.com.au/blog/introducing-hollow-knight)明确说明简洁、接近单色的造型及传统2D动画；[官方介绍](https://www.hollowknight.com/)同样强调手绘并逐个制作生物动画。[Unity的Team Cherry案例](https://unity.com/made-with-unity/hollow-knight)用于核实制作管线，不据此猜测具体战斗代码。GDC原《Juice It or Lose It》和《Don't Juice It or Lose It》页面本轮实际跳维护页；YouTube原演讲页面可开但无可读字幕，未完整观看，不把搜索摘要当完整演讲证据。网上二手反编译分析给出的FreezeMoment毫秒值没有独立核实，本线不用作实现参数或官方事实。

本项目的设计推导（不是声称Team Cherry公开了以下代码）：

1. **先建立命中确定性。** 只有当前epoch被正式HP接受的弹体触发亮闪、身体反应与局部接触图形；擦过/无敌/过期不演一套假的命中。普通命中与致死保持层级。
2. **接触要快，余势要短。** 原批准的0.12秒奶油闪保持，v4增加不超过0.075秒的三条渐尖接触碎芒，细屑随后向来弹一侧散开。扩大空间，不增大方块；不堆烟雾、屏幕白闪或环形礼花。参数为本任务候选，非空洞骑士实测值。
3. **身体有材料重量。** 保留真实击退和已有运动节奏；金属/甲壳避免橡皮般反复拉伸。死亡是失去支撑、翻倒、一次轻接地、静止保留；活体与静止残骸同时靠姿态和材质状态识别。
4. **特色先来自形体与动作。** 草甲/石腹、铜翼/钟身应形成大的材质面和轮廓。暗色用于描边/关节，受光材料面应可读。实际的新走路、收翼和死亡关键帧仍需要独立图集；程序整图旋转不是逐帧动画的替代品。
5. **下一步才是共享手感试验。** 顿帧、定向相机微冲击应由总控协调现有time-scale/pause/相机接口并按武器强弱配置，先A/B操作比较，再决定是否采用。声音已由用户暂缓，未来归人物/装备武器。不能为追求打击感擅改AI恢复、真实击退、弹速、伤害或奖励。

因此v4只实现本任务边界内的材质、接触图形与死体姿态，未声称复刻《空洞骑士》的内部实现或完成完整美术。


## 用户指定视频：Challacade · Creating impactful combat for my indie game!

用户2026-10-22给出[原分享](https://b23.tv/BoR2aOJ)，实际HTTP200解析到[Bili BV1wtmiBoEss](https://www.bilibili.com/video/BV1wtmiBoEss/)。可检索简介指向[Challacade原短片](https://www.youtube.com/shorts/q9Kzd6f5mR0)，公开索引记50秒。搬运简介列音效、受击闪烁、粒子、击退和屏幕震动。当前直接Bili页/API412、YouTube页与公开字幕403，公开嵌入只有播放器外壳；root和art_direction_v2均未完整观看或读到字幕。因此只把这些列为简介可核实的组成，不推断实际叠加顺序、强度、帧数，不把hitstop说成这支视频明确示范。

应用到本线的层次对照：

| 层 | 当前实际情况 | 下一步边界 |
| --- | --- | --- |
| 命中闪色 | 已保留用户批准的正式accepted flash，非接触即受伤 | 同步必须继续用当前event/epoch/serial，不新增假命中入口。 |
| 粒子 | v4短接触核＋细屑的actual envelope已测，合成仍被既有cyan接触主导 | 总控协调ProjectileFeedback的接触颜色/优先级，不能仅叠更多层遮住敌人。 |
| 击退 | 原正式伤害链已有，录像可见 | 不从VFX重复apply force/stagger，物种重量主要靠新动作帧与恢复节奏表达。 |
| 声音 | 用户明确搁置，未来按人物/装备武器管理 | 保留所有旧事件，不替换shared audio或取消回能提示。 |
| 镜头震动 | 本次rg未发现可复用的shake公共接口，未实现/未改相机 | 向总控提出既有相机的可取消局部offset请求，正式accepted事件与run/stage epoch去重；不新增第二相机/信号总线。候选必须开关A/B操作验证，不能以固定夸张抖动当完成。 |
| 顿帧 | 未从这支视频核实；当前也未实现 | 如后续比较需要，先协调共享时钟与暂停/慢时叠加、重载取消；此为项目建议，不是对视频内容的断言。 |

工程落点仍是“同一被接受命中的多个表现层同步、各层有界收束”，不是让粒子或相机决定伤害。新参考到达时生产源已冻结8f0fd51；本次记录/研究不冒充已按该视频再制作/操作验收了一版。
