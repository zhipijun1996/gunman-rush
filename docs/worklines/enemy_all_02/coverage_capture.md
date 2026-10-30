# ENEMY-ALL-02：库存、录制覆盖与当前交付状态

最终媒体目录为`docs/evidence/enemy_all_02/candidate_v5/`，相对媒体路径见该目录实际manifest。当前可交用户审片的候选包括14种普通怪、22条宿主渲染链、2个开发候选、8个Boss场景／9个实际Definition组合。完整逐怪时间表见[实机审核索引](../../evidence/enemy_all_02/README.md)，结构清单见[roster.json](../../evidence/enemy_all_02/roster.json)。本页记录覆盖语义，不能用库存数或零gap代签完成。

## 口径与真实消费者

| 类别 | 数量 | 范围 |
| --- | ---: | --- |
| 普通物种 | 14 | 平原7＋森林7 |
| 普通宿主链 | 22 | 平原7×scene/Underworld，森林7×scene，再加根铃独立RootBell链 |
| 开发候选 | 2 | candidate_lure_guard／candidate_crosswind_moth，不进正式随机池及保存契约 |
| Boss场景 | 8 | 原场景各自运行；不能把孤立plains_bell_warden资源多算为已准入Boss |
| Boss scene/Definition组合 | 9 | windkeeper原scene默认12HP与正式storm36HP必须分列 |

森林正式身体通过`forest_bible_actor_art=true`，Underworld正式身体通过`underworld_formal_style=true`选择；相同scene的备用几何不能冒充正式身体。实际renderer、Definition、安装器、来源SHA均在库存／trace／局部源合同中分列。全局style-v18／creative-v21及原81引用不因本轮叶改动机械刷新。

## 已有媒体与覆盖边界

- 正式实机总览56.68秒：00:00.00–00:09.43平原既有冲锋怪；00:09.55–00:39.55森林正式map1原出生点输入；00:39.77–00:56.60正式App的storm36HP牧风者。按完整章节拼接，不能称同一条自然campaign。
- 平原159.55秒：15链；森林83.85秒：7物种；候选24.42秒：2例。各组技术事件覆盖零gap，仍须逐怪身体／声音／用户审核。森林7种现为d91干净源新录制。
- Boss总览257.97秒：前240.95秒是8原场景实验台，随后正式App storm；9组合分列零技术gap。原scene素材／行为／弱点／HP政策均保留，不以实验台计自然准入。
- 冲锋22.27秒、俯冲22.30秒两份严格补录：各两链，精确检查settled之后210帧，visible／settled／alpha／位置／旋转／缩放／D7恒定。普通主片仅“death后210帧”的旧读数保留原含义，不能冒称settled后证明。

平原正式片与formal storm仅在开始前有一次公开披露的玩家审核站位；原生成地形、原有怪物、HUD、StageCameraRig和双方伤害权威不改，战中仅Router输入。森林debug直入正式map1后使用原出生点，片内只观察棘籽哨、未见悬荚，不能签自然跨区解锁或全部地图完成。

实验台在开始前配置真实支持、线段／双入口或两岸；之后原Controller／Router／真实武器弹体／双方FrameDamagePolicy／敌AI均运行，不直接写HP、强开state／弱点、暂停AI或战中搬角色。场景与目标窗口不同于正式随机遭遇，必须保留fixture标签。

## 采证工具与原声

使用`tools/enemy_all_review_02.py`和对应普通／Boss／formal／route driver，Godot4.7.2 MovieMaker、1280×720、60fps、正常速度；每组保存review.mp4、原report、chapters、完整trace和引擎原PCM归档。驱动输入、实际shot、accepted HP、phase、死亡、process前／post_draw观察分别记账。音轨仅来自引擎，存在音轨不等于听感通过。

每例先等待真实攻击或相应接触移动承诺，分隔非致死命中以观察hurt退出，再致死并观察终态。接触巡逻、摆荡荚、铃囊萤、跃枝怪使用自身真实相位；固定生根对象不伪造locomotion。原型守卫按真实recovery窗口命中，盾甲虫按真实角度／绕盾规则。

`recorded_complete_coverage`仅表示该驱动要求的事件已出现；缺攻击、命中、hurt恢复、terminal或足够尾帧一律`recorded_with_coverage_gaps`并保留可审片。引擎错误、泄漏、源漂移、媒体不完整记failed，原失败不覆盖、不提高预算掩盖。玩家／设备／导演判断不由driver自动签署。

## 审查与当前源

R3独立审查在67d生产身体／b71采证源与所绑定媒体中接受“可供用户逐怪审核的实现候选”；没有签所有招式、全部阶段打断、全速观看、声音、设备或G5。根铃本片返铃反击次数0，织网结点分支及边角策略仍未穷尽。

当前最新d91源的森林80图矩阵已实际80／80通过：`forest-depth-region`单个Harness check，原600秒预算内540.378秒、exit0、0复用、精确干净d91，Harness总墙钟553.226秒，实际report为`build/verification/harness/20261029T051735.820131Z/report.json`。森林屏外裁剪与荚帽绳端修正后的新逐怪影片已入最终manifest；R4独审另限定可见旧片的复用范围，旧媒体原source身份不改。旧94c普通片／b71正式片和旧R3保留真实来源；不能把它们重标为d91通过，也没有在本草稿宣布全CI绿。物理设备帧时、原音轨听审和用户最终视觉／趣味仍保持未验。

最终manifest／media及当前源矩阵结果已归档，公开下载按实际收据核验；本页命令、静态清单与历史通过不替代新执行证据。
