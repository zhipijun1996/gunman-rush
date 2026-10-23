# DEMO-UI-01 R3：资源回归测试写集

作者 `/root/independent_review` 本轮是测试实现作者，**不是这些测试的独立审查者**。未改生产脚本／道具／配置，未运行 Godot，未提交。由 root 串行引擎租约运行，由 ui_audit 另行独审。

当前正式：`r3_energy_runner.gd`，默认 `enable_shot_energy()` 消费真实 `time_energy_v2.tres`，不替换正式资源或注入假 HUD 数字。显式 fixture 仅用于出生点、Damageable 健康／位置、耗尽的 D/H 资格、资源边界和容量增长；真实 Motor、Router、Controller、发射／beam、伤害政策、焦点状态、BuildState、HUD/ring仍实际运行。

覆盖：默认一发；零时间能量可开枪；枪消耗零能量；真实命中只回一发不回时间能量并去重；枪瞄／钩瞄只在接受慢时时按真实秒消耗；停瞄空中不回；shot policy本身不回；真实落地通过 AirFocus唯一恢复；地面瞄准不耗；普通／三级激光实际 beam 在0与60能量都可运行且无额外消耗；五件v2道具真实授予／撤销及非空效果；本飞行容量增长不赠送资源；健康增长不回血；实际子弹与钩接触D/H资格恢复；ring实际绑定／比例／Motor Canvas变换；取消／暂停／死亡／解绑无残留显示或慢时所有权。

建议由租约持有者运行：

```sh
bash tools/godot.sh --path . --headless --script tests/demo_ui_01/r3_energy_runner.gd
bash tools/godot.sh --path . --headless --script tests/plains_experience_energy_runner.gd
bash tools/godot.sh --path . --headless --script tests/grapple_focus_hud_runner.gd
```

新专项完成标记为 `DEMO UI R3 ENERGY: N checks, 0 failures`，退出0；结构化结果 `build/verification/demo-ui-r3/energy.json`。有失败／缺标记应保留并修复，本文不预先签通过。

历史边界：`r3_d079_original.gd` 是旧 D079 runner 的**原字节档案**，不是当前规则执行入口，不把它放进 current 自动测试集。`tests/fixtures/demo_ui_01_r3/history.json` 记录原提交和该原件／五件旧道具的完整SHA；独立逐字节核查均吻合。迁移后的原入口 `tests/plains_experience_energy_runner.gd` 保留全部66个源码 check 调用，旧战斗／构筑测试明确用两发fixture、原 `plains_shot_energy.tres` 与旧握柄／铃匣引用；实际 DemoApp／ModuleLab继续检查当前v2共享资源和实际focus道具效果。`grapple_focus_hud_runner.gd` 仅将原默认 enable 绑定为显式旧D079资源，保留25项旧分离资源断言，不代表当前正式HUD。

没有用回退正式配置、降低断言、删测试或扩展生产资源上限满足历史。实体设备、自然战斗、用户认可和独立审查均不由本测试写集签署。
