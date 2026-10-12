# 当前交接：开发质量流程与项目现状整理

本轮来源为最新远程开发分支 `feature/plains-cohesion-and-pressure@53f88e5`，运行提交 `63c56aa`；文档分支 `docs/development-quality-process`。2026-10-12 fetch 后比较全部远程分支，按用户要求采用最新开发分支，main `ab51fca`仅作历史对照。当前正式流程为平原两图、小Boss→大Boss，旧八关仍为开发回归。

[D082运行交接归档](archive/handoff_plains_cohesion_d082.md)保留原CI、公开包和失败证据。本次没有改变游戏代码、物理、素材、随机算法或发布游戏包；公开试玩仍以D082已验证包 `da08f78fa687` 为基线。

提交身份：本轮文档提交使用 `docs: define development quality gates and explain current region generation`；最终SHA可由 `git log -1 --format=%H` 获取，避免在提交内容中循环嵌入自身SHA。PR以 `feature/plains-cohesion-and-pressure` 为base，不合并。

## 本轮交付

- [项目现状](project_status.md)：当前接入、历史规则边界、待验及后续优先级。
- [正式随机算法](generation_current.md)：格子占地/连接/动作配方/独立流/相位/保底及验证局限，明确与旧生成器的区别。
- [开发质量流程](development_quality.md)：完整样板→正式消费者→技术/GUI/连续动作→独立审查→用户与设备体验的门槛；可退回条件与证据。
- [任务模板](templates/development_task.md)、PR模板与AGENTS/README/项目管理导航，避免AI仅实现最小功能就宣布完成。

## 验证与限制

本轮 `python3 tools/check_docs.py` 退出0：33必需文档、相对链接、129任务依赖与参数检查通过；`python3 tools/check_world_design.py` 退出0：16候选地区、29白名单边、六层与来源检查通过；`git diff --check` 退出0。独立审查方 `/root/quality_docs_review` 核对源码/统计与四份新文档，指出画风认可误述、缺独立世界检查两项，已修复；完整审查见[记录](evidence/development_quality_review.md)。这些检查不认证游戏运行。本机 `bash tools/godot.sh --version` 退出1：PATH仅Godot `4.6.3.stable.official.7d41c59c4`，项目要求4.7.2 Standard。本轮为文档整理，不安装/切换引擎，不用旧引擎重跑并认证游戏；D082的运行CI结果仅作为已提交历史证据引用。

完整真人两图/Boss通关、主观画风/趣味性、手机/手柄/Windows实机仍待验；不因文档完成关闭原任务。下一步按正式路线建立体验样板与缺陷清单，使用新任务模板开展已有授权内的工作。

复验命令：`python3 tools/check_docs.py`、`python3 tools/check_world_design.py`、`git diff --check`。运行相关任务先准备固定引擎，再按质量流程选择专项/GUI和发布检查。
