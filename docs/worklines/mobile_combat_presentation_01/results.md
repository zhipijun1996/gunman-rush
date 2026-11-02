# 手机战斗表现性能：第一批

生产／测试提交：`cd12edc4ef35fe06ca6b6e8f5fd418addc3a0503`。本批消除了已确认的重复工作，**尚未证明用户手机的战斗停顿已经解决**。没有导出或发布新 Web，没有合 main。

## 真实改动

- `EnemyPresentation` 与正式 `UnderworldEnemy` 正常帧各只调用一次 revision refresh，并复用本次 `EnemyPresentationLifecycle.snapshot`。原来该路径通常三次 Actor 状态快照、两次表现刷新／落地射线，现在稳定 epoch 正常帧为一次。
- `PlainsRevisionVisual.refresh(delta, state = {})` 继续在无传入状态时读取当前 Actor；初始化、完整恢复、RootBell 独立调用保持原零时间同步。终态仍先返回，保最后活体姿态，转向、时钟和最终刷新位置不变。没有跨帧缓存 Actor 状态。
- 原 `plains-motion-loot-02` 追加两真实宿主的正常帧、`.10/.18` 转向边界、快速反向、暂停、同 epoch 恢复、新 epoch 恢复及终态反例；旧断言和预算保留。

## 已执行的有限验证

| 来源与范围 | 结果 |
| --- | --- |
| 旧生产实现＋首版新回归 | 12 条重复状态读取断言失败，原日志保留；不是旧正式功能失败 |
| 当前精确生产／测试字节，原四命令 | motion/loot 563、正式反馈150、尸体快照129、变形逐字节等价5796，全部零失败；退出、原预算和原错误检查保留 |
| 干净 cd12，原 Development 计划 | 16 项全部 fresh 通过，273.4 秒；含 core5686、enemy733、当前森林、伤害、架构、图声版本及文档检查 |
| 独立只读审查 | 三生产文件、追加测试、精确保存字节与测量边界限定接受；非玩家或实机认可 |

四命令实际执行时 HEAD 是9da＋已记录候选工作树字节；五个源码 SHA 均与随后保存的 cd12 Git blob 一致。不能将其改称干净 cd12 上的全量 CI。16 项 Development 则确实在干净 cd12 上执行。原始日志、命令、预算、失败、source binding 和独审保存在[证据](../../evidence/mobile_combat_presentation_01/receipt.json)及同目录压缩包。

## 测量意味着什么

同一外部脚本调用实际工厂／两宿主／六物种，暖机后每组25批、每批150个显式 tick：12组平均耗时从约25–29微秒降到13–19微秒，分别减少31.9%–49.3%；108个采样的姿态、朝向和运动值完全相同。未更换 renderer 或注入性能开关。

这是云端原生 CPU 的受控表现管线测量，不含顶点变形／上传／绘制、AI或浏览器。批均值分位不是游戏帧 P95/P99，更不是手机 FPS。[完整比较与限制](../../evidence/mobile_combat_presentation_01/comparison.json)。之前当前公开 PCK 的625顶点核测量为毫秒量级；本批微秒级节省不能据此宣称整帧卡顿消失。

## 下一批与交付边界

1. 优先测量／优化原 `PlainsRevisionPose`、Ground／Flora 的逐顶点重复计算。复用已有准备与权重缓存；以现有 frozen oracle 的367640顶点逐字节回归守门。先测再保留改动，不默认降网格、降帧或修改动画。
2. 对真正交战记录空场、移动、未命中射击、持续命中和成批死亡的帧耗时及可见怪物／尸体／弹体数量。现有浏览器 RAF／LongTask 观察器可复用，旧跳射 runner 不等于实战；软件 GPU 不代签荣耀手机。浏览器型号尚未知。
3. 聚合下一批后冻结源码，按现有 Integration 计划执行 full171，再做所需 Web 构建、同源包／真实 GUI 和手机复核。本批未执行 full171，不修改分流规则来缩小要求，也不重跑已通过且输入未变的检查。

公开试玩仍为运行源 ab263ea6／build2e1274f62210。本任务保持 review；手机帧率和用户体验未验。回退基点为9da：在干净回退分支应用[六路径逆补丁](../../evidence/mobile_combat_presentation_01/rollback-runtime-tests.patch)，一并撤回三生产叶及附加测试／UID，保留后来文档、质量卡和原始证据。该补丁已实际通过 `git apply --check`，未执行回退。先检查再应用，不覆盖用户工作树：

```sh
git apply --check docs/evidence/mobile_combat_presentation_01/rollback-runtime-tests.patch
git apply docs/evidence/mobile_combat_presentation_01/rollback-runtime-tests.patch
```
