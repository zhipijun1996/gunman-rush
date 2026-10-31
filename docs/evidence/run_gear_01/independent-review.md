# RUN-GEAR-01 独立技术审查

结论：**ACCEPT，仅限下述技术范围**。审查源为 `91ea8850f308cc3c955bcece2c35cd66f75e7bda`，基线为 `26e7f2a4459623f35613a857da8a75e89daa3e62`。独立审查者是 `/root/inventory_review`，实现由 root、gear_core、gear_ui 等其他代理完成；本审查者没有修改生产代码或测试。使用仓库 [gameplay-reviewer Skill](../../../.agents/skills/gameplay-reviewer/SKILL.md)，主动构造反例、反馈作者修复并独立运行原 Harness。该结论不代表 G5 玩家认可、实体设备验收、整区美术认可或 full profile 通过。

## 当前源的实际执行

最终独立验证期间 HEAD 保持上述 SHA，前后工作树 clean。采用原预算、`--release --jobs 1`，全部 fresh，没有重用旧结果。完整命令、Harness 原报告、15 项原日志及收据保存在 [reviewer](reviewer/)；机器可读索引为 [review.json](review.json)。

| 执行范围 | 结果 | 用时 |
| --- | --- | --- |
| 单次选定 15 项 Harness | 15 passed / 0 failed，exit 0 | 445.748 秒（驱动墙钟） |
| 其中 gear-inventory | 107 assertions / 0 failures | 8.053 秒 |
| 其中 gear-ui，headless | 64 checks / 0 failures | 14.931 秒 |
| 其中原 core | 5685 assertions / 0 failures | 37.623 秒 |
| 其中 forest-bible-app-discoveries | 92 assertions / 0 failures | 12.563 秒 |
| 其中 forest-campaign | 67 assertions / 0 failures | 11.987 秒 |
| 独立 Window / 软件 GL `run_gear_ui_tests.py --capture` | 67 checks / 0 failures，exit 0 | 29.285 秒 |
| 原 `menu_scroll_touch_tests.gd`，原 90 秒预算 | 44 checks / 0 failures，exit 0 | 4.863 秒 |

15 项为 docs、quality、structure、gear-inventory、gear-ui、core、underworld-ui、demo-ui-time-energy、root-bell-current、forest-bible-discoveries-tests、forest-bible-app-discoveries、region-bible-contract、region、cloud-production-planner-tests、forest-campaign。原报告 `profiles=[]`、`targeted_checks=true`，**不是 full、不是 15 套设备验收**。region 的当前 15 suites 实跑通过；原工具明确标注的 27 条 legacy itineraries 未运行，不改写为通过。

独立查看最终原尺寸 [desktop-equipped.png](reviewer/gui/desktop-equipped.png)：Purple Vessel 卡片显示生命上限 +1.5，面板实际显示 `生命 5.0 / 6.5`，证明 F10 修复在真实像素中可见。GUI 自动验证包含原生鼠标、合成触控、焦点/手柄输入及小屏滚动；另外保存 [背包截图](reviewer/gui/desktop-backpack.png) 和 [触屏布局截图](reviewer/gui/touch-equipped.png)。截图仅证明对应时点。没有在本审查中完整播放最终操作视频或听音轨，连续自然操作录制由独立 capture 交付另列；不得从本报告补签该录制。

## 所有权、效果和生命周期审查

`RunInventory` 拥有稳定实例身份、定义 ID/版本和来源快照，同定义可有不同实例；持有数量限制与装备限制分开，背包不按齿轮容量限入。定义快照及集合对外复制，避免调用者修改已提交实例。`EquipmentService` 持有实例 ID 集合和配置容量，按整个候选集合统一验证所有权、重复实例、装备数量、互斥、负荷和前置条件后提交。`BuildState` 只接受已装备来源，每次从基础属性重新计算，提供可扩展 effect channel/source metadata。

反例覆盖了恰好 8/拒绝 9、蓝高负荷/金低负荷、超负荷仍可入包、同定义多实例/叠加/互斥、卸装重装无收益累积、生命钳制、空中能力上限单向收紧、请求数组回调篡改和提交中 clear。`JumpAbility.maximum_jumps()` 保留独立核心能力 floor；卸装时当前飞行已使用状态不回补。空中射击 reconcile 不补充剩余次数、不改速度；正式 ShootAbility 消费当前 tuning，因此装备效果存在真实战斗消费者。

Service 层也要求玩家仍在树中且树实际暂停；session 同时绑定 token、router epoch、revision、存活和 focus。DemoApp 另验当前构筑页面，关闭、换页、失焦、恢复和切场景撤销旧会话。特别验证了 unpause 后提交被拒绝、立即 repause 后同一旧会话仍被拒绝，中间没有 open/close 新会话掩盖结果。拒绝失败没有部分装备变化。

Reward/Shop 成功交易只入包；装备满负荷不是拒收或拒买条件。receipt 同 ID 回放不再扣款/发实例，变更 payload 冲突，死亡优先，待处理旧请求与新 epoch 隔离；失败回滚钱包和库存。扩容 8→10→12→14 使用配置和原 RunWallet/同一商店交易收据，不动永久音符。已完成旧 receipt 的只读 replay 不构成过期新交易。

同一局切地图/地区复用 build、wallet 和 shop。当前 forest-campaign 原流程在实例入包后显式暂停装备、实际扣 10 金币扩至 10，经原 H 能力/地区选择进入森林，核对完整实例 provenance、装备 ID、负荷容量、真实效果、同 wallet/shop、旧 ledger 及新增金币来源，跨 epoch 回放不重发/重复扣款。该专项有明确 fixture 前置，不能冒充自然走完全地区的录屏。存活环境回退保留，真正死亡/Retry/Home 清理同时核对装备来源和全部库存；随机道具没有成为地区核心能力授予。

## 发现与修复链

以下发现均先退回作者，不由审查者改生产源。历史失败原件保留；“已修”只对应当前冻结源的复审结果，不能追认失败的旧源。

| ID | 反例 / 实际问题 | 作者修复与复验 |
| --- | --- | --- |
| F1 | component-only 效果能算进 BuildState，但 ItemPresentation 只读旧 modifiers，卡片漏显示 | 卡片改读 `stat_modifiers()`；补实际 Player 入包无效、装备 +2.5、完整来源/channel/版本、卡片、卸装撤销反例 |
| F2 | R3 数据版本仍断言 v2，与新增 gear 数据的 v3 不符 | 明确更新到 v3，保留严格版本断言 |
| F3 | 原 energy 断言把 overcost 的不可装备当作不可持有 | 改为允许入包且无效，再明确拒绝超负荷装备；原伤害/射击容量因果断言保留 |
| F4 | root-bell 重放前置仍假定领取 brake_boots 自动生效 | 通过真实暂停/session fixture 合法装备，再保留原 map2 StringName、快照和回放断言 |
| F5 | 只依赖 UI 暂停门禁，service 会话可在实际未暂停时使用 | 核心要求实际暂停；unpause 永久撤销旧 session。重排反例，排除新开 session 导致假阳性 |
| F6 | 同步 Health.changed 回调可篡改 submit 的调用者数组，或 reentrant clear 先清半套数据 | 私有 typed ID 快照、clear 在 applying 时先拒绝；Manifest 记录真实提交集合；补回调反例 |
| F7 | 迁移清局测试时以 inventory.empty 取代旧 equipped.empty，丢失原 active-source 守卫 | 两类均断言，after_boundary 同时记录 owned/equipped；campaign/练习 Retry 保留原守卫 |
| F8 | creative-v17 技术重绑误把森林 Bible section 数量 13 改成 14 | 恢复 13；其他 Bible 合同、原始文档和前版 archive 独立比对 |
| F9 | 补清理守卫误加到仍持有 Gold 的活局跨区断言，变为自相矛盾 | 删除活局 inventory.empty，真正 Home 边界保双空；再加强实际跨区实例/装备/扩容/ledger 测试 |
| F10 | 真实截图 Purple Vessel +1.5，summary `%.0f` 显示 5/6，误报最大生命 | 只将显示改 `%.1f`，新 UI 断言验证 6.5；本次实际像素 5.0/6.5 已确认 |
| F11 | ModuleEnergyTrial 测试仍假定选奖自动减少 drain | 先验持有/未装/drain45，再真实暂停装备验原 drain36；重复领取/Retry 双空不变。ModuleLab 只读预览另有明确 fallback |
| F12 | 独立原 core 发现相同优先级 override 依 StringName intern 创建顺序，不按字典序 | 窄复现 12/3→12/0；5 处显式 `String(a) < String(b)`。原 expected3 未改，新增12反序创建/提交及 common-prefix 断言；最终107/0、core5685/0 |
| F13 | `:= load(...).add_and_equip()` 无法推断返回类型，root-bell 原 runner parse fail 后真实 timeout | 显式 bool，不放宽超时；49 个变更脚本逐 path check-only clean，campaign 增量另 parse；最终原 Harness 通过 |
| F14 | discovery fixture 关闭临时暂停后立即取按钮，正常 App 尚未下一帧重建 `_actions`，83/8 失败 | 仅等待原生 physics/process 两帧，不私调刷新；原 first-W、按钮和死亡守卫不变；完整路径实际执行后最终92/0 |

旧 F10 图保存为 [reviewer-f10-before.png](reviewer/history/reviewer-f10-before.png)，旧 `%.0f` 代码存在于 `582c8167d8134ee0019adf0c5561c3011ea824a1`。该图没有完整独立 source guard，不能声称它精确绑定该提交；最终新图有 91ea 源稳定收据。

## 敏感测试迁移和 testguard

逐 path 比较基线与当前测试 diff；[review.json](review.json) 保存路径、前后 SHA256 和迁移理由。此次改变的前置是“入包后由真实暂停/session 显式装备”，不通过写 tuning、补血补弹或改物理救测试。

- economy/demo 保留原 equal override 3/4、stack/exclusion、wallet/stock、receipt replay/conflict、回滚、死亡和环境回退；新增同时检查 owned/equipped。
- extended_reward 保留九间房选择的领取数量，只将“自动装备”改成九件持有/零装备；不缩奖励池。
- R3、plains energy、exploration、forest spiral、plains redesign 在需要真实效果前显式装备，先验入包不生效；原 shot/energy/伤害/弹道守卫保留。
- forest discovery 模型与 App 保原按钮链、重复领取、死亡优先/first-W；F14 等待两帧仅恢复真实异步前置，不删失败分支。
- forest trace 仅将“重复领取”观察对象改为 inventory ID，装备效果的消费者另显式装备。campaign/boss/canopy/练习 Retry 均保原装备清空并加库存清空，F9 的错误活局断言未进入最终验收。
- root-bell 原版本快照和 StringName/regen 预期未放宽；只合法装备前置并显式 bool，F13 timeout 原件未删。
- planner 只因新增两个串行 check 更新精确数目 142/89/53→144/89/55。

独立比对 `tools/harness/profiles.json`：所有原 check 定义完全相等，旧 profile 内容保持为相同前缀，只追加 gear-inventory、gear-ui；没有删除旧检查、缩原断言或放宽原预算。新增两个 wrapper 继续使用原严格 engine 错误/泄漏和完成标记判定；退出码为零但出现 ERROR/泄漏不会签通过。最终报告每项 `reused=false`。旧部件兼容/27条旧物理路线不因本次迁移声称当前已测。

## 技术 style 重绑的限定影响

独立核 v13→v14 的 36 条 runtime reference，只有 `scripts/demo/demo_app.gd` 的实际 SHA 改变，另外 35 条完整条目字节值相等；当前绑定 SHA256 为 `841e4f35762e265fda3316201a7705123ee3b78148b0b8a794d9d55c5a5649c6`。旧 v13 JSON、两个原始 Bible 文档及三份 creative-v16 archive 与 origin/main 原件逐字节相同。F8 森林 section 数恢复 13。

另审实际 DemoApp diff：新增装备入口、会话与生命周期门禁、构筑 summary、正式 Manifest 装备集合及输入释放处理；summary 调 `maximum_jumps()` 保独立核心 floor，HP 格式仅影响展示。没有改变地形、世界绘制、相机、角色/敌人动画或 BGM 调用。region-bible-contract 在本次最终 Harness 实跑通过。这是消费者依赖 SHA 的技术重绑，不继承旧审美 ACCEPT，也不证明新一轮整区画面、手感或商业质量认可。无需为本局部系统重新扩产美术。

## 历史执行与未验边界

历史独立 core95/0 是早期 dirty candidate，不能拿来替代 91ea 的107/0。旧批次按实际源留存：6f646c 的 core5685/1；9d73 的 root-bell parse/timeout；4762 的第一批2/2和第二批12/13、discovery83/8，均保持原状态。最终91ea才是单次统一15/15。证据索引列出每批原报告位置、绑定源和 portable 副本；没有追签失败报告。早期 movie trial 功能断言20/0但因 ERROR/source drift 严格失败，不能当最终录屏交付。

已知限制：主动/武器专属/钩索复杂效果仅提供通用接口；未新增跨进程 run save；扩容价格为配置试验值；开发 ModuleLab 是只读效果预览而非正式自由换装入口。触屏适配器消费输入后 footer 偶尔仍为键盘提示，这是已知轻微 UX 风险。UI 的一个滚动容器支持装备和行囊，小屏需滚动才能看到完整容量区和底部控件。

未验：实体安卓/真实手柄/浏览器触控、硬件性能和触摸手感、完整自然正式地区路线录屏、音轨听审、玩家趣味与最终美术认可、PR Integration 和未运行的完整 profile。合成输入、软件 GL 截图、单个技术测试通过均不能替代这些证据。最终录制完成与发布链接由 capture/root 的独立收据补充；本报告写入时不代签。
