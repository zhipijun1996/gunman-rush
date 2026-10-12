# D082 独立严格审查，第 5 轮

审查方 `/root/d082_strict_review5`，遵循 AGENTS 每轮新独立审查方要求。生产代码与仓库测试只读，唯一仓库写入为本报告，实际独立探针在 `/tmp`。

## 基线裁决：REJECT

基线提交 `3b3f26ee94dd640a285dfb92f21152d79d7e9968` 存在正式小 Boss 高台起跳被错误判定离场的阻断缺陷。封场实体墙与战斗资格仍使用不同范围：实体墙覆盖世界高度，而 `DemoApp._in_boss_core()` 使用旧的 Boss 矩形顶部局部 y=250。小 Boss 最高平台顶为 y=410，人物真实站立中心 y=392，正常 held jump 可以越过顶部。Boss 平台战斗不应把正常的空中操作判作场外。

### 独立实际复现

命令 `bash tools/godot.sh --headless --path . --script /tmp/d082_review5_probe.gd`，Godot `4.7.2.stable.official.ed1daf0bf`，退出 0（诊断探针记录反例，不是通过验收）。正式 `DemoApp.start_plains("d082-review5-mini-top")`，首图 linked_rings，实际 mini 场地。

明确 fixture 将角色出生于场内触发真实封门，然后出生于实际最高平台 `(800,392)`；此后只使用真实 InputRouter 跳跃与射击，未修改 Motor、速度、跳跃高度、资源或碰撞。为隔离几何资格问题关闭敌方攻击与 Boss 行为，不冒充自然战胜 Boss。

实际输出：

```
START seal=true grounded=true local=(800.0, 392.0) core=true
APEX core=false local=(763.333, 249.4474) eligible=0 seal=true alive=true
RESULT minimum_y=249.447387695312 outside_frames=8 eligible_empty=true
```

正常 jump 后约 8 帧被判场外，实际 shoot_release 无 Boss 有效射击记录，封门仍关闭且 actor lifetime 仍活跃。此时外框判定同时取消此前射击资格，禁用攻击接触消费者。最低 y 受随后真实横向射击反冲影响，此证据只声称已越过 250，未声称达到理论极限高度。应将**已实际封门的正式场地**战斗资格与实体墙可用横向范围及真实世界高度对齐，同时保持未封门、旧八关退出、死亡拒绝和真正越过横向墙的拒绝条件。

修复与修后实测待追加。此次否决必须保留，不以先前 round4 的有限通过覆盖。

## 修后独立复测：有限技术 PASS

生产修正仅在正式 `PlainsRegionStage` 的真实 `BossArenaSeal.closed` 状态下，将资格范围改为实体墙之间的 x 范围及与墙体覆盖一致的世界上下范围（world bounds ±200）。未封门与旧八关仍使用旧矩形，未修改人物物理、碰撞、弱点或精力。修后工作区 `git diff` 对 Motor/Tuning/Input 仍为空。

复跑同一正式 seed、同一实际最高台和真实输入，并增加真实 receiver 消费者负例。探针 `/tmp/d082_review5_probe.gd`，日志 `/tmp/d082_review5_probe_fixed.log`，退出 0。实际输出：

```
APEX core=true local=(763.333, 249.4474) eligible=1 seal=true alive=true
RESULT minimum_y=249.447387695312 above_old_trigger_frames=8 eligible_empty=false
FIX_PASS=true
SIDE_OUTSIDE_REJECT=true SINK_SIDE_REJECT=true
UNSEALED_OLD_TOP_REJECT=true SINK_UNSEALED_REJECT=true
DEATH_SUBMIT=true
DEATH_ACTIVE_FALSE=true DEAD_SHOT_REJECT=true DEAD_SINK_REJECT=true
```

同样越过旧顶部的真实 jump 现在保持战斗资格，实际发射有资格记录；侧墙外和未封场顶部仍拒绝资格与捕获的 Boss damage_sink。通过真实 FrameDamagePolicy 显式死亡 fixture 杀死玩家后 lifetime 停止，射击登记与旧 receiver 消费者均拒绝。场外位置/死亡是明确负例 fixture，不声称玩家自然逃过实体墙或自然完成 Boss 战。

额外独立运行生产回归：

- `bash tools/godot.sh --headless --path . --script tests/plains_cohesion_runner.gd` → `/tmp/d082_review5_modules.log`：退出 0，**63 assertions / 0 failures**，新模块实际双向扫身与四相位消费者保留。
- `bash tools/godot.sh --headless --path . --script tests/plains_cohesion_drops_runner.gd` → `/tmp/d082_review5_drops.log`：退出 0，**17 assertions / 0 failures**，实际落物到达/领取/重载幂等、场内环境回退保留。

死亡探针和 drops 回归退出仍出现已有 ObjectDB/resource 泄漏警告及资源在用日志，未声称日志无 error；此次未扩大改动处理既有退出清理。新生产正式生命周期回归由主代理另跑；公开部署和自然 Boss 战/设备手感不在本轮独立验收范围。此前基线 REJECT 保留，必须以修后实际代码重新导出发布，首次 `3b3` 的 CI `38213313129` 已成功发布（取消请求晚于完成），该构建仍是存在已知缺陷的基线；最终修正必须再次部署 `17c6ef1b1de0c34aaf83d6002c5b32344ea04237`，以新部署核验结果作为交付证据。

主代理已将复测修正提交并推送为 `17c6ef1b1de0c34aaf83d6002c5b32344ea04237`。主代理另外报告生命周期18/0、正式Boss22/0、旧八关WindkeeperApp19/0；这些非本审查方独立执行结果，完整15套区域回归及修正后的最终公开部署继续由主代理完成。
