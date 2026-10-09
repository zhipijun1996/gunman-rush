# 开发任务

任务状态与远程 Issue 链接后续同步。M0 完成表示规划就绪，不代表游戏完成。

| ID | 阶段 | 依赖 | 状态 | 交付与验收 |
| --- | --- | --- | --- | --- |
| DOC-01 | M0 | — | done | 文档、模板、配置；check_docs 通过 |
| ENV-01 | M1 | DOC-01 | review | 锁定工具链已安装并实测；Android/Windows 灰盒导出通过；Cloud 界面配置发布待用户完成，见环境报告 |
| CORE-01 | M1 | ENV-01 | review | 工程、Router、Controller、Motor、可启停 N 跳；解析与真实物理测试通过；A01 窗口启动及 A04 手感待验收 |
| CORE-02 | M1 | CORE-01 | review | 射击反冲、0/N资源、圆形 sweep 攻击弹体与独立 Damageable 已实现；A05–A08/A18射击/A31自动通过；手感待验收 |
| INPUT-01 | M2 | CORE-02 | awaiting-device | 三指独立、触屏/键鼠释放射击及取消已实现并自动测试；A09–A10真机待验收 |
| INPUT-PC-01 | M2 | INPUT-01 | awaiting-device | 回中射击/防抖/重武装/断连取消、配置与提示已实现；A24–A26自动部分通过；真实手柄与A27轨迹待验收 |
| WIN-01 | M2 | INPUT-PC-01 | awaiting-device | Windows x86_64 EXE/PCK单独导出通过；A28 Windows实机启动/操作/通关待验收 |
| APK-01 | M2 | INPUT-01 | awaiting-device | 含基础动作/触屏的debug APK导出、签名及配置打包检查通过；A09–A10真机待验收 |
| WORLD-01 | M3 | CORE-02 | awaiting-device | 独立补充点/单向平台/扫掠锯轮/开关/安全检查点已实现；A11–A14/A19自动部分通过，试玩待验收 |
| LEVEL-01 | M3 | WORLD-01, APK-01 | awaiting-device | 固定挑战候选可切换；动作链/20–30秒目标未证明，A15三次通关与A16性能待真机，不开始GEN |
| ART-01 | M3 | DOC-01 | ready | 三种风格小样及音乐工具评估；不锁最终风格 |
| GEN-01 | M4 | LEVEL-01 | planned | 5–8模块、Seed+manifest、验证；A17 |
| LOOP-01 | M5 | GEN-01 | planned | 局内强化与风险选择，先补细化规格 |

本轮已实现 CORE-02 及按依赖可独立推进的基础输入/世界对象，产出 APK 供用户试玩。详情见 [本轮验证报告](core02_report.md)。ENV-01、CORE-01人工/界面项仍review。本分支叠加未合并PR #12，不假定main已包含工程，不自动合并。首轮用户试玩指出手感/抬升不足，正以可回退短爆发与敏捷横移进行试调（不是已通过手感验收）。下一步完成Android固定挑战真机验收与针对反馈修复，GEN-01仍planned。

## GitHub 执行入口

- [ENV-01 / #1](https://github.com/zhipijun1996/gunman-rush/issues/1)
- [CORE-01 / #2](https://github.com/zhipijun1996/gunman-rush/issues/2)
- [CORE-02 / #3](https://github.com/zhipijun1996/gunman-rush/issues/3)
- [INPUT-01 / #4](https://github.com/zhipijun1996/gunman-rush/issues/4)
- [APK-01 / #5](https://github.com/zhipijun1996/gunman-rush/issues/5)
- [WORLD-01 / #6](https://github.com/zhipijun1996/gunman-rush/issues/6)
- [LEVEL-01 / #7](https://github.com/zhipijun1996/gunman-rush/issues/7)
- [ART-01 / #10](https://github.com/zhipijun1996/gunman-rush/issues/10)
- [GEN-01 / #8](https://github.com/zhipijun1996/gunman-rush/issues/8)
- [LOOP-01 / #9](https://github.com/zhipijun1996/gunman-rush/issues/9)

## 各任务新增约束

CORE-01 同时验收 A18 跳跃部分；CORE-02 验收 A18 射击部分。WORLD-01 加 A19。ART-01 加 A22，候选必须在已确定方向内。后期敌人/Boss/持久存档在 LOOP-01 规划中分别建任务并细化数值，不塞进 MVP。

跨平台补充已写入架构、输入、路线图和验收。后期存档与 Steam 平台适配分别细化 A29、A30；普通游戏开发无需 Steam SDK/账号。Android 与 Windows 记录独立构建和运行证据，Linux/macOS/Steam Deck 尚未开展。新增 INPUT-PC-01、WIN-01 尚未建立远程 Issue，任务表为权威索引。

## 2026-10-09 可变跳高 / Web迭代补充

CORE-01/CORE-02手感增量实现短按小跳、长按大跳与三设备持有/释放统一意图；默认参数靠近已核实社区预设，原始出处与尺度选择见variable_jump_report.md。实际295断言/0失败，不替代用户手感验收。Android/iPhone以后共用Pages网页快速迭代，APK改为按需导出；固定挑战真实通关与性能仍awaiting-device，GEN-01不提前启动。

## 空中瞄准慢时增量

用户授权CORE/INPUT手感扩展：AirFocusAbility独立组件、主动瞄准意图、全场时间域、真实秒精力消耗/接地恢复、腾空累计上限、HUD精力条与取消恢复。新增自动测试与网页试玩证据记于handoff/acceptance_tests；真实Android/iPhone手感仍awaiting-device。道具只预留可消费的参数，不抢先实现GEN。
