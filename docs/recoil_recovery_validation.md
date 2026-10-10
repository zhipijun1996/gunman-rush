# 反冲补救断桥：实际运动证据

本轮实现 `plains_recovery_bridge`，作为断桥横渡中的低压力补救教学段。平台为 x=0–300 / 480–800、地面 y=600，荆棘位于缺口底部 y=700。入口与出口均有完整站立空间；没有新增奖励、移动规则、能力或虚拟补充次数。

默认一跳、两次空中射击保持不变。正常在 x=280 起跳即可跨越 180 像素缺口，不强制开枪；在 x=190 过早起跳的相同输入会落到接收平台以下。此时在第18、22或26物理帧向后释放一枪，反冲可把人物推到宽接收平台。救回只消耗一次射击，仍保留一发；不是宣称任意时机或任意失误都能救回。三个时机采样覆盖约133毫秒，尚待手机操作验证。

左右镜像均通过独立实际 PlayerMotor 验证。只在初始出生放置角色，此后通过 InputRouter 输入；成功轨迹持续检查24×36完整碰撞体的帧间扫掠、连续位移、实际落地、端口和方向。救回同时生成具有伤害与半径的真实弹体。无射击负例明确落下，不以包络估计代替可达性。

验证工具：Godot 4.7.2 Standard `4.7.2.stable.official.ed1daf0bf`。

- `timeout 100 bash tools/godot.sh --headless --path . --script tests/recoil_recovery_runner.gd`：93 assertions / 0 failures，退出0。
- 同命令增加 `--fixed-fps 60`：93 / 0，退出0。
- 固定时钟命令增加 `-- --intentional-failure`：94 / 1，退出1，保留失败退出机制。
- `timeout 120 bash tools/godot.sh --headless --path . --fixed-fps 60 --script tests/branch_library_runner.gd`：1096 / 0，退出0。包括新增模块的平移/镜像与完整原模块库验证。
- `python3 tools/check_docs.py`：33 required documents / 85 task dependencies，通过。

原始日志保存在忽略提交的 `build/verification/recoil-recovery/`。组装整关、浏览器和真机结果由本轮交接统一记录，此处不把独立模块测试视为其通过证据。美术复用当前平原表现层，视觉最终验收仍待试玩。
