# Forest v18 round11 原生记录与短反馈独审

2026-10-22，reviewer `/root/forest_v18_review`。本报告前半是对冻结 round11 的只读独立技术审查，没有运行 Godot；后半的wrapper修复由同一agent依root新委派实现，属于作者自验，明确不自签新wrapper独立验收。

## 来源已独立恢复

证据：`/tmp/gunman-forest-v18/round11`。原before/after source inventory完全一致，3699路径；44项changed-source.zip逐项SHA吻合；其余3655路径逐个从baseline `e594d3ff54daaf9d8f5e30f3190890737ce39a1e` 的Git blob重新计算SHA，也全部吻合。未借当前工作树解释旧原生输出。

独立可执行分析 `/tmp/forest-v18-native-audit11.py`，结果 `/tmp/forest-v18-native-audit11.json`。脚本只读原记录/Git，把结果写/tmp；不是另一次原生重跑，也不是从meta文本推断源稳定。

完整receipt为exit1/source_stable/137.396s：world与union通过，四条App局部路径通过，两个lower-window回路失败。必须保留整体非绿结果。

## 四条路径的有限技术接受

| 实际记录 | 帧数 | 完成/完整itinerary | 终点 |
| --- | ---: | ---: | --- |
| map1-main / places_main_trial | 985 | 21/21 | gate_ready |
| map1-reward / places_reward_trial | 1284 | 28/28 | gate_ready |
| map1-outer / places_outer_trial | 2144 | 38/38 | camp |
| map2-main / places_main_trial | 985 | 21/21 | gate_ready |

四条合计5398实际帧、108段。独立重新由各记录的manifest.routes→connections重建Bible reader itinerary（包括ordinary_sequence的末尾walk），与每条报告完整逐项相等，不只是比较长度。每个完成事件索引/edge与实际itinerary对应，108次完成均有末12帧真实grounded、完整脚宽落在manifest中实际support上。最终位置与真实area goal在原消费者容差内，末帧同样有完整支撑。

所有5398帧观察body均为24×36、与中心位置相符；motor_steps均为int1。tick逐帧连续，无缺帧跳段。源中的驾驶通过Router提交轴/跳/钩/射击与实际modal鼠标事件，没有调用第二个Motor、途中搬运或资源写入；继承Motor、控制、资源源均已从baseline核原字节。

**四条都是局部C fixture，不是正式普通出生点。** fixture记录original spawn[-2200,1882]、actual C[1030,282]、motion_steps_before_override=0、resource_or_health_override=false；对应`fixture_app._load_stage`只在同步实际装配之后且首个Motor之前设置一次global_position。初始快照H启用、D/W关闭，pulse_gun tier1、2枪、HP5、energy100。没有middle/resource injection的声明与实际源一致。

因此接受的是：当前source上，实际App/Stage对象、Router和Motor在这一个初始C定位之后的四条指定完整路线。不外推formal_spawn、其它种子、低资源、失败恢复全覆盖、手机操作或趣味。

## 真领奖及幂等

map1-reward不是到箱位置便算领取：tick958记录 actual OR wallet before0coin/0note → after4coin/0note；地区claim键`thorn_forest/map_1/places_seven_backside_cache`变true，items未变。实际modal5帧和鼠标press/release同一可见选择按钮“Coin Pouch”有原件，duplicate_before与duplicate_after全快照完全一致。

源是实际wallet/meta/claimed snapshot，与原 `drive_cache`/真实GUI按钮派发联合，未直接加余额或写claim。限定接受本次“4金币 OR 0音符”的金币分支与重复领取不变；round11没有执行音符分支，不能签两种奖励都已跑完。后来的primary音符记录是另一个来源/版本，不能追认本轮。

## 危险、HP、生态的实际范围

四条记录的角色HP观察范围均5..5。重新对每帧body与manifest全部静态dangers做相交检查，0直接相交；相邻body包络的保守swept-AABB候选也0。它只说明这几条记录没有所观测静态危险接触，不是整图无伤/fairness或动态危险穷举通过。

map1-outer有真实战斗：weaver tick1376受1、1397致死；随后root_seed_watch在1924/1973/2024受击并死亡。五条committed_damage均是玩家弹体打敌人，不能误算成玩家扣血。主路其余三条没有这些damage事件；不能拿其中一条静态无事件证明任何敌人策略都成立。

这份trace有实际敌/弹体消费者与事件，仍没有影片或设备观看。没有把HP5写成全图“无伤完成”，也没有推断用户手感满意。

## 两个窗口失败保留

map1-windows、map2-windows均737实际帧、7/11段，失败为`bounded_hollow_phase/hollow_outer_takeoff`、incomplete_actual_itinerary、actual_final_goal_not_reached/E；停在约[1620.0004,1061.9771]，没有到E。它们是**新v18世界里的 places_window_loop**，不能把旧v15 producer的历史通过覆盖到新嵌入，也不能反向声称原v15旧版已被证伪。源里实际旧driver与新translated几何的关系须另修/重验；本审查仅凭这个timeout不宣称几何永远不可通。

整轮exit1是正确的。四条真实成功路径不会抹去两条失败；之后新trace精简/embedding修正和新record只属于新scope。

## world / union究竟证明什么

world原件20条真实root-derived样本、165assert/0fail，核查JSON重播、重新hash实体变更拒绝、小数map拒绝、Boss实际已移出旧sector、normal route含新增场所、保留default15与timing unverified。signature用实际rect/one_way排序去重，改ID、顺序、重复描述不算变体，较v17元数据签名问题已纠正。

但这里统计的是包含旧core的整个图：distinct_shapes8/9不能声称新模块有8/9个不同机制或宏观新拓扑。当前新内容仍是一类seven局部结构变体+复用双窗，地图身份与宏观组合尚未完成。原生20seed通过不证明8–12/15–20分钟；这些仍是首次真人时长目标。

union原件2347assert/0fail，两variant分别297/288 solid、644/636 canonical edges，无内部曝光边；split/reorder/duplicate的等体几何轮廓签名一致，且保留v18.4冻结union不变的检查。它是等体与轮廓技术事实，不是木质艺术/自然构图通过。早期round07 644失败与之后修正保留原范围。

## 原round11短反馈的真实假绿反例

审查精确round11 `tools/run_forest_places_feedback.py`，只在/tmp以mock run_engine注入报告，没有执行Godot、没有修改生产。复现脚本 `/tmp/forest-v18-wrapper-negative11.py`，结果 `/tmp/forest-v18-wrapper-negative11.json`，每个伪报告实验均让原wrapper20checks/exit0：

- 错route/map/seed的真实非空记录被复用到其它job；wrapper未绑定身份。
- `completed=[]`与`itinerary=[]`同时清空仍可通过原长度比较。
- reward job无reward_transactions、无实际OR结算仍可通过。
- formal job自报用了initial fixture pose，原wrapper不检查权限。

模拟中除被试字段外还有复用local/main身份等故意错误，明确是协议反例，不是证明引擎曾输出这些伪数据。四条真实native证据已由独立完整轨迹审计确认，因此这些guard缺口不推翻它们；但以后runner遗漏/错绑可能假绿，wrapper需修。原有正则标记唯一、fresh普通输出目录、native非零/timeout/缺report拒绝、source前后稳定、原90/240/600预算本身无需放宽。

## 新wrapper修复（作者自验，另scope）

root在主冻结解除后明确委派本agent修wrapper。只改 `tools/run_forest_places_feedback.py`、新增 `tests/test_forest_places_feedback.py`；没有Godot、物理、profile、预算或其它生产改动。此段不作为本agent独立验收自己所写wrapper的结论，交root复核。

新guard要求job route/map/root seed/derived seed/layout/scope绑定；formal spawn与第一次Motor前fixture分别核对实际初始pose；禁止注入；强类型连续tick/Motor1/body观测；从manifest精确重建非空itinerary；完成逐段实际目标与末12帧fullfoot；最终真实goal；reward实际选择的OR增量/claim/duplicate完整快照，以及真实modal暂停/鼠标按钮证明。local仍保留明确初始fixture、选定变体/route、真实完整step事件与实际目标，没有将它升级formal。

8个纯Python测试均通过，包括正式/fixture/金币/音符正例和身份错误、同步删证、正式偷用fixture、Motor bool、假body/支撑、缺真实奖励、OR错选/双领、动态modal、重复20seed等反例。对primary source3f37...的18个已有原生JSON（world/union+8local+8App）离线严格复核全部接受；并非新runtime引擎重跑或新harness全绿收据。

作者自验收据 `/tmp/forest-v18-strict-revalidation.json`。6个对真实原生记录的精确单字段/同步截断反例由新validator全部拒绝，见 `/tmp/forest-v18-wrapper-negative-fixed.json`。root应审这些改动及反例，不能由本agent自签独立通过。

## 最终限定

round11四个C-fixture路径与一次真实金币领奖获有限技术接受；本轮候选整体因两个窗口失败不通过，原wrapper报告协议有可复现缺口。森林新库、地图身份、宏观随机、整体艺术、正常首次时长与彻底探索时长、用户/设备均未完成。不能把这些native帧数换算成真人8–12或15–20分钟，也不能拿静态App黄金冲销这份真实失败。
