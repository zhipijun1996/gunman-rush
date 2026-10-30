# Run41016649030 原始 CI 独立审查

**拒绝 full167 技术通过声明；原件完整性限定接受（1064项核对／0失败）。**

审查源 `ab96fb27f22ab0db12e3558d3bec5ba7c79675d9`，审查者 `/root/guard_review_recovery` 未编写生产或测试、未运行引擎、未重试或推送。范围不包含正在整合 main 的未提交工作树。

官方 prepare 与 parallel 成功；parallel 原始92项全 fresh 通过。serial 原始17项通过、forest-depth-region 在600.190秒超时、余57项未执行，合计109通过／1超时／57未执行。forest 原matrix80请求仅完成53，完成者均通过，4有效CPU、4workers；case中位42.683秒。affected123954062133 因lane前置失败而失败，无官方merged收据。旧两轮53/80失败保留，不能把本轮称全绿。

七份原ZIP已按官方同run/head、字节数、SHA256和路径安全逐一核对，保存在 `build/plains-ci-41016649030`。原lane顺序、原argv/预算/marker/token/input digest/log SHA、源与工具链前后稳定、跨lane输入一致，均逐项核对；调用原 `harness.verify_lane_reports` 正确拒绝失败lane。Foundry56个准备工作区修改披露为非Git clean，未把准备后的源称干净checkout。生产字节等于冻结A/de22。

## main 基线的实际证据

main `feb0106849e12c18c0337c8cdb23d01333580e42` 与PR121 head `161055bcc14f95f2748e9e27c1296519f0f4e57c` 整棵Git tree相同。官方run41008752243第一轮serial job123913464904确实同一forest超时；第二轮同源成功，parallel91、serial75、官方merged166、partial=false、affected SUCCESS。原serial forest日志SHA与收据一致，80个唯一case都passed，耗时586.108秒，仍是600预算。这里未独立重跑或逐日志重验基线全部166项。

所以证据支持“同一main源出现一次真实超时，后来成功”，不支持“main持续红灯”，也不能单凭它证明本分支三次超时纯属基础设施。B的其他17个已通过serial checks相对main第二轮耗时比中位1.0377；forest完成吞吐差异明显，但运行主机和游戏源均不完全相同，未作因果归属。

## 源差异与约束

两源的production workflow、harness.py、forest实际GDScript runner逐字相同，forest argv和600预算相同。Python adapter差异为CPU容量记录与auto worker选择；本轮实际仍选择4workers，main默认4。profiles为本线167、main166；游戏表现源、foreground和音频确实不同，Ground/Skin仅本线存在，详见 `main-vs-B-selected-source.diff`、`main-vs-B-source-comparison.json` 和全路径状态清单。该比较不将main新优化追签到旧B，也不对当前冲突整合源码签字。

main AGENTS 明文要求精确源双lane/affected全绿后普通merge，且“不跳红灯或放预算”；本次“快速合入”没有明确解除该门禁。应保留本次失败，不可改写成passed或据本报告绕过合并检查。

此报告只签失败CI原件完整性及上述有限基线比较；不签艺术、听感、设备、经济、用户接受、G1–G5，也不追签996影片为新源。

实际复现脚本 `/tmp/audit_plains_ci_41016649030_failed.py`，执行日志 `/tmp/plains_ci_41016649030_failed_audit.log`，逐项proof `/tmp/plains_ci_41016649030_failed_proof.json`，汇总JSON `/tmp/plains_ci_41016649030_failed_review.json`。预备第一次审计因旧证据稀疏缺件停止，后改读冻结B原Git blob后完成；原CI原件未修改。
