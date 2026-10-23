# 远端已有工作与本次增量

本检查点初始从当时最新 `main@e9ab0e0743466b8983e34cc7de17bab1abf9d53a` 进行独立基线审计。推送前核对远端发现同名 `feature/player-presentation-01` 已有提交 `b34511a7ee27f03b6d87d070ca20e9309e1e8a2e`（2026-10-22 13:17:06 UTC，Preserve PLAYER-PRESENTATION-01 M1 movies and recoverable evidence）。本次没有覆盖、合并或重标该分支。

本次交接分支改为 **review/player-presentation-01-baseline-methods**。最初审查文档内 feature 分支名描述的是本地采集时状态；实际可审查远端入口以本文件为准。本分支是同一任务的补充审计／方法研究，不是与已有 M1 争夺生产脚本的第二实现线。质量卡只适用于本分支的基线检查点，不能整张覆盖已有分支的同任务卡；总控合并时按真实证据逐条归并。

只读取得已有 M1 的 README、impact-v1、UnderworldPlayer 和独立 dev 驱动，未运行其代码或独立验收其电影。其原件在[已有远端M1](https://github.com/zhipijun1996/gunman-rush/tree/b34511a7ee27f03b6d87d070ca20e9309e1e8a2e/docs/evidence/player-presentation-01/m1)。不能把它的 before/after、27/11 检查或本地 Preview 宣称为本次 fresh。

已有 M1 已定位 disabled Adapter 信号仍连接、恢复计时不推进的问题，并在 UnderworldPlayer 增加 recover_weapon_anchor 配置与恢复计时，结束后调用 Courier.set_state(idle)。其报告明确记载：相同输入的 Motor／资源／事件轨迹相同，但权威枪口纠正约3.375wu，**后续弹体出生位置会随之变化**；style独审／显式重绑仍待总控。此处仅核对其源码／自述，不追认通过。

本次补充的价值与交接决策：

- 同一 main 的真实 Home 三外观基线复现卡recoil，补了正式 Plains 的自然环境伤害窗口；原始生产代码保持不变。
- 补全十五装备／九mode／六Lv3技能、三外观、旧Courier、Bible森林与瞬闪残影消费者；发现替代身体按陈旧Courier.state绘制，家园能切不等于切后完整动作成立。
- 读取公开开发者原文形成[方法研究](methodology-01.md)，提出可读层次、武器节拍、响应与收势的同条件试验。
- 本次[impact-v1](impact-v1.json)建议新的纯绘制上身／只读快照保持现有权威枪口不变；这与已有 M1“有意纠正玩法锚点”的作用范围不同。总控先裁定是否把锚点bug修正列为独立前置接口及回归范围，再决定沿用M1还是分离纯表现层，不能把两者描述成完全等价的cosmetic改动。
- 独立可操作 Preview 的本地来源已存在于已有 M1，但本次未验证、未构建、未上站；不造新旧链接。发布与共享重绑／Integration由总控统一安排。

下一动作是总控合并两份证据与写集决策，避免重复实现或并行改同一 UnderworldPlayer。平原线继续共同基线只读比较。无需用户为本次公开方法研究或普通可逆工作重新签字；受保护资源变化的独审／重绑仍按用户本轮明确边界执行。
