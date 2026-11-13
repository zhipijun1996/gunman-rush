# 内容开发

从本次任务选择相关设计圣经、对象规范和真实消费者。现行正文是设计权威；原始附件只供溯源，不作为另一套规则强制载入。先重整受影响的规范，再同步实现、配置和素材。

## 制作顺序

1. 明确本次范围、玩家操作与判断、合法构筑及未决选择。需要讨论时使用 design-grill，最终确认前不改正式文档。
2. 写完整的现行设计，说明行为、反制和视听表现；参数引用唯一配置，代码定位放模块导航。
3. 做出真实可玩的样板，在正式镜头下检查角色、地形、敌人、动作、声音和反馈。成立后再扩第二种空间／组合，允许结构灰盒，按任务约定检查适用项。
4. 按实际影响做功能回归；新内容重点记录美术统一和玩家体验。具体方法见 [开发与审查](development.md)。
5. 将结果、未验和下一动作写入父任务唯一交接，清理临时稿并保留必要原件。

## 房间美术的专业分工

设计规则归Visual Bible／区域Bible，对象与分类归各自正文，代码与现有能力归模块导航，进度与未实现方案归当前工作线。场景美术生产主流程唯一为[godot-room-art](../../.agents/skills/godot-room-art/SKILL.md)，区域套件、引擎前置、跨房型检查均由它维护；职能技能不再各自复制制作顺序。

| 专业入口 | 持有的工作 |
| --- | --- |
| [region-creative-director](../../.agents/skills/region-creative-director/SKILL.md) | 主题、体验、区域语言与成本边界 |
| [godot-room-art](../../.agents/skills/godot-room-art/SKILL.md) | 美术生产主流程，区域套件与跨房型适用范围 |
| [scene-composer](../../.agents/skills/scene-composer/SKILL.md) | 整房／连续机位的体量、入口、负空间与组合布局 |
| [art-director](../../.agents/skills/art-director/SKILL.md) | 材质母版、资产家族、完整边界和来源 |
| [visual-director](../../.agents/skills/visual-director/SKILL.md) | 实帧诊断，区分共享缺陷、单房构图与工程损失 |
| [godot-recoil-level-design](../../.agents/skills/godot-recoil-level-design/SKILL.md) | 玩法、几何、能力门、恢复与真实控制器复验 |
| [level-module-creator](../../.agents/skills/level-module-creator/SKILL.md) | 局部房间／组合的同源定义与实际动作验证 |
| [region-generator](../../.agents/skills/region-generator/SKILL.md) | 固定世界装配、邻接、状态和授权范围的批量推进 |
| [game-quality-gate](../../.agents/skills/game-quality-gate/SKILL.md) | 按范围审查技术、视觉、复用与体验证据 |
| [project-integration](../../.agents/skills/project-integration/SKILL.md) | 依赖、构建、发布与来源一致性 |

按当前任务选入口，不要求每次通读或同时执行全部技能。固定机位原型不自动升级为多房生产方式；同批套件跨几何成立后仍逐房审看。新组合先查已有注册与members能力，不因方法整理另建万能模块或平行素材目录。尚未实现或未验证的能力必须保留该状态。

## 按需工具

固定世界按任务交接由普通 Codex 直接实施。旧随机地区自动量产 route/content_plan 已停止；`visual_director.py route`转交旧route时也停止，不作为固定世界前置。历史数据分析仍可显式使用。地区正文及技术引用由 docs/data/creative_direction/ 注册表绑定，修改正文同步摘要及本次确认依据，历史验收不改签。

[自动生产协议](production_loop.md) 仅在显式使用执行器时读取，保留已有命令、预算、来源和写集保护。普通任务不必使用执行器或质量卡。专业方法从相关 Skill 选择，不通读全部技能。
