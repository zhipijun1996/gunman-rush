# 正式风铃平原像素迁移：独立审查

审查者 `/root/pixel_golden_review`；实施者 `/root` 与专业实施代理。审查者只写独立探针/证据，没有修改被审生产代码或已有断言。本报告与此前一屏小样审查独立；用户后续明确认可该感觉，授权整区、3张独立背景，并要求纹理无需复杂，旧小样“应增加材质复杂度”的判断不能覆盖新要求。

## 身份与结论边界

初始基线 `300d65c81b61fdfd8d0e7223e9e5a7a60e32e8de`。原生消费/路线最初检查未冻结worktree，哈希见 `source_snapshot.json`。早期独立GPU包 `d54a2ddedf5f` 保留其历史身份。最终独立GUI已重新运行并严格绑定构建 **`d2c684ef8fc0` / 源 `c0f8e50770145795db5affd4afdbffff2479f1ea`**，详见 `final-gui/report.json`、`final_source_snapshot.json` 与 `final_observed_frames.json`。没有把旧GPU包追认为最终包。PF-03已在最终源内修复，其12断言严格复验通过。

**最终包的限定技术与已观察像素范围 ACCEPT；完整全区视觉终审 UNVERIFIED。** 已独立证明正式两图实际消费新表现、教程真实操作与部分生命周期；不等于两图全路线或Boss自然战胜、全部Seed、所有动画/声音、用户最终审美及实体设备通过。用户认可的是方向，不是本代理替用户签收全部输出。

正式地形采用精确矩形并集表现适配，保留现有非格对齐物理；这部分不是47-mask或dual-grid TileMap。既有47态样板另存，不能把它的拓扑检查冒称正式地图瓦片迁移。

## 独立运行

1. `formal_inventory.gd`：普通菜单 `requested_plains` 信号 → 实际DemoApp图1 → 真正 `_load_stage` 重载 → 现有明确outcome fixture切图2。21000检查/0失败，严格run_engine退出0。图1实际13敌人、74 one-way、7 moving、27装饰；图2实际22敌人、69 one-way、11 moving、20装饰。图2覆盖是明确的结果定位fixture，不是自然通关。
2. `formal_route.gd`：复用现有 `level_formal_trace.attach(app)`，真实Controller/Motor运行教程，不移动演员位置、注资源或禁敌。574帧，实际跳跃/射击接受事件、无段回退。自然停稳后实际相机横移超过1700wu，3图原始hash不同、far<middle<near视差位移；16检查/0失败，严格退出0。仅教程；没有声称已跑完整两图。
3. 原 `tests/plains_region_lifecycle_runner.gd` 完全不改：27断言/0失败、严格退出0。覆盖cache/商人/掉落幂等、同图snapshot/reload、shortcut与Boss/玩家同帧fatal死亡优先。此测试包含明示定位/伤害fixture，不当路线证明。
4. `formal_breakage.gd`：明示图2/phase3几何生命周期fixture，实际 `WindkeeperArena` 回调破桥，实际terrain observer重建，并对每株装饰根做真实物理ray。发现PF-03后原断言修复复验，再增加两次configure幂等和实际重载恢复phase3/相同49piece/装饰支撑：12检查/0失败、严格退出0。不是Boss打法、战胜或phase3完整实像证明。
5. 独立Chromium WebGL `formal_gui.py`：普通URL标题Enter实际进入正式图1、走跳、暂停返回；两个fresh定位场看两Boss。构建d54a2ddedf5f，console无脚本/着色器/页面错误。两个实际GPU oracle各552960检查/0失败，范围仅不透明占用、孔洞与分块像素等价，不是美术打分。
6. 最终 `final_gui.py` 在构建d2c684ef8fc0/源c0f8e50重新开启3个fresh contexts。普通URL标题Enter真实进入正式图1，实际键盘移动/跳跃输入、暂停返回；两个地图都等待真实PIXEL_INSPECT spawn就绪后先Enemy再Boss。两图各采6个相邻敌人样本，再采Boss登场/预告2帧；console无脚本/着色器/页面错误，两个GPU oracle又各552960/0。最终独立实际看过的14原件及hash列于 `final_observed_frames.json`。普通跳跃采样中演员实际落入下方，保留 `ordinary-jump.png`，没有把自动按键这一次尝试报成跳过教程/完整路线；路线结论仅来自独立574帧实际Motor教程轨迹。

原探针自身的类型错误、未停稳的相机/CanvasLayer邻帧精确比较失败均留日志。相机探针保留同一精确断言，改为自然停稳180帧后采样，没有放宽误差或改生产代码。此采样修正不记为生产缺陷。

## 真实消费者覆盖矩阵

| 消费者 | 原生实际消费者/行为证据 | 已实看GPU像素 | 未验边界 |
| --- | --- | --- | --- |
| 图1/图2静态地形 | inventory两图真实assembler/module；碰撞尺寸未变，实际PixelFormalTerrain，GPU占用oracle | 普通入口；根作者inspect-draft图1-00/03/06/09/11/13、图2-00/04；独立两Boss图中的实体与孔洞 | 全20/23区域逐点、所有Seed和所有镜头极值未全看 |
| one-way | 两图每个真实shape仍one_way，独立样本目录新renderer | inspect-draft图1-03/06/09/11/13的薄桥、独立敌人/两Boss上层薄台 | 不能把小样独立drop-through外推正式每座桥；正式全桥实际下穿未独立跑 |
| moving | 两图真实原carrier挂新art；物理尺寸不改 | 两Boss前后帧与图1-11可见铜移动台不同位置 | 没独立站到正式每座ferry验证携带/最坏相位 |
| 风铃/门/shortcut | 正式metadata→新绘制分支；真实教程接受射击并通过生产风铃 | 图1敌人样本右上风铃/符号、inspect-draft图1-03 shortcut、两Boss封门 | 每类计时/序列机关所有状态未逐像素采样 |
| 草/花等装饰 | 两图完整bounds保护区；根支撑；PF-03破桥/重载原生实证 | spawn、junction、merchant、两Boss场；独立敌人场草花 | phase3破桥后的GPU装饰清除未单独看，仅物理/实际placements证实 |
| 三独立背景 | actual paths/hash不同、9实际Sprite；教程真实相机差速 | 普通入口/移动、junction、merchant与两Boss，冷暖层级可区分 | 垂直极值、超宽/竖屏、完整循环接缝未全验；Web原PNG hash字段为空，不假称有效 |
| 主角 | 真实PlayerMotor上新Actor，旧CourierVisual隐藏；真实接受走/跳/射击 | 独立ordinary-entry/jump，Boss/敌人系列 | 受击/死亡代码读取真实接受事件，当前没有逐帧独立实看完整死亡与复活 |
| charger | 两图实际新Presentation、health/collision身份不改 | 最终两图各enemy-00至03连续实看，见轮廓、姿态、HP/顶部标识变化 | 未绑定完整state事件时间线，不签警示/判定时序全通过 |
| diver / hopper / sentry / fan_sentry | 两图实际实例inventory；现版源码有behavior/aerial分型及locked_direction/attack_goal预告 | inspect-draft图1-11可见空中敌人；其余专属警示未独立逐帧看 | 各行为警示、attack/recovery/死亡完整序列仍unverified |
| root_bell | 当前两图seed未实例化；源码分型/固定地面标记已读取 | 无独立GPU样本 | 不把支持代码或另代理fixture计作本代理实际观看 |
| Bellstrider | 图1真实Boss pixel_style；原Boss流程未替换 | d54包map1-boss-01/02，登场/金色roll lane；最终包map1-boss-02重新实看轮廓/状态 | 只看前段，未完整所有攻击/露芯/死亡、未战胜 |
| Windkeeper | 图2真实Boss pixel_style；phase3破桥actual原生fixture | d54与最终包map2-boss-01/02均实际看，登场/地面攻击预告 | 只看phase1前段，phase2/3完整实像/战胜未验 |
| pickup / chest / merchant | 两图新图标消费，真实生命周期原27断言保留ledger | 图1-03/06心/金币/商人；其他图可见金币 | cache/chest打开前后独立实像未全看 |
| 玩家/敌人/Boss未来弹体 | 两图实际玩家shoot产生PixelPlainsProjectile；敌人/Boss未来弹体通过stage metadata选择新分支，代码检查parent链成立 | 两Boss警示与少数粒子；玩家原d54普通shot另外root采样 | 没逐个看所有敌弹/Boss弹/技能形态；路径存在不等于视觉通过 |
| 暂停/重载/退出/保存 | 独立普通GUI暂停返回；原27生命周期；PF-03实际reload | ordinary-pause（UI） | 完整自然探索后跨图保存回退、实体设备/手柄未全验 |

## 发现与处理

| ID | 事实、证据与责任边界 | 结果 |
| --- | --- | --- |
| PF-01早期候选 | 最早读取的未冻结PixelPlainsEnemy只有泛用身体、无专属预警。重新读取时作者已扩展behavior/state/aim/goal/HP/死亡；没有把过期源码判断写为现版失败。 | 现版静态候选关闭，警示完整GPU仍未验 |
| PF-02艺术定位工具 | 根作者inspect-draft report/log真实3次Nil `controller.return_to_segment`，因为死亡清理后按钮仍有旧points。仅显式艺术工具，不外推普通入口。 | 作者guard修复；独立d54普通/两BossGUI无脚本错误。实际死后重复按键尚未专门GUI复演 |
| PF-03装饰悬空 | 实际图2破桥后3株草在(5664,18)/(5712,18)/(6192,18)无实际物理支撑；terrain已正确48→49piece，装饰没有重建。`formal_breakage-run2.log`保留7/1失败。 | 作者configure clear + geometry_changed连接重建同一scenery。原断言及新增重复/重载12/0；只改表现，无物理变更。最终源c0f8e50已包含此修复 |
| 定位采证边界 | 独立先Boss再Enemy时caption改为enemy，但封门/段返回规则使角色仍在Boss；这些map*-enemy图只能作Boss连续样本。fresh图2Enemy点击早于_collect ready，六图仍spawn。 | 不记敌人GPU覆盖；最终采证改等实际PIXEL_INSPECT spawn日志后先Enemy再Boss，不改封门/补血 |

## 像素意见及剩余范围

按用户新要求，简洁体块与少量宽块明暗可保留，不能沿用过期“复杂肌理”要求拒绝。已观察的主体、可站边、危险金色线、冷暖天空与退后的遗迹层级可读；没有证实背景遮住唯一落点/玩家。两Boss轮廓确有区别，不是同一身体换色。艺术定位按钮压住Boss HUD的情况属于显式fixture UI，普通入口没有该工具栏。

这是AI专业范围意见，不是用户审美签收。没有完整播放所有录屏、没有听完声音、没有实体设备或完整自然战役证明；三背景纵向极值和所有敌人警示仍未签。原小样失败与本次正式候选的新边界分别保存，不抹掉历史，也不把历史拒绝强行覆盖用户最新认可。
