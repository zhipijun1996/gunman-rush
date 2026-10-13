# 证据边界与更正

- cb26733 的完整25检查在干净冻结工作树上执行。之后7968905仅素材/轮廓细化，aa40f90用native ColorRect替代Polygon2D，追加独立几何、1044专项、冻结Web及严格GUI。
- 旧29b9与c74的GUI report把WebGL诊断漏当成通过，整体GUI通过声明撤回；像素bbox比较结果仍是其实际观察。原误标report与console保留在webgl_false_pass，不能再次用作GUI完成证明。最终53e0包启用严格WebGL失败检测，exit0。
- 原v4被视觉审查的8张PNG在后续采集中被覆盖，未伪造同SHA重采图；当时源哈希/审查原文与原始正常速度录像reviewed_v4_video.webm保留。v5审查原截图另存reviewed_v5，最终采集另存gallery。
- GUI键盘输入记录证明真实控制，不证明跨沟/落地成功；坠落截图暴露背景底部断界，未归因新回归或原缺陷。完整黄金合屏、正常速度动作专项、完整路线与真机尚未通过。
