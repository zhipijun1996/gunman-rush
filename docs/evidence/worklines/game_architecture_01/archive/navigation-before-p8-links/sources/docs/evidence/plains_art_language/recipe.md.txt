# 风铃平原：生成阶段的美术语言候选

本轮任务 `PLAINS-ART-LANGUAGE-01`，从 PR88/`07ffe3f3` 开始，独立分支 `feature/plains-art-language`。这是参数和消费者实验，不是新风格定稿、整区黄金或正式池准入。森林、核心操作、资源与保存不在写集。

## 为什么过去对接不好

现有配方保留了动作、端口和矩形站面，但不能充分表达“这是哪种构造、如何落地、需要什么绘画接口”。地图坐标冻结后，表现只能对碰撞并集铺旧材质；全区域后墙再减孔又把天空变成直边槽。单纯新增标签不会改变结果。因此本次让表达失败能够拒绝候选，让肩部和恢复空间在坐标之前参与列距计算，并换掉该候选的全屏后墙表示。

## 实际执行顺序

1. 原拓扑与挑战配方选取；`PlainsArtLanguage.plan_recipe` 读取真实 Definition，匹配有限规格与构造家族。失败有界重选，不伸缩画件救场。
2. 家族肩宽、模块表达跨度、quiet arrival 进入区域跨度计算；`plan_world_intent` 必须在坐标和节点之前生成有限山体/开谷意图。
3. 坐标嵌入后、模块实例化前解析世界轮廓；物理继续使用真实 Definition。横向模块携带预先表达；生成内联 junction/connection 在其几何已确定、场景实例化之前绑定同一语法，并用外部实际源节点重新校验。
4. `PlainsRegionArtPlan` 验证表达，`PlainsRegionalComposer` 直接消费有限后山体轮廓、世界 UV 和源画 SHA。前景只将表达绑定到实际相交的源平台区域，仍使用旧材质；**未实例化新绘画件**。

源接口：[目录](../../../resources/generation/plains_art_language.json)、[实现](../../../scripts/generation/plains_art_language.gd)。四家族为草原母岩、裂隙岸体、溪流栈道、修补砌体。9 档完整挑战占地与9件拟议岸端/梁端/墙端及芯段是两种不同尺度，不能混称九件可用资产。固定画件按源像素分配有限重叠，禁止随跨度拉伸；实际画源仍缺失。

支座/根部/吊挂目前是可核验要求和待生产接口，不是已完成支承求解。家族连接只覆盖同站面初版，不是任意墙脚/材质过渡。配方依旧先由玩法选择再映射家族，尚未实现地貌反选挑战、局部修复或通用连续地质场。

## 启动与恢复

短请求：

```sh
python3 tools/level_design.py route --request "优化风铃平原关卡模块与随机生成的美术语言和尺寸规格" --output /tmp/plains-language-route.json
```

这是原 Harness 的计划入口，不代表 worker 已执行。相关原生合同：

```sh
python3 tools/harness.py --check plains-art-language-contract --jobs 1
bash tools/godot.sh --path . --script res://tools/plains_art_language_preview.gd -- --seed=joint-recoil-01
```

后一个是真实 DemoApp 的显式候选，保留正常输入与角色，不写入保存；第二 Seed 可用 `joint-recoil-07`。不替换默认入口。新 profile 的完整路线 MovieWriter 适配尚未绑定，不能拿旧 profile 影片代签。正常出生截图与仅改变相机的 debug 总览分开标注；总览不是正常游戏品质证明。

## 验证及扩展边界

先测选中横向模块，再在独审建议下仅扩到 junction/connection。四 Seed 比较默认/旧候选原 SHA、JSON 重建、非法规格/来源漂移/拉伸反例、真实碰撞、实际有限后山体与源平台交集域。两 Seed 用同配方/同拓扑反事实检查新参数是否实际改变列距，而非只增加字段。原始失败和最终结果见 [证据索引](records/index.json)，判断见 [独立审查](independent-review.md)。

本轮没有新图像生成、完整新前景画件、正常速度全路线录像、真人/设备验证、新可下载包或 Web 发布。历史 /tmp 包不作为当前可取得产物。下一项必要实验是制作并实际消费一个岸端—芯段—根部画源家族，在两个合法跨度和一个非法跨度验证画面、连接及支承；不是继续增加装饰、参数或 Seed 数量。只有该绘画闭环成立后再扩大美术生产。
