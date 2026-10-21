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

地区开发先取短反馈：新GDScript在同一root引擎租约执行 `bash tools/godot.sh --headless --path . --check-only --script <实际脚本.gd>`，随后跑局部真实消费者，最后按原案例和预算做完整验证。新连接的局部Motor记录必须写 `initial_fixture_spawn_override=true`，只允许首次Motor步前的初始fixture定位，不改资源/能力/physics或中途位置；通过也不签正式fullspawn路线。parse、局部反馈与正式完整验收分别留证，均不扩原测试/CI上限。

合屏在geometry、render与source metadata完整源集冻结后才开始；source_guard漂移令整轮失败，保留 `build/region_bible_v2/golden-third/receipt.json` 的source-changed原件，不借已生成画面或后续通过改签。离线fixed-fps与音频backend墙钟须分开，手动释放fixture只隔离自主调度，保留真实弱引用释放与12voice断言；实际native-third→fourth的局部边界见[animation-vfx](../.agents/skills/animation-vfx/SKILL.md#自动验收)。

`forest-bible-ambience` 已追加gameplay/art/full，实际CLI含90秒import及90秒native，外层210秒；每轮以 `{check_token}` 新目录保留原失败。它验证本地Node/GameAudio生命周期，听音、正常速度合屏、正式campaign和设备仍单列，注册不冒充本次已执行。

`forest-practice-bell-restore` 追加gameplay/art/full，复用实际90秒native及完整源清单，外层120秒，新token目录保留旧结果；只验机关相位/原子恢复和实际App卸载重建，不签完整路线。新增实际App发现检查和G世界检查的缓存输入也涵盖scripts/scenes/resources/config/shaders/assets/tests/tools及project.godot，避免同屏body PNG或共享helper变化沿用旧缓存；原132检查的命令、断言与预算保持原值。局部Motor用 `run_forest_bible_world_fixture.py`，正式路线用 `run_forest_bible_world_motor.py`；双区静态合屏用 `run_forest_bible_golden.py --compare-plains`，均读取同一完整源inventory，局部或静态结果不能代正式路线/影片/设备。

每个切片先写“玩家在什么场景遇到什么问题、改变后可观察什么”，定义一个可玩的体验和禁止回归项。明确 Seed、入口、能力、配置与目标设备。实现后依次检查：真实动作可达/资源与生命周期 → 正式入口 GUI（标题、家园、出发、探索、伤害、奖励、返回）→ 目标设备 → 用户对操作、节奏、视觉的评价。卡住时保留失败轨迹，缩小切片修复。

浏览器入口例如 python3 tools/verify_plains_region_browser.py URL；现有验证按实际任务选用。Web 弱网 suite 使用 tools/verify_web_resilience.py 的 before/after 部署目录；不能把缓存预算单测说成弱网实测。手机/大陆网络/用户趣味性没有自动通过字段，始终单独记未验或实际证据。

任务记录模板见 [迭代模板](templates/iteration.md)。精选报告随实现提交至 docs/evidence/，handoff 指向证据；自动临时日志保持忽略。未来迁移到其他游戏时先替换权威契约、引擎和 checks，不继承平原的一跳/两图作为通用游戏规范。

## 质量声明与 CI

[总门槛](development_quality.md) 负责 G0–G5，[质量工具](quality/README.md) 校验十一维、证据和 done。docs profile 在所有 profile 内复用 quality / quality-tests / quality-drills，不替换旧检查。PR CI 另外运行 `python3 tools/check_quality_diff.py --base <PR-base-sha>`，检查新 done、生产修改的任务归属、资产来源和已有测试/检查删除或敏感断言变化。日常 push 仍执行全部 docs 检查，跨基线保护在 PR 检查。

敏感测试修改需覆盖该路径的质量记录、test_change_justification 和实际独立审查证据；不能用假 reviewer 名字绕过。此保护是保守文本/集合差异，不证明任意代码语义等价；例如保留断言但改变辅助函数仍需人工 diff 审查。代码和 CI 不是不可篡改安全边界。

收集证据只处理本轮变化的输出。为避免大型轨迹再复制一份耗尽磁盘，新增的至少8MiB JSON流式进入每检查的`artifacts-large-json.zip`，完整索引、每成员大小/SHA及CRC校验后才发布；小文件和`check.log`仍保留原路径，原生输出不删除。缓存同时核对ZIP、索引、独立记录的原始输出摘要，以及普通工作区的live输出；隔离lane也保留原始摘要。缺件、篡改、源在读取中变化或写入失败均拒绝，不使用硬链接或仅保存哈希替代数据。`harness-artifact-archive-tests`在六个原标准profile末尾执行12个真实正反例，旧150检查字典及原profile前缀保持。

离线分析可显式恢复一个完整成员到已存在安全目录中的**新文件**；不覆盖原件，不自动修改live输出。示例中的成员名取自该检查的索引：

```python
from pathlib import Path
import sys
sys.path.insert(0, "tools")
from harness import restore_archived_artifact
restore_archived_artifact(Path("build/verification/harness/RUN/artifacts/CHECK"),
                          "build/example/capture.json", Path("build/restored-capture.json"))
```

原生检查通过而收集器中断时，外层仍是失败或`interrupted`；不能补改旧收据为通过。实际80路线已通过但外层ENOSPC，以及归档初版的缓存误接受与独立修复链，随源版本分别保存；新的完整fresh执行另立收据。

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

整区平原候选的短反馈入口为 `python3 tools/harness.py --profile regional-art-feedback`，复用docs与原检查调度，运行实际整区生成/默认Manifest对PR85原件比较、无标签图同构及伪造覆盖反例。真实电影仍走原`visual_director.py capture`和新增regional适配器；完整源码、正常输入、伤害/HP、清理退出门槛保留。长电影临时AVI允许保存在明确唯一的系统临时目录，经原始SHA验证后成功清理，失败保留；MP4/日志/回执仍在build。当前仅技术候选，艺术失败见[实录](evidence/plains_regional/recipe.md)。


## 区域圣经与共享画风准入（2026-10-21）

区域创建和优化先绑定[注册表](creative_direction/bibles/registry.json)中的完整Bible及[当前共享参考](creative_direction/bibles/style-continuity-20261021-v2.json)，不能只传摘要、只继承脚本而漏掉实际纹理依赖。缺Bible只做文档提案。`region-bible-feedback`用于窄反馈，`region-bible-contract`与`region-bible-tests`追加到原profile；原132检查和10个profile前缀不变。风格绑定/缓存防漂移是技术守门，仍须实际跨区合屏和独立视觉审查后扩产。

新版路线按实际输入、枪口、互斥UI和当前Manifest消费；保留旧版本driver与保存重建，不把新版Manifest改标签交旧校验器。诊断先复验真实失败场景，再跑原16代表；完整原80案例和600秒预算留到候选源码冻结的正式准入，不以窄反馈代全量。暂停中的新UI须有process-frame故障边界，不能仅依赖已停止的physics tick；真实关闭仍走Viewport输入，并保持奖励幂等及冻结资源断言。

新增森林正式路线检查覆盖两图的连接/背枝取奖返营及图二F08真实Reader木芯路线；初始出生fixture只作开发诊断。每次记录完整runtime/test/tool输入前后SHA，新增/删文件同样令源漂移失败。素材小改不重签旧路线或旧画面；原失败、限定接受与最终完整发布证据分开保留。

区域Bible的新reader与采证逻辑通过现有`forest-bible-reader-tests`、`forest-bible-av-reader-tests`进入gameplay/art/full；原检查与预算不替换。它们检查有限正反例和源闭包，不能签路线、审美或声音听感。新覆生材质先跑目标实际合屏，例如`python3 tools/run_forest_bible_golden.py --thorn-only --compare-plains --output build/region_bible_v2/<fresh>`，查看两区正式角色与平台、上/下/侧/真实转角，再作独立审查；实际静图不冒充连续动作。连续采证使用`tools/capture_forest_bible_route.py`复用已存在的全出生点路线，保留原AVI与真实引擎draw/physics时钟；其验收器的单元反例通过也不等于已运行电影。
