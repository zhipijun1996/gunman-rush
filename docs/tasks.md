# 开发任务

任务状态与远程 Issue 链接后续同步。M0 完成表示规划就绪，不代表游戏完成。

| ID | 阶段 | 依赖 | 状态 | 交付与验收 |
| --- | --- | --- | --- | --- |
| DOC-01 | M0 | — | done | 文档、模板、配置；check_docs 通过 |
| ENV-01 | M1 | DOC-01 | review | 锁定工具链已安装并实测；Android/Windows 灰盒导出通过；Cloud 界面配置发布待用户完成，见环境报告 |
| CORE-01 | M1 | ENV-01 | review | 工程、Router、Controller、Motor、可启停 N 跳；解析与真实物理测试通过；A01 窗口启动及 A04 手感待验收 |
| CORE-02 | M1 | CORE-01 | in_progress | 射击反冲、0/N资源、攻击弹体体积 sweep 与独立 Damageable；A05–A08、A18射击、A31 |
| INPUT-01 | M2 | CORE-02 | planned | 多指、取消、键鼠释放射击一致；A09–A10 自动部分 |
| INPUT-PC-01 | M2 | INPUT-01 | planned | 手柄回中射击、防抖重武装、断连取消、输入档案与提示；A24–A27 |
| WIN-01 | M2 | INPUT-PC-01 | planned | Windows 正式构建入口与实机键鼠/手柄验收；A28，当前仅灰盒导出通过 |
| APK-01 | M2 | INPUT-01 | planned | 可重复 debug APK、构建日志；A09–A10 真机部分 |
| WORLD-01 | M3 | CORE-02 | planned | 补充点、单向平台、机关、检查点；A11–A14 |
| LEVEL-01 | M3 | WORLD-01, APK-01 | planned | 固定挑战；A15–A16；真机前 awaiting-device |
| ART-01 | M3 | DOC-01 | ready | 三种风格小样及音乐工具评估；不锁最终风格 |
| GEN-01 | M4 | LEVEL-01 | planned | 5–8模块、Seed+manifest、验证；A17 |
| LOOP-01 | M5 | GEN-01 | planned | 局内强化与风险选择，先补细化规格 |

当前继续 CORE-02，用户补充攻击性和体积碰撞弹体；按依赖完成基础移动、跳跃、瞄准/释放射击及触屏操作后生成 APK 供真机测试。ENV-01、CORE-01 人工/界面项仍 review。本轮基于未合并 PR #12 的实现开发，不假定 main 已包含工程，不自动合并。

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
