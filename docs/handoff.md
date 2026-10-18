# FOREST-DEPTH-02：实现与验证交接

最新验证跟进：[原CI失败与限定修复](evidence/forest_depth_v2/release_followup01/README.md)。0cf完整CI49项通过（含当前固定80路线），Guardian原生25/0后因旧map2身份reader失败；df3f版本严格迁移已获独审，干净源原Harness定向7实际通过，非最终完整CI。当前0cf正常影片的16px结标记已获实景限定接受，“岸”正式objective未展示；原浏览器首20/24与唯一诊断24/24分账，首发根因仍未证，另两组48/48不消除原FAIL。整体仍REVISE，最新完整CI／部署以PR与元数据实际终态为准。

2026-10-18，`/workspace/gunman-rush-design`，分支 `feature/thorn-forest-depth`。PR76仍OPEN/DRAFT，基线 `bee850c66b2f402d644d7daa4c13db91c8abe8f8`；实现历史 `9fdf7fad08550ea0da46b59ef7126fa721571f28` 与生态检查点 `dd214dde`保留，不改写／压掉。当前实际实现见[当前状态](current_state.md)，以最新源与独立证据为准。

默认v10／Canopy-v3已接入真实地图、自然入口、封场和奖励消费者。女王两部正常完整片、三种黄金完整打法、正式App03真实保存恢复和24HP击杀、9个实际畸形原子拒绝、GOLD/D/Home闭环均已有[便携证据](evidence/forest_depth_v2/canopy_app03/README.md)。原01／02失败不覆盖；03战斗HP4→4，恢复按原checkpointS，HP/E/上限保持，不能称保留空中位置。原生读取器与后续离线补强分账。

新N推荐回程已由单root00／map2／growth真实1013帧严格通过；最初1ULP方向误比较失败保留，修复只观测真实Router队列，不改输入、Player或原exact断言。旧V7／V9整Manifest与原哈希重建126/0；旧版本、旧Queen194／schema13 App强回归仍必跑，当前默认另验精确Canopy scene/resource／v10，不能互相代签。

完整现有Harness为88项，最终固定80路线及其余正式回归由本提交CI执行。随后使用原publisher交付Web／Windows／HTTPS预览，准确核对源commit和build_id；[分支运行](https://github.com/zhipijun1996/gunman-rush/actions?query=branch%3Afeature%2Fthorn-forest-depth)与最终PR记录实际结果。本文不预签尚未产生的CI结果；勿为纯文档记录重复整套原生长跑。PR基于`feature/playable-thorn-forest`保持draft，不合main。

质量记录仍in_progress／整体REVISE：H核心与大部分区域的体验价值、广泛探索差异、有效遭遇密度、高结保留／诱导收益、初见可读性、音频、玩家与真机均未认证。普通快解保留，不靠加血、缩台、加刺或禁普通策略突出钩索。新16px活结文字后补0cf正常片／密帧获限定接受，headless不签像素，正式“岸”目标未展示。技术回归不能签商业品质。

仅用Godot4.7.2及现有工具链。全局`build/verification/engine.lock`单引擎；派生缓存清理26／27只涉及终止快照import／shader，源／raw／收据／电影SHA均保持，终态N02的可重建导入缓存已回收，源码／raw／收据前后SHA保持。源码、失败与正常影片原件不得删除；重放旧快照可能需重新导入。

发布命令沿用 `python3 tools/publish_playtest.py --ref feature/thorn-forest-depth --repo zhipijun1996/gunman-rush --expected-commit <SHA> --checkpoint build/verification/publish-playtest/<SHA>/checkpoint.json`。同一dispatch轮询超时用同checkpoint的`--resume`，不盲重派失败CI；必要修复须先有明确诊断和新提交。最后验证真实CI产物的鼠标／仿触屏入口、暂停及元数据，物理设备仍awaiting-device。后续内容以[森林设计](design/forest_depth_v2/README.md)和[新女王设计](design/thorn_queen_canopy_v3.md)的未通过项继续，不重新扩张已淘汰候选。

上一检查点交接全文（含其他阶段背景）按原字节保留为[历史交接](archive/handoff_before_canopy_v3.md.txt)，来源和SHA见[归档说明](archive/handoff_before_canopy_v3.provenance.json)；历史待办不覆盖本页。
