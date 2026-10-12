# 第四轮独立严格审查

结论：**ACCEPT（本轮实错修复与技术专项范围）**。最初快照不能放行；本审查独立复现两个正式运行实错，主代理修复后重新验证。几何、实际弹体、消费者和账本证据支持当前技术交付；这不代表整张地图的主观趣味、美术认可、所有敌人组合公平性或设备验收完成。最终全套回归、正常 GUI 与公开网页版本核对仍是交付方的发布门槛，不能引用本报告替代。

审查者：独立代理 `strict_review_round4`。只读 production，唯一仓库写入是本报告；诊断脚本和日志放在 `/tmp`。没有修改游戏实现、提交、合并、导出或发布。

## 本轮实际否决并修复的实错

### P0：升降台最低停靠点把地面玩家压落下层

种子 `region-woven_layers`，连接 `area_2_1 → area_3_1`。旧日志显示反冲段从 y700 起跳，真正根因发生在走向模块入口前，不能通过放宽反冲驱动或落地断言修复。

独立 `/tmp/d080-review4-motion.log`：tick1270 玩家仍站在 `area_2_1/Platform0`，位置约 `(2934.182, -0.075)`；tick1271 碰到相邻井 `well_lift` 底面，法线 `(0,1)`，位置变成 `(2938.516, 2.007)`，随后穿出单向地板，跌落 y700 并擦到下层齿轮。全过程没有 drop body 或 collision exception。反冲段地板本身确实从 `(3000,18)` 开始，和路口连续。

正式升降台原 start `(110,-24)`、高24，底面 y−12 与地面玩家头顶 y−18 相交。主代理把最低中心改为 `(110,-70)`，保持碰撞尺寸与 PlayerMotor，提供40px通行净空，登船仍需要真实侧跳。

修复后 `/tmp/d080-motion-diag4.log` 三家族 tour + deep：`DIAG FAIL 0`，均 `safe=true`。随后 `/tmp/d080-regions-final4.log` 地区几何专项 `4242 assertions, FAILED: 0`，包含样板、保底、两种难度、双向 tour、捷径、自然下井及深层撤离；没有降低身体扫掠、落地高度或返回条件。

### P1：敌弹销毁后的再次开火触发运行错误

独立正式压力诊断 `/tmp/d080_review4_pressure.gd` 使用生成 seed `review-pressure/0` 的真实 `plains_ferry_channel`、相位0.5及同模块 fan + diver，保留敌人 AI、ContactEmitter、FrameDamagePolicy 和真实敌弹；不清怪。

初始 `/tmp/d080-review4-pressure.log` 发现 `EnemyAttackBehavior._fire` 的 typed lambda 对已 queue_free 的弹体执行 `filter`，报告 `Cannot convert argument 1 from Object to Object`，随后出现 `Array → Array[EnemyAttackProjectile]` 的 SCRIPT ERROR。只验证首轮三枚弹体的测试不会发现这个问题。

主代理改为倒序按索引清理 invalid/spent 引用，保留原 typed array；cancel 同样在索引访问后先判断有效性再 dispose。

独立复测 `/tmp/d080-review4-pressure-fixed.log`：四轮扇射、serial12，真实输入到达出口，未杀敌，未出现上述运行错误。直接在港口等船会掉血，HP5→2；这是压力路径的结果，不能被描述为无伤通过。

### 回归断言必须等待新的伤害批次提交

`/tmp/d080-regions-final4.log` 的生命周期 `27 assertions, 1 failure` 不能忽略。旧测试在 `_claim_modal_item` 排队后立即读钱包，仍假定同步领取。

更新后的测试保留并加强原标准：显式 medium item_resource 消费者 fixture，排队后等待真实物理批次，精确验证 `coins_before + cache.coins`、`build.count_item(choice)==1`、已领取、重复拒绝、库存及卸载恢复。`/tmp/d080-lifecycle-final.log` 为 `27 assertions, 0 failures`。没有把原授奖断言换成宽松的非负金币检查。

## 独立压力与控制反例

### 正式摆渡与扇射有可测的等待 / 撤退选择

`/tmp/d080_review4_pressure_wait.gd` 与 `/tmp/d080-review4-pressure-wait.log` 使用同一正式种子、模块、敌人和相位，先输入退回安全接近区，读渡船相位，再输入登船、随动、上岸。

结果：HP5→5，fan serial9（实际三轮三向弹），fan / diver HP均3，未清怪，出口成功，`safe=true`、`continuous=true`，536 ticks。没有改人物位置、HP、资源、机关相位或取消敌人。

这证明一个实际生成组合存在可读等待 / 撤退后无损通过的行程，而且与原地等港口结果不同。初始合法出生位置是此真实模块入口，这是局部正式压力 fixture，不是从整图出生点开始的全地图无伤试玩。没有证明所有种子、所有敌人邻接和手机操作都公平。

### 低拱短按不是唯一通行方法

独立 `/tmp/d080_review4_arch.gd`、`/tmp/d080-review4-arch.log` 使用同一原始几何和真实输入对照：

| 输入 | 顶部碰撞 | 最低 y | 落地点 x | 身体扫掠 |
| --- | ---: | ---: | ---: | --- |
| 起跳7帧后松键 | 0 | 209.280 | 365.836 | safe |
| 全程按住 | 2 | 196.075 | 378.836 | safe |

“满按会撞顶”成立，但满按也能通过。低拱提供高度 / 落点控制和避免顶碰的收益，可作为容错教学；不能说必须短跳，不能把测试主动松键当独占操作的证明。主代理已接受此表述。

## 其他维度复核

- 独立执行 `python3 tools/check_plains_item_art.py`：退出0，原图源 SHA / 透明区块、15个AI图标区块、20个实际道具和消费者检查通过。主观画风及缩小辨识不由该脚本确认。
- 独立执行 `python3 tools/check_docs.py`：退出0，33份权威文档、本地链接、126项依赖与 tuning 检查通过。PlayerMotor、基础 tuning、输入配置没有本轮修改。
- 新稳定性减少地面反冲；地面回能、延迟、开火间隔、刹车有实际 Modifier 消费者。精力等待辅助只通过真实地面物理帧恢复，不给空中补能或额外跳跃。
- `/tmp/d080-expansion8.log`：2665 assertions / 0 failures，无 Parse Error / SCRIPT ERROR；正式12种子 high / top 卡片实际涵盖金币、生命、永久音符，hopper 使用正式35px半径及预警冻结落点。事务 fixture 禁用无关环境接触，不冒充实玩。
- 资源保存失败保持箱子未领取、钱包和选项不变；重试成功一次。死亡优先使用真实 FrameDamagePolicy 同批提交验证。HP预算11与当前最大可领取量同步。最新源码把错误显示在当前奖励弹窗 footer，提供 `RETRY SAME OPTION`；正常 GUI 可读性仍待画面验证。
- mini 使用独立场地；没有只允许下方射击的方向设定。八个真实弹体来源专项及每Boss本局开场名账本有证据。源点 fixture 不是普通跳台登场 GUI 证明，不能扩大结论。
- 150张图及50自动家族图的已生成统计：无保底回退；家族实际图签名46 / 50 / 48，早Boss行程签名88。linked_rings 的真实单向下井与独立爬升返回是空间差异。统计不等于有趣性。
- 退出日志仍有 ObjectDB / resources in use 信息。它们与 Parse Error / SCRIPT ERROR 分开记录，不应声称日志零错误；目前没有把退出泄漏信息当成当前通路通过的理由。

## 留给后续迭代的具体建议

1. 家族用实际空间不变量定义：crossroads 的多入口中枢与 woven 的庭院跨接目前仍共享相邻网格删边算法，主要差异是 footprint宽高和竖井权重。下一轮应检查“从不同方向两次回到同一地标”的实际行程，避免只改家族名字。
2. 两处深层入口仍在固定顶行 col0 / col2。扩展入口深度、归返方向与邻接组织，避免每局形成“顶部两个大奖”的固定搜索习惯。
3. 地标现已脱离固定行，但逐节点独立随机尚不构成连续的溪谷 / 维修区 / 钟台。让区域意象、真实机制和可判断路线线索互相支持。
4. 中级箱目前主要是随机路口成长补给，risk多为固定值。可以保留这种安全成长，但不能把它当“完成完整可选挑战”的验收；后续把挑战奖励位置与模块操作 / 压力 / 回程成本实际关联。
5. 本轮十种动作签名具有真实几何或资源消费者，但并非十种互斥必需操作；保留低拱反例，进一步验证节奏、耗能、时间和受伤风险的不同收益。
6. 正式动态组合至少已有独立摆渡扇射无损路径；下一步扩展多种子、双方方向、齿轮落点俯冲与第一图同时攻击限制，保留失败案例，不凭敌人数量宣布公平或有趣。

本报告允许本轮已修复技术内容进入后续验证与交付，不授权自动合并 PR，也不宣布未验证的 GUI、网页更新和设备体验已完成。
