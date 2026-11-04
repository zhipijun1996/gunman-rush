# FOREST-FEEDBACK-01：有根的森林敌人候选

适用范围：2026-10-18 用户四点反馈后的生态增补；采用 enemy-creator 和 encounter-director，共享父任务质量记录。两新行为是可玩灰盒候选，未获整区／趣味／美术准入。旧五种行为及其 Definition 参数未改，Boss 和 Player 未改。

先比较三种机制假设：树皮甲虫要求观察朝向、绕背或从树枝下射；吊荚摆锚要求理解有根的移动弧线、选接锚相位；树孔喷籽只会复现棘籽哨的预告后远射，因此淘汰。选择前两者分别补根地角度战斗与树冠动态空间，不按新增数量扩产。

## 树皮甲虫：根盘上的方向材质

唯一参数源 [Definition](../../resources/enemies/forest_bark_beetle.tres) 和 [ForestEnemyDefinition](../../scripts/enemies/forest_enemy_definition.gd)。HP 3，身体 36×24，普通接触伤害沿正式消费者为 1；巡速 32 px/s；Definition 默认巡半宽100 px，正式实例由版本化 Manifest 覆盖（本轮20／55／60／65 px等），不把默认值当作全部遭遇参数；正面左右各 55°树皮挡弹，后部及顶部普通受伤，不增加 HP。攻击距离 220 px且垂差小于60，预告 0.9 s，沿预告时面向以180 px/s推进，最长0.45 s，原巡逻边界内最多81 px；恢复1.2 s，再休息1.8 s。保护半径45 px，正式并发预算仍来自原消费者。

状态：idle 在实际有地面的巡逻带缓步→目标在正面、垂差／距离／保护岸／真实视线／并发合法时 telegraph→锁朝向及末点 attack→recovery→idle。越过甲虫不会被瞬间自动转向追脸；只有到巡逻边界或真实阻挡才转身。取消攻击复用既有恢复债务。伤害仍由 Damageable 的 epoch、去重、HealthState、正式回调与资源账本处理，盾仅拒绝正面方向，不另建 HP。

1. 新问题：横向站桩枪线被树皮阻挡，玩家先读壳面，再决定从背后或上方进攻。
2. 策略假设：走树洞侧路绕背、从上枝向下射击、借固定／活锚换侧、等巡逻转身或非击杀通过。正式已证明的具体范围见后文；这些假设不全算已验证策略。
3. 关系：树干平台提供高度，钩索改变相对侧，射击反冲可维持顶部枪角，但不强制把每次反制都变成固定连招。
4. 差异：根盘冲锋只考验预告位移，甲虫新增固定朝向的防护材质；棘籽哨射程与高 HP 均不能复制此问题。
5. 单独先展示正面拒弹、顶部可伤，再与较远的铃囊萤组合；禁止用盾体堵唯一树洞或唯一接收岸。
6. 站桩：在背面得到安全枪线可以迅速杀死，这是成功绕位后的奖励；固定朝向的正面枪线被挡；巡逻转身后的背射可以快速击杀。不能把枪线始终在背面生成后仍声称有效角度遭遇。

生成合同：根地／树根地块，身体脚底为出生y+12；连续承托区覆盖完整巡逻身体包络，预告可见；甲虫不占唯一落点。场景提供可见上枝或绕背通路。已验证的正式路线及具体出生配置见后文；未覆盖路线、低资源和非击杀替代仍未验，局部 fixture 不代签。

## 吊荚摆锚：树冠悬根的相位工具

唯一参数源 [Definition](../../resources/enemies/forest_swing_pod.tres)。HP2、身体26×30、接触伤害1。没有额外弹体。出生点是弧线最低中心，悬根在其上100 px；Definition 默认横幅±100 px、上升70 px，周期4.8 s；正式 `grotto_swing_pod` 的 Manifest 横幅为±85 px。实际位置目标为 `home + (radius*sin(phase), -rise*sin(phase)^2)`，速度由该曲线导出，默认幅度的最大水平约130.9 px/s，正式85 px幅度约111.3 px/s；在两端自然减速，`abs(sin)>0.88` 的turn环标出可读接锚窗口。此曲线是幻想植物弹性吊荚的运动，并非宣称刚性绳摆物理。

状态：swing→turn→swing，每个相位由保留的本地时钟产生；真实 EnemyMotor 逐帧碰撞拥有运动，碰到树干进入blocked并停在实际近侧，不穿墙、不瞬移到另一端、不无限重试。失活/暂停保留相位；死亡取消身体与活锚，正式固定替代锚必须仍可用。保存通过现有 depth_snapshot/restore 接口恢复clock与blocked，非有限或越周期值原子拒绝。

1. 新问题：锚点不是两岸点对点直线运输，而是有可见根系的连续弧线，玩家判断何时接近和何时松钩。
2. 策略：两端低速时接锚；中段横移时提前瞄准；从固定锚走稳定路线；普通射杀清除危险；保留活体用作可选快捷角度。
3. 关系：树冠开口匹配弧线，反冲可离荚改向，身体接触仍有风险。唯一主路不能依赖其活着。
4. 差异：铃囊萤按目标/停留点决定平移并留下危险区；摆荚不锁旧玩家点、不造区，其确定周期弧线和端点减速构成空间相位。
5. 单独从宽观察枝展示，后续可与远端织棘蛛的有限线组合，但不能让唯一固定锚被两者同时封锁；观测岸到攻击条件逐项查真值。
6. 站桩：安全射杀合法，但删掉移动活锚捷径；若正式地图普通路线与活锚无实际取舍，应撤掉该遭遇，不以“能抓到”代签价值。

生成合同：树冠／悬枝地块，出生周围横±(实际巡半宽+13)、上85、下15 px无实心遮挡，悬根连接可读树枝；树根不是碰撞平台。不能放入主路狭缝导致一出生就blocked。附近始终有固定替代钩点及可恢复岸，安全岸不放在荚身体扫掠内。

## 验证范围

新 [局部真实消费者测试](../../tests/forest_feedback_enemy_runner.gd) 继承原fixture工具，不改旧断言与旧测试。覆盖真实Router子弹的正面拒弹／后背击杀／顶部受伤、完整预告移动、实际摆动轨迹、暂停相位、存档非有限拒绝、真实钩头捕捉，以及树干碰撞停留。正式全路线、已死／活体替代路线、低资源与端相位组合、正常速度影片和独立体验审查仍须分别实证，不能由此局部检查推断完成。

首轮局部实测 `build/forest_feedback/enemies01/native01/capture.json` 为23断言／1失败、exit1，无脚本错误或泄漏。正／背／顶部弹体和摆荚物理／钩头等局部检查通过；甲虫预告观察未通过，不能以其后巡逻位移的PASS声称冲锋已验证。当时仅假设首枪反冲推离激活范围，原raw没有该case坐标；后续02才用新鲜观察与明确范围谓词补证，未增加激活参数。

后续 `build/forest_feedback/enemies01/native02/receipt.json` 为真实 fresh 24断言／0失败、exit0，13.700秒，原生4.7.2；整个 scripts/resources/scenes/tests/tools 前后 SHA 无变化，完成标记存在，严格日志无错误／泄漏。独立fresh观察实见 telegraph、commit ledger、attack及固定目标推进；甲虫从118.667推进到189.987，实际玩家身体在220阻挡使其停在近侧，未穿人。保留前弹case末状态：玩家334.700、home100、距离234.777超过原激活220、can_engage=false，直接证实首轮混合fixture的射击反冲越范围假设。首轮FAIL不重签。

该局部02之后，按父集成需求仅增加 Stage 的甲虫 `initial_direction` 行字段：严格int±1、赋给已duplicate的Definition，再由原brain.configure消费，未改共享资源默认值。局部02的source guard不覆盖这次后加四行；正式新地图fresh入口／保存／方向验证须覆盖它。正式场景有安全背面枪线、反冲高度、活锚收益、遭遇疲劳及用户体验仍不由24项局部检查推断。


## 最新局部契约证据与正式配置

`build/forest_feedback/enemies01/native03/receipt.json` 为原生4.7.2、原wrapper新增消费者的实际35／0、exit0，严格日志无错误／警告／泄漏；源与验证器前后SHA保持，`feedback/capture.json` 留有全部35项顺序检查。它在同一现有 `run_forest_depth_enemies.py` 的default旧golden成功后追加，旧断言／分支／原生180秒预算未改。该轮只单独执行新增消费者，不能声称旧长golden也在本地重跑；原default仍保留它们。

独审FF-R02指出旧盾在canonical校验前闪光，已在新盾子类内修正：先匹配父Damageable同等的有效事件／正有限伤害／阵营／目标／epoch条件，再按HealthState实例、actor和epoch记一次处理；挡下事件换向重放也拒绝，挡弹不调用提交返能回调。原24项全部保留，新增11项检查验证坏epoch、重复与换向重放、同阵营、负值、自伤、错误目标、空事件、非有限值及HP／commit不变。实际35raw的14种删改全部被严格读者拒绝，见 `build/forest_feedback/enemy_consumer01/reader_mutants01/report.json`。此技术修复不代签整体生态趣味。

当前正式新版 `forest-expedition-airborne-v11` 配置采用森林场景语义，实际关键落点为：

| 实例 | 出生中心／巡半宽 | 承托或悬根 | 当前定位与边界 |
| --- | --- | --- | --- |
| `fallen_crown_beetle` | (-945,466)／20 | `fallen_chain__crown` | 冠岸方向盾，尚不由实例存在推断有效遭遇 |
| `grotto_west_beetle` | **(-580,988)／20** | `grotto_west_lip` | 留空(-690,982)下降接收岸；原低顶位置及后续(-490,988)均退休，同岸旧`grotto_log_watch`删除 |
| `grotto_deep_beetle` | (-180,1078)／65 | `grotto_deep_root` | 深根侧向／高度换位 |
| `western_root_beetle` | (-2130,1188)／55 | `western_root_knuckle` | 桥下纯跳越身后背射；不要求向上反冲撞顶刺 |
| `western_exit_beetle` | (-850,1188)／60 | `western_root_exit` | 去返方向不同的盾面，具体操作范围以实际路线为准 |
| `grotto_swing_pod` | (-650,666)／85 | 根点(-650,566)，`grotto_hanging_bough`底面 | 悬根真实连接已成立，**正式使用价值仍未证明** |
| `grotto_thread` | (330,986)／0 | `grotto_east_root`，脚底1000 | 有限线从(180,982)到(290,982)，不靠脚悬空改变通路 |

西根补充watch位于实际倒木或根盘；`grotto_outer_watch`在新种子mix中选择旧哨或有限织线，不能据不同ID声称新物种。两类新增行为与旧行为保持实质区别，但不同Seed不保证每图出现全部类型；实例数也不是有效互动数。

## 正式路线：已证明什么，仍缺什么

正式驾驶仍只提交真实Router意图，不写坐标／HP／资源或暂停NPC。甲虫顶射先检查真实身体和反冲扫掠、危险与上层单向平台；有截获／顶刺风险则纯held跳越身后落地背射。背面原枪岸不足一次真实地面反冲包络时，先移到有完整承托的独立枪岸；每枪后回岸再射。普通地面反冲的短离地不被冒认为主动空中战斗，不连发额外空枪。意外落到上层单向平台走实际drop-through恢复，实心阻挡明确失败。杀后回原路线起点完整脚12帧，预算保持600帧／12动作请求／每次主动离地至多两枪。它是验证策略，不是敌人或玩家能力修改。

| 原件 | 实际结论 | 适用边界 |
| --- | --- | --- |
| `build/forest_feedback/formal13-west-map1/receipt.json` | 原wrapper三路线同源PASS；map1 growth2536帧、末HP3；high_return1891帧／HP4；change_mind1884帧／HP4 | 该时冻结配置的B仍(-490,988)，不是当前B的map1复验；三路线整局成功不代表无伤 |
| 同轮map1 growth实际事件 | western root beetle、western log watch、grotto deep beetle三次真弹击杀，各自回原岸12帧；三次遭遇末HP均5 | 桥下真实越身与背弹已成立，后续路段伤害使整条路线末HP3；不签全部敌人策略 |
| `build/forest_feedback/formal15-map2-westcache/00-map2-fast/capture.json` | 当前B(-580,988)的fast实际1594帧、末HP2，原读取器PASS | **该整轮receipt仍FAILED**：后续growth地面反冲短离地被误当空中连枪，越岸重生；不将fast局部PASS冒称整轮通过 |
| `build/forest_feedback/formal18-map2-westcache/receipt.json` | 修驾驶后的原wrapper同源PASS：growth3277帧／HP4，high_return2881帧／HP5，change_mind1397帧／HP4，均末E100 | 当前B(-580,988)；growth／high_return实际三次真弹击杀与原岸12帧返回（grotto_west_beetle、western_log_watch、western_root_beetle）；change_mind实际两次。不能合并不同轮源码说成一次全矩阵 |

formal14卡上层单向平台、formal15后续growth越岸等失败保留，后续有界驾驶修复不追签原失败。formal11的真实combat jump与后续route jump曾被旧全局计数混淆；只对完整开战→真实弹体／Policy／HP／资源因果→返回12帧的v11遭遇分类，原路线单跳／held时间／几何断言保留，不能忽略所有额外跳。

**独审FF-R06仍未解决：**摆荚在局部fixture能被真实H命中，也有正常周期、物理阻挡和存档相位证据；但上述正式常用路线没有以它为实际H目标的记录，尚无相对固定路／普通动作的操作收益对照。悬根接上实体枝不是玩法价值通过，更不能写成已完成“活锚捷径”。需实际利用路线与普通／已死替代同条件对照，或删除／重新编排该遭遇。其余高低资源、非击杀替代、最差巡相、真人初见与设备认可仍未验，整体维持REVISE／review。
