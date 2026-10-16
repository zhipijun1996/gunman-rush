# GRAPPLE-FIX-01 实际证据

实现检查点为 `8fe31f25a8c4166ec7e70e6bfab7e7cdc2bee5e8`（C1），基于最新远端开发分支 `feature/production-capability-repair` / `9ffe8e7`。后续提交只收口证据和文档。Godot 4.7.2 Standard，Linux 云工作区；不是实体设备。

| 实际执行 | 结果 | 原件 |
| --- | --- | --- |
| `python3 tools/run_action_budget_tests.py`，C1 | 7305/0，退出0；231px、24px每轴、30/60/120Hz左右迎面/逃离真实移动敌人 | final-action-budget.log、final_native_trace.json |
| 隔离工作区 action/actor actions | 7305/0、2871/0 | targeted-isolated.log、positive_native_trace.json |
| 旧代码同移动目标反例 | 855断言/12失败，退出1 | old_runtime_negative.log |
| 首轮候选观察窗 | 7410/3，退出1；1.1s后落地合法恢复资格，改为落地前0.6s观察，未删断言 | first_candidate_fixture_failure.log / trace.json |
| Foundry原build/promote、stamp、Lab | 36短语/18连续路线、Lab35/0；54回放只更新来源哈希，frames及内容一致 | foundry-*.log、foundry-content-comparison.json |
| `python3 tools/harness.py --profile gameplay --jobs 1 --release` | 失败；前10检查通过，core5676/0、generated-consumers31组通过；region中plains_region_runner达300s超时，后继未执行 | gameplay/report.json、各check.log |
| 历史H-only严格退出 | 候选186/0后泄漏，失败；恢复三份原基线字节185/0后同样105 ObjectDB /63resources /7RID。未定位root cause | legacy_candidate_failed、legacy_baseline、legacy_diagnostic_report.json |
| `python3 tools/build.py web`、`python3 tools/check_web_bundle.py`，C1 | 均退出0，实际PCK闭包检查无失败 | web-build.log、web-bundle.log、web-build-info.json |
| Chromium实际GUI鼠标操作、正常物理 | 6项全真，无浏览器错误：进入真实钩索练习、向上命中/接触/弹离、每轴24px、45度、远钩231px封顶、超距不拉近 | gui_probe.py、browser/report.json、events.json、截图、video/*.webm |

GUI原件绑定 C1 与完整PCK SHA `c1562ae6a885e61e3e8d9b7d6bc21b0ff1e42c178157f8cd263df785dea921ee`，build_id `c1562ae6a885`。使用仓库真实入口与画布鼠标，不注入玩法状态；读取STUDIO_EVENT。向左/右移动目标另由真实EnemyActor原生矩阵证明。录像无音频，不替代用户手感、听音或实体设备。首次GUI采集在启动前因缺Playwright ffmpeg失败，原日志保留，安装依赖后重新采集成功。

`gameplay/artifacts.tar.gz` 无损保存原harness子产物（含失败）；`artifacts.sha256.json`核对原成员哈希。原件内旧绝对路径仅用于追溯，不要求旧机器路径仍存在。森林开发fixture明确冻结旧长H，不能作为默认短H覆盖；未开放森林。平原超时原因未知，不与森林泄漏建立未经验证的因果关系。

独审见 independent_review.md。当前是限定小修技术接受；完整玩法回归未通过、正式消费者完整准入未签、用户/真机未验。此Web是本地验证产物，未部署，不引用旧公网预览冒充本轮。

## 最新分支收口

已合入远端最新92f9336，合并检查点af014ac，PR71；与C1相比scripts/resources/config/scenes/project.godot全部字节一致。上游新增工具不倒签为旧GUI覆盖。quality diff实际退出1：目录常量assets/production_repair/未被既有有限适配表识别；静态比较相关三文件在原基线与当前一致，不放宽守门。日志quality-diff-failed.log。提交文件闭包check_release_evidence对af014ac退出0。

首次收口docs profile并行运行期间同步了最新上游，源已变化，主动停止该过期验证，不据其签通过；final-docs-harness.log保留。合并后冻结源另跑docs profile。

合并后冻结源docs profile实际退出1：前12项通过，level-design-contracts触及原60秒timeout，后继未运行；未放宽门槛。原件docs-final/report.json及各日志。
