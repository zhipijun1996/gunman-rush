# 游戏开发 harness

harness 将现有检查组成可执行的验收入口，不替换实际测试，也不把技术通过当成高质量游戏已经获用户认可。技能负责需求到交付的工作步骤，harness 负责执行、失败码和证据。

```sh
python3 tools/harness.py --plan
python3 tools/harness.py --base origin/main --profile auto
python3 tools/harness.py --profile docs
python3 tools/harness.py --profile gameplay --profile art
python3 tools/harness.py --profile web
python3 tools/harness.py --profile full
```

| profile | 检查范围 |
| --- | --- |
| docs | 文档/世界设计/入口结构/runner 故障回归、Skill/模板/记录检查、质量防伪回归与三种模板演练；每轮必跑 |
| core | docs、固定工具链、解析和核心套件 |
| gameplay | core、历史开发回归、当前两图地区的真实 Motor 与生命周期 |
| art | docs、manifest/哈希/尺寸/各运行素材包；素材接入同时跑 gameplay |
| web | docs、缓存预算、实际 Web 导出、分块重构/许可和包完整性 |
| full | 合并上述检查，按 ID 去重 |

默认 auto 比较 base...HEAD，并包含暂存/未暂存/未跟踪文件；docs 和 skill 改动选 docs，assets 选 art+gameplay，Web 工具选 web。运行代码、配置、构建、其他 CI 或未知文件保守选全部。这是最低自动检查范围；需求涉及 GUI、保存、输入或设备时必须补验，不根据文件名省略业务验证。

首次环境安装见 README；art 需 tools/requirements_art.txt，web 需 Node 与固定导出模板。缺依赖显式失败，不跳过。checks 的 argv、超时和成功标记只维护在 tools/harness/profiles.json。老工具 CLI 保持兼容。 argv 中仅显式 `{check_token}` 会展开为该次执行的唯一 token，使要求 fresh 的检查保留旧输出并使用新目录；报告同时保留模板 argv 与实际 expanded_argv，缓存输入摘要仍使用模板。

每次执行生成独立 build/verification/harness/时间戳/report.json 和逐检查日志。报告记录提交、工作区差异、命令、Python 版本、退出码和时长，Godot 版本在 environment 日志。非零退出、缺完成标记、Godot 脚本/解析/着色器错误和超时都失败，停止后续检查；超时清理包括独立会话中的引擎子进程；不会提交、推送、合并或发布。--plan 仅规划，不写通过证据。

## 从需求到游戏品质

每个切片先写“玩家在什么场景遇到什么问题、改变后可观察什么”，定义一个可玩的体验和禁止回归项。明确 Seed、入口、能力、配置与目标设备。实现后依次检查：真实动作可达/资源与生命周期 → 正式入口 GUI（标题、家园、出发、探索、伤害、奖励、返回）→ 目标设备 → 用户对操作、节奏、视觉的评价。卡住时保留失败轨迹，缩小切片修复。

浏览器入口例如 python3 tools/verify_plains_region_browser.py URL；现有验证按实际任务选用。Web 弱网 suite 使用 tools/verify_web_resilience.py 的 before/after 部署目录；不能把缓存预算单测说成弱网实测。手机/大陆网络/用户趣味性没有自动通过字段，始终单独记未验或实际证据。

任务记录模板见 [迭代模板](templates/iteration.md)。精选报告随实现提交至 docs/evidence/，handoff 指向证据；自动临时日志保持忽略。未来迁移到其他游戏时先替换权威契约、引擎和 checks，不继承平原的一跳/两图作为通用游戏规范。

## 质量声明与 CI

[总门槛](development_quality.md) 负责 G0–G5，[质量工具](quality/README.md) 校验十一维、证据和 done。docs profile 在所有 profile 内复用 quality / quality-tests / quality-drills，不替换旧检查。PR CI 另外运行 `python3 tools/check_quality_diff.py --base <PR-base-sha>`，检查新 done、生产修改的任务归属、资产来源和已有测试/检查删除或敏感断言变化。日常 push 仍执行全部 docs 检查，跨基线保护在 PR 检查。

敏感测试修改需覆盖该路径的质量记录、test_change_justification 和实际独立审查证据；不能用假 reviewer 名字绕过。此保护是保守文本/集合差异，不证明任意代码语义等价；例如保留断言但改变辅助函数仍需人工 diff 审查。代码和 CI 不是不可篡改安全边界。

## 多包任务执行

`--mission` 模式见 [生产循环](quality/production_loop.md)，默认只计划，`--execute` 才真实调用 Codex Skills。原有 `--profile` 验证模式不变。

## 人物动作专项规划（2026-10-13）

见 [人物动作规划](quality/player_action_plan.md)：inventory、输入、运行、资源、生命周期、表现、能力锁和预算八类专项目前planned。其runner尚未实现，不能以已有profile通过宣称这些检查通过；只在真实runner、失败反例和完成标记就绪后注册。动作转换采用 [覆盖卡](templates/player_action_coverage.md)，正常速度音轨录像与GPU输出/设备/用户证据分开。

## 已接入人物动作专项（ACTOR-ACTIONS-01）

`actor-actions`已在gameplay/art/full执行真实Player场景、Controller/Motor、普通枪/三连、H/W/D及输入/取消/资源和所有Studio演员实例检查，命令`python3 tools/run_actor_action_tests.py`。它不替代正常速度带音轨录像、GPU合屏、正式成长授予、独立审查或真机。规划中的其他八类专项仍需按具体范围扩展，不把本单套件外推为六武器/16区覆盖。

本轮 ACTION-BUDGET-01 新增 `action-budget`，接入 gameplay/art/full：30/60/120 Hz实际Motor地空路径、D与1.5D/0.5D段预算、清速短驻/顶点缓落、激光首帧可见/限时收束、空中即时炸弹、同探测器钩辅助/墙阻/双侧45°、技能共享主瞄准及Web device0伪鼠标反例。`python3 tools/run_action_budget_tests.py`要求非零断言、零失败完整标记；`tools/verify_action_budget_browser.py`用实际鼠标与CDP多指触屏，不能代替实体设备和主观视听验收。

## 2026-10-14交付提效

--jobs 4隔离并行；--check为明确标记的开发专项；--reuse只复用同依赖原证明；--release强制fresh。旧八关专属入口与测试已移出运行范围，共享消费者继续完整执行。执行规范见[交付提效](delivery_efficiency.md)。一键本地交付：python3 tools/deliver.py --jobs 4。

## Level Design Harness V2 专项

详见[生产体系](level_design_harness_v2.md)。原G0–G5、十一维与现有profile全部保留。docs追加设计合同、诊断正负例、路由与黄金证据防伪测试；gameplay/full追加 `level-design-runtime`（真实能力/正式Manifest/连续Motor路线）和 `level-design-golden`（新鲜Foundry短语/完整路线）。所有完成标记与退出码由原harness处理，缺失/错配/陈旧证据拒绝。

```sh
python3 tools/harness.py --check level-design-contracts --check level-design-analysis --check level-design-routing
python3 tools/harness.py --check level-design-runtime --check level-design-golden
python3 tools/level_design.py route --request "制作荆棘森林" --output build/level_design_v2/forest-mission.json
python3 tools/harness.py --mission build/level_design_v2/forest-mission.json
```

`mechanism-comparisons` 作为轻量 Python 回归加入 docs 及其余 profile，专项命令为 `python3 tools/harness.py --check mechanism-comparisons --release`。它执行 `tests/test_mechanism_comparisons.py`，校验预期操作、廉价替代解、消融及独立审查的比较结构，并拒绝技术检查全绿却缺少 promotion 依赖的 stage；合成记录通过不代表实际玩法、趣味或 v2 内容验收。

mission默认只规划；`--execute`才调用现有生产循环。诊断候选不是趣味评分，设计fixture不是正式森林，合屏/录像/真机/玩家认可另行留证。

## 森林深度重构的当前技术检查

`forest-depth-guardian`、`forest-depth-guardian-tolerance`、`forest-depth-enemies`、`forest-depth-versions`、`forest-depth-restore`沿既有gameplay/full profile执行，原检查及其预算保留。前三者分别核局部战斗／有限时机／敌人因果，versions核旧版本和实际入口事务，restore核真实DemoApp获得状态后重载；任何一项不证明整区趣味或商业品质。另六项 `forest-depth-queen`、`forest-depth-cavity`、`forest-depth-cavity-controls`、`forest-depth-region`、`forest-depth-campaign-guardian`、`forest-depth-campaign-queen` 已接同一入口，分别要求整战、站地目的法／强廉价控制、固定10root×两图×四路线的80次真实路线（含原16）与真实App两Boss消费者；注册不表示当前版本已执行通过。

新增CLI自己执行一次有界editor import，不依赖作者快照的预导入缓存；游戏原生预算不变。输出保持fresh目录、旧证据不覆盖，Harness收集各自build/forest_depth原始轨迹／收据。仍需最终源正式入口、完整正常速度电影、不同作者审查以及明确未验项，局部通过不构成v2推广许可。

`forest-depth-ecology-expedition` 在同一gameplay/full保留地图1正式13段取奖返营后的活锚与满跳双R对照，并以既有 `--include-map2-expedition` 在同一次import后追加root02／map2／level0自然取奖→R的活锚／双R两组，两者共同使用普通满跳apex单枪E→C跨联到真实门。四组保留实际指针领奖、资源与完整路线守门；地图2局部独评CONTINUE不代表整个区域丰富度或玩家认可。旧上层活H边与侧环已退役。新增检查仍12项，每次使用 `{check_token}` 新输出，原300秒外层预算与其余阈值保留。

`forest-region-matrix`、`forest-formal-combat` 两项坐标专属历史回归由 `run_forest_v1_regressions.py` 在精确bee源fixture中执行原命令／断言；它们证明历史v1消费者，不覆盖新默认v2。完整原输出保留于legacy-runs，legacy-evidence只复制SHA绑定原报告、日志和fixture构建收据，不复制缓存、素材和影片；桥失败仍令检查失败。当前自然入口／调试入口／版本恢复／v2正式App与80路线另做实际检查。

## 历史证据与当前配置分离

参数合同改变后，固定历史native/Manifest仍须绑定原始配置字节与原source inventory；不能重写旧capture、只换指纹或借旧成功认证当前运行。历史Python消费者可在明确限定的语义校验scope读取SHA绑定的旧authority，必须验证当前默认校验仍拒绝失配历史数据、篡改旧authority被拒绝、正常及异常退出都恢复当前scope；真实当前生成与原历史整串断言分别保留。内层CLI重定向日志的检查应沿原profile artifact_paths收集原件，不只保留外层通用错误。FOREST-GRAPPLE-02的根铃旧20%／当前15%修复是一次实际案例，不是新的并行生产流程。


### 原预算超时与驾驶失败的分账（FOREST-GRAPPLE-02）

原80／600秒检查在修正真实起跳策略后完成59条严格通过，但整组600.167秒超时仍为FAIL；内层receipt被终止时保留running，不能后补source_stable或passed。`run_forest_depth_region.py` 的每例seconds包含native、JSON读取、validate和rawSHA，不能直接称引擎耗时。先用一份已有capture做有界离线profile：本例2214帧读取0.174秒、带profiler校验0.275秒，不足解释整组缺口，故未凭假设修改校验器。后续同原案例／上限的CI结果另记，不覆写本机失败。详见[原件](evidence/forest_grapple02/release02/README.md)。

Driver为通关证据提交的输入可以改进，但不得改原断言、case、能力、资源或预算；改进后必须重采并保留旧FAIL。固定短跳失效不证明完整跳跃失效，强删动作对照也必须允许剩余能力的合理使用。本次完整跳跃→H实测成功，冠叉R不能继续宣称必需。驱动策略收益与内容收益分开，仍使用原Harness与独审，不新增平行评分体系。


### 公开GUI采证的OCR返工边界（FOREST-GRAPPLE-02）

S3实际CI／公网包通过后，GUI01因可见MENU未被识别而在3/20退出。先保存原截图／失败，再在真实像素上做黄金；初版追加单行ROI虽识别真实按钮，却把MENU2拆词误收，独审真实REJECT保留。仅新增PSM7路径改为整ROI归一化文本必须恰为MENU、再读取实际MENU单词字框；原5ROI、真实输入／事件／PCK身份／8入口／20检查／480秒均不改。整图抹字、真实无MENU、同字节MENU2等负例拒绝后才执行完整GUI02（最终378.771秒、20／8实测通过），不用固定点击坐标或游戏JS钩子绕过OCR。

发布游戏仍为S3原PCK；后续采证工具以自己的源码SHA绑定，不把工具修复后的GUI误称新游戏HEAD构建。CI ZIP代理403与公开GUI是不同证据：前者原包72未执行，后者只按实际结果记录，不相互替代。详见[原始失败／REJECT／复验](evidence/forest_grapple02/release03/README.md)。
