# Gunman Rush

Godot 4.7.2 Standard、类型化 GDScript 动作肉鸽。正式入口：`project.godot` → `game/application/demo.tscn` → DemoApp。

## 按任务加载

1. 核对 Git 分支、工作区、任务基线，读 [当前状态](docs/project/current_state.md)。
2. 从 [活跃任务](docs/project/tasks.md) 定位父议题，只读其 `docs/project/worklines/<议题>/` 和直接依赖；旧 ID 按需查归档。
3. 用 [模块导航](docs/project/module_map.md) 找代码与检查，用 [文档分类](docs/README.md) 找相关设计圣经、对象数据与参数来源。
4. 按描述选择相关 `.agents/skills/*/SKILL.md`；专业细则和 [质量方法](docs/project/development.md) 按需加载。

## 文档与实现

- 项目管理记录当前状态、依赖、进度和交接；设计圣经规定长期方向与约束；具体数据从开发者视角描述玩家可感知的行为、招式、反制和视听表现；临时审计／中间稿在任务结束时清理。
- 设计圣经与具体数据按最终交付件维护：直接重整正文，使全文完整、自洽、准确；删除被替代和重复内容。新规则融入原有章节与步骤，不追加补丁、修订说明或重复尾注。每条规则只定义一次，其余引用。
- 功能修改先读相关圣经和对象规范；设计尚未定案时按需用 `design-grill` 澄清，讨论期间不改正式文档，用户确认最终设计后重整正文。先更新受影响的设计／数据，再改代码与配置，同一任务同步交付。具体数值只维护在运行配置／Definition；对象规范保留简短配置入口，代码结构、字段映射和检查方法归模块导航／工程文档。
- 沿用现有文件；进度、验收结论和恢复信息归工作线，候选与未实现项如实标明。交付前通读修改后的整篇文档，检查重复、冲突和职责混杂。历史由 Git、PR 和必要原始证据追溯。

## 实现约束

输入提交意图，PlayerMotor 唯一执行玩家移动；表现消费已接受事件。Run／Stage／Actor 生命周期、随机流、奖励与交易幂等、死亡优先及 Run／Meta 边界按相关主题合同。

新代码归 `game/` 所属功能。`scripts/`、`scenes/`、`resources/` 仍有正式消费者，移动／删除核对引用、UID、动态加载、导出和版本。保护用户改动及密钥；从最新 main 开主题分支，PR 面向 main，合并／发布按本次授权。

## 验证与交接

日常验证：`python3 tools/ci.py` 四项。专项通过 `python3 tools/harness.py --list` 和 `--check <ID>` 选择；文档运行 `python3 tools/check_docs.py`。具体方法见 [Harness](docs/project/harness.md)，只声明实际覆盖。

更新工作线的分支／SHA、写集、完成项、检查与证据、阻塞及下一命令。全局表只登记父议题一行，阶段和局部质量卡留在工作线；产品事实变化时更新当前状态。交付前清理临时文件，保留必要来源、许可及可恢复证据。技术、独审、用户与真机结论分别记录。
