# 正式敌情感知试玩与证据闭包：技术候选

任务 `PLAINS-REDESIGN-ENCOUNTER-01`；沿用 encounter-director、game-quality-gate 与原 Harness，当前只验 G0/G1 工程范围。没有修改生成器、PlayerMotor、武器、资源、敌 AI、保存或能力授予。不同代理独审、最终整区质量、正常音画、实体设备与真人趣味认可另行记录；实现者不能预签自己的审查。

旧80组原盲走是18个策略目标、56次失败结束、6个策略失败。它不是玩家成功率，也不直接证明全部死亡由地形造成。新策略用于定位正式场景的真实问题，不能通过更聪明的脚本掩盖不可见预告、坏落点或不公平遭遇。

## 实际入口

```sh
python3 tools/level_formal.py --seed level-design-v2-baseline --maps 1 2 --strategies fast growth --encounter-policy kill_from_bank_v1 --output build/plains_playtest/new_run
python3 tools/level_formal.py --maps 1 --strategies fast --encounter-policy bait_then_bypass_v1 --output build/plains_playtest/nonkill_run
python3 tools/level_visual_capture.py --map-index 2 --strategy growth --encounter-policy kill_from_bank_v1 --output build/plains_playtest/movie_run
python3 tools/run_plains_encounter_policy_tests.py
```

不指定新flag时仍为 `blind_legacy`，历史request的原command无新增参数；旧receipt和raw不重写。新CLI未知模式拒绝。三种策略均通过正常调度的InputRouter→PlayerController→PlayerMotor，不能手动步进正式Motor、搬角色、注能或关闭敌人。底层原move/drop输入不属于未授予H/W/D；drop只在真实one-way支撑满足条件时生效，不能编造accepted_drop信号。

`kill_from_bank_v1`读实际敌身体、HP、AI状态、锁线、活动弹体与碰撞；在真实静态支撑岸选择站位和反冲退让，必要时通过真实移动换站位；每目标最多六次射击、900帧窗口，整条路线有独立帧预算。每次先回到稳定岸、等实际落地/冷却/精力，再Router射击；看见被墙或铃挡住的射弹通路不会把它当敌命中。无安全支撑、身体/弹体压力、无进展或非预期回退明确停止并保留失败，不给每个地图所有状态承诺全解。

`bait_then_bypass_v1`先正常走近可观察范围，等待真实telegraph/attack/recovery；退离已锁线，地面敌在真实安全起降岸允许以现有跳跃越过，保留活敌和实际无损跨越事件。空中敌的恢复窗口只表示候选通过时机，后续身体越过仍须实际运行；远程弹未清不因state=recovery便判安全。敌死亡、移动离开、仍活但超距不能混成同一“失活”。

策略读取Manifest和完整实际AI状态，属于有特权的自动化测试。每个战斗站位附真实canvas投影下敌身体screen AABB和viewport事实；屏外预杀不证明真人能先看到，更不证明HUD无遮挡或预告易读。

## 动作与资源因果

本轮修复的新观测合同 `capture_contract_version=3` 保留原formal_level_capture schema、完整逐帧input_requests/accepted_events/碰撞/资源与实际失败outcome。shot_accepted绑定真实PlayerProjectile的owner/session/shot/packet/event_id/aim；FrameDamagePolicy.batch_resolved记录真实committed event_id、damage_kind、target、health_after、lethal。正式Damageable经sink分支不发damaged信号，不能拿该信号作正式命中证据。

资源取真实StaminaState已存在的事务receipt，记录APPLIED状态、请求量、实际amount_applied、current/capacity/epoch/session；包括满槽时实际退款0的有效receipt，不能把每次命中都写成固定+20。射击消费、实际弹体、选择后的真实伤害和hit退款按ID关联；连续地面自然恢复仍保留帧状态，不能当作注能。死亡批次可能先失效actor而取消退款，必须保存该优先级。

近战AI的原_serial只对实际远程发弹递增；观测器另以真实state_changed信号记录本地transition_serial，不改AI或伪称所有攻击都有同一种serial。停船/登岛/返船/重启及承诺空中动作保护其输入链，不能因站船时grounded就随意插战斗射击。BranchModuleDriver只向可选观察器报告真实move_to目标，原轴输入运动循环保留。

## 正式成长、岛箱和失败重试

aware growth按实际奖励访问两个medium后回营地，再继续原路线目标。正式chest.id带 `PlainsRegionCampaign.prefix(map_index)`；其运行箱位置和账本不能用未加前缀的Manifest ID替代。普通箱真实走近位置；有approach合同的溪谷箱，从entry dock调用共享 `plains_creek_discovery_motion.traverse`，在同船已暂停、岛岸实际落稳窗口，通过Router interact打开原Modal、提交原UI回调并等队列真正提交。

`_claim_modal_item(true)`只代表入队；验收另核实际claimedID、箱状态、正式RunManifest cache输出和钱包/health/meta效果。岛helper的bool只证明身体链，不代表领奖；callback后继续真实drop回原船、射铃重启、出dock并回camp。旧v9无approach时使用普通箱路径。

正式失败恢复专项从正常DemoApp起步，先真实领第一medium、合法返回已开井，在井岸仅用无跳轴输入跌入现成危险。原ENVIRONMENT伤害/segment return、真实安全锚、session/actor epoch变化及合法重试都有原事件。场景、敌、机关和奖励实例保留；敌旧攻击按原cancel规则进入recovery、旧弹被取消，所以不能要求attack_state/clock完全不变。HP、精力、冷却不能免费重置，奖励不得再次发放。该预期失败probe与普通路线的非预期失败停止分开，不冒充无伤通关。

## 同字节比较与版本边界

Godot独立采集runtime_source_hashes，与Python的完整runtime源清单逐文件哈希相等；少一个非core文件也不能通过。每侧完整source_before/source_after/source_files和capture_source_hashes仍绑定各自真实runtime、Scenery、Definition与配置，source漂移/未知模式/空轨迹/错命令/篡改事件严格拒绝。新policy_basis分为精确tests/tools传递驱动闭包和共同core实现字节：player/input/combat/damage/resources/actors/builds/meta/reward/shop/save/run、实际玩家/武器/物品定义、config、player场景碰撞和courier muzzle实现与project。配置相同但Motor、武器或资源实现改变，不能被算作纯关卡内容收益。

新/新比较必须同策略、同reward policy、同闭包和core字节；只合法Gen/Scenery等内容变化可以比较，但每侧完整来源仍保存，DemoApp混合流程/表现差异仍须独立审查，不由小投影宣称语义等价。历史无新协议的记录继续旧完整observer比较，不重标旧证据。

专项从已归档的精确30f/v9源重建隔离工程，只覆盖共享tests/tools闭包；原scripts/scenes/resources/config/project/shaders全量哈希前后核对，绝不将新runtime、美术或lowarch v2覆盖旧图。四个实际原失败用相同新策略在旧/新内容复采，保留旧/新任何策略失败。完整双80与正常音画由最终源冻结后继续；这些少量案例不是全Seed或玩家策略覆盖。

## 本轮真实返工与限制

保留编译类型错误、producer漏闭包、教程窄岸反冲二次射击未回位而真实跌落、视线只查地形漏layer8铃导致实际渡船四次切换、普通箱前缀漏匹配、非击杀越过后原waypoint回头导致重复越过等原失败。原生fixture的初版零能量探针仍在冷却、diver首弹瞄准偏失，以及正式井铃地面射击被真地板挡住，也保留后通过真实落地/冷却/重新瞄准/原动作链返工。

原生Fixture覆盖物理遮挡、实际冷却拒绝、合法消耗至0后的空中拒射、真实终态/死敌不退款、活敌/移动离开/超距但仍处理。它不是正式地区；正式真实App领奖/失败/非击杀另有消费者证据。JSON变异只验证验收器，不能代物理。Godot退出ObjectDB/resource/RID警告仍保留，不宣称无泄漏或真机性能通过。最终计数和命令以本任务portable证据索引为准，独立审查仍由不同代理执行。


## 本包实际工程验收

最终完整原始证据、压缩/原字节SHA、旧/新同策略具体outcome、命令与版本见 [portable索引](../evidence/plains_redesign/encounter/index.json)。原生实际14项fixture与正式DemoApp失败回退各自保留边界；四组两侧重采只证明这些策略的实际结果。map1 return的deep_high入口contact与有界策略停止仍是内容/策略联合候选，不因别的路线通过而隐去。正常构图、屏外射击公平、双80、视频、独审、手机/手柄和真人趣味仍需后续独立证据。G1是这个观测工具切片的技术准入，不是平原整体好玩通过。


## 独立 REJECT 后的 R2 窄返工

原 [233成员索引](../evidence/plains_redesign/encounter/index.json)、源归档及raw原字节保留。独立审查发现原Harness直接入口只跑11/15项而手动discovery跑16/21，以及实际growth记录可篡改钱包收据/效果、资源/金额仍被接受。现把唯一unittest.main移到两文件全部class之后；新增资源邻接也通过原直接入口执行。原审查、原四反例和修复证据另存 [R2索引](../evidence/plains_redesign/encounter/r2_repair/index.json)，不覆盖原件。

v3在真实Modal打开后记录实际offer候选/所选ResourceRewardChoice和stage，在提交前后读取原wallet grants、HealthState事务result（状态/epoch/请求量/实际clamp/current/capacity）、MetaProgression持久事务与余额/版本。验收将实际候选→正确stage/chest的最终RunManifest cache输出→唯一新增服务收据→前后效果连接起来。钱包净变动汇总全部新增grant，生命汇总实际damage/heal，notes汇总原持久收据，因此允许同窗口其他真实交易，不假定净差恒等单项奖励。任意缺失、错ID/错stage、重复、未知资源、改请求/实际金额、offer和输出不符均拒绝。

历史v2不改字节或重标版本。它已有的最终cache、钱包receipt和余额/notes/heal效果继续严格校验，所以独立原四单字段变异被拒；其缺少实际offer和完整HP/meta前后ledger，由报告保留的version2及本合同明确标为历史部分证据，不能冒充v3完整事务证明；不改历史报告的派生字段或指纹以强塞新说明。v2与v3不做同协议比较。新策略只选择原生合法资源选项，不移除游戏item选项；未实际选择的item/build路径不在该资源专项证明范围。

实际资源专项除coin外，使用原代表seed账本的`level-design-v2-baseline/05`首箱heart候选；由Router在原井跌坑损血、原模块通过、箱近岸交互后真实请求2而实际只回1（HP4→5），随后正常失败回退/重试。它是刻意失败的经济与夹紧探针，不是无伤通关。原baseline首箱只有coin/note；/02虽Manifest含heart，但实际item+coin已占两候选；以及先到area中心拾取供应而回满的失败都留存。专项据实际offer选择覆盖样本，未改资源或生成规则。note从原baseline满血首箱的真实替代选项领取，核实际notes收据和持久revision。
