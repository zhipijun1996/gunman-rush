# 怪物完成标准与冲锋怪盘点证据

2026-10-28，基线main `45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`。本线先落实用户追加的统一完成标准，再按同一标准核对冲锋怪。标准任务 `ENEMY-COMPLETION-01`为process，实际怪物核对 `ENEMY-CONTINUITY-01`为animation，两份记录分开，不把流程检查写成怪物PASS。

## 已形成的产物

- [每物种完成标准](../../quality/enemy_completion_standard.md)：E01–E12、完整状态与转换、原四态、G0–G5／十一维映射及完整完成出口。
- [原制作卡模板](../../templates/enemy_design.md)：增加实现事实／状态／证据／缺口，身体母版、所有权和转换表。
- enemy-creator／art-director／animation-vfx已连接同一标准，原质量policy、运行代码、资产、参数和测试断言不改。
- [冲锋怪卡](../../design/enemies/plains_charger.md)：两表现链、实际身体所有者、live／H／D切换、尸体／保存路径和未验清单。
- [源盘点](source_inventory.json)：19个基线文件的完整SHA256、Git blob与大小，仅证明源码事实，`runtime_executed=false`，不证明当前动画自然。

## 版本和历史边界

旧ENEMY-FEEDBACK-01的formal66/1、Legacy飞怪876→877及当时来源缺口保留原范围。后续[尸体保存集成](../enemy_corpse_save_integration/README.md)已记录strict66/0、保存72/0等限定修复；本轮不按旧摘要把已修问题判成当前冲锋怪失败，也不把后续技术修复签成完整动作／用户认可。

用户已要求统一标准，未因此认可任何新素材或当前怪物完成。标准文档、源审查、fresh运行、连续音画、独审、设备与用户分别记证据。当前记录见[标准任务](../../quality/records/ENEMY-COMPLETION-01.json)及[冲锋怪任务](../../quality/records/ENEMY-CONTINUITY-01.json)。实际检查和媒体将在本目录追加，计划不算执行。

## 本轮环境准备

系统预装Godot为4.6.3，未用于项目采证。已通过原`bash tools/cloud_setup.sh --godot-only`安装锁定4.7.2 Standard及模板，原日志在`build/enemy_continuity_01/toolchain-setup.log`，准备报告在`build/verification/environment/setup-report.json`。输入沿原`tools/cloud_inputs.py --profile docs --materialize`恢复选定闭包，报告只证明输入可用，不是测试通过。

无独立审查或用户／设备证据时保持unverified；不伪称ACCEPT或done。此文档不执行合main或游戏发布。

## 当前源实跑与发现

原native458／0、support199／0、corpse-save72／0、corpse-snapshot147／0均本轮fresh退出0，原预算／断言不改。[26.133秒实际影片](underworld/after.mp4)与[原producer报告](underworld/report.json)source_stable=true；[原轨迹](underworld/after.json)为1560游戏记录、6次HP提交、2死亡、各210记录终态可见稳定长尾。影片包含两个原fixture物种，主要核对charger；不是新内容／自然正式路线／设备性能。

实际解码观察在[连续性核对](continuity_review.md)：视频94→95、143→144受伤退出结构突变为CHR-VIS-01，E03／E05 failed；charger片段没有attack状态，不能签完整冲锋动作。旧保存问题本轮原专项通过，不以旧记录重判。没有完整播放器观看或音轨试听，相关整体／声音认可仍未验。所有原件大小与SHA见[产物清单](artifact_inventory.json)，观察附图不替代原片。

## 标准文档验证收口

精确实现源`1f11b24`的原`python3 tools/harness.py --profile docs --release --jobs 1`已完整33／33 fresh通过，0复用；[原报告](docs-profile/report.json)及同目录逐项日志保留，[验证汇总](validation.json)分列源和范围。此前design_contract.json缺失、preview／build原隔离文件缺失、任务索引in_progress／记录review不一致的失败原件均在checks/failures；前两项恢复精确Git原件，后一项同步真实review状态，不改检查／断言／预算。最初CLI误用不支持的output参数没有执行检查，原usage也保留，不算一次测试通过。

ENEMY-COMPLETION-01按原process门槛done，仅表示标准、制作卡和skills入口已形成并通过文档验证；ENEMY-CONTINUITY-01仍review且有实证failed。标准process不需要游戏设备／用户验收，不能将这一适用性用于怪物内容。源码／工具／测试／资源／配置／shader相对基线无修改。最终元数据收口另跑原记录、文档和差异守门，不把它称又一次完整33或full165。
