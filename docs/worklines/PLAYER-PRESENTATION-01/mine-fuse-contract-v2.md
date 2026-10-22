# 磁吸雷最长引信专项

用户本轮明确要求：“磁吸遥爆增加一个定时爆炸的上限，到了时间即使不控制爆炸也爆炸，增加音效，从慢到快的滴滴声”。这是本轮唯一的玩法改动例外，覆盖之前本工作线仅表现的限制；滴声仍由表现消费者读取真实引信，不拥有爆炸定时器。

共享运行写集只涉及 `WeaponDefinition`、`WeaponEntity`、`resources/weapons/magnetic_mine.tres` 和 `magnetic_storm.tres`。原定时基础炸弹 `fuse_seconds` 保留，不能复用于磁雷最长引信。新增 `mine_fuse_seconds` 默认为0（其他分支），有效磁雷必须是有限正值且不大于实体寿命，上界30秒。两件磁雷 Definition 都显式配置6秒，从实体真实生成时起包含飞行／附着时间；普通攻击、Lv.3 普攻及强化雷共用当前 Definition。

旧磁雷只有通用4秒寿命，到时无声消失。此版两件磁雷的 `entity_lifetime` 和 `mine_fuse_seconds` 均设6秒；每个物理帧先检查宿主／附着目标是否仍有效，再结算引信，最后处理通用寿命，避免同一截止帧先静默销毁。到期只调用原 `runtime.explode(self)`，保留原伤害、爆心、遮挡、借爆反冲、攻击包与资源路径。原 `valid_owner`／spent 判断和 dispose 保证手动提前爆炸后不会再爆一次。

暂停沿现有 PAUSABLE 实体过程冻结 age；不创建实时时钟／Timer。死亡、换装、重生、场景切换、段返回或失去合法宿主时仍按原规则移除实体，不留延迟爆炸。附着目标已移除、飞出射程等既有失败退出保持不变。本次没有延长任意飞行射程、改变碰撞、移角色或新增资源／授予。声音和视觉只可读取 `entity.age` 与 `runtime.definition().mine_fuse_seconds`；可计算剩余比例／节拍，不能反向触发爆炸。

影响消费者：所有实际用两件 Definition 的 Home、正式 Plains、其他正式装配与旧测试／工作室，而非仅本次 Preview。共享 UnderworldPlayer 与 body/style 无变化；原动作设计附件不重写，新规则由本用户原话及此版本增量追溯。合入前仍由总控组织全部受影响 Integration。

可证伪条件：有效存活磁雷未遥爆时，生成后6秒内按原 explode 路径产生且仅产生一个 blast；六秒前不自动爆；任意有效缩短配置也生效；手动提前爆炸不会在原截止再爆；暂停不推进引信；原退出不产生迟到 blast；所有非磁雷配置为0且实际枪弹不新增定时爆炸。

`tests/player_presentation_01/mine_fuse_v2.gd` 通过原 Home 创建真实正式 actor，使用原 Router 开枪、原 Home 墙面附着；没有写玩家坐标、HP、精力或共鸣。两个真实磁雷 Definition 的6秒测试各观测360个物理 tick，自动到期一次；配置克隆0.10秒验证仍在飞行中到期且同寿命优先爆炸，0.65秒配置用于退出反例。配置克隆仅是明确的测试 fixture，未写回 Definition 资源。验证还含暂停／手动遥爆、equipment/death/reset/respawn/segment_return/scene_changed 退出、所有15 Definition 和实际非磁雷射击。音频服务静音，仅验玩法，不签声音或美术。

首次专项运行：`bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/player_presentation_01/mine_fuse_v2.gd -- --output=build/player_presentation_01/weapon-v2/mine-fuse-first.json`，退出0，107检查、0错误；原 JSON／日志保留。此结果含 Lv.3 Definition 的真实普攻，不是攒资源释放 Lv.3 技能证据；后者由全武器专项覆盖。声音、连续真实电影、玩家手感／设备及完整 Integration 仍未验。

独审发现并关闭一个截止帧竞态：原先引信检查在附着目标有效性之前，目标恰在截止帧移除会错误地在旧位置爆炸。现将原附着有效性检查提到引信之前；目标已 free 或已移出场景树时立即 dispose，不能提交爆炸。合法附着到期时先用原 attachment 关系更新当前爆心，再走原 explode。新增实际 Home 回归：真实附着到原墙，等待 age=5.99999999999998，恰在下一步越过6秒之前分别移出／free 该墙；不写玩家或雷的位置。修复前 `mine-fuse-host-regression-before.*` 123检查、4错误，确实观察到两种过期旧爆心；失败原件保留。修复后 `mine-fuse-host-regression-after.*` 123检查、0错误，两种移除均0 blast，完整原专项仍通过。新增测试的墙移除是明确破坏式 fixture 行为，不是正式移动平台／敌人生命周期全面认可。
