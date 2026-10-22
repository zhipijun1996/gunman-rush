# Motion candidate交接

后继用户追加的起跳／落地音效、高落差震动和视觉后摇见[feel交接](feel-handoff-03.md)；本文件继续描述原v1/v2已冻结证据。

分支 `feature/player-presentation-01-motion-candidate`。main仍 `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`（本轮结束前再次查询）。运行源v1 `9c693787b201a655d9e8589d3bb1e1350ae64e29`、v2 `5ff0c7aea4fcfb51713363b0b8ec4d4b5f56a22a`；后继只加证据/质量/交接，不改变这两份已采runtime。未合main、未覆盖已有同ID M1分支，未开自动Integration PR。

当前贡献：真实正式平原主角的任务子类中，idle/fall各6帧、下落围巾上扬循环，旧run位移积分帧序，accepted跳/落地世界锚点尘效；全部参数有界配置；重启取消token、活跃pause、toggle不补播、旧actor释放、非法profile回退。两轮真实Godot同条件片已公网匿名下载核SHA；第二轮局部落地反馈独审接受。

证据和实际失败见[本轮交付](../../evidence/PLAYER-PRESENTATION-01/motion-v1/README.md)。最终可操作本地包build `c7a2529b3958`，完整ZIP166886784字节，实际解压重建/PCK和Chromium键鼠通过。公网Preview未部署：共享900MiB容量拒绝两次；临时tunnel API直连被网络拒绝。用户以网站试玩的要求仍未满足长期公网入口，不用本地通过冒充。

未完成：两版新run图拒绝后停止扩产；步态原画、握持衔接、全武器/三角色/Home新动作及完整首里程碑未验；用户手感/审美、全速听看与真机未签。保护4件/正式场景/DemoApp/共享配置/Harness/通用音频未改；总控先解决既有M1枪口权威与本候选独立视觉路径，再独审/显式共享版本重绑、受影响完整Integration。中央任务仍planned，本任务质量卡如实in_progress，状态同步归总控。

专项实跑：原Underworld607断言/583Motor帧/7状态；v2新trace1208、lifecycle19；600x2与前1080x2各16字段全同。Development计划未知路径仍full，不冒称整套执行；docs依稀疏历史证据缺失退出1。完整源库存、失败和日志均保留归档。

复现：`python3 tests/player_presentation_01/capture_motion.py --samples 1080 --output build/NEW_ATTEMPT`；VFX局部600不替代1080。`bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/player_presentation_01/motion_lifecycle.gd`。操作本地ZIP：解压后 `python3 start_preview.py`；旧完整游戏入口保留。发布Web须先有容量/独立托管，不手改cap；原工具 `python3 tools/cloud_delivery.py stage-preview --bundle build/web --host-root HOST --task PLAYER-PRESENTATION-01 --seed player-presentation-01/motion-01 --entry scene --scene res://scenes/dev/player_presentation_01/motion_candidate.tscn`。
