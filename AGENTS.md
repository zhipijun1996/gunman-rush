# Codex 工作规则

## 权威来源

产品目标：docs/game_design.md。物理规则：docs/player_mechanics.md。输入：docs/controls_contract.md。资源：docs/combat_and_recharge.md。参数原型唯一来源：config/player_tuning.json，开发 Resource 时从该文件迁移并同步文档引用，不维护两套数值。
任务状态：docs/tasks.md；验收证据：docs/acceptance_tests.md 与 docs/handoff.md。

## 执行流程

读取规则与当前 Git 状态 → 选择依赖满足任务 → 创建 feature/fix/docs 分支 → 小范围实现 → 验证 → 修复 → 更新状态和证据 → 提交并推送 → 创建 PR → 继续可独立任务。
用户已授权项目内文档、可逆实现、验证、分支、提交、推送和开发任务管理。日常工作不逐项请示。默认不自动合并 PR、发布商店、使用付费服务或更改核心玩法；这些需明确授权。禁止强推、覆盖用户改动、提交密钥。

## 实现约束

Godot 4.7.2 Standard + 类型化 GDScript；先验证安装版本再创建工程。文件 snake_case，类型 PascalCase。组合优先；不用没有实际消费者的框架。输入不得改人物位置。PlayerMotor 是唯一 move_and_slide 调用方，每物理帧最多一次。表现订阅事件，不能决定玩法结果。
参数可配置；新能力使用资源策略和能力配置，不能在关卡中硬编码玩家脚本。固定/生成关卡共用对象契约。随机生成晚于固定关卡真机验收。

## 验证与完成

每次运行 `python3 tools/check_docs.py`。创建工程后运行 `godot --headless --path . --editor --quit`。M1 必须新增有失败退出码的 tests/run_tests.gd，然后运行 `godot --headless --path . --script tests/run_tests.gd`。
针对改变运行必要测试。记录命令、版本、退出码、提交与输出；未执行写未验证。禁止降低标准、删除失败测试来伪造通过。输入和手感真机验收由用户实际试玩，不可用 headless 代替。
任务完成需实现、相应检查通过、文档同步、证据和提交齐全。需要真机的任务保持 awaiting-device，不能标 done。

## 会话恢复

结束前更新 docs/handoff.md：分支、提交、已完成、失败、阻塞、下一任务与命令。阻塞时推进独立工作，不声称后台无限运行。没有用户明确要求，不启用子代理。
