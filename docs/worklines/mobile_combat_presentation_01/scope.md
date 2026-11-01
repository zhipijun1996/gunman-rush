# MOBILE-COMBAT-PRESENTATION-01

用户反馈：手机浏览器战斗时画面间歇停顿，设备自述“荣耀magic60”。浏览器型号及实机帧耗时未知；不归因于硬件不足。

基线：`9da210e0cdf61e5af6f383738445985707968851`，分支 `refactor/game-architecture-02`。公开包仍为运行源码 ab263ea6／build 2e1274f62210，不把本次本地修改称已发布。

本批只合并 EnemyPresentation、UnderworldEnemy 正常帧对 PlainsRevisionVisual 的重复刷新，并复用本次 EnemyPresentationLifecycle 已读取的状态。初始化、新 epoch 和显式恢复仍允许零时间刷新；独立调用 refresh 仍读取当前 Actor 状态。保留转向时钟、地面射线、命中闪白、死亡姿态、所有动画与玩法参数、图声及保存格式。不改网格密度或绘制频率，不并入新地图工作。

验证：在已有 plains-motion-loot-02 消费者补充两宿主的快照次数、转向边界、暂停、显式恢复和终态测试；旧实现先跑以记录重复读取失败。使用同一外部脚本在实际工厂／宿主上测正常帧 CPU 时间并比较姿态轨迹，窗口内不运行绘制或截图。此测量只签受控原生表现管线，不能当自然战斗、浏览器或手机 FPS。最终执行现有模块影响计划及相关原 Harness 检查，独立只读审查。

采用 animation-vfx 技能约束表现与玩法分离，按 small_fix 轻量记录。质量与下一步见当前任务记录／handoff；用户实机保持未验证。回退基点为上述基线，仅逆向撤回本批生产三文件，保留原失败证据。
