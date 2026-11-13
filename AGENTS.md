# Gunman Rush

Godot4.7.2 Standard／类型化GDScript。固定世界入口project.godot→game/application/world/fixed_world.tscn→FixedWorldApp；旧Demo／手机工作台退役，保留正式消费者用的底层能力。

## 按任务加载

1. 核分支、工作区、基线，读[当前状态](docs/project/current_state.md)。
2. 从[任务表](docs/project/tasks.md)定位父议题，仅读docs/project/worklines/对应当前交接、子任务／直接依赖。
3. 内容制作执行[开发流程](docs/project/development.md)六项检查；结果写现有交接，删除过时报告和无消费者旧实现，历史留Git。
4. 用[模块导航](docs/project/module_map.md)找代码与检查，[文档索引](docs/README.md)找圣经、对象规范、参数与相关Skill。

恢复后重读约束与未解决失败，摘要通过不代替现行源与证据。

## 文档与实现

项目管理写工作／交接，圣经写长期约束，对象规范写玩家可感知行为、反制和视听。现行圣经与对象规范是设计权威；世界导入与派生归[世界输入](docs/data/world/README.md)。房间仅取目标、邻接、相关对象，不全文读世界JSON。

长期规范按最终交付件维护：重整正文，清除被替代、重复和过时内容；保持完整自洽，不追加补丁、修订尾注。每条规则只定义一次，其余引用。

用户修改意见本次写回现行正文／方法／参数，并核索引、交接和消费者，不能只留聊天或补充报告。未决的用户／规范／源冲突须说明具体来源、内容及影响，请用户决定；暂停依赖项、继续无关工作。用户已明确的新规则直接落实并清旧说法，无需再问；实现落后按规则修复，不反改设计迁就实现。

改功能先读规范与真实消费者；未决设计按需用design-grill，讨论先记结论，最终确认后落稿。规范先于实现／配置同步交付，已准确正文不制造改动。数值只归配置／Definition；结构、字段映射与验证归模块导航。系统职责、依赖、状态及契约归[架构](docs/project/architecture.md)，边界变化时读；日常内容不默认加载全架构或原始附件。

## 管理与验证

普通任务用任务表一行、工作线一份交接。进度只在任务表编辑；交接写目标、分支／SHA、写集、结果、检查、阻塞和下一动作，不复制状态。历史留Git／PR，已放弃PR不择取。

新内容按需质量卡，只记适用项；灰盒验结构／状态／可玩性，正式内容另验美术和完整战斗。默认Codex实跑审查；用户试玩、真机、额外独审仅在任务明确要求时成为完成条件。工作、技术、专业判断、用户反馈与设备结果分记，方法沿开发流程。

检索遵守.gitignore／.ignore，大型世界输入用room_context.py按房读；原始附件／测试录制按需加载，不当现行规则。临时文件任务后清理；日志、截图、录屏和报告进build/，交接留结论与链接。

日常CI：python3 tools/ci.py四项；专项从模块导航及python3 tools/harness.py --list选；文档跑python3 tools/check_docs.py。只声明实际覆盖。

## 实现与协作

输入提交意图，PlayerMotor唯一执行运动，表现消费已接受事件。生命周期、随机流、奖励／交易幂等、死亡优先及永久／周期／尝试／瞬态边界沿相关合同。

场景美术、地形、47邻接、景深与光影用[godot-room-art](.agents/skills/godot-room-art/SKILL.md)，设计权威仍归Visual Bible／区域Bible；素材接入见该技能references/cloud-import.md。关卡与能力设计用godot-recoil-level-design。

新代码归game/；scripts/、scenes/、resources/仍有正式消费者，移动／删除前核引用、UID、动态加载、导出和版本。新任务从最新main开主题分支、PR面向main；并行隔离工作树与写集，保护用户改动和密钥。合并／发布按本次授权，沿[协作规则](docs/project/cloud_production.md)。
