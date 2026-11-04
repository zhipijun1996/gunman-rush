# 质量记录入口

规范版本 **1**。任务类型、G0–G5、十一维和必要证据由 [policy](policy.json) 定义，自然语言判据见 [开发质量](development.md)。一个任务共用一份记录，各专业补充自己的实际结果。

## 使用

```sh
python3 tools/quality.py init --id TASK-ID --type process --output docs/project/worklines/<议题>/quality/record.json
python3 tools/quality.py check docs/project/worklines/<议题>/quality/record.json
python3 tools/check_quality_diff.py --base <任务基线SHA>
```

init创建未验证记录。普通check验证格式、来源和一致性，允许任务未完成；最终完成声明使用`--require-complete`。全局任务索引与父议题质量卡状态一致，实际合入事实和待验体验分别记录。创作路由的内部阶段记录放 `docs/project/worklines/<议题>/quality/<阶段ID>.json`，由生产循环显式逐项校验；不为阶段向全局任务表追加行。

证据写明源码、版本、方法、观察、退出码、路径与SHA。执行记录、图像、连续音画、正式GUI、独立审查、用户反馈和真机测量各覆盖其实际范围。素材使用现有asset_records及资产manifest。

## 专题

| 需要 | 按需读取 |
| --- | --- |
| 专业制作与审查 | 对应 `.agents/skills/*/SKILL.md` |
| 验证选择与执行 | [Harness](harness.md) |
| 地区／挑战体验审查 | [Q1–Q8](level_review.md) |
| 普通怪逐物种核对 | [完成标准](enemy_completion.md)、[开发手册](../../.agents/skills/enemy-creator/references/development_workflow.md) |
| 独立审查方法 | [审查方法](review_method.md) |
| 自动生产执行协议 | [production_loop](production_loop.md) |
| 任务恢复与交付 | [协作规则](cloud_production.md) |

当前设计正文直接维护完整版本；冻结来源与运行原件只为确实需要的校验／复现保留。记录有效不等于游戏品质或用户已经认可。
