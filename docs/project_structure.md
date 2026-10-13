# 项目结构与清理规则

| 目录 | 职责与保留范围 |
| --- | --- |
| scenes/、scripts/、resources/、shaders/ | 运行场景、类型化组件、Definition 和表现；模块接入查 module_map.md |
| config/ | 实际运行参数和固定工具链来源，不放任务状态 |
| assets/ | 原始母版、运行资源、manifest、许可；运行资源的 .import 与 .uid 保留以稳定 Godot 引用 |
| tools/ | 现有验证/构建/素材工具；统一执行入口 harness.py，检查清单 tools/harness/profiles.json |
| tests/ | 技术回归；旧命名 run_plains_ten 等保留兼容，不冒称正式十关 |
| .agents/skills/ | 仓库内可发现的技能，每个目录一个 SKILL.md；按任务使用，不复制配置默认值 |
| docs/ | 权威契约和主题说明；先 current_state.md，再按主题读取 |
| docs/archive/ | 历史交接、整合前 AGENTS/README；不作为当前规则 |
| docs/evidence/ | 精选成功/失败证据与报告，不能因整理而删失败记录 |
| build/、.godot/、__pycache__/ | 忽略的导出、临时证据、导入缓存；工具链放工作区同级 toolchains/ |
| .github/ | CI 和任务/PR 模板；文档 CI 使用同一 harness docs 入口 |

## 本轮实际清理

原 AGENTS.md 中叠加的历史指令和 README 的旧入口说明移入 archive 原文快照，当前两文件只保留通用约束与现行导航。检查命令集中进 harness 清单；当前玩法集中到 current_state.md，不让每个 skill 再写一套。历史正文仍用于溯源，开头的最新修订优先。

assets/painterly_v2 已由 D083 排除 Web 包，源母版与素材校验仍有用途；biome_style_review 为用户风格候选。旧八关/三关 tests 与 Lab 仍有消费者。因此本轮不删除这些源资产/测试。运行 res:// 路径不整体搬迁，避免破坏场景/资源 UID。

## 后续删除与移动

删除前同时检查代码/场景/资源/config 引用、动态加载、manifest、工具消费者、文档和许可；没有静态引用只算候选。记录路径、理由、替代入口和验证，实际删除后跑对应 harness 并更新引用。可重建的缓存只清本项目路径，不清玩家保存和用户工作区。

归档需修正相对链接，保留任务/决策编号；历史 PR 和分支不因整理批量关闭/删除。新生成物写 build/，禁止把导出包、工具链或一次性大截图提交为运行源码。

## 源码与资源重复检查

本轮对 scripts/scenes/resources/assets/tools/tests 做内容 SHA256 分组：脚本、场景、Resource、工具和测试未发现完全相同文件。资源有三组小型 SVG 重复：checkpoint_ring/recharge_jump、thin_platform 左/中/右、inner_corner 左/右。它们具有独立 manifest ID 和语义用途，删除需要先迁移 manifest/消费者；本轮保留，不把字节相同直接当废文件。git ls-files 未发现已跟踪的 build/.godot/__pycache__ 产物。

## 测试产物隔离

四个地区测试 runner 原来直接写 docs/evidence，会覆盖历史语料和报告；现改为 build/verification/generated/，目录在运行前创建，断言/轨迹不变。check_project 阻止测试再次直接写历史证据目录。精选证据需显式选择后归档。

docs/ 与 preview/ 无 Godot 运行资源引用，且导出原已排除，加入 .gdignore 停止导入图/预览；删除这两个目录的 9 个已跟踪 .import 元数据，保留源图/页面。其他运行资产的 .import/.uid 不动。

2026-10-13：build/ 仅跟踪空的 .gdignore 标记；所有生成物继续忽略。结构检查同时检查该标记，防止 Godot 再导入测试截图、旧导出图与临时审查夹具。
