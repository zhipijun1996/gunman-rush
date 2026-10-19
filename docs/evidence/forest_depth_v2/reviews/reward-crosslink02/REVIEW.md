# reward_crosslink02：领奖后可选活锚返Queen的有限复审

**有限 CONTINUE：该已采 root02/map2/sk0/cache0/level0 的完整回程可纳入现有 include-map2 专项；不代表全Seed准入或森林整体设计通过。** 审查者 `/root/forest_ecology_review`，实现者 `/root/forest_ecology`；本人曾咨询C出口/左环/E→C目的地，未写受审源和驾驶，不能作为这些宏观方向的唯一最终独审。本轮采用 gameplay-reviewer，只读离线，不native、不改生产/driver。

## 身份和实际因果

冻结源 `build/forest_depth/snapshots/reward_crosslink02`；原两组 `build/forest_depth/ecology/reward_crosslink02/{00-alive_lift-direct_one_R,01-jump_two_R-direct_one_R}/capture.json` 和父 receipt。原技术结果两组strictPASS，39.9058s。独立重算receipt.source_before的907个文件全SHA相符；不是以source数量证明内容。详见 `audit.py`、`raw-audit.json`（含reader/base SHA及实际原控/删证结果）。

两法前450帧及15条请求逐项全等：真实箱奖336、领奖后另一出口到R450，身体/HP/精力/钱包/物品/奖励幂等、敌位置/相位/HP和epoch均包含于逐帧比较。R入口HP4/E100/两枪；没有camp强绕（camp_tick=-1）。原前缀263蜘蛛织线真实伤1，不能宣称整路无伤。

|实际路线|R|E|C|Queen门|下层R/上层R|C精力（preMotor）|门精力/HP|
|---|---:|---:|---:|---:|---|---:|---|
|借活Lantern|450|521|582|719|1/1|72|100/4|
|普通完整跳+2R|450|538|599|736|2/1|52|95.5/4|

下层70/87ticks；上层两法都从E用普通完整跳+真实向下1R到C，声明60ticks（开始回调到结束差值；逐帧包含两端有61个记录），再共同宽prep和实际门环。下层E pre85.5/65.5，post86/66；C到达post比pre多0.5。门差4.5而不是20，后继地面自然恢复已吃掉大部分局部差值。17帧仅是本策略实际差，不能宣称H最优上限或重要速度优势。

活锚471真实移动敌身体接触，正常Policy将Lantern2HP→1HP，combat独立账本+7，没有普通子弹精力返还/额外补枪；485实际free，486第一可控自由步真实向下R扣20/一枪。普通下层两枪合法，落E自然恢复空中枪额度，随即上层一枪；不人为补能或等待敌相位。两法回程451之后无新增玩家伤害，末HP4。敌相位随后因17帧耗时差自然不同，没有把后继冻结到同相位。

源中侧环已删除；E→C仍是真实跨联，后尾不含D/M/S，最终门真开/形体禁用，目的地属于Queen入口而非旧E终点。原B DROP原因“升E后立即降D”在这次实际完整轨迹中已消除。固定R→D与原fast/growth/high_return/change_mind等路线仍保留，新增ecology_expedition不覆盖它们；当前两组未重新实跑死敌/固定fallback，不把静态保留说成同源全状态验证。

## 内容判断及反证边界

此处终于形成了一个有目的的选择：保留移动活敌时可借它少花一枪到上岸，随后普通一枪把领奖回程直接接到Boss前岸；普通解保持完整可用。区别由实际身体/移动敌/H扣血与连续资源产生，不是H密码或删退路。它足够支撑这一个可选生态关系继续；不必证明H必需或必须最快。

但Lantern仅2HP，玩家可以普通枪杀死；杀后仍有普通2R和固定回路，本次整路未采杀敌准备成本、已死/HP1、左相位、低精力、失败恢复。以往lower8局部控制只能保留其原有限范围，不能替这次完整消费者自动签字。此例不新增怪物类型，不修复整区敌人密度/多样性，也不回答“移除H整区大部分乐趣是否消失”。原上层LOW支配 liveedge 的永久DROP、旧B绕圈DROP和侧环DROP继续保留。

## 验收器离线反例

用冻结reader实际重跑两原capture均收。删真实身体接触、改实际485free帧、删471帧、删上层545 Router射击请求、截断到C、伪门未开、删奖励pointer、抹486精力扣费，共8项真实破坏均拒。删 `lift_first_actual_free_frame` 说明事件仍收：这里不构成first-free验证漏洞，因为reader直接从frames推导firstfree，并要求486请求绑定485free；改实际free帧已拒。未将冗余事件的接受伪称全拒。原件未修改，无引擎重采。

## 正常片证据的范围

同snapshot `build/forest_depth/ecology/reward_crosslink_movie02`：实际原receipt strictPASS，735电影帧/60fps/12.25s、719连续物理观察。电影与原headless源集合SHA完全相同；frames/requests去仅GL新增的presentation_frame/process_frame后逐项完全相等。events含额外展示元数据/运行身份，未声称整个events字典相等。

我实际看了从0至12秒每0.5秒抽样的25格contact-sheet（末格无帧，实际24帧）；样本覆盖初入、上岸、领奖弹窗、自然落根、活敌回升、普通跳到C、返门。可见此为下探奖后回到先前上岸再向更高Queen岸的连续路线，不是回调瞬移；原型枝岸与敌/环可区分。但2fps缩略不能验证短预警、全部身体间隙或动作舒适；未正常全速观看、未听音频，不签完整G2、艺术质量或玩家认可。`movie-contact-sheet.jpg` 保留采样；电影不复制到review目录。

下一步保持有界：允许该具体已采include-map2专项注册/证据归档；扩大Seed或状态覆盖时逐一记录适用性。若将其宣称整区主要生态/主路H价值，仍需不同正常探索路线、实际死亡fallback/低资源恢复和正常速度独审，不能用本例继续外推。
