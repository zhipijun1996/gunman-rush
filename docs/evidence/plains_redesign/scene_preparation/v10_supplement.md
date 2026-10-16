# v10 当前只读补充（2026-10-15）

无实施租约、只写ignored。新读当前PlainsExplorationTopology/Generator和GeneratedShotLatchEncounter/ShotLatch全部相关表现代码；实际view `intermediate_spatial_main_movie/movie_t10_45.png`。此1100tick中间影片的Generator SHA与现在源码不相同，只可作保留的失败表现证据，不是修复后空间v10的通过证据。

## 新且影响租约的事实

1. LINK/OPEN/RETURN的大字并非全部由Stage._sign生成。`scripts/world/shot_latch.gd::_draw`直接draw_string画caption与多个link标签；`add_access_bell`又生成RETURN / RIGHT SIDE Label；`restore_sequence_gate`改变prompt_text。`scripts/world/generated_shot_latch_encounter.gd::setup`正式设置formal_presentation=true，并为每module创建回程侧铃。仅改Stage/Scenery不会清掉这些文字。**场景租约还必须允许 `scripts/world/shot_latch.gd` 中纯表现分支，以及必要的 `scripts/world/generated_shot_latch_encounter.gd` 纯presentation配置；不得修改receive/health/epoch/打开门/return_side_only权限/碰撞/clock/sequence_step。**
2. 最小实施可给ShotLatch增加仅当前connected-region启用的紧凑context presentation；保留现有彩色sigil和铃/门绑定，closed状态只在附近观察岸显示短操作提示，OPEN短反馈仅开门事件后的短窗口，已开门不永久重复OPEN。远处gate LINK标签不常驻；回程侧RETURN仅接近该侧观察岸显示。普通模块Lab/Foundry旧formal/非formal外观默认不变。不要简单删全部提示使未教玩家失去机制因果。
3. `movie_t10_45.png` 主井铃动作顶点实际在约(700,115)，当前HUD12..772×8..152几乎吞掉角色；右侧gate约x1000，map从1018,180开始盖住门的上中段，右侧RETURN标签跨出屏幕。将HUD压到约370宽，已能避开这一具体actor位置，不必先改相机；真实敌人左上追击仍须动态test。保持完整UI的正式合屏才算修复。
4. 当前真正使用的四身份键是 `identity`（不是space_identity）：`windmill_plateau`/`clock_court`/`creek_well`/`repair_gallery`；`spatial_intent`补观察用途。生成器把row0=clock，row>=2=creek，merchant=repair，其他=plateau。场景计划需按真实identity读取，不错误消费不存在字段。Clock对应landmark=ruin_arch、creek=stones、repair=ivy、plateau=windmill。
5. 当前修复后的路由定义确实包含完整端点：short_technique 0_1→1_1→2_1，upper_discovery 0_1→0_0→1_0→2_0→2_1，creek_return 1_1→1_2→2_2→2_1；均initial_open。中间影片录到的旧route_intents仍是遗漏入口/汇合的版本，**不能把该旧capture当最新route-contract接受证据**。
6. 真实语义坐标不均匀但仍按整列对齐。中间片实录column_positions 0/1760/3140/4420/5760，terrace -700/0/700/1400，first well offset(200,-282)、lowarch(840,-282)、join(1480,0)。新正式场景能精准把开阔前岸→井铃下方空域→反冲门上侧→低顶压缩→宽恢复岸串成构图，而非仅每节点换装饰。
7. 风车放置要由真实支持决定：标准junction400宽、中心保护约180宽，侧肩仅110，140..180高风车约113..145宽且还需margin时可能放不下。允许清楚记录omitted、优先640宽恢复岸/实际相邻solid，不能缩到不可辨/漂浮/移碰撞来凑“每身份都有asset”。低对比远景风车可以没有当前gameplay支持，但必须标背景深度，不能用它冒充已验证有solid支持的landmark项。

## 具体实现与检查建议

- Stage在setup_shot_latches成功后为正式connected region启用新的context表现；ShotLatch暴露实际绘制文字rect telemetry，测试能检测立即draw标签（仅枚举Label树会漏掉）。context只读实际controller位置/grounded/shotstate，不写Gameplay状态。
- 对presentation-only setter/context更新前后比对Bell健康/epoch、gate碰撞、序列步、接受shot表和资源快照；禁止为了清屏把正在工作的交互体hide/process停掉。隐藏文字不影响铃Sprite/功能sigil/真实碰撞。
- 修复后首个正常速度合屏固定相同主井铃场景约10.45秒，独立查看角色顶点、门和下一低拱接收岸，而不是只拍spawn。再补CB04上方敌telegraph、奖励返回、井底回程、camp/shop真实UI。
- 当前源码仍被其他任务锁定，本补充没有执行新Godot、改源、修改正式记录或写host_response。正式实施必须等父任务租约与最新空间/observer来源。
