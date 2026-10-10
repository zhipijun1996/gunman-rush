# 家园、永久成长与存档契约

## 状态边界

RunState拥有局内金币RunCoin、路线、主题/小关、临时道具/技能/枪支/Modifier、当前Health/Stamina/动作资源及奖励/交易账本。MetaProgression拥有profile_id、permanent upgrades、character/weapon/content unlocks、story flags、独立MetaCurrency钱包与永久结算账本。BuildState是RunState内部本局构筑；死亡清临时来源，从Character与Meta基础重新推导，不把局内属性累加进永久配置。

RunPolicy={id/version,death_cleanup,success_cleanup,retention_rules,settlement_policy,meta_grant_rules}逐项定义保留/清理/转入规则。局内金币能否带回、永久升级货币与兑换比例待决策；币种分离，不默认1:1。开发测试政策NO_TRANSFER仅是无经济结算的fixture，不是正式经济决定。未确定政策不能偷偷把RunCoin转永久币；保留只读RunSummary供后续正式政策评估，不让已结束局的钱包在家园继续消费。

RunDirector原子进入终态后产生唯一RunEnded(run_id,end_id,reason,summary)，未提交奖励/商店/Boss回调全部取消；RunPolicy仅处理已合法提交的局内事实，不能借终局结算补发同帧被死亡取消的Boss金奖励。Meta授权与幂等收据按profile_id/end_id保存。单纯返回家园不承诺自动保存断点续局；是否允许退出后续跑/死亡自动存盘细节待定，RunManifest的内容复现不等于完整存档恢复玩法状态。

## 发光花家园与环境叙事

新[世界背景](world_and_story.md)中的平原苏醒对应平原边缘独立安全家园。它不是挑战段起点/当前小关入口；死亡仍结束本局，存活环境回退仍不重抽地图或重置奖励。主角复活的具体原理、身份与花的关系未定，先作为风格意象。永久基础升级方向保留，不由附件“属性待定”撤销；内容/货币仍Q008/Q012。

StoryDiscovery定义stable_story_id/version/layer/biome/equivalent_group，未来由局部StoryService去重，必经或等效线索覆盖每层主线；Run保存本局发现来源和地区路径，Meta保存长期已发现线索/解锁/结局标记。StoryDefinition不依赖玩家控制器；短互动只在安全区，不能抢跳跃/瞄准输入。SaveService未来同版本化Profile原子保存发现与幂等收据，重复发现只简化展示，不再次发奖励。现有session-only摘要不等于剧情已持久化，结局解锁规则仍待定。

## 家园与解锁

家园独立场景/上下文。2026-10-10用户明确：家园是玩家可以控制人物行走的场景，分别与NPC对话开启换人物、永久升级、成就功能，NPC随进度逐步解锁，场景出口开始冒险；不能仅以全屏按钮页代替家园。三类功能、NPC渐进开放和出口用途已确认；人物名单、升级条目/价格、成就奖励、解锁顺序与门槛仍待确定，不把Q012整体标为已解决。

P4已接入无永久经济的最小入口/返回演示；当前`DemoMenu.show_home`仍为按钮菜单，尚未实现上述可操控家园。真实永久购买、故事内容、人物/枪支解锁在P6逐项接入。UpgradeDefinition/UnlockDefinition/StoryDefinition使用稳定ID与版本；视觉与交互交接见[标题与可操控家园](title_home_ui.md)。

升级事务校验政策/报价/前置、余额、等级上限与transaction_id；升级与扣MetaCurrency、解锁/剧情标记及收据在同一ProfileRevision提交。重复升级/重复解锁/重试存档不能再次扣币或发奖。永久基础能力也以来源Modifier注入新局，不直接写玩家脚本。Android/PC共享数据，不包含触屏坐标、机器路径、Steam账号或SDK对象。

## SaveService与存储适配

SaveEnvelope={schema_version,content_version,profile_id,profile_revision,checksum,payload(meta,policy_versions,settlement_ledger)}；可选续局快照另有run_snapshot_version与完整RunManifest。只写JSON等可验证数据，不保存Node引用/Resource实例地址。当前没有SaveService，实现延后SAVE-01。

SaveService负责校验、序列化、迁移和提交；LocalSaveStorage负责平台文件/原子写入/恢复；WebStorageAdapter显式处理浏览器异步持久化确认；未来CloudSyncAdapter只负责传输/冲突，不决定奖励经济。Native同目录临时写→flush→校验读回→保留上一有效备份→原子替换最终文件，完成存储确认后才发SaveCommitted。文件重命名/浏览器存储的原子与持久语义各平台实测，不能以Linux成功推断Android/Windows/Web。

奖励/解锁的永久结果及其幂等收据放同一profile提交，防止成功落盘但响应丢失后重试重复发奖。写失败保留上一有效版本，dirty状态可重试，不能宣称保存成功；云同步失败不破坏本地可玩。

加载先验证checksum/schema/稳定ID，坏主档恢复上一有效备份，保留损坏文件供恢复；主/备份都坏时报告恢复失败并保留原件，不自动覆盖成新档。未知未来schema只读/报不兼容，不降级写入；支持版本用纯数据迁移链，迁移前留原件，迁移失败不提交。SAVE-01至少做旧版→新版、截断写入、主档坏/备份好、两者坏、存储拒绝、重复commit的实际测试。云冲突策略在平台接入前另定，不假定按最后时间戳覆盖。

## 当前家园 demo

`DemoApp`从HOME创建全新Player/BuildState/RunWallet/RewardService/ShopService；RunEnd清本局Modifier与钱包、取消lifetime并卸载当前关/玩家，再显示家园。`scripts/meta/meta_progression.gd`只在当前进程内独立保留完成/失败次数和只读本局摘要，按唯一end_id去重且拒绝冲突；这属于P4演示，不是永久升级内容或已持久化进度。重复返回HOME不再次结算，新局不继承上一局道具/金币。MetaCurrency保持独立，开发NO_TRANSFER fixture没有兑换规则。

刷新浏览器或关闭游戏会丢失该内存摘要；目前没有SaveService、Web持久确认、自动保存、升级商店、剧情或解锁内容。界面明确显示session-only，不能把进程内保留当成正式永久成长完成。试玩步骤见[固定 demo](demo_playtest.md)，证据见[交接](handoff.md)。
