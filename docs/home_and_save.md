# 家园、永久成长与存档契约

## 状态边界

RunState拥有局内金币RunCoin、路线、主题/小关、临时道具/技能/枪支/Modifier、当前Health/Stamina/动作资源及奖励/交易账本。MetaProgression拥有profile_id、permanent upgrades、character/weapon/content unlocks、story flags、独立MetaCurrency钱包与永久结算账本。BuildState是RunState内部本局构筑；死亡清临时来源，从Character与Meta基础重新推导，不把局内属性累加进永久配置。

RunPolicy={id/version,death_cleanup,success_cleanup,retention_rules,settlement_policy,meta_grant_rules}逐项定义保留/清理/转入规则。金币用于局内升级；音符用于永久升级（D055用户确认）。金币能否兑换/带回及兑换比例仍待决策，不默认1:1。当前生成demo政策D056为音符合法拾取即永久保存，死亡保留；金币死亡清除。开发测试政策NO_TRANSFER仅是无经济结算的fixture，不是正式经济决定。未确定政策不能偷偷把RunCoin转永久币；保留只读RunSummary供后续正式政策评估，不让已结束局的钱包在家园继续消费。

RunDirector原子进入终态后产生唯一RunEnded(run_id,end_id,reason,summary)，未提交奖励/商店/Boss回调全部取消；RunPolicy仅处理已合法提交的局内事实，不能借终局结算补发同帧被死亡取消的Boss金奖励。Meta授权与幂等收据按profile_id/end_id保存。单纯返回家园不承诺自动保存断点续局；是否允许退出后续跑/死亡自动存盘细节待定，RunManifest的内容复现不等于完整存档恢复玩法状态。

## 发光花家园与环境叙事

新[世界背景](world_and_story.md)中的平原苏醒对应平原边缘独立安全家园。它不是挑战段起点/当前小关入口；死亡仍结束本局，存活环境回退仍不重抽地图或重置奖励。主角复活的具体原理、身份与花的关系未定，先作为风格意象。永久基础升级方向保留，不由附件“属性待定”撤销；内容/售价仍Q012，货币音符已确认，兑换与保留细节见Q008/D056。

StoryDiscovery定义stable_story_id/version/layer/biome/equivalent_group，未来由局部StoryService去重，必经或等效线索覆盖每层主线；Run保存本局发现来源和地区路径，Meta保存长期已发现线索/解锁/结局标记。StoryDefinition不依赖玩家控制器；短互动只在安全区，不能抢跳跃/瞄准输入。SaveService未来同版本化Profile原子保存发现与幂等收据，重复发现只简化展示，不再次发奖励。现有session-only摘要不等于剧情已持久化，结局解锁规则仍待定。

## 家园与解锁

家园独立场景/上下文，提供开始下一局、永久基础升级、简单剧情/互动和解锁的接口。P4已接入无永久经济的最小入口/返回演示；本轮新增音符与一种永久生命升级最小切片；故事内容、人物/枪支解锁在P6逐项接入。UpgradeDefinition/UnlockDefinition/StoryDefinition使用稳定ID与版本，具体内容、成本和触发条件未定。

升级事务校验政策/报价/前置、余额、等级上限与transaction_id；升级与扣MetaCurrency、解锁/剧情标记及收据在同一ProfileRevision提交。重复升级/重复解锁/重试存档不能再次扣币或发奖。永久基础能力也以来源Modifier注入新局，不直接写玩家脚本。Android/PC共享数据，不包含触屏坐标、机器路径、Steam账号或SDK对象。

## SaveService与存储适配

SaveEnvelope={schema_version,content_version,profile_id,profile_revision,checksum,payload(meta,policy_versions,settlement_ledger)}；可选续局快照另有run_snapshot_version与完整RunManifest。只写JSON等可验证数据，不保存Node引用/Resource实例地址。本轮SAVE-NOTES-01实现音符/升级与事务收据的最小持久服务，不包含中途续局或云同步。

SaveService负责校验、序列化、迁移和提交；LocalSaveStorage负责平台文件/原子写入/恢复；WebStorageAdapter显式确认浏览器写入；本轮采用localStorage同步写入并读回验证、异常拒绝提交，不将Godot文件内存缓存当刷新后持久证据；未来CloudSyncAdapter只负责传输/冲突，不决定奖励经济。Native同目录临时写→flush→校验读回→保留上一有效备份→原子替换最终文件，完成存储确认后才发SaveCommitted。文件重命名/浏览器存储的原子与持久语义各平台实测，不能以Linux成功推断Android/Windows/Web。

奖励/解锁的永久结果及其幂等收据放同一profile提交，防止成功落盘但响应丢失后重试重复发奖。写失败保留上一有效版本，dirty状态可重试，不能宣称保存成功；云同步失败不破坏本地可玩。

加载先验证checksum/schema/稳定ID，坏主档恢复上一有效备份，保留损坏文件供恢复；主/备份都坏时报告恢复失败并保留原件，不自动覆盖成新档。未知未来schema只读/报不兼容，不降级写入；支持版本用纯数据迁移链，迁移前留原件，迁移失败不提交。SAVE-01至少做旧版→新版、截断写入、主档坏/备份好、两者坏、存储拒绝、重复commit的实际测试。云冲突策略在平台接入前另定，不假定按最后时间戳覆盖。

## 当前家园 demo

`DemoApp`从HOME创建全新Player/BuildState/RunWallet/RewardService/ShopService；RunEnd清本局Modifier与钱包、取消lifetime并卸载当前关/玩家，再显示家园。原P4的`MetaProgression`默认无存储fixture仍保留；正式demo显式配置持久适配器，新增音符钱包/升级及原子收据。本次技术完成与平台实测结果见handoff。重复返回HOME不再次结算，新局不继承上一局道具/金币。MetaCurrency保持独立，开发NO_TRANSFER fixture没有兑换规则。

旧无存储fixture刷新即丢失；新音符模式须经实际刷新重载确认才记录Web持久通过。没有中途续局、云同步、剧情或角色解锁；原生Android/Windows的真实存储仍分平台验收。试玩步骤见[固定 demo](demo_playtest.md)，证据见[交接](handoff.md)。

## PR33运行接入与新家园边界

D058要求接入[标题与家园交接](title_home_ui.md)：TITLE主菜单进入固定安全行走Home，死亡/大关完成返回Home，靠近NPC显式交互打开永久升级/只读角色与成就面板，出口发起新冒险。已有音符SaveService与生命升级是真实消费者；PR33原稿“尚无存储/经济”只描述其独立美术交付，不能覆盖本工程既有服务。未有实际角色/成就系统不伪造解锁或消费。详细运行/表现与验收见[本轮约束](plains_polish.md)。
