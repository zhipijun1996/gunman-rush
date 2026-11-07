# Gunman Rush

Godot 4.7.2 Standard、类型化 GDScript，目标为固定世界类银河恶魔城。正常入口：`project.godot` → `game/application/world/fixed_world.tscn` → FixedWorldApp；旧DemoApp保留回归。

## 按任务加载

1. 核对分支、工作区和基线，读 [当前状态](docs/project/current_state.md)。
2. 从 [任务表](docs/project/tasks.md) 找本次父议题，只读其 `docs/project/worklines/<议题>/` 当前交接中本次子任务与直接依赖。
3. 用 [模块导航](docs/project/module_map.md) 定位代码与验证，用 [文档索引](docs/README.md) 找相关设计圣经、对象规范和参数来源，按需选相关 Skill。

## 文档与实现

项目管理写当前工作与交接；设计圣经写长期约束；对象规范从开发者视角写玩家可感知的行为、反制和视听表现；临时文件在任务结束时清理。现行圣经和对象规范是设计权威；固定世界拓扑的唯一导入源与派生关系见 [世界输入](docs/data/world/README.md)。房间任务只按 ID 提取目标房、邻接和相关对象，不全文读取世界 JSON。

长期规范按最终交付件维护：直接重整受影响正文，删除被替代、重复和过时内容，使全文完整、自洽、准确，不追加补丁、修订说明或历史尾注。每条规则只定义一次，其余引用。

功能修改先读相关规范和真实消费者；设计有未决取舍时按需用 `design-grill`，讨论期间只整理会话结论，最终设计确认后再落稿。先更新受影响的规范，再改代码／配置，同一任务同步交付；已准确描述的正文无需为修复实现而制造改动。数值只维护在实际配置／Definition，代码结构、字段映射和检查归模块导航。系统职责、允许依赖、状态主人和跨系统契约归 [架构](docs/project/architecture.md)，系统边界变化时读取；日常内容打磨不默认加载全项目架构或原始附件。

## 管理与验证

普通修复、规则调整、工程和文档任务只需任务表一行及工作线一份当前交接。任务表是进度状态的唯一可编辑来源；交接写目标、分支／SHA、写集、结果、实际检查、阻塞及下一动作，不复制状态。历史由Git／PR追溯；本轮已放弃的旧PR不再择取。

新区域、新地图、新怪物等新内容按需使用质量卡，重点检查美术统一和玩家体验，只写适用项；结构灰盒验收真实连接、状态和可玩结构，正式内容另验美术与完整战斗。默认由 Codex 实际运行并审查；用户试玩、真机和额外独审仅在本次任务明确需要时作为完成条件。工作完成、技术结果、专业判断、用户反馈和设备结果分别记录。方法见 [开发与验收](docs/project/development.md)。

日常检索遵守.gitignore/.ignore；大型世界输入用room_context.py按房查询；原始附件和录制测试输入由消费者按需读取，不作为现行规则上下文。临时日志、截图、录屏及报告写入build/或构建产物，交接保留必要结论与链接。

日常验证：`python3 tools/ci.py` 四项；专项从模块导航及 `python3 tools/harness.py --list` 选择；文档运行 `python3 tools/check_docs.py`。只声明实际覆盖。

## 实现与协作

输入提交意图，PlayerMotor 唯一执行玩家运动；表现消费已接受事件。生命周期、随机流、奖励／交易幂等、死亡优先与永久／休息周期／挑战尝试／动作瞬态边界按相关合同。

房间美术、Underworld 地形、47 邻接、景深与光影制作使用 [godot-room-art](.agents/skills/godot-room-art/SKILL.md)；已认可标准仍以 Visual Bible 和区域 Bible 为准。素材包接入状态与导入方法见该 Skill 的 `references/cloud-import.md`。关卡与能力设计继续由 godot-recoil-level-design 负责。

新代码归 `game/` 所属功能。`scripts/`、`scenes/`、`resources/` 仍有正式消费者，移动／删除须核引用、UID、动态加载、导出和版本。从最新 main 开主题分支，PR 面向 main；并行会话隔离写集与工作树，保护用户改动及密钥。合并、发布按本次授权，交接见 [协作规则](docs/project/cloud_production.md)。
