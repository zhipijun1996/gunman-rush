# 上游要求与完整地图缺口

本页沿现有Provider→Plan→Stage→Runtime，不另立地图协议。当前固定SDK0.4.1、module1.1.0、runtime-map/v2；普通出发未替换。

## 已实测的合同

- 实际map坐标为x右/y下、128px/block、owned rectangle local frame。SDK已物化源偏移和镜像，宿主只加 `origin_blocks * 128`。原完整平台、封口与机制不删改。
- 合法权限词为INPUT/OUTPUT/INOUT；当前切片对合法但未支持的单向连接明确拒绝，IN/OUT为非法协议值。不要为宿主切片把上游权限缩成旧词汇。
- 未用Port合法封闭后，旧authored entry/exit helper可能不可站。宿主按实际连接Port、真实24×36身体、净空和落脚准入，旧helper仅保来源；原几何/能力检查继续有效。
- 真实生成是内存结果：保原上游request_fingerprint，另绑定实际结果摘要、SDK/模块、全content、选择范围及宿主bindings。不存在map.json文件校验记录。冻结来源继续核原字节SHA，两来源进入同Provider内部转换。
- 原SDK job为协作advance，可主线程yield；生成阶段不碰SceneTree，节点装配在主线程。宿主持有job/run/stage/actor信封，旧、重复、取消/退出结果不提交。已验证库按SDK和moduleSHA复用，取消单job不等于销库。
- Godot4.7.2原版SDK基本验证、gears真实生成及完整safe_lesson夹具已执行。0.4.1实际Web等待/长帧与完整入口验收在后续收据前仍未签；上游HANDOFF性能数字只为上游证据，不替代宿主。

## 给map-gen的具体要求

1. 保持package manifest、19GD各叶SHA、交付提交与实际source_commit分离、module/archive锁、原request/config及success/failure参考结果。宿主升级走显式旧版核验→新版本安装，不等待可变main，也不修改SDK源码。
2. 运行输入继续原typed request/library/config。实际普通能力从controller/tuning/body构造；conformance含grapple不能自动授予玩家。当前快照主要是能力标签、身体尺寸、武器/跳跃及资源观察，不是完整动态物理可达性证明；缺少的运动/时序约束请作为后续明确协议议题，不能由宿主伪造能力。
3. 性能热点继续由算法仓优化并发新版本/SHA。宿主记录preload、校验/解压/parse、实际计算、yield、复制/摘要及装配的执行耗时与墙钟。当前advance单位仍可能长帧，不声称已有硬帧预算；如要硬预算须交可中断计算单元及可测合同，不能只改host tick数字。
4. 保留内容有效性负例和奖励空间回归。0.4.1同请求布局内容保持不等于宿主已支持全图；奖励和机关可达性仍须结合真实消费者/已授予能力验证，不能只看端口拓扑。

## 给map-edit的具体要求

- 旧覆盖表绑定0.3.0，不能沿用M16/M18/M21或M35编号。当前新提取件是 [实际0.4.1/930007库存](../../evidence/mapgen_041_windchime/coverage/actual-041-930007-inventory.json)，其source SHA绑定同次生成result，明确仅一张conformance地图，不是40图或controller请求的完整覆盖表。
- 每次按实际module_id/content_version/role/content_ref/连接定位，并保留原platform、gate、bell、seals和所有敌人奖励。内容版本改变必须重新核验和提取；不为了宿主“支持”删掉不支持字段。
- 起点 `game-plains-windchime-lesson` 当前content_version为 `sha256:b2ee44df5422a7b4dd9be1358a075c46cefb00992de802607389f6f94ecfa433`，safe_lesson为永久开门。提供Port几何点、身体落脚岸与authored helper的语义区分；未用Port封闭不应要求旧helper仍可站。
- 当前起点实际邻居含未支持消费者。若要认证跨缝，须装邻模块全部内容并逐项实现；单模块到本侧出口岸只能报告本侧范围，不删邻居机制/敌人凑通路。

## 距离第一张完整可玩地图的具体消费者

以下来自当前Provider明确拒绝范围和真实0.4.1/930007内容库存，不承诺本批实现：

| 消费者 | 当前状态/必须补的实际接法 |
| --- | --- |
| 起点邻模块完整内容 | `idea-interface-s12-001` 在实际库存含moving_platforms和enemies；完整接入其运动定义与敌人Factory/实例状态后，才能验跨缝 |
| 其他钟门/多条件门 | 仅固定版本safe_lesson已适配。库存有`b31-n06-fourport-two-low-ingress`、`batch30-block-n04-0-2`、`idea-interface-s11-001` latches；需按真实kind/内容实现原正式机制与恢复，不能通用默认开门 |
| 敌人 | Provider目前拒非空enemies。库存含多个工坊/idea模块；需把行为/变体映射到现有Registry/Factory、唯一DamagePolicy、Run/Stage/Actor取消和敌人恢复；不同实例状态隔离 |
| 奖励/宝箱 | Provider拒非空reward_sites。需映射原RewardService/Wallet/claimed收据及实际装备掉落目录；稳定实例身份、成功后领取、幂等与恢复，不造第二套经济 |
| 钩索/墙/荆棘 | hooks、wall_platform_indices、thorns目前拒绝。需原controller真实能力/表面/伤害消费者、已授予能力与路径验证；不能补能力或自动改地图 |
| 其他危险与运动 | 当前支持范围限已有三模块ellipse和固定gears危险/锯齿/两台linear。其他模块的非空saw/hazard/trajectory不能按字段相似就宣布支持，需定义级验证、共享时钟及生命周期 |
| 多端口/单向/垂直跨缝 | 当前准入面向受控水平岸/固定gears支撑；合法但未支持Port方向/表面/单向仍拒绝。需完整相邻体积、实际连接及真实Motor路径，不能关闭原几何验证 |
| Boss与完整终点流程 | map生成的boss角色不等于宿主已绑定BossFactory、arena/门、奖励、退出、死亡优先及恢复。必须沿现有RunSession/Stage组合正式消费者 |
| 正式App/整图承载 | 需全图Plan内容支持、正式HUD/地图记录、区域/出生、完整出入/取消/同图恢复及Web预算，再考虑替换普通Provider选择。此次开发入口不等于普通出发已迁移 |

全图开放前应从同次真实controller请求重新提取完整库存，选择一个实际完整相邻消费者增量验证，再逐批覆盖整图。不能把本页有限库存当新权威运行注册表，运行准入仍由现有Provider/Registry/Factory负责。
