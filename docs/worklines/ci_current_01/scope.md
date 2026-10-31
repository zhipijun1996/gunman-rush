# CI-CURRENT-01：当前消费者契约和历史 CI 边界

2026-10-31 用户明确先合 PR124，再重构和修复 CI。PR124 已普通 merge 到 main `bd86237456c7ce12a352b040857b208bdede7f66`，父提交为原 main `840108da9ae91e412dc9f1d8a38ccdad0229bb11` 与 PR124 `1fe4889d02359517252644c3aaf0450ddec8f853`。此次采用新顺序，不把合并签成全量 CI 通过；原 [失败 run](https://github.com/zhipijun1996/gunman-rush/actions/runs/41118658287) 保留。PR122 未因此自动合入，原 main＋PR122 架构候选保持在独立工作区，PR123 仍排除。

本批从新 main 创建 `fix/current-ci-01`，先处理 generated-consumers 的实际失败。只读复核发现所有生产 PlainsStageVisual 宿主均继承 DemoStage 的 nullable boss 字段，而旧 VisualFixture 没有此字段。修复仅给该测试替身补 `var boss: Node2D`，以 null 表示没有 Boss 实例；全部原断言、60 秒预算、成功标记和故意失败模式保留。生产代码、Boss 规则、美术声音、CI profiles 和 workflow 未改。

当前已重现原 SCRIPT ERROR，修后单项 27 断言/0 失败。负例实际28断言/1个故意失败、退出1；最初本地诊断脚本误填断言数的失败保留，后继从正例实测计数验证，不改游戏或原 runner 迁就诊断。完整 26 套 generated-consumers 已按原 harness 通过（161.372秒）；[原始收据](../../evidence/ci_current_01/README.md)保留失败和成功来源，不用该专项签完整169。

CI 分类依据真实调用：正式路径/共享能力必须继续验证；明确历史内容可隔离为手动兼容检查；混合新旧的 runner 先拆覆盖再调整触发。源码输入登记不等于重复执行，旧文件名也不等于无当前消费者。保留森林超时失败，不通过删场景或放预算伪造绿色基线。

本批回退点为 `bd86237456c7ce12a352b040857b208bdede7f66`。完成当前最小修复后，继续形成 current/experiments/legacy 的真实检查映射和变更影响范围；架构按已确定的功能模块迁移，不在此修复中复制一套运行服务。
