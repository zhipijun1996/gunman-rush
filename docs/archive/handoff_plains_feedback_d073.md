# 当前交接：D073 平原战斗、音效与组合

分支 `fix/plains-combat-variety-audio`，基线 `ca5ea84`，包含尚未合并的[PR41](https://github.com/zhipijun1996/gunman-rush/pull/41)。[上一轮归档](../archive/handoff_plains_polish_d072.md)，[本轮规格与证据](../plains_combat_variety_audio.md)。main目前仍为旧公开包，本轮不自动合并或部署。

完成真实核心/护甲的中文命中与窗口提示；25种Kenney官方CC0声音、会话音量/限频/12声部/世界暂停；真实手绘敌方弹体；260px单跳反冲横渡、双层渡台移动齿轮、可选双次落地反冲；镜头平滑构图与方向键纯观察。补全中文字体、动作次数/空弹反馈、墙体同帧挡弹、领取接受之后的声音、道具焦点和HUD重绑定清理。保留一跳、两发、260速度、0.55地面反冲、0.20慢时及正式8关。

Godot `4.7.2.stable.official.ed1daf0bf`。完整平原42套退出0、Core5942/0；最终补测反馈264/0、生命周期31/0；实际组合库1310/0，三Seed支路8599/0，镜头7914/0，分岔15235/0，生成4673/0。192正式样本横渡15/渡台齿轮5/双次反冲16。新跨度无射击负证明确落不到远岸，四相位与镜像无损标准保留。文档33权威/114依赖，世界16候选/29边/六层通过。

Web/Windows导出0，两个正式PCK均 `2278621309a2`，均附OFL、四份Kenney许可及逐文件来源SHA。Boss独立浏览器fixture正常输入/真实子弹从12HP至0，覆盖三阶段及键盘暂停，玩家2HP；不冒称真人通关八关。最终正式Web GUI退出0：家园购买/刷新、正式首关鼠标射铃OPEN、真实音符4→5回家刷新保留，Web Audio非静音；完整Boss录像也退出0。运行提交 `cc5d78b`，[PR42](https://github.com/zhipijun1996/gunman-rush/pull/42) 已推送，验收清单见[持久证据](../evidence/plains_feedback/verification.json)。

运行命令：`python3 tools/run_tests.py`、`python3 tools/run_plains_ten_tests.py`、`python3 tools/check_docs.py`、`python3 tools/check_world_design.py`、`python3 tools/build.py web`、`python3 tools/build.py windows`、`GUNMAN_RECORD_GUI=1 GUNMAN_AUDIO_PROBE=1 python3 tools/verify_living_plains_browser.py`。Boss评审先单独 `python3 tools/export_plains_review.py` 再 `python3 tools/verify_plains_review_browser.py`，临时入口由工具finally恢复，不能与其它导出并发。

快速headless退出仍有音频资源清理告警，实际Web未见脚本/着色器错误；Windows只导出、Android未构建、实体手机/手柄听感与完整八关趣味性待验，森林未开放。自动真实轨迹与声输出不替代真人反馈。试玩包：本机 `build/gunman-rush-plains-feedback-windows.zip`、`build/gunman-rush-plains-feedback-web.zip`；日志、CSV与录像为 `build/gunman-rush-plains-feedback-review.zip`。GitHub CI已启动，待完成；未合并/部署。下一步：按实际设备反馈调整声音混音、镜头与组合难度。
