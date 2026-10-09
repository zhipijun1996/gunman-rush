# 开发任务

任务状态与远程 Issue 链接后续同步。M0 完成表示规划就绪，不代表游戏完成。

| ID | 阶段 | 依赖 | 状态 | 交付与验收 |
| --- | --- | --- | --- | --- |
| DOC-01 | M0 | — | done | 文档、模板、配置；check_docs 通过 |
| ENV-01 | M1 | DOC-01 | ready | 核实并安装工具链，版本证据；引擎阻塞可独立记录 SDK |
| CORE-01 | M1 | ENV-01 | planned | 工程、Router、Motor、移动跳跃；A01–A04；测试入口 |
| CORE-02 | M1 | CORE-01 | planned | 射击反冲与资源事务；A05–A08 |
| INPUT-01 | M2 | CORE-02 | planned | 多指、取消、键鼠一致；A09–A10 自动部分 |
| APK-01 | M2 | INPUT-01 | planned | 可重复 debug APK、构建日志；A09–A10 真机部分 |
| WORLD-01 | M3 | CORE-02 | planned | 补充点、单向平台、机关、检查点；A11–A14 |
| LEVEL-01 | M3 | WORLD-01, APK-01 | planned | 固定挑战；A15–A16；真机前 awaiting-device |
| ART-01 | M3 | DOC-01 | ready | 三种风格小样及音乐工具评估；不锁最终风格 |
| GEN-01 | M4 | LEVEL-01 | planned | 5–8模块、Seed+manifest、验证；A17 |
| LOOP-01 | M5 | GEN-01 | planned | 局内强化与风险选择，先补细化规格 |

下一项 ENV-01。当前会话完成 M0，未开展游戏实现。独立可做 ART-01 能力调查，但不得因其阻塞推迟角色开发。

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
