# 高地完整三翼风塔：实景候选与一次有因返工

父任务 `PLAINS-PRODUCTION-V3-01`，真实实施者 `/root/v3_highland_identity`。资产位于 `assets/region_production_v3/spaces/windmill_highland_v1/`，source原图、图生前要求、真实提示/参考SHA、调用时间及数值失败都保留。仅一次图像生成，无AI编辑。

- `static_v1/`：200world完整塔，6张正式1280×720 A/B，最高翼出屏，作为实际失败保留。原240world的源规格已更早失败，不改签。
- `static_v2/`：因实际镜头返工为146world完整等比，6张同pose A/B。前两窗全部翼/塔根入镜；第三窗随玩家右行进入HUD后，装饰并非关键信息。父协调随后报告不同作者实际查看v2八张原图并接受有限146预览范围；商业/动态/设备/用户认可仍未验。
- 每轮另有 `woods_on.png` / `woods_off.png`：两旧树林Sprite显隐反事实诊断，paused同源同actor/camera，无玩法变化，并恢复显示；不是新旧版本通过证明。
- 各轮 `invocation.json` 保存真实命令、退出码、798源before/after逐项SHA及稳定性；`report.json` 保存真实节点/根基/相机/角色/Manifest不变。
- `original_directed_suite.zip`：原20map专项原件，1135assert/0fail；故意失败例210assert/1fail，source稳定。`multiseed_summary.json` 定位每Seed/map的11实际节点与9明确omit。
- `actual_runtime_delta_bytes.zip`：相对内置basis Git HEAD，本次v2采集实际source inventory所有发生差异的原字节，包含其他父级已冻结但未提交源，仅用于重建，不构成本包改写授权或功劳。
- `phase1_exact_source_reconstruction.zip` / `.json`：首轮family+consumer精确字节重建后SHA与原invocation相等，保留失败来源；没有以新146字节冒充旧200。
- `static_probe.gd` / `run_static.py`：实际采集脚本，仅开发reset-pose，不是自动输入、完整路线或电影。

当前默认关闭，仅 `PLAINS_HIGHLAND_PILOT=1` 建节点。原source完整采样，真实static支持不足则omit；不改变碰撞、资源、生成/RNG、相机或旧家族。普通设备/商业美术/真人认可未验；这些静图不证明动画、音效、手机性能或完整探索质量。

本轮采集后仅修正family的stale200文字、146实际GPU状态及独审范围；视觉参数/source/consumer未改。原capture使用的family字节仍在`actual_runtime_delta_bytes.zip`，原source稳定记录未改写。当前元数据变更与前后SHA见`family_metadata_correction.json`。是否开启有限默认由父协调另行实施，不能把本说明当运行时默认已变。
