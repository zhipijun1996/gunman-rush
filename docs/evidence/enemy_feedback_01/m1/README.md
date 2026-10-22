# ENEMY-FEEDBACK-01 M1 · 两代表与旧链兼容

运行源after `d9c9e0e8546f10c4c3c5a4be04cd9c75418e4e37`；before `7df37b16de37ec5197ba60ee80209fb943a9e552`。同一字节的 `tests/enemy_feedback_01/test_feedback.gd`。Underworld root_bell/diver与旧EnemyPresentation diver/patrol分别为四个初始定位fixture，保真实AI/Router/碰撞弹体/HP，不注资源、不在战斗中搬演员、不直接调用反馈或receive_damage冒充战斗。每个三次真命中，hurt两次/death一次；暂停实际冻结，恢复terminal不重播。第三RootBellPresentation保持只读，未推广。

两部真实Godot MovieMaker正常速度MP4均1280×720/60FPS、1233绘制帧/20.55秒，1200动作帧position/HP/AI state差异0。其余为准备/暂停/切换/收尾帧；不能把录制墙钟或Mesa llvmpipe时间称目标设备FPS。两次完整source前后稳定。原生图形环境为专属Xvfb、OpenGL llvmpipe；Dummy有音轨，不签听音。

- before：`build/enemy-feedback-01/m1-before02/movie.mp4`，714872字节，SHA256 `2cced7ca4f76331c347560eb5d62545e509b3d6419d8606d2efc945018e793d4`。
- after：`build/enemy-feedback-01/m1-after01/movie.mp4`，708468字节，SHA256 `a83e7762a12ee9e4b25b62d74a077b3e1757fee5ad3fe26a2f2cb7dd1ace5090`。
- 复核ZIP：`build/enemy-feedback-01/enemy-feedback-01-m1-review.zip`，1795509字节，SHA256 `0ba0cf55327eec0551e03cb4dfae837429533ac360d68d36749cef16b7963842`。含两MP4、完整trace/来源回执/检查与失败日志，每成员完整读回核对。原AVI留在两个build目录。这里是本地原件定位，公开下载/托管由总控负责，未伪称已发布。

执行（所有shell均本树workdir/source专属env）：`python3 tools/run_enemy_feedback_01_tests.py --output res://build/enemy-feedback-01/m1-candidate01.json`，46/0；`tests/enemy_feedback_01/test_feedback_state.gd`，18/0；原 `tests/plains_cohesion_drops_runner.gd`，17/0。后两项由原`run_tests.run_engine`执行，分别30/120秒原有界等待。状态边界为隔离HealthState事务测试，不冒称弹体影片；掉落检查原本是显式结算fixture，不能冒称自然击杀。

原Harness fresh `--check underworld-damage-feedback --release --jobs 1`：317/0；`--check underworld-formal --release --jobs 1`：96/0、两图17/20敌。formal报告Seed `underworld-formal-integrated`，包含diver等，没有root_bell；不外推root_bell自然地图战斗。检查运行时HEAD仍7df37b1、候选源在dirty树；原Harness回执保留完整diff/untracked/input_digest，未改标签为clean d9c9。随后相同生产代码冻结d9c9并重新采after电影46/0，后者才是精确clean运行源。

电影命令为 `python3 tools/capture_enemy_feedback_01.py --source-commit <上述准确SHA> --output build/enemy-feedback-01/<fresh> --display <专属Xvfb显示号>`；before额外`--baseline`。实际Godot完整argv在两receipt里。缺`xvfb-run`后改为使用仓库toolchain的Xvfb，未改引擎/画面/timeout。

本目录保存必要portable回执/trace/原专项/失败链，MP4先留build。`failures.log`明确汇集原失败日志，原build各文件及ZIP仍保原字节。没有独审、连续像素准入、音效听审、玩家手感/审美、真机、完整Integration/Release、Preview或公开交付结论。静态抽帧只做本线定位，不替代连续片审查。
