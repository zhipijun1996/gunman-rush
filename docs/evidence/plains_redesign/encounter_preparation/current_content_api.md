# 当前内容接入预审（严格只读，尚未运行）

本次只读最新源码与 docs/quality/plains_redesign_experience.md；未实施 driver、未提交 host_response、未修改 source/docs/record，未执行下述候选场景。源码行号以此次读取时工作区为准，实施租约开始后必须再次核对。本页不是 PASS、真实领奖或失败回退证据。

后续正式包预算按 root 最新指令：首次启动 call_timeout_seconds=3600，max_calls=6/max_rounds=3，属于既有全局28次，不增加预算；本页和旧plan里的1800秒推荐均不能覆盖真实新租约。

## 1. 已实现的溪谷接入合同

- `scripts/generation/plains_region_generator.gd:155–163`：非sample默认正式图为 purpose=creek_discovery 的连边取其首模块，并加入真实 inline `creek_cache_bank`。bank平台局部Rect2(350,210,140,18)，one-way；实际站立中心约module.offset+(420,192)，不是场景原点。
- `...plains_region_generator.gd:163`：m.creek_discovery 包含 module、bank、entry_area、exit_area、camp、reward_id、safe_observation、return、hint_from。它的module字段为实例node ID（非仅module definition ID），`bank="creek_cache_bank"`，`reward_id="plains/chest/medium_1"`。
- `...plains_region_generator.gd:207–213`：第二中箱世界位置为实际ferry_node.offset+(420,192)，其 `approach` 复制该creek_discovery合同；奖励所属area仍area_2_2，但物理位置在渡船中段侧岛。因此follow_to(reward.area)并不构成找到/领到箱子。
- `tests/plains_creek_discovery_motion.gd:17`：实际API为 `static traverse(driver,module,bank,claim_callback=Callable(),forward=true)->bool`。caller需先module.set_meta("discovery_latch", real_encounter.for_module(module))，helper在20–22行读取真实绑定，不能伪造latch。
- helper24–43行：真实岸边起步、必要时射击启动、等实际泊位、jump登船、真实船顶支撑；44–63行：在实际途中停车、跳岛落在bank中点、至少12帧确认同船clock/position未变；64行 await claim_callback.call()；66–85行：Router drop_through返回同船、射击重启、到收岸jump退出。
- helper回调不读取/返回claim bool，最终traverse=true只证明它身体完成此链。formal必须额外核选定箱的claimedID和modal结果；不能拿原生岛上窗口测试签真实领奖。
- helper上船/停车/登岛/drop/重启属于已承诺链。自动敌情策略先在起dock处理可见敌与活动弹体，随后以局部critical-traversal标识保护该链。尤其boat上is_on_floor=true不等于安全地面射击许可；不能插任意横向射击把角色反冲出船。岛上callback可在完整实际支撑/威胁核查后处理敌情，必须保留船停/资源/回船条件。全edge永久禁策略又会恢复长地面盲走，故边界应由真实module/helper阶段限定。

旧v9无reward.approach/m.creek_discovery，继续普通箱实际位置路径；同一份driver代码按实际合同字段分支。新helper及其所有test-only依赖加入两侧共同字节闭包。旧runtime、Scenery、资源和module geometry绝不overlay。

## 2. 正式领奖的精确消费者

1. `scripts/input/input_router.gd:102` 的 request_action(&"interact")进入真实输入队列；`scripts/player/player_controller.gd:103–104`消费后emit interact_requested。
2. `scripts/demo/demo_app.gd:137`已把controller.interact_requested接到app.interact；`...:1170–1171`把_commit_interact排入原app动作队列；`...:1182–1193`验证当前life token/_can_interact后执行。测试不直接调用_region_interact或_claim_region_chest绕过输入。
3. `...demo_app.gd:601–605`由connected_region转入_region_interact；`...:1484–1492`先判nearby_shortcut（优先级高于箱），然后判箱。`scripts/demo/plains_region_stage.gd:206–209`要求该chest未claimed且欧氏距离<80。岛中央当前正对箱子，理论应优先取到箱；需实际证明没有意外shortcut吞交互。
4. `...demo_app.gd:1493–1524`根据真实build.can_add、chest.resources/reward_mode形成 `_region_offer:RewardOffer`，offer_id=chest.id；记录 `_region_chest`、`_region_offer_token`，清Router，暂停tree，调用reward_modal.show_offer。callback必须检查实际modal.opened、offer.offer_id、该索引chest.id和当前位置；不得假设随便按一次interact已经开正确箱。
5. `...demo_app.gd:1433–1440` `_claim_modal_item(selected.stable_id)`是既有UI item_selected连接的正式回调（1050–1052行）。它验证pending/modal/token，置pending，解除tree暂停，再把_commit_region_choice排原队列。返回true仅代表提交被排队，**不是已领奖**。
6. `...:1550–1555`实际队列调用_commit_region_choice→_claim_region_chest；失败可能重新pause并show_error。`...:1558–1596`验证token/health/候选，真实资源或道具服务成功才置 `chest.claimed=true`、`region_state.claimed[chest.id]=true`；record_output(stage_index,"cache/"+chest.id,{choice,resource,amount})；清offer/index、关modal、恢复tree。
7. callback须有限process-frame/physics-frame轮询到modal真实打开→提交→实际claimed且modal关闭，保留每一步时刻。当前tick会await physics_frame：tree暂停之后不能先无条件await多物理帧而不提交modal（需实际检查SceneTree暂停时physics_frame与controller_tick行为）；应在process_frame安全观测modal。不能因为Controller暂停就改手动step。

具体账本/效果：

- `scripts/shops/run_wallet.gd:4–14`：wallet.balance，真实grant(amount,event_id)以_grants幂等，测试只读_grants/余额，不调用grant。coin ResourceRewardChoice走 `demo_app.gd:1569–1571`，receiptID为app._run_receipt_prefix+"/"+chest.id+"/resource"；不是另加chest.coins。
- heart资源走1569/1572–1574的SupplyHealEffect真实health receipt；满血heart会在候选形成时跳过（1511），不可硬选不存在项。
- note资源走1575–1579的app.meta.grant_notes；使用meta.snapshot()读真实状态/receipt，保存失败则箱应保持未领；test meta_persistence_enabled=false不代表伪造notes，必须保留真实本局服务效果并标磁盘保存非覆盖。
- item选择走1581–1584的rewards.claim(RewardClaimRequest)，成功后wallet额外grant(chest.coins,chest.id+"/coins")，实际build改变应记录。为对照控制，尽量选择真实存在的资源项（原formal也是资源优先），不能强造候选或直接grant。
- 必须保存claimed前后、modal offer/choice、wallet/health/meta/build前后、真实manifest cache output及receipt身份。只看钱包差值不够，因为可能附近coin自动拾取；只看modal关闭也不够，因为可能拒绝/死亡/取消。

最小正负测试：实际岛callback成功领取medium_1、出dock→camp；原普通第一medium真实位置领取；重复interact不重复发奖；实际错误choice或未打开modal提交不得claimed（只调用原UI回调作输入边界，不能直接篡改offer/token）；移除/搬走callback或只声称traverse=true必须被验收器拒绝。保留真实badcase原件。

## 3. 实际环境失败、回退与保留语义

- 正式环境接触源在 `demo_app.gd:289–292`：每个assembler.world_static_dangers创建DemoContactEmitter(kind ENVIRONMENT)，用真实危险矩形。移动锯另由assembler.setup_damage（283）启用；越界还在444–445有真实bounds环境伤害。
- `scripts/damage/demo_contact_emitter.gd:24–59`通过上一帧到当前帧相对全身扫掠形成DamageRequest；不是点触。`scripts/damage/frame_damage_policy.gd:86–108`真实health.apply_damage后，非致死ENVIRONMENT发environment_return_requested；致死走failure，不是回退。
- `demo_app.gd:272`连接_environment_return；587–593中先取消敌待发攻击/实体弹体、latch待处理请求，再 `segment.return_to_anchor()`，成功后policy.protect_player。不能由测试直接调用这条函数或return_to_anchor制造“实际失败”。
- `scripts/damage/segment_respawn.gd:21–37`历史anchor需真实activate且is_safe；return选择最近仍安全anchor，controller.return_to_segment后invalidate_actor并emit returned(anchor_id)。`...:45–72`校验完整body不与危险/实体重叠及三个真实脚底支持射线。
- 正式anchor加入在demo_app274–281，当前默认区域assembler.world_anchors见 `scripts/generation/plains_region_assembler.gd:63–68`：spawn及非Boss的area站位。不要把某个模块definition.anchors当正式已激活segment anchor。DemoApp446–449只有grounded且距真实area anchor<38才activate。
- `scripts/player/player_controller.gd:221–238`正式return_to_segment选择性重置：session_id+1、清Router/玩家弹体/跳跃和空中动作，Motor经游戏自身reset_at回锚点；**HP、stamina、cooldown不免费重置**。segment随后使actor_epoch变化；信号回调时epoch可能尚未递增，需下一真实帧检查完整结果。
- 敌/机关/奖励保留要说准确：同一stage、EnemyMotor/Actor、latch、chest及钱包实例保留，不重建地图/恢复敌满血/重新发奖。`demo_app.gd:1471–1476`会调用实际EnemyAttackBehavior.cancel；其136–141行清活动弹体并进入recovery、保留health/home/position，不能错误断言attack_state/clock完全不变。latch `cancel_pending`在shot_latch.gd190–196只清待处理请求/seen/eligible并递增request_epoch，保留已开门/计数/clock和motion；GeneratedShotLatchEncounter39–43清玩家旧弹体。取消旧攻击是正式规则，不能称测试关闭敌人；下一真实phase继续自然AI。

## 4. 最小正式失败回退候选（未运行）

选择map1默认第一段真实 `plains_windchime_well`，它已在D1保留；从正常DemoApp.start_plains与教程真实输入进入，按实际Manifest first_short_chain连边的modules查实例，不硬编码绝对坐标。其 `resources/generation/modules/plains_windchime_well.tres`真实leftbank localx0..280/floor300、pit x280..380、ENVIRONMENT danger Rect2(280,390,100,30)。实际module.offset决定世界坐标。

预条件：实际health>1，未paused/life active；不要为满足前提注血。先走真实左岸，例如module.position+(250,282)，记录最近正式安全anchor历史，不手动activate。可先用真实Router射铃开门后落稳，记录该latch实际is_open/open_count；若要同时证明奖励不回滚，先沿主路到第一medium实际箱位置领取，再用正式双向路径回本well。初次最小probe只证明实例/门/资源保留，不把没领取的箱当“奖励保留已测”。

刻意失败输入：不跳，Router.set_move_axis向井中心，仅有限帧走至module.position.x+330并保持该x，身体自然从实际地面边缘跌入坑；不调用damage、force_return、return_to_segment、bounds请求，不删平台/改危险，不碰任何actor坐标/资源。用实际接触源/FrameDamagePolicy commit证明ENVIRONMENT伤害→segment_returned/segment.returned，而非仅看到位置突然变回。最多一次，health不足或环境未触发则bounded failure，不换Seed/乱走别处刷成功。

回退验收：health真实减少1且未terminal；same stage/assembler/enemy/latch/chest对象ID；真实session+1/actor epoch变化；返回真实记录anchor（其is_safe及脚底支持），冷却/精力按实际自然时间推进而非归零/满补；已开门不关、已claim不清、钱包/奖励receipt不重复；敌HP和终态保留，但允许原cancel进入recovery/旧弹清理。记录伤害event_id/source/damage_kind与回退信号、输入、前后frame支持/位置/资源及manifest/cache输出。

随后从实际返回点更新当前区域，停止原走井指令，重新使用正常well→短拱合法动作并实际走到下一恢复岸。**这一步必须是真重试**，不能沿旧move_to在回锚点后继续盲走。普通正式aware route遇到非预期return仍停止并报告失败；仅此明确标注的失败恢复probe允许一次预计回退并继续重试，不把它伪装为无伤主路完成。

风险：即使第一well无强制敌，必须从实际runtime确认非致死/安全观察，不能假设敌状态；角色跨坑期间可能先碰另一实体、被动态敌打至致死，需保留本次失败，不能关敌；最小probe不等于已验全部锚点/全部设备/其他危险/所有重试。对溪船特意跌水是更高风险第二案例，会牵涉船clock和回程距离，不宜用它替代第一条可解释的well静态坑候选。

## 5. 下一租约最小需要的验证范围

1. 保留原默认blind与历史receipt命令；明确kill/bait request/closure同字节复采；当前15GD闭包加入实际creek helper与未来policy helper，完整source绑定仍包含每侧独立runtime/scenery。
2. actual formal岛callback领奖+出dock/camp；普通第一medium兑奖；重复领取负例。
3. alive/moving-away/dead/engagement-ineligible真实状态与shot→projectile→committed DamageRequest.event_id→APPLIED消费/命中回能 receipt因果；不调用正式sink缺失的Damageable.damaged信号签证明。
4. 一次上述well真实失败→合法回锚→重试，并保留实例/奖励/资源/cooldown真实边界；无构造成功轨迹不签PASS。
5. Formal tick遇到真实modal暂停时不得卡死；helper critical section禁止任意战斗射击，真实岸上的干预仍有资源/反冲/支撑保护；预算有限，所有失败可复现。
