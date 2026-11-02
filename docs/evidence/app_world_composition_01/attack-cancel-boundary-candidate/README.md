# P1 窄候选：取消攻击回到实体/Stage owner

固定源 `c8d39551bbe79b40895e96bdcdf8250c56939813`，三份原件均与该 Git blob 完整相同。仅外部候选；不写主树、不运行 Godot、不干预正在运行的完整171 CI。candidate.json给每叶与补丁SHA、实际调用者。当前结果不是 native PASS。

调用方向：

- 原：App._cancel_enemy_attacks → Stage.enemies → EnemyMotor.get_node("Actor") → Actor.attack_behavior.cancel；再 Stage.boss.get_node("Encounter").call("cancel_pending_attacks")；最后 App 清自身 eligible shots、有效controller的玩家projectiles。
- 新：App 原 Generated/instance guard → Stage.cancel_enemy_attacks → 原顺序遍历，每个有效Motor的Actor.cancel_attacks → 原Boss查找/has_method/call → bool；App仅bool为true时执行原两项自身清理。
- Actor.cancel_attacks 真正复用三处：Stage遍历、原_on_death、原apply_skill_impact。**reset原来没有取消语句**；root已确认不得新增取消行为，reset完整字节不动。on_death仍先音效、再取消、再stop/碰撞/processing/defeated；技能仍先terminal/cooldown拒绝，再stagger状态，再取消，再可选knockback。

Stage bool只表示原Boss方法存在且call执行过；不解析/要求Boss取消方法自己的返回值，不改失败语义。没有有效Boss或没有method时false；敌人照旧已先取消。保原Motor is_instance_valid与get_node("Actor") cast，没有新增Actor空值防护；保原Boss is_instance_valid、get_node("Encounter")、has_method/call动态行为，不把get_node换get_node_or_null、不加额外guard。无新epoch/RNG/物理/伤害/状态机。

精确静态证明：

1. prepare.py反向替换后3完整文件原字节相同；外部有限文件镜像git apply/check/reverse均通过。
2. 将新Stage体的所有权字段名、Actor窄方法展开，结果与原App从enemy loop到Boss.cancel调用的语句序列逐字相同。
3. App原Generated准入guard未改；原_Boss_eligible_shots.clear → controller有效性 → clear_projectiles次序保，6个实际App调用点不变。
4. 新Actor方法仅保原非null条件与行为.cancel；两个原位consumer精确逆还原，reset函数原字节一致。没有仅为外部封装留下两份同算法。
5. 未发现tools/tests Python内直接要求旧_cancel_enemy_attacks/actor.attack_behavior.cancel/cancel_pending_attacks字面源码的静态consumer（有限rg，不是全工具语义证明）。没有新注册/配置/测试/UID文件。

真实App入口6处：_load_stage（换图）；_environment_return（环境回返）；_player_fatal；_run_ended；_offer_generated_exit；_enter_generated_exit。原tests直接App消费者16处在candidate.json中保留路径/行/所在函数；多数是显式历史森林路线，列为调用者不等于要求恢复到默认CI。当前一般audio_feedback_rewards有两处。Actor死亡由damageable.died连接；技能真实PlayerController:210调用，原all_weapons_runner:188也是消费者。

待CI完成后root决定是否应用/验证；建议有限原检查为core（720）、enemy-structure-native（300）、all-weapons（300）、audio-feedback（240），覆盖实体死亡/技能、App取消后的真实奖励/音频路径。run-session（180）与item-v5-boss-time（240）可按实际受影响覆盖取舍。确切原argv见candidate.json，不改任何预算或默认171集合；本候选未跑任何一项。不把本批写成所有生命周期完成。
