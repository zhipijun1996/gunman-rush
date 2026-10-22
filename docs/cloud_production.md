# Codex Cloud 商业 Demo 生产入口

本页只管理《失序之钟》的任务、验证与交接；产品和品质权威继续使用 [AGENTS](../AGENTS.md)、[当前状态](current_state.md)、[现有质量流程](development_quality.md)及[生产执行协议](quality/production_loop.md)。不新增一套验收状态机，不以技术通过代替玩家体验。该体系的首要产出是可评审的真实游戏变化，流程工作不能占据内容生产本身。

总控维护范围、依赖、共享接口、任务所有权、证据与集成；各生产线在隔离工作树中自主完成任务。Codex Cloud 会话不假定实时互通、自动唤醒或永久保留上下文，可靠交接通过源码分支、任务文件、PR和检查点完成。

## 本轮仓库审计要点

现有Harness已支持专项检查、隔离lane、同依赖复用、fresh发布与失败归档；质量系统已有任务、独审、租约和恢复协议。现有动作录屏是真实引擎电影模式，Web构建已有内容指纹、chunks和完整PCK验证，均优先复用。旧prepared试玩发布会替换整个正式Pages站点，因此不具备独立工作线隔离；独立托管解决这项缺口。原主题push与PR重复完整导出的问题由本轮CI分流处理，Release门槛保留。

历史 `docs/evidence` 约8.3GiB；本轮首次完整clone传输约2GB后真实early EOF失败，随后用sparse检出当前运行源及必要文档，保留失败记录。sparse仅减少本地历史下载，不删除仓库内容；引用历史证据时仍须取得并校验原件，不能把未下载当作无关或已经验证。

## 一条生产线的最短用法

1. 阅读当前状态，从最新 `origin/main` 创建 `feature/<task-id>-<topic>` 等独立分支／工作树；记录精确基线SHA。
2. 使用[工作线模板](templates/cloud_workline.md)写清玩家目标、完成条件、允许写集、共享文件所有者、接口依赖、开发模式及交付依据；任务ID沿用 `docs/tasks.md` 和现有质量记录，避免另建任务数据库。
3. 运行 `python3 tools/production_plan.py --stage development --base origin/main` 查看影响计划；确认额外动态依赖，执行时加 `--execute`。只允许增加检查或升级范围，不能为通过而缩减推导出的范围。
4. 自主实现、做最小相关验证，并按本页选择录像／Preview／工程报告；提交、推送并创建面向main的PR。交付链接只能来自实际文件或真实部署。
5. 用户直接评价画面、手感或趣味，原工作线针对反馈继续；总控核验接口和正式消费者后集成。生产线默认不合main。

Cloud稀疏工作区先用 `python3 tools/cloud_inputs.py --profile docs` 或所选 `--check` 输出缺件计划，需要时显式 `--materialize`；未知对象大小保留unknown，输入ready不代表测试通过。Harness隔离不再先检出全树，按实际已物化源保留精确index／sparse语义；细节与退出码见[Harness](harness.md#稀疏检出与选定输入预检)。历史证据先证明可恢复和真实消费者，再提出清理，不直接删旧媒体。

新工作线无需把简单反馈扩成冗长设计文档；影响方向、接口或生产阶段时才补足决策依据。已授权可逆工作继续执行，不为普通技术选择反复请求确认。

## 四种模式，按阶段切换

| 模式 | 适用 | 必须留下的审查依据 |
| --- | --- | --- |
| Fast Iteration | 局部动作、UI、VFX、音效、镜头、模块体验细节 | 一个可观察目标、相关检查、短片或可操作入口、下一轮具体反馈问题 |
| System Engineering | 动画／骨骼、统一受击、武器表现、UI组件、环境音频等共享系统 | 接口和生命周期约定→少量代表对象→真实正式消费者接入→逐步推广；接口改动先协调 |
| Long Production | 完整地区、家园、复杂Boss、视觉重制 | 阶段与里程碑、可恢复检查点、接口／美术／玩法方向的提前审查、当前可玩范围 |
| Creative Exploration | 风格、空间、Boss创意、新玩法机制 | 候选的实际游戏效果对比、选择或淘汰理由；技术可运行不自动获得推广许可 |

同一工作线可从Creative Exploration转System Engineering，再进入Long Production或Fast Iteration。长任务无需人为切成大量短任务；只需在难以逆转的方向选择、共享接口冻结和阶段升级前提供证据。

## 按验证需要选择最轻交付

| 实际评审需要 | 默认交付 |
| --- | --- |
| 无直接视觉或交互变化 | 工程报告：真实测试、适用的前后指标、失败／回归、SHA与PR、必要日志下载 |
| 观察即可判断局部变化 | 真实Godot短片，默认约10–30秒 |
| 必须亲自操作 | 独立真实Godot Web Preview，直达目标并可回完整游戏 |
| 既需观察细节又需操作 | 短片＋独立Preview |
| 长期制作到达里程碑 | 以当阶段审查需要组合上述证据，再附完成范围、问题、下一阶段与恢复点 |

交付选择依据是风险、人工评审需求和成本，不能仅看任务大小。共享输入／动作、AI／Boss、复杂机制、随机整区、家园／成长与UI交互通常需要操作；平台局部演出、受击死亡、攻击预警、粒子／光影通常先短片。用户要求实际操作时交付网页；工具推断不足时保守增加操作验证，并在任务合同注明理由。

录像必须由真实Godot运行生成，展示完整关键动作和真实音轨，不用静图拼接、概念演示或伪动画替代。尽量同Seed、同输入、同镜头、同分辨率和同运行条件录制before/after；任一差异须列明。基线无法运行时可只交after，明确缺失before，不能制造对照。软件GPU／离线fixed-fps录像不是实体设备帧率证明。

每份可视化交付只需简短写清：目标、实际变化、可下载视频／可打开Preview、主要检查、一个具体反馈问题、已知限制。用户未确认的审美、手感和趣味性保持未验；AI不得代签。连续两轮同一方向无实质改善时沿原流程RETHINK，工程故障和创意失败分别记录。

## 文件、媒体与来源

源码仍在 `zhipijun1996/gunman-rush`。正式试玩继续使用既有Pages入口；独立开发Preview使用专用 `zhipijun1996/gunman-rush-previews` 托管仓库，不调用会整站替换正式Pages的旧部署入口。

Preview绑定任务ID、PR（创建前可暂空）、源码SHA、构建ID、Seed及目标入口。每线／每PR独立路径；更新保留必要历史，已有SHA路径不可用新包覆盖。页面明确标记开发版，保留返回完整游戏的入口；直达场景必须来自真实导出，不以旧网页承载本轮新成果。发布后实际打开入口，并核对公网 `build-info.json` 和完整PCK字节／SHA；HTTP 200或排队不能代表可玩。

同一GitHub Pages域名的不同仓库仍可能共享浏览器origin。存档、Service Worker与缓存隔离须按真实导出行为检查，不能只按仓库名推断。本轮独立Preview的bootstrap禁用meta持久化，返回菜单的新DemoApp也继续禁用；不能据此签成长存档或持久化流程。已验证范围与未验证设备／存档边界在交付中单列。

短片默认可通过Actions Artifact交付：记录实际artifact归档链接、文件名、有效期和登录要求。需公开稳定分享时上传实际MP4到GitHub prerelease资产或合适静态托管，给文件下载URL；源码／构建来源保存在同一交付收据中。不得只给本地路径、仅给workflow列表页，或拼出未经访问核验的地址。删除／过期后链接须明确失效，不保持假“可下载”。

Web大PCK沿已有内容寻址chunks传输，并在托管端恢复、核对完整SHA。托管有容量预算，达到上限时明确阻塞；不自动删仍活跃工作线，不无限复制历史。退役Preview须保留可追溯收据和必要归档；日后可迁对象存储，无需提前引入付费平台。

## 三层验证与CI

`tools/production_plan.py`负责解释影响与选择，原 `tools/harness.py`负责执行、超时、错误检测、日志和证据。命令、断言、预算和完整发布守门继续由原Harness权威维护。检查选择映射不是依赖证明，动态加载／共享参数／未知范围必须保守升级。

| 阶段 | 执行依据 | 可声明范围 |
| --- | --- | --- |
| Development | docs每轮一次＋确定受影响的专项、必要导入／解析／构建检查 | 本轮开发专项；不能称完整回归或发布通过 |
| Integration | 受影响系统的完整专项＋共享接口／信号／资源＋正式消费者；未知范围完整检查 | 明确列出的集成范围 |
| Release | 保留原完整CI、GPU／音频、Windows／Web导出、浏览器与公开部署验证 | 只按实际完成门槛声明；用户／设备认可仍分开 |

```sh
python3 tools/production_plan.py --stage development --base origin/main
python3 tools/production_plan.py --stage development --base origin/main --execute
python3 tools/production_plan.py --stage integration --base origin/main --execute
python3 tools/production_plan.py --stage release --base origin/main
```

Release在该规划器中仅计划，`--stage release --execute`明确拒绝；实际执行原 `tools/deliver.py`／精确SHA正式CI。不得把局部 `--check` 或仅完整profile改称所有发布条件已满足。`--plan`不是执行；未执行、失败和超时保留原状态。缓存只复用同依赖证明并标原来源，fresh发布继续 `--release`。

CI分流采用本地Development、PR自动Integration、手动Development／Integration；主题分支push和已测draft转ready不重复触发昂贵完整CI。PR以sparse检出、原preflight按需补件和两隔离lane执行，Foundry准备后重plan并补齐可能升级的输入，serial仍按原顺序执行。main及手动原Godot core保留完整Release；实际运行状态以workflow和本轮证据为准。避免同一SHA由多个生产会话重复发起完整CI；总控记录已冻结源的唯一正式运行。不能因为一个大资产任务改文件多就全量，也不能因为一个小共享参数改动文件少就局部。

## 并行所有权与合入

每任务写集包含脚本、运行场景、Definition、纹理／atlas、UID、导入设置、公共配置和生成产物。两个生产会话不可无协调修改同一资源；共享文件由一个明确所有者负责，其他线提交接口需求。跨线前置接口必要时单独PR，消费者基于已合入SHA继续。场景按现有架构自然拆为逻辑、表现和独立组件，不为并行强行重构。

独立工作树隔离 `.godot`、导入、输出与user数据；原Harness隔离lane继续复用。共享工作树的引擎／导入／导出仍由单一租约持有。冻结录像／构建期间禁止修改其源，漂移则失败，不能用旧绿换签新源码。

总控合入前检查的不只有Git冲突：场景／资源引用、UID与导入、接口／信号、参数和Definition唯一来源、玩法／存档兼容、Seed／Manifest，以及真实正式消费者回归。按main更新后重新评估影响，记录冲突解决；无文本冲突不等于可安全集成。使用普通PR和既有守门，不强推、不回写历史证据、不让生产线自行合main。

## 长线检查点与反馈

检查点复用[现有生产协议](quality/production_loop.md)，记录任务版本、分支／源码SHA、适用权威版本、阶段、已完成范围、下个动作、可运行命令、证据／失败位置、依赖与写集所有者。规格或外部源变化后新建证据目录并重验依赖，不能修改旧失败或刷新Hash恢复旧通过。

里程碑只要求足够决定下一阶段：真实可玩版本或必要录像、关键视听／功能证据、最小检查、已知问题、下一阶段及恢复点。不是每次编辑都导全站。用户一句“反冲太僵硬”可直接触发原线修订：保留原反馈和版本→针对原因修改→同条件新对比／同线新Preview→说明变化与剩余问题。

## 建议首批独立工作线与Prompt

本轮优先顺序为生产基础→主角表现→普通怪物反馈→平原黄金切片→森林→通用视听／UI／家园→后期区域→完整Demo打磨；有清楚依赖和写集边界即可并行。已选地区Bible、共享像素母版及BGM资源来源仍从AGENTS读取，新的明确用户选择优先。

本次用户已指定当前会话为总控，并授权先提效合main后启动并行；可直接执行的首批三个Prompt、正式消费者与共享母版依赖、精确写集见[本批调度合同](demo_wave_01.md)。各线在实际merge SHA启动，旧建议表不代替本批所有权。

| 工作线／模式 | 依赖与写集边界 | 可直接使用的简短Prompt |
| --- | --- | --- |
| PLAYER-PRESENTATION／System Engineering | 主角表现脚本、动画资源与锚点；不改Motor、物理、资源和授予 | 从最新main按工作线模板建立任务。先审计正式主角事件／锚点，以一个移动中射击和受击／死亡样板完成分层动作接口与真实消费者验证；同条件短片＋可操作Preview，用户认可方向后再推广其余动作。 |
| ENEMY-FEEDBACK／System Engineering | 普通敌人反馈组件与代表资源；公共接口与主角线先协调 | 为普通怪物建立可配置命中、受击、死亡及材质反馈。先接入体型／材质不同的两种正式敌人，复用共同生命周期而保留各自动作；不让每个Creator再造反馈系统。交付带真实声音对比和战斗Preview。 |
| REGION-PLAINS-GOLDEN／Creative Exploration→Long Production | 等共享反馈接口稳定；平原独占模块／表现资源 | 按风铃平原Bible制作商业品质黄金切片。先用真实游戏比较少量构图与战斗节奏候选，明确取舍；用户确认后扩展，统一母版但保留地区特色。保留完整冒险／奖励／死亡回家再开局路径。 |
| REGION-FOREST／Long Production | 已选森林Bible、当前正式资源家族；模块／生态／Boss分阶段 | 按完整森林Bible和共享母版继续荆棘森林，保留当前可玩内容与失败证据。先选择一处钩索空间黄金样板，验证普通解、奖励、返程及随机结构，再按里程碑扩展整区；不得以Hash／几何连通签趣味。 |
| ENV-AUDIO／System Engineering | 事件、资源管理、生命周期、动态混音；不改无关区域玩法 | 审计并复用当前音效／环境动画基础，为两个正式地区代表消费者建立可配置事件、voice生命周期和混音规范。交付真实连续音画与环境操作Preview；BGM资源按用户当前选择处理，不擅自生成替换。 |
| UI-HOME／System Engineering→Long Production | UI组件／交互先行；家园成长存档接口需单独协调 | 统一HUD、菜单和家园交互，先验证一个组件与一条真实成长流程，覆盖鼠标、DOM触屏和手柄输入边界。交付直达目标且可返回完整游戏的Preview；实体设备与玩家评价单列。 |
| LATE-REGION／Creative Exploration | 前述动作／能力接口稳定，先补完整区域Bible | 为世界钟心等后期全能力区域做可操作预制作，展示合法全部能力的组合空间。缺Bible先提案和候选对比，不直接批量造正式内容；方向确认后转长线制作。 |

可并行的前提是写集和接口不冲突；共享系统先代表对象实机验证，再推广。每个Prompt都沿同一模板和质量记录执行，无需复制整份规范。

## 本轮验证证据

本轮两条路径已按[实际交付原件](evidence/cloud_production_01/README.md)验证：真实MP4、独立Godot Web、完整公开字节与GUI、main并存均有精确来源；完整docs／Release及玩家／真机仍单列。本轮 `tools/capture_slice.py` 是一个固定样例：同源、同动作的开发banner关闭／开启各12秒，检验真实Godot短片对照和文件交付；它不是通用输入录制器、两个历史commit的前后对照或玩法改善证据。其他内容任务按范围复用原 `capture_actions.py`／`visual_director.py capture` 等真实消费者，另写符合任务的driver，不能把本样例的运行签给其他动作。

```sh
python3 tools/capture_slice.py --output build/verification/cloud-slice-<fresh-id> --task CLOUD-PRODUCTION-01 --seed cloud-review-01
```

输出目录须为新目录；生成本地文件后仍需上传实际MP4并核验下载URL，不能把本地路径当作交付完成。

## 实际工具与后续提效

```sh
python3 tools/cloud_delivery.py select --kind local_animation
python3 tools/cloud_delivery.py select --kind ui --long-task
python3 tools/cloud_delivery.py stage-preview --bundle build/web --host-root ../gunman-rush-previews --task TASK-ID --seed review-01 --entry actions
python3 tools/cloud_delivery.py stage-preview --bundle build/web --host-root ../gunman-rush-previews --task TASK-ID --seed review-01 --entry scene --scene res://scenes/dev/consumer_test.tscn
python3 tools/cloud_delivery.py stage-media --capture-dir build/verification/cloud-slice-FRESH --host-root ../gunman-rush-previews --task TASK-ID
```

`--kind`自动选择验证形式，显式观察／操作需求只追加，不降低默认要求；长线只追加里程碑。`--entry scene`要求已导出的自包含测试场景，工具核真实PCK，调用者仍须运行实际消费者。默认menu/actions和直接DemoApp均在入树前禁main meta；自定义场景的其他持久化由其合同约束，不能当成任意脚本的文件系统沙箱。

两种stage命令只暂存；在独立host提交推送后，唯一Pages工作流核PCK／媒体inventory及900MiB上限，再部署。实际访问／下载核验后才报成功。`stage-media`提供稳定静态下载作为Release上传受限时的正式可用路径。初次建立host需仓库创建及Pages启用权限；已建立后不重复请求。

本轮新增两项Python检查接入原profile，真实preview生命周期接入gameplay/art/full；原158检查定义及原profile前缀不变。当前稀疏工作区与新CI用jobs1，避免现有隔离clone偷偷物化全树；Release原分机lane不变。完整数据与下一批三个工程Prompt见[提效审计](cloud_efficiency_audit.md)。
