# 最新交接：探索场所原型 v18

## 2026-10-22 Cloud生产与交付（最新）

分支 `chore/cloud-production-system`，运行源 `6ca72efb1cbdb38cf83ae91c097d192a35403ccd`，未合main。四模式、交付选择、独立托管、影响选择和工作线模板见[生产入口](cloud_production.md)；[真实交付及失败](evidence/cloud_production_01/README.md)包含MP4／Preview和公开全字节／真实GUI。主站build-info前后同一703f9b040e5f/source9c349f44；新开发站独立，没有替换main。

原158检查及profile前缀保留，新增14/30/25专项fresh通过，独审技术ACCEPT；本地完整docs因稀疏缺旧证据实际失败，未追认为通过。完整集成／Release及用户／真机仍未验。PR自动Integration，本地Development，main／手动原完整Release；默认不合main。

[提效审计](cloud_efficiency_audit.md)：历史证据8392.57MiB，占93.7%；同blob工作树冗余660.50MiB已在Git对象去重。先做partial+sparse必要输入预检、稀疏隔离修复与可恢复冷归档试点；不批量删除当前历史依据。

恢复命令：`python3 tools/production_plan.py --base origin/main --stage integration --plan`；当前稀疏工作区先jobs1，补齐原检查实际依赖再执行。源码与包来源分开，不能把文档后续提交冒称新游戏构建。


## 当前主线收口（最新覆盖）

2026-10-22已按用户明确要求通过PR102合main，合并SHA `9c349f44caa7e230b7784a340a839906cac58d0e`，PR101已merged，本地当前分支main且与远端一致。原93个开发head和新integration全部已含；5旧art head原祖先保留、当前树未切旧画风；15playtest＋1deploy产物不入源码，未删除旧分支。[盘点／独审／真实合入／源等价／docs29原件](evidence/main_closeout_20261022/README.md)。后续从最新origin/main独立分支／worktree直接提PR到main，勿继续串旧实验分支。

基线767627f8完整CI已成功，新main CI39741355698／docs39741355652自动执行中，不能混作同一次fresh。后续纯文档提交保存回执，运行文件与合并提交完全不变。公开仍e361原型source263afd；main自动发布另核实际PCK。森林ART_REWORK／拓扑／模块库／真人计时／设备及平原未完成，不因Git收口升通过。下列原“未合main”及分支名为历史交接。


2026-10-22，分支 `feature/region-bible-v2-forest`，草稿 [PR101](https://github.com/zhipijun1996/gunman-rush/pull/101) 未合 main。准确提交以 Git 为准。公开已更新为[探索原型 e361](current_state.md#当前公开试玩)，入口FOREST PLACES MAP 1/2，普通THORN_FOREST保留旧v15。

## 已实现和边界

用户已选每图正常8–12分钟、充分探索15–20分钟作为初步真人目标；没有真人计时，不能用原生帧数换算。v18 新显式 FOREST PLACES 入口保留 v15 核心／早段休整根／HH和螺旋技巧线，加入双窗、7型高枝回落、Z内外折返、倒木上下路，图二另有固定果 H＋反向射击背枝。真正root Seed改变Z／倒木顺序，两图反排；Boss完整factory后移到最终出口。真实奖励为金币或音符二选一且幂等，没有清空支线开门锁。

当前仍是带多处分流汇流的场所链，非充分网状森林，也不是完整模块库。活果渡口未实现；固定果不冒称活目标。森林含美术优先，平原仍planned；BGM未生成或替换。普通森林 default15 与历史producer保留，没有修改Motor／物理／资源／能力／保存。

## 实际失败与继续点

原33项在600秒超时，29项完成不能追认为整轮通过。App04独审拒绝Fallen巨L；18.3真实西根外弯、东根凹窝及心木底面已改，App05八张源稳定且独审确认有实质改善，只允许继续候选通行验证，未签ART。Z的细悬臂／倒L、Back浮空平楔／通屏夹层、倒木长地板和木质识别仍待定稿。两条失败材质方向完整归档，未进入runtime。不能再用纹理、更多变体或测试计数覆盖构图失败，不能把原型覆盖旧公开包。

新开发反馈分成 `python3 tools/harness.py --profile forest-places-feedback --release --jobs 1`（core20）和 `--profile forest-library-feedback`（library16）。根据改动选，不每次部署整套；保90import/240native/600whole、fixed60、串行引擎和严格非空／完整输入／完整脚／OR结算守卫。旧80/full/CI未改，本轮没有重签完整CI。

精选原始源码、全轨迹、失败、静图、独审和每成员完整SHA在[证据索引](evidence/forest_variety_04/README.md)；当前质量状态见[记录](quality/records/FOREST-VARIETY-04.json)。新浏览器 `--forest-places` 只实际OCR点击候选入口并校验组装18，默认四入口不变；只验GUI，不签奖励／手感。

## 操作与存储

root唯一Godot/import/GPU/browser租约；运行源与Git冻结期间禁止并行写生产。只用 `bash tools/godot.sh` / Godot4.7.2 Standard。不动 `/workspace/gunman-rush-ci-H`、原始附件、`.git/.godot` 或历史失败。audit SHA保持 `c47e366e9fbc1e3584a7c7e3eb8b983422156e21eb420a34456a2d8eb7219791`。

先 `df -h /workspace /tmp`。旧564份大JSON以完整字节/SHA读回验证后可逆存于 `build/storage-preservation-20261022/large-json-lossless.zip`，旁有RESTORE-INDEX.json；旧平原run_vs12o4rc原件同目录lossless.zip和RESTORE-INDEX.json。不是删除不可恢复证据。运行时快照仅复制实际源与必要资产，不复制海量历史build。

合入/完整交付另跑适用原profile。新试玩按已有快速流程复用同源已验包或仅Web重建和必要检查；当前艺术未过，不以新原型替换旧公开包。完成更多有趣机制与网状拓扑后再验人类时长、手感、手机性能和玩家认可。

本轮最终新库16项inner／outer均exit0，334.075秒；新倒木之后两图正式主路线分别55.099／79.963秒通过，整轮135.791秒，源稳定。不是fresh完整core20、原80或fullCI。静图是明确摆位fixture，不作自然游玩／动态证据。

文档／流程29项fresh通过；具体证据路径已普通Git归档。PR实际base仍7be8c340372d1e20db6685cbd6a559191821eb0e，需保持差异与commit-tree证据闭包检查。

首次Web构建真实失败：旧Foundry池的basis包含整个generation目录，新增区域脚本使其失配。已用原工具实际重新验证36短语／18连续路线与回放，只更新开发池JSON／export stamp；没有直接换SHA或改guard，森林几何／动作／参数字节未动。第一次失败保留，Web重试结果另记。

Web06导出与PCK检查通过，但实际候选点击后browser截图30秒超时，保留失败且未增timeout。已定位并实现精确边界邻居粗筛：两完整世界3000断言逐项几何相同，11对跨区App／GPU图逐像素相同；同一原生App初始化27.23秒降至5.527秒，仅限定该样本。旧style-v3保持原字节，新v4和creative-v8显式重绑；首次遗漏current方向绑定的Bible测试失败也保留，补齐后六项受影响harnessfresh通过。浏览器重试与最终本地包结果另记。

最终本地Web原型已完成：运行源 `263afd4fbdd535df6b4e80b1f4b584a05b55c7ea`，build `e361af714d54`；两图×鼠标／模拟DOM触屏共4入口、12项实际组装／暂停恢复检查通过，errors为空，四次完整PCK身份一致。仅签这些GUI入口，未签浏览器全程、手机真机、趣味性或人类时长。完整本地包为 `build/gunman-rush-forest-v18-e361af714d54.zip`（298440075字节，SHA `e8312144a72e071b2e4162a1492e44c88d5b376b53b086597f1c22ef10c7a69a`），解压后运行 `python3 -m http.server 8000`，打开localhost:8000；DEVELOPMENT DEMOS → SELECT REGION → FOREST PLACES MAP 1/2。包内含许可与README，全部成员读回核对。原浏览器06失败保留，未增加超时；本次GUI通过不重签美术。当时尚未发布新Pages，后续实际上线以最新段落为准；仍未合main。详见[最终原件索引](evidence/forest_variety_04/README.md)。

## 最新补齐：公开试玩交付

用户明确“我都是通过试玩网站试玩的”；上一轮只推远端／本地ZIP未满足该方式，已纠正并补到AGENTS／project-integration。现已[公开e361原型](https://zhipijun1996.github.io/gunman-rush/?v=e361af714d54)，DEVELOPMENT DEMOS → SELECT REGION → FOREST PLACES MAP 1/2；旧默认THORN_FOREST不变。原Web07同源复用，Pages39733962550成功，公开完整PCK141811380字节／完整SHA一致，四实际GUI入口＋暂停恢复12项通过、errors[]。准确PCK source263afd；workflow helper81e4f0ab／prepared297bb91，最终文档提交不冒称运行源。[全部原件与边界](evidence/forest_variety_04/public_v18_01/README.md)。

没有修改运行代码／重建／全CI／合main，也不抵销ART_REWORK和其他未完成项。后续仍先网状探索、多难度真正不同的模块与自然结构美术，再真人验证每图8–12／15–20分钟，最后平原。用户只通过网页体验，不能仅给本地包结项。
