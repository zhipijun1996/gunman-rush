# 最终冻结验证

运行源 `32200d04fe233bda16cf50f678aabee51a9715e5`；之后仅报告/证据和发布工具文件名校验加固，游戏运行文件无变化。

- `registered_harness.log` 与 `registered_harness/report.json`：实际 fresh `python3 tools/harness.py --check style-exploration --release --jobs 1`，exit0，43.052秒，无 source_changed。
- `registered_runtime/`：同次原始导入、17215/0与20主路往返+80上层访问返回、1706/0与16地区消费者、3个CLI，6个进程均成功。
- `full_profiles.log` 与 `full_profiles/`：实际 fresh docs/art/gameplay/web完整profile，exit1，在首项docs因稀疏工作区未取齐历史证据/归档断链失败，后续检查未执行。不称完整回归通过；本轮新增报告无断链条目。
- `preserved_source_changed_failure/`：较早并发写源触发的真实失败，不追签为本次成功。
- `runtime_equivalence.json`：1454个现存游戏运行文件与冻结源一致。
- `final_anchor_check.log`、`final_manifest_check.log`：可重建原图集与151素材声明检查通过。

原始报告保留当时绝对路径和工作区指纹；随附本目录原件可离线查看，不将原静帧收据改签为通关。最终45张GPU图、7段动态影片、独审及公开浏览器证据各在同级独立目录。全项目release、实体设备与商业美术终审仍未通过。

质量卡单项schema/来源一致性检查exit0；商业内容准入仍REJECT/未完备，任务review。全局quality exit1（历史证据/skill断链，无本任务专属错误），原件分别保留为 `task_quality_consistency.log`、`global_quality_failure.log`。
