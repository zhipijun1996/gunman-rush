# 当前状态

2026-10-21。分支 `feature/region-bible-v2-forest`；最近已记录本地检查点 `083fbdc4a29a9d26c99b89bd5f2d506b3a88fcdb`（未推送），后继修改准备新检查点；准确HEAD以Git为准。原起点R `7be8c340372d1e20db6685cbd6a559191821eb0e`。先完整荆棘森林含美术，再优化风铃平原；SFX/风叶背景动画可做，BGM由用户后引入。当前开发中，未发布新Bible区域，不能把旧main通过代签新内容。

## 权威与当前默认

[两Bible注册表](creative_direction/bibles/registry.json)绑定用户原文；[实际共享风格16参考](creative_direction/bibles/style-continuity-20261021-v2.json)要求所有后续地区沿正式平原Underworld像素家族发展地域材料与生态。原始PNG、玩家动画metadata、许可及历史v13/v14保存/算法保留。森林creative-v7另绑定[用户自然缠绕荆棘平台要求与参考](creative_direction/bibles/thorn-covered-platforms-20261021.json)，只借生长关系，不移用参考游戏画风。

工作分支普通默认现为 `forest-bible-world-v15`；debug、自然campaign、post-Boss、跨区表现及独立版本期望同批更新。旧PlayerMotor唯一移动、合法能力、物理、资源、伤害、RNG和保存合同保持。任务见[任务表](tasks.md)；Forest/Bible仍in_progress，Plains仍planned。用户选择方向不代表视觉、手感或设备签收。

## 已实现与最新限定验证

- Bible-first及恢复/缓存防漂移、缺Bible先文档预制作、未来地区共享风格检查、skills入口已接。最新经验补入真实宿主联合面、专用目标职责、真实JSON往返与freeze前UID导入。原132检查字典/10个profile前缀、80/600秒、90import/240native、固定60与双worker保持。
- Forest新连接、F05背枝真实奖励与异路捷径、F06交替蛛网、六发现物/Reader及一次性奖励、F08唯一木芯、练习铃、风叶与3个SFX已实现。F08正式31腿/3551帧无伤、真实Reader木芯0→1/弹伤1→2.5并返营已在其冻结源通过；后继源码不自动重签。
- 已接回同平原16px/32wu、47邻接核心/精确适配及UnderworldPlayer；8类生态/两Boss native主体候选齐备。实际18图独审仅接受主体、花荚接缝与单个共享TREE背景用途，整区大形、运动/音画仍未完成。
- 自然荆棘以真实solid union/危险面生成，v15仅退役距宿主210wu的旧悬空prototype带，旧13/14不动。原20producer643/0已过。数学藤线两轮失败停止，平褐v3退出运行；native第一轮6图REWORK，第二轮6图18.346秒/3597源稳定获限定静态ACCEPT。全部6实际HUD图、精确源码ZIP与独审保普通Git；不再第三轮修同家族参数。
- 新版普通fast28/2154无伤；正式crossbranch live_H46/3810无伤、策略2442→3204通过；正确Lift22/1836通过但最低HP4。entry_wait第五轮真正空pin29/2096无伤且活体策略执行通过；前四次失败保持。专用entry前缀新增合法jump/R/drop恢复，保原历史driver、120/1800预算及最终12帧落脚，不声称中途策略字节未变。west_wait无正式producer，属未准入历史消费者，不能编造目标凑验收。
- 实际45°二次float32归一化差8.43e-8曾被逐位射线比较误拒；现仅双边有限2D单位方向容差1e-6，保真实同tick/queued绑定，独审21个实际变异均拒。真实JSON重放另暴露两处v15局部深比较的int/float问题，已复用既有严格canonical比较，保全量候选匹配/RunManifest与分数、bool、几何篡改拒绝。新增36实际JSON检查永久接入已有Bible versions，原56不变，两native共用原90秒。
- 最新七项fresh检查全部通过，完整输入漂移守门通过（targeted报告不序列化总清单；Bible wrapper另有3600份前后完整SHA相等）：[原始收据与失败链](evidence/region_bible_v2/style_continuity_20261021/json-and-default-fresh-third/README.md)，源报告 `build/verification/harness/20261021T052050.268603Z/report.json`。涵盖debug/campaign、presentation109、原327/schema6/24、Bible56+JSON36、reader55与AVreader8。原45版本unit亦独立通过。此前campaign JSON两FAIL及新UID首次import漂移FAIL不追认。仅targeted，不是完整profile、原80或最终发布。

## 尚未完成

真实F05/F08正常速度连续AV仍未录；现仅验收器8unit/12timeline/9原误接受与短静音黑帧拒绝通过，不能称听过/看过电影。Forest有机大形尚待完善；新的ONE木根肩源板在ignored build第一轮像褐色贴片已REWORK，第二轮仅源板制作中，未接生产，不签macro。

原80最终当前默认完整回归、实际Boss默认消费者、保存恢复、完整适用harness/正式CI、实际CI ZIP原三浏览器及公网完整PCK仍待当前实现冻结后做。SFX/动画/设备/用户/FUN分账，未执行写未验证。精选证据与失败来源见[阶段索引](evidence/region_bible_v2/style_continuity_20261021/README.md)。

Plains只读差距与实施方案已完成，尚无新生产修改。复用真实v12下层回环：西井→铃控船→岛上Reader/原箱二选一→异侧东井返营；图1先一个读物，不新造几何。顶桥不能看见旧址，不能冒称已做整座Bible石桥。森林内部样板/功能完成后再晨光、风与平原探索；不重写已成立Boss、不引入跨循环世界例外。

## main与存储

PR96/99/100已合main；运行P `66e8b912854d6d4cccadb45b9c348a618689f5a1`及档案R已完成旧正式发布验证。已修起跳镜头突变、接有根果实、退役旧八房间30文件；当时106远端head中88已包含，18旧art/UI/部署未盲合。公开仍P，不能作新Bible/荆棘预览；[旧main完整证据](evidence/main_pr96_repair01/main-P66e8/README.md)。

旧142终态capture已无损归档并验证按需恢复；本轮另将79份终态JSON无损归档，保守恢复6份旧audit输入，实际空闲约2.65GB；原收据/日志/所有AVI、CI ZIP与ci-H用户工作树保留。当前磁盘与恢复命令见[交接](handoff.md)，不要删除唯一证据或全量git repack。

文档/流程28项fresh profile已通过，报告`build/verification/harness/20261021T053927.330071Z/report.json`。旧creative-v6期望已显式改为用户荆棘方向creative-v7；可选jobs2因20GB隔离空间预检中断且未启动lane，最终jobs1原预算执行通过。仅流程/文档，不代剩余内容或发布。
