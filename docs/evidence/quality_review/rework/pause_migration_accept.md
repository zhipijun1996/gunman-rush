# 暂停测试语义迁移：独立局部 ACCEPT

Verdict: **ACCEPT（仅本报告声明范围）**。

审查者 `/root/independent_gameplay_audit`，独立只读生产源码并实际运行定向测试，未参与该修复。源 HEAD=`89ca510cad97b8940389d25423ab7869313734eb` dirty；2026-10-13最终核对以下源哈希未变。不得把此报告用于整份返工、普通敌人表现、地形、美術、设备或玩家认可放行；原 `independent-rework-review.md` 的整体REJECT与其他未解问题保留。

## 唯一通过范围

`tests/plains_enemy_attacks_runner.gd:129–159`暂停期待从“清除telegraph/敌弹并给recovery”改为“冻结原状态/时钟/弹体，恢复同一攻击继续推进”，以及所验 DemoApp 公共 `_pause_for_menu`、`_resume_from_menu`、`abandon_run`/`_run_ended`路径。旧测试要求的行为正是已确认IQA-01无代价打断攻击exploit，迁移是修正契约，不是删除失败以掩盖回归。

生产 `_pause_for_menu()` (`scripts/demo/demo_app.gd:699`)清输入、结束慢时，再暂停SceneTree，敌人和敌弹PAUSABLE；不再取消战斗攻击。放弃本局仍沿 `abandon_run()` (:804)→director.end_failure→`_run_ended`取消攻击。新测试对phase、state_time、cooldown、实际弹体位置与存活、health、serial逐项验证；等待3帧检查冻结、恢复3帧检查旧弹推进且不重发、abandon检查销毁。原套件death/stage/actor_epoch取消、墙体挡弹与重复伤害无敌检查未删除或放宽。

## 实际验证与限制

实际通过 `tools.run_tests.run_engine`执行 `--headless --fixed-fps 60 --path . --script tests/plains_enemy_attacks_runner.gd`。原始日志 `build/verification/independent-rework-enemy-test.log`：Godot4.7.2，**42 assertions, 0 failures，wrapper exit0**。本次最终文件哈希核对复用这次已执行证据，未冒称又跑一遍。

该测试使用start_plains_regression回归消费者，显式设置telegraph/直接_fire创建状态夹具；是公共DemoApp暂停/清理路径的定向测试，不是自然遭遇完整试玩或全部GUI菜单/地图/商店/正式两图组合验证。上述更广范围不在本局部ACCEPT中。

退出还有18 ObjectDB实例及8 resources未释放诊断，原日志保留，本次未归因，不能声称零错误清洁退出、无泄漏或性能通过。没有玩家认可声明。

## 绑定文件 SHA256

| 文件 | SHA256 |
| --- | --- |
| scripts/demo/demo_app.gd | 5be7eb342005b9c59c1b529783b31c46e843f82f73134e4edfb028910268942f |
| tests/plains_enemy_attacks_runner.gd | a06a73333ef0c4dbbe503d1112c6adde566b3a94ab5a1b0540b0554dd64b50c1 |
| scripts/enemies/enemy_attack_behavior.gd | 2631c540f3d62b4ea313b60cdf935bf2feacbc998bb6a023afcbf4c98c1afe9d |
| scripts/enemies/enemy_attack_projectile.gd | dabc0f3e1e8b7aceaaed4a085c18b82fe19dfca483d772bb0dd9dcc6b0deaa06 |

差异守卫只能引用此暂停迁移范围和匹配的文件版本；文件后续改变需核对相关行为后再使用。完整历史、失败和Boss/Enemy审查继续见 `build/verification/independent-rework-review.md`。
