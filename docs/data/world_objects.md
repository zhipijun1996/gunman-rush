# 可交互元素库（简称机关）

对象通过外形、预告、运动和反馈让玩家理解功能。共同伤害规则见 [伤害合同](../bible/damage_and_respawn.md)，组合场所见 [平原](../bible/regions/windchime_plains.md) 与 [森林](../bible/regions/thorn_forest.md)。本页定义对象行为，数值从所在地图或对象配置读取。

本页是可交互元素库的唯一说明入口，仅收录具有触发、响应、运动、伤害或资源交互行为的场景机关。纯美术贴图、静态地形、怪物、NPC／剧情及奖励数据分别归各自分类和文档；共用实例化接口不改变其业务归属。每种机关的独立定义位于 `config/world_elements/definitions/`，行为合同位于 `behaviors/`，唯一注册索引为 [index.json](../../config/world_elements/index.json)。实例化、信号和状态共用规则归[关卡要素圣经](../bible/world_elements.md)；本页维护对象行为、适用场景和配置入口，数值以定义文件为准。

## 房间制作方式

1. 配置房间空间、出口与镜头，使用 `room.standard` 根定义。
2. 从统一关卡目录的对应分类放置实例，设置稳定 ID、定义版本、位置和参数。地形和机关分别归类，按同一实例化协议读取，实体地形由组装服务批量生成，保持连续的47邻接表面。
3. 风铃／开关的 `links` 指定输出、目标实例 ID、目标输入；接收者独立管理门、移动平台或齿轮状态。房内连接不得指向未装载房间；跨房开锁由世界 action 提交事实，目标读取该事实。
4. NPC、奖励、遭遇和剧情使用登记宿主。这些宿主属于各自内容分类；参数中的 action／NPC ID 仍属于世界相应数据主人；新增奖励或NPC时一并登记权益，不能复制旧的永久领取身份。
5. 普通房间不添加专属脚本。星桥灰盒用 `presentation.trial`；房间服务与Boss内场等内部组件不出现在放置列表。

静态岩土／砌体与空中实体平台共用47地形；木梁、单向平台和移动平台采用对应构件外观。四向尖刺的区域皮肤与支撑材质分开配置，实例可覆盖；危险轮廓和方向仍由玩法定义负责。建筑外观本身没有碰撞，需要实体平台组合；无碰撞布景不会创建站立面。

机关主体、区域皮肤与状态反馈的共同画法归[Visual Bible](../bible/visual_bible.md#基础要素与机关的共同画法)。制作或换皮时与本房地形、各类平台、建筑和危险表面一起合屏，并触发已有状态检查；美术统一保持现有分类、信号与状态所有者，不能把仅显示机关图样视为行为已接入。

## 扩展一种机关

同一行为换皮或调参时增加独立定义文件并登记到索引；需要新的触发／响应方式时增加独立行为实现及合同。声明参数、输入输出、状态版本和持久范围，再给出默认定义、编辑分类和外观。为真实触发、拒绝、暂停、重入和保存失败补充针对性检查。已有机关通过本页及定义文件管理；编辑器只配置实例，不另存一套行为定义。

可攻击隐藏入口、伸缩刺、风场、弹跳蘑菇和空中浮石尚未作为新玩法实现。后续分别用受击、定时、场域、接触和运动行为加入本目录。它们共享实例和状态接口，各自拥有碰撞、力或伤害，不以隐藏贴图代替玩法状态。

## 铃锁与通路

射击铃锁由真实射击命中触发，铃声、摆动和相连门的变化同时反馈。普通门打开后保持通路；限时门显示剩余窗口，到时恢复；正在穿门时延迟关闭，不能夹住或弹出玩家。此类短时开合属于当前房间的动作瞬态，暂停冻结计时，重入/死亡重建时关闭，不写成永久开门权益。真实弹丸的资格与伤害/死亡时序仍沿ShotLatch；铃声、门运动与进度灯消费接受后的命中。双铃顺序门先完成当前铃再处理下一铃，顺序与关联通道可辨认。

移动平台控制铃切换运行与停靠，击中后的声音不能只表示开门。固定世界中的控制铃通过既有ShotLatch接收真实弹丸；App在伤害/死亡裁决后提交同一世界账本中的机关状态，成功后才切换碰撞或承载。停靠相位和运行状态跨房、保存及死亡保留，休息不偷偷恢复原位；入口和上层都可看到对应控制铃，任何停台位置都能再次启动。背面捷径铃要求玩家先抵达指定上岸控制位置，再发出真实射击；从入口远射不提前开捷径。门、铃与平台用一致符号和空间关系表明关联，失败命中不假报成功。

## 索点与果实

普通钩索锚命中后按 H 规则拉近、踢离；明确标记为停靠点的锚允许暂挂，随后可跳跃、射击或再次使用 H 离开。两类目标用形状提示区分，不仅换颜色。

森林果实长在可见枝梢、根或洞壁上，果梗交代宿主；它是索点，不因果实外观自动提供治疗或额外资格。移动活锚的行为归 [森林敌人](enemies/forest.md)。未授予 H 时，目标存在不等于授予能力；实际命中与恢复规则归 [能力](abilities.md)。

## 平台与危险

单向平台的可站面与实体厚墙可辨，装饰枝叶不伪装可站面。移动平台按可观察轨迹运行，起动、停顿和转向连续；相邻动作有可执行时机与接收位置。沿折线导轨行驶的检修笼在每个转角减速到停，再沿下一段起动，原路返回；不能瞬移换轨或靠重置角色位置承载。导轨、各停靠层和控制铃共同提示去向，轨迹全程须容纳站立角色，载具相位继续使用同一机关状态。

尖刺、锯轮与地表危险的方向、运动范围和有效伤害区域一致。循环危险在进入威胁前可观察，机关与敌人不能遮死唯一出口，安全点不能落在其完整运动范围内。

## 检查点与补给

安全检查点在玩家真实落地、恢复位置有完整支撑且无危险侵入时激活。悬空掠过不设置恢复点；选中反馈明确，后续回退遵守 [伤害合同](../bible/damage_and_respawn.md)。

空中补射击点在玩家缺少射击次数时提供补充，成功补给后熄灭；满资源或站地重叠不抢先耗掉它。它补的是射击次数，与地面恢复时间能量、回血、H 资格分别显示。

## 宝箱、商店与出口

| 宝箱档次 | 外观与反馈 |
| --- | --- |
| medium | 蓝色平盖箱，关闭与开启姿态 |
| high | 紫色拱盖箱，关闭与开启姿态 |
| region_top | 金色紧凑钟箱，关闭与开启姿态 |

宝箱仅在奖励成功提交后开盖；取消、拒绝或保存失败保持关闭，返回已领地点仍保持开启，不再发奖。静态开／关姿态与完整开盖动画分别判断，外观映射与尺寸取 [chest_art.json](../../config/chest_art.json)。森林困难可选资源箱借用金箱外观，奖励仍按该箱真实内容说明。

商店显示价格、当前收益与失败原因，刷新和购买沿 [奖励构筑](../bible/rewards_and_builds.md)。出口显示实际去向与准入条件，主路不能依赖未来能力。对象代码与对应检查见 [模块导航](../project/module_map.md)。

## 已登记机关与参数入口

这里只列 `library=mechanisms` 的定义及组合。机关上的贴图和换皮是机关外观；独立无碰撞布景归[美术表现](world_presentation.md)，怪物行为归[怪物文档](README.md)，静态平台和建筑碰撞归[地形与材质](../bible/terrain_materials.md)。

| 定义 | 用途／名称 | 参数源 |
| --- | --- | --- |
| `assembly.bell_carrier` | 风铃与升降台 | [定义](../../config/world_elements/definitions/assembly.bell_carrier.json) |
| `assembly.bell_gate` | 风铃与机关门 | [定义](../../config/world_elements/definitions/assembly.bell_gate.json) |
| `gate.masonry` | 砌体机关门 | [定义](../../config/world_elements/definitions/gate.masonry.json) |
| `hazard.area` | 危险区域 | [定义](../../config/world_elements/definitions/hazard.area.json) |
| `hazard.gear` | 移动齿轮 | [定义](../../config/world_elements/definitions/hazard.gear.json) |
| `hazard.spikes` | 附着尖刺 | [定义](../../config/world_elements/definitions/hazard.spikes.json) |
| `interaction.action` | 世界行动宿主 | [定义](../../config/world_elements/definitions/interaction.action.json) |
| `interaction.return_gate` | 捷径门 | [定义](../../config/world_elements/definitions/interaction.return_gate.json) |
| `interaction.sign` | 告示 | [定义](../../config/world_elements/definitions/interaction.sign.json) |
| `platform.moving` | 移动载台 | [定义](../../config/world_elements/definitions/platform.moving.json) |
| `recovery.anchor` | 安全恢复点 | [定义](../../config/world_elements/definitions/recovery.anchor.json) |
| `recovery.station` | 充电保存站 | [定义](../../config/world_elements/definitions/recovery.station.json) |
| `switch.shot` | 射击风铃 | [定义](../../config/world_elements/definitions/switch.shot.json) |
| `traversal.hook` | 钩索锚点 | [定义](../../config/world_elements/definitions/traversal.hook.json) |
| `traversal.hook_point` | 固定钩索点 | [定义](../../config/world_elements/definitions/traversal.hook_point.json) |
| `zone.environment` | 环境区域 | [定义](../../config/world_elements/definitions/zone.environment.json) |
