# PLAYER-PRESENTATION-01 · 基线证据

这是检查点 01 的未修改生产基线，**没有 after、正式表现改进或新 Preview**。实现目标、实际消费者、全武器矩阵、拟改接口及总控协调边界见[检查点](../../../worklines/PLAYER-PRESENTATION-01/checkpoint-01.md)和[版本化影响分析](../../../worklines/PLAYER-PRESENTATION-01/impact-v1.json)。

- [真实家园短片 home.mp4](home.mp4)：依次使用既有信使／旅人／少女选择 API；移动、射击走真实 Router。选择调用不证明鼠标／触屏 UI。三外观共 720 观察样本、12 次 accepted shot，首枪后 Courier.state 卡在 recoil。
- [真实正式平原短片 plains.mp4](plains.mp4)：原出生点、相机、敌人、地形；720 观察样本、8 次 accepted shot，HP 自然 5→2。没有伤害注入或位置写入；只展示此移动／下落／自然环境受伤窗口，未验完整死亡链或通关。
- [summary.json](summary.json)：精确来源／条件／媒体 SHA／范围／真实失败。
- [baseline-evidence.zip](baseline-evidence.zip) 与 [archive-index.json](archive-index.json)：原始轨迹、完整 capture receipt、实际输入驱动、日志、607 断言专项、文档失败及抽帧原件。已逐成员读回字节／SHA／CRC，无损归档。

两片均是 Godot 4.7.2 Standard MovieMaker 连续输出，729 帧、12.15 秒、1280×720、60fps，真实引擎 stereo48kHz 音轨；软件 llvmpipe／Xvfb／Dummy backend。source_stable=true。720 是观察样本数，729 是媒体帧数，当前没有精确 sample→视频帧映射，不据此签延迟。没有完整播放／听音或实体设备测量；只查看原尺寸 home9秒、plains1秒与每0.5秒抽帧，不签连续性或音质。

基线生产提交 `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`。采集时任务 driver／初始质量记录尚未提交；完整 working_files、driver SHA 及前后 materialized-source inventory 在 ZIP 的 capture-receipt.json 内。不得把归档后的文档提交当作这次运行的完整源码 SHA，或把源码稳定等同艺术认可。

实际执行：home／plains headless、两次 rendered observer、既有 underworld-player-animation 均 exit0；后者 607 assertions／583 real Motor frames／7 states，仅签旧基线。`harness --check docs` exit1：稀疏检出缺少历史 evidence/archive 的引用，原始失败日志在 ZIP 的 harness/docs-failed.log。未修改断言、阈值、共享绑定或旧失败。Development planner 对新 driver 保守选择 full，计划未执行；受影响完整 Integration 由总控安排。

媒体随本分支保存，GitHub 仓库当前为公开；下载可用性以远端实际字节核验为准，尚未核验的本地路径不是公开交付。未建立独立可操作 Preview，仍列下一里程碑义务。用户手感、审美与真机保持未验。
