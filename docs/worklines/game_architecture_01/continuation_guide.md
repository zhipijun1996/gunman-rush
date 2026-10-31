## 本页暂停状态已由后继执行更新

2026-10-31已继续工作。R3六文件共享消费者迁移已由760e同源原完整Harness实际通过：313/16/65及两图4954/5053全0。下一步是审计索引冻结、同源full185与导出；不能把本单项签成full185。最新提交、当前租约和命令以[当前状态](../../current_state.md)及[交接](../../handoff.md)顶部为准，细节见[R3独立测试合同迁移](r3_current_content_contract_01.md)。下方暂停源/构建状态仅为原始历史，不要重复构建已发布安装的固定工具链。

# 换模型交接：后续重构与验证指导

## 最新暂停节点（2026-10-31，6.1sol阶段）

用户已再次要求暂停。两实现提交为dce43112（消费者/CI）和61c4fac9（RootBell独立原缺陷修复）；后继仅本暂停证据与交接。当前工具链已是固定上游修复版，完整构建/发布/安装已完成；下方旧“工具链未切换/编译仍在跑”已过时，不要重做。

**重构代码已经落地，完整验收仍被R3阻断。** 精确main原有同一跳跃失败；现有正式自动策略也实际死亡。新的低台策略只双静态独审、未编译/未原生，未应用主树，不能签成功。不得修改玩法/物理、删原断言或扩大预算来换绿。

恢复先读[本轮完整操作指导](../../evidence/game_architecture_02/pause-checkpoint-05/README.md)与[精确清单](../../evidence/game_architecture_02/pause-checkpoint-05/index.json)，再核Git干净、实际HEAD、唯一引擎租约和磁盘。候选patch/两源原件与候选/两独审/索引生成器及其依赖均已在该目录保存，后续不依赖仅存在于旧模型记忆的路径。

尚余：一次限定平台诊断及R3契约处理；更新实际全文件/调用图索引；同一冻结提交fresh完整185；最终Windows/Web/Android/PCK、三个浏览器消费者、原生连续原声影片和公开PCK。未创建PR、未合main、未部署新游戏；新地图统一接口已完成，新库和算法仍后续。

---

> 已于同日按用户要求恢复工作；本页保留暂停快照，最新执行结果与优先级见 `docs/current_state.md`、`docs/handoff.md` 顶部及独立音频修复说明。

记录时间：2026-10-31 UTC。用户要求“到某个节点先暂停，我要换模型”，因此本地工作在诊断检查结束后暂停。**没有完成全部重构验收，没有切换正式工具链，没有合并或发布本重构。** 远端引擎编译继续运行，接手先读取实际结果，不要重新启动同一构建。

## 1. 先恢复这些事实

| 对象 | 精确状态 |
| --- | --- |
| 工作区 | `/workspace/gunman-rush-refactor`，分支 `refactor/game-architecture-02` |
| 暂停前已验证源码提交 | `05c3e3dba43f3fc9283aa74198a9bf0d04d99bfb`；本指导及暂停证据作为后继文档提交，实际 HEAD 用 Git 核实 |
| 生产 GDScript 最近整合源 | `063d6ccbd7a6ab659fd27abcb20a5c59c7308c53`；之后为路径、技术绑定、工具/测试消费者及文档修复 |
| 内容基线 main | `2ce4ffa64ef65dd5fba892776eea019c9e2841d4`，包含 PR122/124/125/107；PR123 关闭、未合入、排除 |
| 已核公开网页 | `55b07609ea756c6faee771aaa84f080b249917fe`，不是本重构候选 |
| 原用户工作树 | `/workspace/gunman-rush` 有原改动，未动；不可 reset/clean/覆盖 |
| 工具链候选树 | `/workspace/gunman-rush-toolchain`，本地 `fix/godot-shutdown-toolchain-01` 在 `63afcb1ba43c7d16c85745478cd3617037f20848` |
| 远端正在构建的树 | `/workspace/gunman-rush-engine-retry`，本地 `fix/godot-shutdown-build-retry-01` 在 `184970c7fff5baa6842efb8f34339ce87fff5bfd` |
| 远端构建分支 | `fix/godot-shutdown-toolchain-01` 指向 **184970c7**，与同名本地分支有意不同；不要直接推本地 63af 整条分支 |
| 工具链当前选择 | 主工作树 `config/toolchain.json` 仍为官方 Godot 4.7.2；新安装器尚未接入，不能只装半套 |
| 剩余磁盘 | 暂停前约 3.9 GiB；先核容量，再下载大产物 |

恢复命令：

```bash
cd /workspace/gunman-rush-refactor
git status --short --branch
git rev-parse HEAD
git worktree list
ps -eo pid,ppid,etime,args | rg 'godot|harness.py|foundry.py|run_candidate|entry-startup|audio-entry-interaction'
gh api repos/zhipijun1996/gunman-rush/actions/runs/41180438395 --jq '{status,conclusion,head_sha,html_url}'
df -h /workspace
```

本地诊断进程和代理持续监测均已结束。后续执行仍由 root 协调唯一的本地 Godot 租约；不同云 runner 可以各自隔离执行。不要重新并发启动多个本地引擎。

## 2. 用户目标及不可改变的边界

用户已授权从“只审计”进入分批大规模重构，要求**先设计合理职责，再迁移真实调用者**，不只搬目录。允许 subagent 并行，但须明确写集和接口所有者。用户最新明确选择固定上游修复版工具链，无须再次询问是否采用。

- 保留玩家物理、碰撞、伤害、消耗、奖励、随机调用和存档/Manifest 格式；不生成或擅换正式图声。
- 既有 Definition、ItemCatalog/authoring、EnemyBehaviorRegistry、avatars、音频 selected 配置仍是权威；不再造平行注册表、全局服务定位器或万能事件总线。
- 地图先统一接口，之后接同一个新模块库与新算法；现有生成器是过渡实现，**不采用 PR123 的接法**。怪物、箱子等实例化仍需工厂、位置/稳定 ID、状态恢复与生命周期绑定，不能仅复制场景就视为迁移完成。
- 旧版本删除前核真实消费者、回放、实验、许可和证据；不可因文件旧就删入口或破坏历史回放。
- 原有缺陷和内容升级单列，不混入“行为不变”。原失败、断言、检查集合和预算保留，不能为了绿灯删测试或提高超时。
- 新重构 PR 默认不自动合 main；旧 PR 合入授权已经完成。可玩预览交付已有授权，但必须满足实际门槛，不能以旧网页冒充候选。

先读本文件，再按需要读 [目标架构](target_architecture.md)、[迁移报告](migration_report.md)、[执行记录](execution.md)、根 AGENTS.md 和当前状态。项目 integration、quality-gate、gameplay-reviewer 技能已使用；换模型应按仓库规则读取相关技能，不默认加载全部历史文档。

## 3. 已完成哪些结构和调用改造

1,124 文件已按功能迁移到 `game/{application,player,combat,loadout,economy,rewards,progression,enemies,bosses,world,presentation,platform}` 与 `experiments/`，491 UID 保留。协议身份和历史输入刻意保留旧路径，不维护两套运行实现。

- App → RunSession/RunComposition 拥有原 Director、Lifetime、Wallet、Build；窄依赖显式注入，run/stage/actor epoch 语义保留。
- 地图 Request → Provider → 原生成器/版本验证 → LegacyRegionPlanAdapter → Plan。**App 配置 Stage；Stage 调 LevelRuntime；Runtime 调 Assembler/工厂**。裸 Plan 已能装配，旧 Stage 的表现与记录仍依赖 Manifest 适配，不能承诺任意新生成器零适配。
- Inventory 拥有库存事务，Wallet 拥有余额，Shop 四操作共用收据；两个主动效果族共用施放流程，Time 使用窄上下文。
- 三个 Stage/App 共用实体快照/恢复；Boss 自身拥有生命快照和森林决斗恢复校验。Bell 两种弹体全部五处调用共用 epoch 准入；Pressure 的不同策略保留。
- 生产 AudioLifecycle 已由实际宿主消费；菜单输入、矩形危险物、角色顶点纯函数也有真实共用调用者。
- 17 组旧生成算法重复涉及历史回放，不能机械折叠；不同 RNG、奖励和 Boss 策略也不强行合并。
- CI 继续使用原 Harness/profiles/影响选择，收敛跨 job 重复并补 `game/experiments` 输入守门。完整集合是 **182 = 95 parallel + 87 serial**，原 172 前缀和预算保留。

全文件职责和依赖见 `file_inventory.csv`、`runtime_inventory.json`、`dependency_graph.json`。目前索引源是 **6f743953**（33,051 路径、1,554 runtime 文件、35 入口、3,447 静态边、118 动态未解析点）；不是最终 05/新工具链之后的索引。最终再用外部 `persist-main-layout-report.py` 更新三份生成索引，保护人工报告，不造第二运行注册表。

## 4. 已有证据，勿重复或扩大声明

暂停证据与原日志：[索引](../../evidence/game_architecture_02/pause-checkpoint-04/index.json)。所有诊断使用 O0 构建 C，**不是正式优化构建验收**。

| 验证 | 实际结果与范围 |
| --- | --- |
| 当前 docs33 | 全部 fresh/pass，318.136 秒；报告 `build/verification/harness/20261031T072149.039640Z/report.json`，在 precommit 工作树执行；独审已将 46 个已审文件 SHA 精确绑定到 05c3 |
| 当前质量 diff | 2,348 文件通过；旧导航、fixture、字符串伪造等失败均在 static-closeout-03 保留 |
| release evidence 路径检查 | 05c3 提交通过；仅提交树证据路径完整，不是玩法验收 |
| 35 入口 + 3 正式模式启动 | 38/38、原日志无加载/退出错误，source_unchanged=true，独审限定接受；Foundry 只有 UI、无 Player，不能签就绪 |
| AudioDirectorLab 原脚本 | 25/0，23.253 秒，严格退出干净 |
| AudioDirectorV2 原脚本 | 66/0，76.276 秒，严格退出干净 |
| AudioDirectorReels 原脚本 | **126 条、3 失败、退出 1**，116.009 秒；不是超时，不得记通过 |
| 先前官方原生专项 | 063 后 Bell/Pressure/forest-depth-restore/core/Blob47/Windchime/Pixel/Style/Cloud/player-default/studio 共 11 个检查最终通过；分批源与失败保留 |
| 全量与发布 | **完整182、最终 Foundry、实际新 PCK/GUI/Windows/Android 导出均未完成** |

新发现的 Reels 失败必须优先定位：

```text
enemy_hurt A actually plays exactly one candidate for each accepted target
enemy_hurt B actually plays exactly one candidate for each accepted target
enemy_hurt C actually plays exactly one candidate for each accepted target
```

日志位于暂停证据下 `audio-entry-interaction-diagnostic-C-01/3.log`，receipt 与 report 同存；原件在 `/workspace/refactor-evidence/audio-entry-interaction-diagnostic-C-01/`。尚未二分或在基线复现，**不知是原缺陷、重构回归还是特定构建相关问题**。先读日志、原 `tests/audio_director_reels.gd` 与真实事件消费者，再做同源/基线对照；不能先改播放计数断言。两个通过的音频实验也只覆盖有限脚本操作，不签听感。

## 5. 固定引擎：现状与下一步

官方 4.7.2 源 `ed1daf0bf001b61586d9930840f2f1394092c079` 的 formal191 行为通过，但退出泄漏 57 ObjectDB/25 resources。相同 4,186 个运行文件下：A 原源码和 B 仅 PR117991 都失败；C 加 PR117991 + PR120976 后 formal191/0 且严格退出干净。PR120976 影响 await 取消、脚本/实例销毁、PREDELETE/hot reload，不能只按 quit 补丁看待。

诊断 C：`/workspace/engine-diagnostics/godot-4.7.2-standard-shutdown-c`，SHA256 `c54ecbeb70aa099d3e985b6e3098b84540491c567578b0dce838ca0922f33311`。显示标签仍为 `gdscript117991_ab`，实际两补丁由源码/二进制 SHA 绑定；禁止把它交付成优化引擎。

正式配方 `config/godot_build.json` 位于工具链树，版本应为 `4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf`。固定 source/patch/SDK/container/构建参数，production=yes、optimize=speed。10 个 lane 输出 Linux editor/templates、Windows x86_64、Web 四模板、Android arm64；不混入未修补官方模板。

当前构建：[41180438395](https://github.com/zhipijun1996/gunman-rush/actions/runs/41180438395)，源 **184970c7**。暂停时 plan 和 Windows debug 成功；Linux editor/debug、Web threaded debug、Android 在构建；其余 5 lane 排队。接手必须查新状态，不能使用此快照代替最终结果。

旧 run `41178076878` 已取消：Windows/Web debug 成功，Android 两份 native 库完成后 Gradle 缺 `scons` CLI 失败。新 run 仅补固定 wheel 的受控 CLI wrapper，独审/8 个构建契约测试通过；必须实测 APK。**旧 run 成功产物不可混入新 run 打包。** 原 checkout 阻塞 run `41177767546` 也保留。

激活顺序详见暂停证据中的 `engine-184-activation-review.md`：

1. 确认同一 run 的全部 10 lane 和 package 成功。取得实际 artifact ID、摘要、provenance 和完整产物；只看到编译成功不够。
2. 用既有 `tools/engine/package.py` 对同 run 产物复验/重打包，要求 recipe commit=184970c7、run=41180438395；比对远端 candidate 的 8 个文件、ZIP/TPZ 全成员和日志 SHA。先计划磁盘，已验证的重复下载缓存可按收据清理，不能删失败证据。
3. 发布一次性的工具链 Release `toolchain-godot-4.7.2-gunman-sd1`，固定标签目标 184970c7；暂停时标签 404，恢复先查。不得覆盖已有不同字节。通过最终公开 URL 完整重新下载并核 SHA；不能用临时 Actions URL 作安装地址。
4. 将真实 `godot-lock-candidate.json` 替换主树 config 的 **godot 对象**，保其他 Android/Windows/git/python 配置；与 builder、两个 patch、已审安装器和消费者**一起**接入。没有真实完整 lock 前禁止只合 wrapper 或放占位 SHA。
5. 安装器改动提交：`3a3062b0` + `3faa72d3` + `62eceec4`；后者修共享 level receipt 的 custom build 解析。`63afcb1b` 是 Android CLI 修复，远端 184 是它基于 390 的单独 cherry-pick。已做 05 与本地63的 merge-tree 预检，无冲突；实际接入仍核最终差异。保留源提交，不要误推同名本地分支覆盖远端。
6. 原官方控制二进制/已安装模板保留。新 `godot_identity.py` 是统一身份入口，校验实际 binary SHA/精确版本/source/provenance/templates，路径按 build_id 隔离；GODOT_BIN 不应绕过。原官方模板压缩下载缓存已按 SHA 删除，安装本体还在。

安装器 62 有限定独审（25 个组合测试、SparseIsolation6、crosslane1、receipt3），Android CLI 新测试令组合变为26；必须在最终完整主树重跑。稀疏工具链树的 Harness91 曾因缺历史输入有22失败，不能称完整通过；主树此前原91通过，接入后再跑。

## 6. 引擎到位后的执行顺序

不要再扩大成一轮新的全仓设计或搬迁。先收敛实际失败，再按冻结源验证：

1. 复核/定位上述 Reels 三失败。修复若涉及生产行为，单列范围及基线对照；保原测试与失败，并更新相应技术 source-binding，不能刷新历史 SHA 掩盖变更。
2. 接入真实工具链后运行既有 downloader/身份测试、`python3 tests/test_harness.py` 原91和环境检查。引擎生命周期独立夹具在 `/workspace/refactor-evidence/engine-lifecycle-candidate`：用最终 binary 和 SHA 执行 `run_candidate.py --label fixed --binary ... --expected-sha256 ...`；另跑原4条强引用负例。
3. 生命周期最终夹具28条有明确修订历史：原26条中3个“编译脚本必须立即销毁”假设在官方和C都失败。已独审改为相对空编译脚本基线无额外引用，另2控制；保留全部原失败。C28/0+负例4/0通过，官方同文件在PREDELETE退出崩溃。优化版仍未验，不可删旧失败或虚称原26等价通过。
4. 原 Foundry 前处理必须用最终引擎真实执行：

```bash
python3 tools/foundry.py build --count 24 --promote
bash tools/godot.sh --headless --path . --script tools/foundry_export_stamp.gd
```

审查原36模块/路线与 tracked 生成数据差异，保原回放；不得手写 basis/SHA。原 import120秒、每 profile300秒预算不改。

5. 最终源完整182必须 fresh。沿现有协议：本地 `python3 tools/harness.py --profile full --release --jobs 1`，或已提交候选 PR 的现有 Production impact 双 runner `--lane parallel|serial` 再 `--verify-lanes`。PR 草稿可触发原自动 Integration；不得把单 lane/定向通过当全部。完整输入已在主树 materialize，约4.34GB，恢复先查缺件，别无故重下。
6. 原入口补充命令在暂停证据 `optimized-engine-entry-interaction-plan.md/json`。优先复用 full182 已覆盖的检查，不重复调用相同 wrapper。补 Director 三套、Home/Ambience service、Foundry lab/touch/feedback、Motion/Landing/Weapon 四套及 Forest golden。原 runner 覆盖不到的 Graybox RESET、旧 Boss8 review、音频 Lab 全 UI 等必须真实检查或明确未验证。
7. 实际 Web/Windows 导出；Android 保原应用 SDK/API 配置做实际导出，不因引擎 NDK29/API36 构建而默改应用原 NDK28/API35。检查模板完整性和实际耗时，不调宽旧预算。
8. 实际 PCK 在**空目录**用新引擎 `--main-pack <pck> --script <绝对tools/check_recorded_enemy_pack.gd>` 检查历史 raw Definition/remap/工厂及当前资源，不允许源码 fallback。v11 源 SHA `1afd5e34d497e3850d794b028fd5fe5407d3722fcd451d862f4c14a67ca98fc0`，旧碰撞28×32；当前28×28。配置排除规则不能代签实际包内容和许可。
9. 用实际导出跑真实浏览器入口、操作与错误检查；既有 Playwright/browser 脚本可用。完成后才交付可玩预览，核公开提交、build id、完整PCK SHA。源码合并、上传成功、旧网页能打开都不等于候选已发布。
10. 最终更新三份索引、依赖图、批次状态/验证/回退、质量记录与 handoff，独审后提交/推送可审 PR。当前 refactor 分支尚未推送；不要默认合新 PR。

## 7. 剩余架构方向和独立问题

下一轮实质架构优化应由真实需求推动：App 的跨区流程/实验导航、Stage 的 Manifest 表现适配仍是集中点。新地图实现应消费统一 Plan/Runtime/工厂，并迁移真正调用者；不得在新模块库另开一套钱包、伤害、掉落或怪物构造。当前目标是把这批重构验证收口，再接新模块库，不能边验证边无界重写。

独立问题保留：四个 Lab 的 Courier 旧外观遗漏装配；Graybox RESET/旧 Boss8 review 的历史假设；能量初始化失败回滚、Inventory patch 后效果拒绝、同帧音频 stop 的既有局限；以及本暂停点新发现的 Reels 3失败。没有用户或实测依据，不把它们“顺手修正”为行为等价。

## 8. 必须保留的工作区材料

- `/workspace/refactor-evidence/`：所有独审/失败/计划、当前入口原日志、安装器拒绝探针、source绑定。暂停精选已入仓，其余不是可随意清理的缓存。
- `/workspace/engine-diagnostics/`：官方 source tar、两个补丁、A/B/C 二进制和同源对照、原失败；只有可再生 compiler `.o/.a` 已按收据回收。
- `/workspace/refactor-evidence/retained-inactive-worktrees/`：已移除干净工作树的 ignored 失败/构建材料；不要误以为对应旧工作树仍存在。
- 本仓 Git `maintenance.auto=false`、`gc.auto=0`；不要接手即运行全仓 cleanup/GC。
- 质量记录候选若保存于 `/workspace/refactor-evidence/engine-quality-candidate/`，它仍是草稿，未激活/未签实际产物；先读其状态再采用。

恢复模型可从“查询41180438395 → 定位Reels3失败 → 核完整产物 → 原子接入真实工具链 → 冻结并完整验证”开始。用户暂停期间不再执行新重构；本指导是下一次继续的入口，不是完成声明。
