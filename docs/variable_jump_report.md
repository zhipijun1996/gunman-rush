# 可变跳高与手机网页迭代

2026-10-09；feature/snappy-shot-burst，PR #14，未合并。最新证据见handoff，前轮shot_burst报告保留历史。

## 已实现行为与来源

短按小跳、长按大跳，所有设备共用JumpAbility。按住最短4/60秒、最长9/60秒维持跳跃速度；释放在最短升程结束后截断仍属于跳跃的上行，包括维持窗口结束后的自然上升。落地/撞顶/取消清状态。新有效跳跃可以结束正在进行的爆发，射击解除跳跃升程控制，之后释放跳跃不会截断射击；同tick仍先跳后射。保持不会自动连跳，次数仍0/N可配置。

实际读取社区KnightInSilkSong固定提交3c673d3cbf15928f09a4c1f477e8ed1b2c4a8901的公开Unity包，并解析唯一Hero序列化数值；只保存数值/来源/摘要于[community_reference.json](community_reference.json)，不提交资产、包或解析依赖。它是社区移植预设，未证明官方原版或原版全局物理配置。

| 字段 | 社区预设 | 本项目选择 |
| --- | --- | --- |
| RUN_SPEED | 8.3 | 330px/s（约40px/单位） |
| JUMP_SPEED | 16.65 | -666px/s |
| 第二跳源码倍率 | 1.1 | -732.6px/s |
| JUMP_STEPS / MIN | 9 / 4 | .15s / .0666667s（本项目60Hz，社区步长未核实） |
| MAX_FALL_VELOCITY | 20 | 800px/s |
| DEFAULT_GRAVITY | .79倍率 | 保留本项目2600px/s²，不作无依据换算 |
| DASH_SPEED / TIME | 20 / .25s | 射枪原创爆发仍1100px/s × .14s = 154px |

## 实际验证

Godot4.7.2 Standard。`python3 tools/run_tests.py`退出0，295断言/0失败（254旧断言保留、14输入+27跳跃新增）。首跳真实峰高：同tick按放41.566px；保持7tick72.699px；12tick120.255px；30tick162.910px；更久不增加上限。覆盖晚释放、缓冲小跳、次数0/1/3/5、多输入源/重复保持、取消/禁用/死亡、碰撞及射击互不错误截断。

`python3 tools/build.py web`退出0；Chromium151手机触屏模拟渲染、Godot真实启动与下射操作退出0，无脚本解析错误。Web单线程，无额外跨源隔离要求。Safari/WebKit运行时未安装、iPhone/Android真机手感/性能未验证。

## 迭代方式

Android/iPhone共享https://zhipijun1996.github.io/gunman-rush/；PCK按内容SHA指纹命名，build-info.json记录版本，左下角显示试玩版本。旧缓存HTML检查当前元数据并至多跳转一次，避免手机继续测旧玩法。常规CI验证物理/Windows/Web，指定试玩分支push发布Pages；PR事件不发布。Android改按需独立导出，保留手动build_android（工作流进入main后界面可用）及本地命令。浏览器证据不替代APK或Windows实机证据。
