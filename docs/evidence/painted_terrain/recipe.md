# 连续绘画截面：当前候选制作范例

> 路径维护说明：本页仅修复迁移后的导航链接，不重验或继承旧艺术、玩法及声音结论。原字节和原证据身份保留于[冻结原件](../../worklines/game_architecture_01/archive/navigation-before-p8-links/sources/docs/evidence/painted_terrain/recipe.md.txt)。

04首代表空间已获静态/运动抽帧整体艺术ACCEPT_SCOPED，仅允许一次同家族、结构明显不同的实际迁移；第二空间仅实际两薄岸局部复用获[限定接受](independent-08-second-structure-scoped-review.md)，不是第二商业黄金或整map准入。不是完整G2、用户、设备、商业或正式生产池认可。Git父0905516不是本轮dirty运行树，原采证source_snapshot与catalog SHA才绑定每次实际画面。

- 母版：[B1](../../../assets/visual_development/master/b1_master.png)、[方向板](../../../assets/visual_development/proposals/b_board.png)。保持盘筑低重心与蛋彩大明暗，不把所有土体画成陶器。
- 功能截面：[section_v2](../../../assets/visual_development/painted_terrain/section_v2.png)、[真实提示](../../../assets/visual_development/painted_terrain/section_v2.prompt.txt)、[来源](../../../assets/visual_development/painted_terrain/section_v2.record.json)。先画连续顶面、根肩、低频深土的共同体积，侧边是采样边界，不画孤岛或纹理卡。
- 安静中景：[meadow_v2](../../../assets/visual_development/painted_terrain/meadow_v2.png)及[来源](../../../assets/visual_development/painted_terrain/meadow_v2.record.json)只替换既有连续远层，不生成整屏关卡。
- 左右转面：[左](../../../assets/visual_development/painted_terrain/left_end_v1.png)、[右](../../../assets/visual_development/painted_terrain/right_end_v1.png)。独立编辑实际折转、光线及内接，不旋转顶条假造转面。
- 维护记忆点：[接收岸陶片与木销](../../../assets/visual_development/painted_terrain/left_end_repair_v1.png)只在真实端部与碰撞线以下，不添加假落脚或交互信号。

[当前catalog](../../../game/presentation/world/resources/visual_development/painted_terrain_candidate.json)的terrain.grammar保存真实source_surface_profile、ends.outer_profile与分带深度；[消费者](../../../game/presentation/world/art/painted_terrain_grammar.gd)沿真实顶轮廓弧长有限取源，并按真实侧轮廓接端面。顶/根肩保笔触尺度，深部使用安静体块；源长度不足明确拒绝，不repeat或全片挤压。具体数值是本源图/本样板校准，不能推广为任意素材硬值。

[首次实景独审](independent-02-first-live-review.md)确认体积进步并支持制作转面，但记录坡顶明线、纵拉和缺端部；660tick不是完整路线。[后续端深独审](independent-03-end-depth-live-review.md)保留下一轮实际缺陷。这些历史缺陷及原始红灯保留；04新范围以随后独审为准，不能按mesh或文件数量批准。

当前依据为[04整体艺术限定独审](independent-05-first-space-art-sample.md)及[真实04summary](first04/summary.json)、[18.68秒原速影片](first04/gameplay.mp4)。完整去返工程结果不替代艺术范围；独审看了实际全屏与20帧联系表，未完整连续播放/亲听。复用先沿已有section_v2/端面/维护件/meadow_v2重新推导真实轮廓与主次，不强制重生成源；仅实证缺连接时绘制，不复制第一空间坐标或每seed换图。

可见底部是新用途，需要[真正底部源](../../../assets/visual_development/painted_terrain/underside_v1.png)，不能把深岸截面任意裁成漂浮薄岸。原02透明收边藏住20world真实天花板而失败；现消费者把每列原源alpha128底界对齐实际物理底边，保留内部圆转明暗。数值采样表不是绘画资产，实际原Motor两点顶头与局部去返分别验证。第一深岸无此分支，19块mesh数组深等价不替代实机回归。

短入口：`python3 tools/level_design.py route --request "改善另一段风铃平原的美术" --output build/painted_terrain/next.json`。现在直接进入既有visual_golden任务，附真实SHA母版/范例/当前源和只读独审租约；route仍只生成任务，Codex宿主必须继续执行图生、原生集成及采证，不能将计划算作品。先局部native mesh检查`python3 tools/run_visual_director_space_tests.py --painted-terrain`，稳定后才原速录像/独审。
