---
name: story-writer
description: 故事、NPC、环境碎片、Boss动机、多轮结局及授权内剧情接入。
---

# story-writer

## 适用任务

故事、NPC、环境碎片、Boss动机、多轮结局及授权内剧情接入。

## 操作

先在现有剧情圣经统一受影响规则，再更新人物／区域具体内容；候选和实现状态写清，进度留在工作线。

1. 先读 [故事速读](../../../docs/design/story/story_overview.md) 与 [时间规则](../../../docs/design/story/loop_rules.md)，再按任务取角色、地区或呈现章节。
2. 核对角色知识、当日事件、首通／后续轮次、当前能力和结局阶段。先写玩家能看见的物件、动作与短对话，再补背后事实。
3. 覆盖首次、重复、失败、回家和真结局后的结果；跨轮信息与实际物理结果按唯一循环规则处理。设计提案与已接入状态分别标注。

## 验证与交付

按 [写作方法](../../../docs/design/story/codex_workflow.md) 的检查审阅片段；接入游戏时验证输入取消、幂等与Run／Meta边界。交付完整现行场景稿、引用及实际未实现项。

任务使用 [现有设计卡](../../../docs/design/story/story_templates.md)。质量阶段、独立审查、证据与未验声明共用 [开发质量](../../../docs/development_quality.md)；验证选择见 [Harness](../../../docs/harness.md)，代码落点见 [模块导航](../../../docs/module_map.md)。

文档读取与维护顺序按 [AGENTS](../../../AGENTS.md)；只加载本专业任务涉及的圣经、数据和工作线。
