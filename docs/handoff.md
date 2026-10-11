# 当前交接：D076 平原两张随机网状探索地图

分支 `feature/plains-two-maps-fog` 从最新 `feature/plains-connected-region` 的 `8621681` 建立；初始工作区干净。远端main=`ab51fca`，PR41–44尚未合并，相关修复全部继承，没有自动合并。公开网页旧八关的原因是前轮只有PR没有部署。[上一轮归档](archive/handoff_plains_connected_d075.md)，[当前实现](plains_two_maps_fog.md)，[两图随机样本](evidence/plains_two_maps/corpus.json)。

正式平原生成两张独立网状地图：第一张20节点、较简单、4HP铃卫小Boss；第二张20/23节点、较难、原12HP三阶段牧风者。小Boss确认后保留血量、构筑和金币，补给仅一次，切换第二张；主Boss金奖才完成平原。只有平原，后续能力/地区明确开发边界、安全回家园，无假能力。PlayerMotor、player_tuning、碰撞、跳数、空中两发及恢复规则没有改动。两张都使用三类拓扑、多处分岔/交汇/环路、高低路线、两条整备入口、两个真实捷径；不是八关串接。

右上角迷雾小地图按实际玩家位置揭雾，点击或M打开大地图，滚轮/按钮缩放、鼠标/单指拖动、双指缩放、定位和关闭。暂停世界、清除待提交输入；拖地图不揭雾。每图实例、库存和探索账本独立且保留，奖励ID含地图号。JSON快照兼容旧版并验证格子。修复反证保留：JSON数值浮点与数组成员严格比较导致v2快照拒绝，现用数值比较，生命周期及两图JSON回归通过，未删失败断言。

Godot `4.7.2.stable.official.ed1daf0bf`；Core5942/0，原43套通过，新两图/地图236/0、生命周期27/0、主Boss22/0、拓扑与连续输入物理4528/0，总计四套成功。50根种子×两张100地图：连接图39/44种，早到Boss实际行程13/26种，无保底、至少5环、9/8分岔。三骨架两个难度、固定样板和两个完整保底使用原Motor连续输入验证正反路线与可选挑战撤离；图统计不冒称真人体验。headless退出既有ObjectDB/音频资源清理告警保留，不把它们当脚本错误或隐去。

公开试玩已更新为两图运行提交 `a21fc8a08631e9d7a58f0b4a152832205853c7a9`。[PR45](https://github.com/zhipijun1996/gunman-rush/pull/45) OPEN，未自动合并。[发布工作流38139321431](https://github.com/zhipijun1996/gunman-rush/actions/runs/38139321431) 全部必要检查及部署成功；线上build-info.source_commit匹配，canonical root也显示新版本。正式试玩：[8d921972c58d](https://zhipijun1996.github.io/gunman-rush/?v=8d921972c58d)。实际公开网页GUI0失败：Home真实购买/刷新保留、随机20节点linked_rings非保底、迷雾小地图→大地图定位/滚轮/拖动/关闭、教学移动/跳跃/射击释放、WebAudio峰值0.340946；无脚本/着色器错误，保留favicon404。此GUI范围不冒称真人完整两图通关。

[完整证据](evidence/plains_two_maps/verification.json)记录实际发布提交、工作流、根页面与构建清单、各测试/导出/原始日志/截图/录像哈希。Web与Windows本地PCK为 `931741aa7438`，线上CI导出PCK为 `8d921972c58d`，分别记录，未假称文件相同；源码运行提交相同且两份Web均实测。包为 `build/gunman-rush-plains-two-maps-web.zip`、`build/gunman-rush-plains-two-maps-windows.zip`，审查包为 `build/gunman-rush-plains-two-maps-review.zip`。此后每轮玩法交付执行 `python3 tools/publish_playtest.py --ref <已推送已测分支>`；页面发现新版本会提示刷新，不打断当前局，保留永久存档。


复现：`python3 tools/run_tests.py`、`python3 tools/run_plains_ten_tests.py`、`python3 tools/run_plains_region_tests.py`、`python3 tools/check_docs.py`、`python3 tools/check_world_design.py`、`python3 tools/build.py web`、`python3 tools/build.py windows`、`GUNMAN_RECORD_GUI=1 GUNMAN_AUDIO_PROBE=1 python3 tools/verify_plains_region_browser.py [实际线上版本URL]`。GUI和长物理测试串行。浏览器范围为默认Home购买/持久化/出门、第一图迷雾大地图交互、教学动作/声音，不冒称浏览器完整两图通关。Windows实体设备、手机、手柄、真人探索/经济/趣味性待验，不实现森林。
