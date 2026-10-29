# ENEMY-ALL-02：库存与真实实录

本页是制作、采证工具说明。库存不代表逐怪完成，视频不代表玩家已经批准。

## 当前库存

可重新读取的结构化清单见 [`roster.json`](../../evidence/enemy_all_02/roster.json)。

| 类别 | 现有对象 | 统计口径 |
| --- | --- | --- |
| 普通物种 | 14 | 平原 7（含 patrol_drone）＋森林 7 |
| 普通宿主渲染链 | 22 | 平原 7 × scene/underworld ＋森林 7 × scene ＋ RootBellPresentation 独立链 |
| Boss 场景 | 8 | clockwork、bellstrider、windkeeper、thorn_guardian、thorn_queen、rootbell_v2、weave_v2、canopy |
| 有运行消费者的 Boss scene/Definition 组合 | 9 | windkeeper 默认旧 12HP 版与正式 storm 36HP 连续可伤版必须分列 |
| 开发候选 | 2 | candidate_lure_guard、candidate_crosswind_moth；不进入正式随机池或存档承诺 |
| 孤立 Boss 资源 | 1 | plains_bell_warden.tres；未找到 scripts 消费者，不多算一个已准入怪物 |

22 是原有宿主链计数。相同 scene 还会受祖先 metadata 影响：森林正式身体需要 `forest_bible_actor_art=true`，Underworld 正式身体需要 `underworld_formal_style=true`。采证必须写出此选择，避免用备用几何冒充正式身体。

## 实录工具

```bash
python tools/enemy_all_review_02.py --group plains --chains all --output build/enemy_all_02/plains
python tools/enemy_all_review_02.py --group forest --output build/enemy_all_02/forest
python tools/enemy_all_review_02.py --group prototypes --output build/enemy_all_02/prototypes
```

调试单怪可加 `--species plains_charger`。`--require-remains` 只用于 charger/diver 等现有政策明确留尸的单怪审查；不能对所有物种强制套用同一死亡政策。

工具真实调用 Godot MovieMaker，1280×720、60 FPS、正常速度，编码出含双声道音轨的 `review.mp4`。同时保留 `trace.json`、`chapters.json`、`chapters.md`、引擎原始日志、媒体属性、源文件指纹与报告。未压缩 AVI 在校验 MP4 与 SHA-256 后默认清理，可用 `--retain-avi` 保留。

每例仅在开始前设置地形与站位。玩家 Controller、InputRouter、武器、资源、物理、敌人 AI 保持运行；只由脚本替代实体键鼠适配器提供输入。玩家与怪物都注册真实 FrameDamagePolicy，敌人接触与弹体伤害仍然结算。驱动不直接写 HP、不强开 AI state/弱点、不在过程中搬移角色、不关闭 AI。

逐例先等待真实攻击承诺；保留警告、动作与恢复，再每 100 帧请求一发真实射击以分开非致死受击和恢复，最后致死并连续观察至少 210 帧。盾甲虫通过真实跳跃与移动绕过盾面；原型守卫等待真实 recovery 窗口。实际输入、射击、伤害事件与终态分别记账。

接触型物种不虚构远程攻击：patrol 为巡逻接触；lantern 为 dwell/telegraph/travel；swing 为 swing/turn；crossbranch 为 rest/telegraph/flight/settle。固定生根的物种不伪造位移需求。森林蜘蛛、双线织网、跃枝怪使用生产接口配置线段、双线或两岸实体支持，这些初始数据进入 trace。

## 判定边界

`recorded_complete_coverage` 只表示驱动记录到本页要求的技术动作事件；画面清晰度、同体连续性、正式自然路线和真人设备性能仍须分别审核。

`recorded_with_coverage_gaps` 会保留可审核视频并列明逐怪缺口，绝不改成通过；例如玩家死亡、无攻击、真实子弹未命中、未见非致死恢复、未进入 terminal。引擎错误、泄漏/严格运行器失败、源漂移或媒体不完整记 `failed`，不通过增加预算掩盖。

charger/diver 记录持久尸体及稳定变换。其余普通怪与 Boss 按原有终态记录身体保留或退场，避免把“没有新增尸体”误记成机制失败。已有 receiver 测试中的禁 AI、直接 Damageable 和强开弱点不属于本实录的完整战斗证据。

运行前须由 root 取得 Godot 引擎租约并让源码静止。当前工具已完成 Python 语法/CLI 检查，尚未运行 Godot，尚未产生任何实录通过结论。
