# ENEMY-STRUCTURE-01 生产重构独立源码审查

审查者：`/root/enemy_review`，2026-10-29。基线`58fb249eb37d469c2ccb9ed22ff4d1311330e2fa`；最终读取公开提交`4af16b8e49ecc6ea4ed6cbff957e06fe78fa9833`（与本地已审`320fce2e080ea75949b8170220172fd0eb3c3dde`完整tree相同：`f0b36a0a60bd8c1b89a6a03387fe7e83e6c2a6a1`）。生产写入0、Godot运行0。本代理编写了新结构runner和wrapper，因此不把该测试的作者身份或root运行冒充“不同作者独立实跑”。独立职责是审生产diff、原检查迁移与真实日志，源绑定见`/tmp/enemy_structure_final_production_binding.json`。

**源码范围：未发现尚未关闭的阻断问题。整项运行／集成结论仍待原受影响回归及最终新runner，不能据此宣布整个重构验收完成。** 用户已拒绝旧怪物成品质量；本轮无新素材／动作制作，该拒绝保持，不因技术重构改成视觉待认可或通过。

## 实际审查范围与保护的差异

逐diff读取工厂／Registry／5种攻击策略、Actor状态出口、显式表现Binding和两个旧installer、普通各host与3motion/helper、7个Boss Encounter脚本与各renderer、两个候选入口、三正式Stage/App消费与恢复通知。冻结后再次核71个变化生产文件（含新增UID）与独立保存的SHA0漂移；未改assets/resources/scenes/config/shaders的字节。不是正常速度观看或前后逐像素等价证据。

- 普通`EnemyFactory`有限登记14种行为及2个开发候选；未知行为、越权实例覆写、候选错行为及未知context拒绝。真实场景与资源映射逐项核对；工厂返回未入树Motor，实例位置、生成、策略绑定仍由原调用者拥有。
- 候选Lab/Review与Studio的原差异保留：moth速度45/0，半宽120/100，原准入仍development candidate。未把差异静默归一。
- `BossFactory`只有8场景／9个scene-Definition组合；默认12HP与正式Storm36HP仍分列。Boss原共享Definition语义保留；普通可调实例的HealthDefinition隔离另述。
- 五普通策略从原状态机提取：冲锋目标／限速／地面碰撞，俯冲sin/cos环绕、回巢与2秒阻塞债，跃击sin(PI*t)*90弧线，炮哨发射时点、扇形三个原角度均逐项相同；公用状态推进、并发／安全区／视线、资源与取消未迁到表现层。Registry的未知策略不静默回退。
- 8个Boss相关脚本（7个Encounter及AttackPattern）147个原函数中146个原文未改；Rootbell `_event`仅追加`presentation_event.emit(row.duplicate(true))`。新增只读查询不改变AI阶段、弱点、投铃／网场、判定、保存或奖励函数。不能由此签原正式战斗已重新跑过。

## 表现与生命周期边界

`EnemyPresentationBinding`现在记录实际actor/profile/renderer/body_key/scene_body/body_theme，图像选源从有限映射读取。fan_sentry明确仍是aerial身体，原scene actors.png与Underworld aerial.png各保其真实消费者；物理aerial字段继续控制运动／bob／尸体策略，不能再暗中改图。以后若要另一种外观须显式profile，不推断任意aerial覆写都应换身体。

实际Pixel→Underworld替换仍保留最终Underworld皮肤，反向重跑早期Pixel installer不降级，重复安装不重建同host。森林普通fine-body由正式安装器明确`body_theme=forest_bible`启用；独立Lab/scene不因profile叫forest或祖先meta而自动启用。原Boss祖先方向选择仍保留，未宣称所有历史皮肤入口已被删除。collision_size/stable_id的fine-body适用guard仍在。

普通统一Lifecycle负责health接线、初始化、可选motion与sample的一次推进、显式dispose；HitTemplate保其唯一sample时钟。Prototype不再推进未绘制的父层motion，自己的pose设计保留。Host/Stage仍分别持有专有纹理、尸体与特殊对象；统一RefCounted生命周期不等于生产host可跨actor热换材质。冲锋／俯冲Stage兄弟尸体、其他隐藏／淡出／暗体及Boss终态未强制统一。

普通快照是递归只读值；Boss快照保raw_clock、elapsed/countdown、真实combat阶段与Weave route独立轴，motion helper不再按具体类翻译。Bell、轨迹、锁定点、结点标签改为fresh值查询，不返回可写内部Node。原Rootbell预警的60Hz积分／每4tick采样几何从renderer移回Owner，抽样顺序与坐标保持。Renderer私有Boss字段读取已移除。

App在普通行为／朝向完成恢复之后，以及Boss场景绑定和generated Boss恢复完成之后调用synchronize；同epoch只重置位移／朝向观测基线，保已接受hurt/death/mode age；新epoch立即同步。没有为画面补写AI clock、HP、Actor位置或阶段。

## 审查中发现并关闭的问题

1. **未知身体路由会绑定成功后无身体。** 初版can_bind仅验profile/宿主，body_key未解析时UW静默不画。现新增无ERROR的binding_error查询，unknown_body_route拒绝；测试含该负例。源码已复核。
2. **盾反馈回调未随dispose释放。** 初版ForestFeedback匿名shield_contact仍可在树内dispose后改shield_flash。现保存准确receiver、具名callback并交own_cleanup断开；测试明确dispose后旧源emit不改字段。源码已复核。
3. **普通外部Health资源未隔离。** native01实际691检查／15失败、39case中24通过，均为平原15链HealthDefinition仍共享，原件保留。Godot duplicate(true)未必复制外部.tres；新工厂返回可变实例配置，却可能让实例调整串改原资源。现只显式复制普通HealthDefinition的原resource_id/version/max/initial字段，未推广所有嵌套资源，Boss保原共享。HealthState.configure只消费数值，不依赖该Resource对象身份；此为明确的隔离边界修复，不谎称旧duplicate本来已隔离。未放宽断言。

## 真实验证、敏感测试迁移与当前缺口

- root开发import01退出0、无ERROR，仅前置parse，不是最终验证。
- 新native02原件`build/enemy_structure/native-02`：692检查／0失败，39/39case、source_stable=true，原日志无native ERROR／泄漏。当前生产SHA与其原working_files仍0漂移。它由root运行，本代理只读复核；state赋值／直接Health事务明确属于结构fixture，不叫合法完整战斗、GPU像素或动作审美通过。
- native02之后应root要求在同39case追加standalone theme、forest_bible显式启用／默认重绑不丢theme、fan物理trait不改图等断言；最后runner SHA`cbf8a726093523fcc50598238e5ee4586a59a6aee6acc75e71b098f69110c514`，wrapper SHA`fabc4051bb98300c17cced996f5f96bd65db58e14dbc7495f3844f987e7aeeb9`。不能让692旧通过覆盖新增断言。
- 原plains lifecycle90/0为root本轮原入口结果。原motion708的首次迁移失败保留；旧复制的result.json明确notfresh，不引用为通过。已独审其两行fixture迁移：只有候选从“一律charger资源＋改ID”改为Factory真实review recipe，moth现在正确sentry行为；森林资源加载、Health私有复制、冷terminal、384姿态与三角阈值、原所有断言都未改。可以fresh重跑，不能修生产去放行错误候选身份。
- 原32/10、style19/creative22的两轮窄技术重绑另见`/tmp/enemy_structure_style_review.md`：保存原18/21、Bind01及源，不刷新历史通过；81/3/78及Bind02的1/80均独立核对。这里只接受测试历史迁移，不代替原运行守门。

原feedback五项、森林机制／Queen／Canopy、实际App两Boss完整战斗、相关core、真实GPU与区域性能/保存验证须按实际影响完成并分别绑定源；缺哪项写未验，不以692或源码保持推导完整通过。全CI、正常速度全片／原音试听、用户与物理设备未签。旧成品的审美拒绝、未完成动作与完整怪物制作卡的缺口仍须回原制作流程解决。

## 精确公开源收口补充

只读核对公开HEAD与本地已审tree完全相同，71个生产文件与独审SHA清单均匹配，当前Git干净。native03原report的source_before/after均为干净`4af16b8e49ecc6ea4ed6cbff957e06fe78fa9833`，无working_files、untracked或diff，source_stable=true。实际`build/enemy_structure/native-03`日志／runtime／report为730检查／0失败、39/39case；包含最后显式theme／保Lab备用身体／默认重绑不丢theme及trait不改外观断言。它取代“这些新增断言尚未跑”的阶段性缺口，不改native01/02原件或通过范围。

原motion生命周期迁移后`build/enemy_structure/motion-lifecycle-02`fresh实跑708断言／0失败，已读取新native.log及runtime；它与此前错误fixture失败／notfresh旧result分开。14项原受影响Harness仍由root串行运行，本报告此刻不签全部通过。源码层本轮具体发现已关闭，可交后续集成；审美拒绝、正常速度全看／听感／设备与怪物完成标准保持原缺口。
