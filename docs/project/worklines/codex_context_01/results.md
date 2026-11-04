# 当前交付与恢复

分支：`docs/codex-context-cleanup`；PR134，目标 main。文档重整交付 `59b8146d49eb6d8a56104cfb1ccf5f05c520ff25`，来源导航修正 `d77a9c3a7984c952e47f11ec588d74a98ae44ddd`。运行实现基线见 [当前状态](../../current_state.md)。

## 结果

- 文档实体按 project／bible／data 整合，必要原件归 evidence；根目录110份Markdown收敛为一个入口，模板20份减为6份。
- 重整武器／能力、地图／难度、美术／动画及开发规范，删除过时任务过程稿、重复规范和当前元数据中的版本修订叙事。地区矩阵统一阶段、能力锁与最终正文。
- 全局保留14个父议题、369个旧任务归档；当前交接与质量卡归各自工作线。
- AGENTS及20份Skill按需加载。design-grill于`02c214bd`单独交付，直接复用原版Grilling；确认前只讨论，最终确认后重整权威正文。
- 冲锋怪与五份Boss规范描述玩家可感知的行为、招式、反制和表现，代码／字段／验证映射归模块导航。运行玩法、数值、图声与CI流程未变。

## 验证与限制

固定四项CI通过；文档、质量静态检查及编译检查通过。相关Python回归370项通过，包括113项生产循环与41项当前Bible保护；目录迁移后的夹具、路径和证据读取均已修复。完整命令、来源和日志见 [验证记录](../../../evidence/codex_context_01/document-restructure/verification.json)。

差异检查仍要求对世界规范测试中“必须保留旧方案历史字段”的退休进行独立语义审阅；未将此检查记为通过。20项逐版本创作迁移断言退休，以当前权威、来源漂移和旧绑定拒绝回归替代，完整清单随验证记录保留。

其余普通怪、道具及机关细节按实际功能任务继续补齐；P17取舍、森林v18采用及剧情人物细案待决定。对象画面、声音、平衡、趣味与实体设备未在本任务中验收。PR保持待审，尚未合并或发布。

## 恢复

先核对分支和工作区：`git status --short`。文档检查：`python3 tools/check_docs.py`；静态记录：`python3 tools/check_quality.py`；差异审阅：`python3 tools/check_quality_diff.py --base 68a87f38`。运行专项从`python3 tools/harness.py --list`选择；日常验证`python3 tools/ci.py`。
