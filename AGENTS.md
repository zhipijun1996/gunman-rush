# Gunman Rush

Godot 4.7.2 Standard、类型化 GDScript 动作肉鸽。正式入口：`project.godot` → `game/application/demo.tscn` → `DemoApp`。

## 按任务加载

1. 检查 Git 分支、工作区和任务基线；读取 [当前状态](docs/current_state.md)。
2. 在 [任务索引](docs/tasks.md) 搜索任务 ID；接续工作只读该任务的 `docs/worklines/<任务>/`。
3. 从 [模块导航](docs/module_map.md) 选具体代码、设计和验证入口；需要调用关系时再读 [架构](docs/architecture.md)。
4. 按 `.agents/skills/*/SKILL.md` 的描述选择相关技能。专业细则只在该专业任务加载；共用质量规则见 [开发质量](docs/development_quality.md)。
5. 默认在导航指定的代码目录检索。`docs/evidence/`、`docs/archive/` 和冻结来源仅按复现需要读取。

## 全局约束

- 参数来自 `config/` 与实际 Definition Resource；设计文档描述行为，注册表标记当前版本。
- 输入提交意图；PlayerMotor 唯一执行玩家移动。表现消费已接受事件。
- Run／Stage／Actor 生命周期、独立随机流、奖励与交易幂等、死亡优先及 Run／Meta 边界按对应主题设计实现。
- 新代码归 `game/` 所属功能。旧目录仍有正式资源和版本消费者，移动／删除先核实际引用、UID、动态加载和导出。
- 保护用户改动和密钥；从最新 main 建主题分支，PR 面向 main。合并与发布按本次用户授权范围执行。

## 验证与交接

日常验证运行 `python3 tools/ci.py`（project／import／smoke／contracts 四项）。开发按修改选择相关专项：`python3 tools/harness.py --list` 查看命令，`--check <ID>` 执行；纯文档可直接运行 `python3 tools/check_docs.py`。具体方法见 [Harness](docs/harness.md)，只声明实际执行范围。

交接更新任务自己的工作线文件：分支／SHA、写集与负责人、完成项、已执行检查及证据、阻塞、下一动作。任务表仅更新一行；产品行为改变时更新当前状态及对应设计正文。

所有文档按最终交付件维护：直接修改并整理正文，使全文成为完整、自洽的当前版本；删除被替代内容、历史解释和补丁式强调，不追加“最新补充／覆盖旧规则”等修订段落。交接直接更新当前字段，变更历史由 Git 保存。候选设计与未实现项仍须如实标明状态。

技术、GUI、独立审查、用户体验与真机结果按实际证据分别记录。未执行的检查标未验证。
