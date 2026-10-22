# 当前状态

2026-10-22，开发现状已通过[PR102](https://github.com/zhipijun1996/gunman-rush/pull/102)收口到 `main`，合并提交 `9c349f44caa7e230b7784a340a839906cac58d0e`；森林[PR101](https://github.com/zhipijun1996/gunman-rush/pull/101)也已merged。原93个开发head及新integration均为main祖先，本地已切回main；纯部署产物分支排除，旧分支未删除。后续从最新origin/main开独立主题分支／worktree，PR直接向main。[收口与原始证据](main_closeout_20261022.md)。

源码／测试／资源／CI子树与767627f8一致，其完整Godot core39734737843及docs39734738277实际success；本轮新文档29项fresh通过。新main CI39741355698／docs39741355652已自动启动，此时尚未完成，公开版本以build-info为准。任务 FOREST-VARIETY-04 仍开发中，整森林未完成；本页以下旧“未合main”属于收口前历史时点。

## 当前公开试玩

[新版探索原型](https://zhipijun1996.github.io/gunman-rush/?v=e361af714d54)，build `e361af714d54`，运行源 `263afd4fbdd535df6b4e80b1f4b584a05b55c7ea`，已公开。入口 **DEVELOPMENT DEMOS → SELECT REGION → FOREST PLACES MAP 1 / MAP 2**。普通 THORN_FOREST 仍旧v15；新内容用显式开发入口。

[Pages39733962550](https://github.com/zhipijun1996/gunman-rush/actions/runs/39733962550)实际success；公开完整PCK SHA／长度与原已验证Web07一致，两图×鼠标／模拟DOM触屏四入口及暂停恢复12项检查通过、无引擎错误。[原始发布证据](evidence/forest_variety_04/public_v18_01/README.md)。这是试玩原型，ART_REWORK、网状拓扑／更丰富模块／真人时长／真机等仍未完成，没有合main或签整区验收。

此前公开的12ac19e2ec02是旧v15恢复包；上一轮81e4f0ab只推源码／交本地包，没有上站。用户再次明确只通过试玩站体验，本次复用同源Web07发布，不重建／不重跑完整CI；后续交付以网页链接与实际公开版本为准。旧恢复收据仍在[历史原件](evidence/forest_variety_03/public_restore/report.json)。

## 新候选 v18

保留用户肯定的 v15 核心、早段休整侧根、旧 HH／螺旋技巧线；默认入口仍 v15。新显式 FOREST PLACES MAP 1/2 接入双窗树腹、7型高枝回落、Z折根内外路、倒木上下路；图二另有固定果 H 后反向射击到背枝高奖励。Z／倒木次序由真正的 root seed 决定，两图取相反顺序，另有结构变体。Boss 完整 factory 随最终出口后移，无需清空宝箱才能开门。

奖励是实际金币或音符二选一：七型／倒木4或1、Z6或2、背枝5或2。不是更多短平台梯，不改物理／Motor／资源／能力／保存；活果渡口仍未实现。当前是多个分流汇流场所的链，尚非充分网状地图；没有把顺序／几何签名当作趣味性证明。

用户每图正常8–12分钟、充分探索15–20分钟为初步真人目标，未计时验证。实际路线证据只证明所列出生点／fixture旅程到 Boss 门前，不能换算真人游玩时长或 Boss 战验收。

## 质量与待办

[设计与范围](design/forest_exploration_v18.md)、[原件及失败索引](evidence/forest_variety_04/README.md)、[十一维记录](quality/records/FOREST-VARIETY-04.json)。33项原轮在600秒超时，保留原 FAIL；基础路线和新模块库已拆成可选开发检查，预算／守卫不变，原80/full/CI不变。

实际App04独审拒绝倒木直角L框；18.3已改真实外弯根腹，App05独审确认有实质轮廓改善，仅允许继续玩法验证，没有 ART 通过。Z细悬臂／倒L、背枝浮空平梁／通屏恢复层及森林材质仍需定稿。两条树皮材质尝试失败均保留、未接入。不能把原型当整区美术或用户认可；本次依用户试玩方式通过独立FOREST PLACES入口发布，保留旧默认。

继续先完成森林含美术，再优化风铃平原。两份完整Bible、共享 Underworld16px/32wu 家族与自然覆生荆棘平台要求有效；BGM由用户后续引入，未生成或替换。整体难度曲线、更多有趣模块、充分网状探索、人类时长和实体设备／玩家认可仍未完成。

最新限定技术结果：新库16项fresh inner／outer通过（334.075秒）；倒木18.3之后两图正式出生点主路线fresh通过（135.791秒），全源稳定。不追认原33超时，不签全量回归、真人时长或ART。

首次Web构建真实失败：旧Foundry池的basis包含整个generation目录，新增区域脚本使其失配。已用原工具实际重新验证36短语／18连续路线与回放，只更新开发池JSON／export stamp；没有直接换SHA或改guard，森林几何／动作／参数字节未动。第一次失败保留，Web重试结果另记。

Web06导出与PCK检查通过，但实际候选点击后browser截图30秒超时，保留失败且未增timeout。已定位并实现精确边界邻居粗筛：两完整世界3000断言逐项几何相同，11对跨区App／GPU图逐像素相同；同一原生App初始化27.23秒降至5.527秒，仅限定该样本。旧style-v3保持原字节，新v4和creative-v8显式重绑；首次遗漏current方向绑定的Bible测试失败也保留，补齐后六项受影响harnessfresh通过。浏览器重试与最终本地包结果另记。

最终本地Web原型已完成：运行源 `263afd4fbdd535df6b4e80b1f4b584a05b55c7ea`，build `e361af714d54`；两图×鼠标／模拟DOM触屏共4入口、12项实际组装／暂停恢复检查通过，errors为空，四次完整PCK身份一致。仅签这些GUI入口，未签浏览器全程、手机真机、趣味性或人类时长。完整本地包为 `build/gunman-rush-forest-v18-e361af714d54.zip`（298440075字节，SHA `e8312144a72e071b2e4162a1492e44c88d5b376b53b086597f1c22ef10c7a69a`），解压后运行 `python3 -m http.server 8000`，打开localhost:8000；DEVELOPMENT DEMOS → SELECT REGION → FOREST PLACES MAP 1/2。包内含许可与README，全部成员读回核对。原浏览器06失败保留，未增加超时；本次GUI通过不重签美术。当时尚未发布新Pages；后续公开交付见页首当前公开试玩，仍未合main。详见[最终原件索引](evidence/forest_variety_04/README.md)。
