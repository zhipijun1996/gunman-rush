---
name: project-integration
description: 项目归整、冗余清理、分支合并和 Web 交付验证。
---

# project-integration

所有命令从仓库根目录运行。现行规则见 [AGENTS](../../../AGENTS.md) 与 [当前状态](../../../docs/current_state.md)；数值和玩法不在 skill 中重复定义。

1. 检查 Git 状态、分支 ancestry、当前交接、CI 和用户授权。最新分支按实际提交时间与累积内容判断，不能只按 PR 编号。确认 main 是否已包含，防止重复整合。
2. 分别识别现行规范、历史说明、运行资源、回归消费者和可重建产物；按 docs/project_structure.md 归整。删除候选必须查代码/场景/Resource/config、动态加载、manifest、工具、文档和许可。无静态引用不是可删结论。
3. 优先收敛当前入口、归档历史段落与修链接，保持稳定 res:// 路径/UID。不要因旧命名删除仍有消费者的 Lab、回归测试、母版或失败证据。不批量删除远端分支/关闭 PR。
4. harness --plan 明确检查；文档整理 docs，工具/运行/构建按影响选 profile，未知 full。改 runner 必须验证非零退出、缺成功标记与超时，不能假通过。
5. 合并前核对目标 SHA 与验证来源，保留冲突解决和未知项。已授权合并则使用普通 merge/受保护 PR 流程，不强推或绕过保护；未授权则交付可审查 PR。
6. Web 使用现有 build/check_bundle，缓存和弱网测试保留实际条件；检查提交与线上构建指纹、许可证、存档和冷暖缓存。合并 main 会触发现有 Pages 工作流，报告实际状态，不把排队当发布成功。
7. 更新当前状态、任务、交接和证据，说明实际清理了什么、保留什么及原因。

交付物：可审查结构变更、删除/保留依据、合并/构建结果与继续命令。

质量状态统一使用 [game-quality-gate](../game-quality-gate/SKILL.md) 与 [总流程](../../../docs/development_quality.md)。纯整理用 process 类型，不能用它隐藏运行文件修改；Git 交付不代表内容/设备验收。

## 快速试玩发布默认路径（2026-10-21 用户最新要求）

用户只要求“部署试玩网页”时，先找目标运行源已验证的Web包；存在就复用包，不重新跑完整CI、Windows、全路线和长录像。使用现有`deploy-prepared-playtest.yml`，prepared分支仅承载该原导出；超100MiB PCK由原内容寻址chunks重建并核对完整SHA/长度。缺包或运行源改变时仅Web重建及影响范围验证，不为部署先跑整套项目交付。完整回归与正式交付继续独立执行，复用证据不冒称本轮fresh。

发布后核对公开`build-info.json`、完整PCK和目标source/build，再做标题→目标区域的基本GUI冒烟；回报可点击试玩链接、构建标识和实际未完成边界。无需每次重新生成计划/提案或征求已授权发布的确认。源码与包的身份必须准确，不把部署成功称整区艺术/真机认可；不默认合main。

用户通过试玩站体验时，已验证的开发原型也按该路径发布并给可点击URL和准确菜单入口；分支已推送或本地ZIP不能代替网页交付。保留旧入口，新候选与最终质量分开标注；公开元数据与实际点击验证后才报上线，未做的真机／时长／整区品质保留未验。[实际纠正与原话](../../../docs/evidence/forest_variety_04/public_v18_01/README.md)。

Web导出遇到 `Foundry source changed after validation`，先检查现有开发池basis。当前旧工坊保守绑定整个generation目录，新区域脚本也会令其失配；用原 `python3 tools/foundry.py build --count 24 --promote` 实际验证并重建开发池／回放，再走原export stamp。保留旧池和失败，不手改basis或跳过guard；这不要求重跑整套CI，也不把工坊通过签成森林品质。

## 实际指针与弹出菜单的交付检查

新增菜单不可以键盘选项通过代替鼠标/触屏菜单项点击。画面存在、按钮能打开弹出层、键盘能选中，都不证明触屏能提交选项；必须逐项检查已接受ID、回调次数、菜单关闭和关闭后首个真实操作。对嵌入Window按当前引擎提交核查事件通路，不能把子Viewport push_input或window_input信号视为原生菜单调用链。取消/点击外部不得泄漏为角色攻击；Web真实DOM touchcancel与原生canceled字段要分开验证，监听退出时移除。默认静止训练目标必须明确标注，不应作为所有敌人运动/战斗验收；保留移动默认与静止样板消费者。

## 提效执行顺序（2026-10-14）

先交付一个真实消费者的完整动作样板，提前验证移动中附件衔接、墙边碰撞、触屏多指、伸缩/过渡动画及正常速度连续音画，再批量扩展。开发使用harness --check定位与--jobs隔离并行；--reuse仅复用完全相同依赖的证明。最终使用tools/deliver.py与--release的新鲜完整检查；也可由同一冻结SHA的正式CI完成全部fresh core/art、GPU/audio、Windows/Web，再以tools/verify_ci_artifact_browser.py对该CI唯一API digest绑定的实际ZIP/PCK执行三个原浏览器消费者，并单列同源原生连续动作影片。两种方式都必须核对公开PCK完整SHA，不把失败的本地deliver追认为通过；任何缓存不能代替独立/设备/玩家认可。规则、命令与删除边界见[交付提效](../../../docs/delivery_efficiency.md)。

发布前运行 `python3 tools/check_release_evidence.py --commit HEAD`：证据路径必须存在于该精确Git提交的普通文件树，不能因本机build尚存而放行。原quality schema/SHA检查继续执行；必要时在无旧build的干净checkout实际复核。实际A3缺9件的失败及无损迁移用于此守门正反例，不改签旧来源或以最终trace覆盖失败原件。

提交PR前还须按该PR实际base完整执行`python3 tools/check_quality_diff.py --base <base-sha>`，不能只用上一笔本地HEAD。family manifest不自动提供`docs/quality/asset_records`的机器登记；真实runtime资产必须有runtime来源，不以offline关联文件覆盖。测试预期随真实消费者变化时，专项独审只签该守门变化，不为通过检查把整区独审维度改成passed。PR默认临时merge提交与分支head不同；选择精确head检出并保持run API、Git、build-info/PCK一致，手动publish的并发租约与自动push/PR分开。

## 共同创作契约

[预制作→制作→验收及版本总谱](../../../docs/creative_direction/README.md)是共同执行依据。总谱SHA变更须RETHINK并复验；交付写贡献、协作、新行为/视觉、主题冲突和实机验证。REWORK局部修复，DISCARD隔离候选；ACCEPT只限真实已验范围，审美不绕过工程红灯。

历史复现按需读取[原始Skill与迁移索引](../../../docs/archive/skill_history/README.md)，不默认加载旧轮授权、PR实录或失败数字。
