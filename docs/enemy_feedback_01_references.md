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
