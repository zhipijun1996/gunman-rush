# 项目结构

正式入口为`project.godot`和`game/application/demo.tscn`。 [模块导航](module_map.md) 提供具体代码、设计和检查； [架构](architecture.md) 描述状态所有权。

| 路径 | 职责 |
| --- | --- |
| `game/` | 按功能组织正式实现、专属场景与局部资源 |
| `experiments/` | 可启动开发入口、练习配置与有限切片 |
| `config/` | 当前参数、authoring、目录与选定版本 |
| `assets/` | 当前图声字体、原图、来源和许可 |
| `scripts/` | 仍在使用的Definition身份、森林布局及显式版本实现 |
| `scenes/bosses/` | BossFactory仍直接消费的场景 |
| `resources/` | 当前武器／Boss／玩家等定义与开发fixture |
| `tests/`、`tools/` | 真实行为回归、内容检查、Harness、构建与交付 |
| `.github/workflows/` | CI调度和同源报告合流 |
| `docs/` | 当前设计、导航与任务索引 |
| `docs/worklines/` | 每个任务自己的范围、结果和当前交接 |
| `docs/quality/`、`docs/evidence/` | 必要质量记录、来源及原始运行证据 |
| `docs/archive/` | 仍有明确复现消费者的冻结输入，按需读取 |
| `build/`、`preview/`、`.godot/` | 生成物、临时预览与引擎缓存 |

## 放置与修改

每项状态和参数有一个所有者。新代码放所属功能，调用实际服务／工厂；同义逻辑抽取时连真实消费者一起迁移。专属场景和资源靠近功能，原图声及许可保持在资产目录。

移动／删除核对`preload/load/extends/ext_resource`、class_name、动态拼接、注册表、UID、启动入口、导出allowlist、Manifest版本与测试输入。保存源文件和进入正式PCK分别判断。

当前设计直接修改完整正文，历史版本由Git保存。冻结证据只保留当前校验、复现或许可确实需要的输入，不作为另一份可编辑规则。临时输出写build；跨会话恢复使用任务自己的工作线。
