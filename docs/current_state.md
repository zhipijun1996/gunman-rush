# 当前状态

2026-10-22。工作分支 `feature/region-bible-v2-forest`，草稿 [PR101](https://github.com/zhipijun1996/gunman-rush/pull/101)；main 未合新区域。任务 FOREST-VARIETY-03 开发中。旧重复交付段落已原字节保存到[状态快照索引](archive/status_snapshots_20261022/index.json)，不再覆盖本页。

## 当前公开试玩

[恢复的旧森林 v15](https://zhipijun1996.github.io/gunman-rush/?v=12ac19e2ec02)，build `12ac19e2ec02`，运行源 `bbf5b24dc6a27374119f67f11fc2eed92a57ba00`。入口：DEVELOPMENT DEMOS → SELECT REGION → THORN_FOREST MAP 1/2。prepared Pages [39704078082](https://github.com/zhipijun1996/gunman-rush/actions/runs/39704078082) 成功；公网完整PCK 141559396字节/SHA一致，真实鼠标map1进入与暂停恢复通过。[原始恢复收据](evidence/forest_variety_03/public_restore/report.json)。这是旧包恢复，不是新扩容发布。

用户明确否定 v16 短平台堆叠，并肯定旧 v15 设计；v16 的玩家验收及G5已记 failed。旧技术结果保留原范围，不抵销体验失败。原因与取舍见[返省](design/forest_v16_rethink.md)。

## 本轮实现与边界

新 v17 独立候选保留旧实体、出生点和原探索模块；普通入口增加一片有实际净空的休整侧根，旧连续HH与螺旋技巧线保留。东侧附林从旧F05恢复根进入，上下双窗、外根环、L空腔奖励与固定果挂跳返程已接。没有任意高差自动补台，没有改核心物理、资源、S2-H能力或旧保存producer；当前普通默认仍v15。

八个候选仅八条孤立goal获限定独审，不是八种新趣味。20实际种子独审确认新增平台矩形布置每张图仍仅1种，只有HH/RH果实坐标、动作与箱口有限变化；未达随机地图目标，Z尚未进入世界。round11六条真实输入路线通过，含旧HH/螺旋、新旧区域往返、L金币/音符实际二选一、远出口与固定果跳返。全部源/失败与真实画面在[本轮证据](evidence/forest_variety_03/README.md)。新增可执行短反馈入口 `python3 tools/harness.py --profile forest-varied-feedback --release --jobs 1`；旧版world签名曾混入实例元数据，现改为真实矩形布置/目标坐标并加反例；严格guard实际两项失败，短反馈当前会如实拒绝该候选，未纳入full或CI。

两轮实际合屏仍 ART_REWORK：巨矩形背体已减掉，但平直梁/方柱/奖励台/长catch尚不自然，两地图的新增场所身份也相似。停止继续调色或尺寸救该母版；不发布附林，不签整区、趣味或真机。下一步先重想根枝/空腔整体轮廓与真实分流，再扩不同机制库；保留已成立的旧森林体验与本轮通行发现。

## 权威与未完成

[用户两份完整Bible](creative_direction/bibles/registry.json)、[正式平原共享像素母版](creative_direction/bibles/style-continuity-20261021-v3.json)及[自然缠绕荆棘平台要求](creative_direction/bibles/thorn-covered-platforms-20261021.json)继续有效。森林先行，风铃平原优化仍 planned；BGM由用户后续引入，未生成/替换。

森林整区美术、更多真正不同且世界闭环的模块、明显种子拓扑、总体难度曲线及设备/用户认可均未完成。过去v15的原80/full141/Web证据仍只属于各冻结源；本轮未重跑完整CI，不重签。新试玩遵循已有快发布流程，功能/设计/艺术不因部署或CI成功自动通过。
