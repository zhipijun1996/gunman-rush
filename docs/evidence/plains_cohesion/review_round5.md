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
