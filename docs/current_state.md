# 当前状态

最新开发续轮：新增v16探索候选已接17种模块、回望高枝、活摆荚/固定果实双解、L下探与Z/7内外回环、领奖短返。低顶短跳已淘汰。fresh native15九条正式输入路线全部通过31952帧/780腿并获限定独审，三摆荚策略及奖励返程均HP5，主路最低HP为4/1；原80/fullCI及闭门对抗/保存仍分开未验。共享像素家族保留，整体艺术仍REWORK（长矩形根体/规则浮梯），不签用户趣味或设备。当前默认/历史保存仍v15；新内容从 `FOREST EXPLORATION / MAP 1/2` 独立关卡测试入口进入。原始失败、完整源闭包与实际23GPU图见[本轮证据](evidence/region_bible_v2/style_continuity_20261021/forest-exploration-v16/README.md)。下一步仅Web构建与快速部署，不默认合main。

最新试玩（2026-10-21）：[公开网页](https://zhipijun1996.github.io/gunman-rush/?v=12ac19e2ec02)现为森林开发构建12ac19e2ec02，运行源bbf5b24dc6a27374119f67f11fc2eed92a57ba00，prepared Pages39593999600已成功。公网完整PCK与原已验CI包一致，真实森林map1进入/暂停恢复冒烟通过；正式原CI39578229334/full141及当前80路线也已通过。本文后面的旧“待CI/公开旧main”是历史时点，以本段和交接最新段落为准；未合main，森林整体美术和Plains优化仍未完成。用户要求今后试玩默认快速发布：复用已验同源Web或只重建Web及必要影响检查，不为每次试玩重跑整套CI。

2026-10-21。分支 `feature/region-bible-v2-forest`；最近已推送检查点 `124815766d1c9fb93224bca05fa2c9f7fe265ac5`、草稿[PR101](https://github.com/zhipijun1996/gunman-rush/pull/101)，后继修正兼容字体和共享表现类型依赖；准确HEAD以Git为准。原起点R `7be8c340372d1e20db6685cbd6a559191821eb0e`。先完整荆棘森林含美术，再优化风铃平原；SFX/风叶背景动画可做，BGM由用户后引入。当前开发中，未发布新Bible区域，不能把旧main通过代签新内容。

## 权威与当前默认

[两Bible注册表](creative_direction/bibles/registry.json)绑定用户原文；[实际共享风格16参考](creative_direction/bibles/style-continuity-20261021-v3.json)要求所有后续地区沿正式平原Underworld像素家族发展地域材料与生态。原始PNG、玩家动画metadata、许可及历史v13/v14保存/算法保留。森林creative-v7另绑定[用户自然缠绕荆棘平台要求与参考](creative_direction/bibles/thorn-covered-platforms-20261021.json)，只借生长关系，不移用参考游戏画风。

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

F05/F08真实连续AV已录并获限定独审：分别3018帧/50.3秒、3380帧/56.333秒；完整时间线、原PCM字节与6/5张实际关键帧通过。两条路线分别32/3001与31/3362段/物理样本，均HP5零伤；F08实际Reader物品0→1、弹伤1→2.5。仅属于clean048冻结源，未声称完整连续视觉观看、感知试听或设备认可。原AVI/WAV/MP4本地保留，普通Git包只有完整轨迹、收据、原关键帧及媒体哈希，不冒充可移植影片。

Forest有机大形仍未完成。木根肩actual6获REWORK_STOP后已精确撤回，源板/源码差量及实图保留；放大背景TREE仅只读分析即NO-GO。另一G0将单个实体换成8片真实变截面实体，最终28检查通过，但实际粗阶梯形及裸根消失获RETHINK_STOP；无生产v16、无Motor/路线通过，不推广或继续调参数救轮。

原80第一次在seed01/map1/growth真实失败：蜘蛛受击后移到栖台角后，旧v15测试驾驶仅三瞄点找不到第二枪。只追加两个身体内缘采样，保真实枪口/弹丸圆碰撞/资源/600帧与12发守门；同一完整路线27/27、1999样本无伤通过，独审确认物理轨迹一致至新增第二枪前。第二次原生80全部通过、3600源稳定，但外层harness复制约931MB新增JSON时ENOSPC中断，`checks=[]`，不能签harness通过。80独审包含23例/29次玩家伤害，不能外推两条影片的无伤结论。轨迹完整无损归档并实际验证恢复。

Harness大JSON现有流式ZIP/完整索引、原生输出摘要交叉绑定与安全恢复；初版缓存反例误接受保留，新版原77/新12及独立14反例通过，新12已追加真实CI检查。旧150检查字典、原132及10profile前缀未改。最终fresh原80外层已在dec23450通过（下述新收据）；完整profiles仍待正式CI。根铃/棘冠完整战斗、恢复、历史瞄准保存兼容、实际平原战后Forest入口及三组历史v10专用策略均有各自新收据，不混称同一源或当前v15路线。

第三次fresh原80于clean dec23450全部通过，原600秒内检查551.426秒、含准备/收集总582.322秒；外层passed/exit0/reused=false。78份大JSON在58,121,248字节ZIP，另2份小JSON原路径保存；完整80轨迹与原始报告/日志/收据普通Git见[最终定点证据](evidence/region_bible_v2/style_continuity_20261021/final-native80/README.md)。随后fresh当前H技术样板3案例及3音效字节复现亦通过，只限其实际scope。上一轮ENOSPC中断不追认。实际Boss、恢复与兼容结果按各自源保存；完整适用harness/正式CI、实际CI ZIP原三浏览器及公网完整PCK仍待。标准workflow覆盖full141，不含独立注册的10项feedback/prototype检查，不能称151全跑。SFX/动画/设备/用户/FUN分账，未执行写未验证。精选证据与失败来源见[阶段索引](evidence/region_bible_v2/style_continuity_20261021/README.md)。

Plains只读差距与实施方案已完成，尚无新生产修改。复用真实v12下层回环：西井→铃控船→岛上Reader/原箱二选一→异侧东井返营；图1先一个读物，不新造几何。顶桥不能看见旧址，不能冒称已做整座Bible石桥。森林内部样板/功能完成后再晨光、风与平原探索；不重写已成立Boss、不引入跨循环世界例外。

## main与存储

PR96/99/100已合main；运行P `66e8b912854d6d4cccadb45b9c348a618689f5a1`及档案R已完成旧正式发布验证。已修起跳镜头突变、接有根果实、退役旧八房间30文件；当时106远端head中88已包含，18旧art/UI/部署未盲合。公开仍P，不能作新Bible/荆棘预览；[旧main完整证据](evidence/main_pr96_repair01/main-P66e8/README.md)。

旧142终态capture已无损归档并验证按需恢复；本轮另将79份终态JSON无损归档，保守恢复6份旧audit输入，实际空闲约2.65GB；原收据/日志/所有AVI、CI ZIP与ci-H用户工作树保留。当前磁盘与恢复命令见[交接](handoff.md)，不要删除唯一证据或全量git repack。

文档/流程28项fresh profile已通过，报告`build/verification/harness/20261021T053927.330071Z/report.json`。旧creative-v6期望已显式改为用户荆棘方向creative-v7；可选jobs2因20GB隔离空间预检中断且未启动lane，最终jobs1原预算执行通过。仅流程/文档，不代剩余内容或发布。

最新PR门槛修复：原PRdocs29项全通过，但对main完整范围检查因资产机器登记/一条测试预期独审不足而失败。已补真实28卡/175文件/21runtime来源（许可unknown、视觉unverified），单独静态消费者独审不代签整区；完整baseR检查已实际通过，且以python3 -S证明可前移到依赖安装前。core精确head与自动去重/手动及publish保护修复另独审，新完整CI仍待。详见[原失败与修复](evidence/region_bible_v2/style_continuity_20261021/ci-admission-repair/README.md)。

最新角色消费者迁移：6dba的新版PRdocs、Windows/Web通过，但parallel原generated26在头像旧25/2失败，整轮cancelled/serial未完成。默认v15实际Underworld符合共享风格，仅测试用显式真实v14保原25，再追加当前37/0；原26完整167.457秒通过，独审限定接受并保同版本pin探针边界。快反馈新增原26，不改151字典/full141/旧前缀。一次整枝新图源级STOP，无引擎/生产接入；整体森林大形未完成。详见[本轮原件](evidence/region_bible_v2/style_continuity_20261021/avatar-default-migration/README.md)。后继新CI仍待，原dec80不重绑。

1248157的区域快反馈实际四项fresh全部通过194.624秒；正式CI39571747310整体失败，不能签full141：Web42/Windows通过、docs39571747315实际29/29通过；parallel原generated26通过后region在兼容字体覆盖537/2失败，serial仅9pass后terrain类型依赖解析失败并240秒超时，其余42未执行，软件GPU/四音频未执行。原80不曾在该serial执行。实际CI Web原包指纹c814c267208b，三个原浏览器25/40/8全通过547.026秒及完整22998源/Git稳定，只属于124旧包，不重签后继。

最小修复仅两类：原Noto工具重建兼容windkeeper子集463→499/+36，保旧463度量/轮廓（独审677项）；两新卡触发缺8unique字，当前正式Underworld字体本来已覆盖，不冒称当前UI缺字。公共敌人helper移除具体ForestStage反向类型依赖，由原App已验证入口传manifest/enemies/rows，原宿主/actor绑定校验保留。新WIP原537/0 11.197/90秒、原terrain全地图508/0及故意破坏55/1均通过，整组50.509秒/完整源Git稳定。独审只签字体/去环范围；新完整CI/准确新包GUI仍待。所有实际失败与新收据见[专用证据](evidence/region_bible_v2/style_continuity_20261021/ci-runtime-font-repair/README.md)。Forest整区艺术与Plains仍未完成。
