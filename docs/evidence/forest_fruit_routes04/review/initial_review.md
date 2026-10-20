# 第一轮独立只读审查

审查者 `/root/independent_review`，独立于实现者；未修改生产代码、原验收器或索引，未启动 Godot。HEAD 为 e7286da1 三方合并，所审修复仍属可变工作树。适用 gameplay-reviewer、game-quality-gate、scene-composer、region-creative-director；本报告是有边界的 AI 专业判断，不是用户认可。

## 实看范围与结论

实际通过 view_image 逐张查看两组原尺寸 1280×720 PNG：composition-v13 与 composition-v14 各 root_bay、interwoven_inner、interwoven_deep_basin、interwoven_root_landing，共 8 张。原路径及逐文件 SHA 见 initial_pixel_sources.json。读取两份 report，身体、相机、HP 对照相同；两侧 Manifest 分别为 649bf589… 与 7e357e86…。这是 fresh DemoApp 的初始 segment 观察岸静态 G2 fixture，不是自然路线通关。没有看电影、听音轨或使用实体设备；截图尚缺采集时源快照及命令绑定，不追认为后续源码画面。

**空间候选第一轮 REJECT / REWORK；技术整合最终 UNVERIFIED。** 小果实剪影与去金属光圈可保留；当前几何和目标数量没有实质改变，不足以说用户的目标摆位/空间美感问题已修好。保留显式候选、pending_spatial_redesign 与未退休目标的诚实声明。

## 发现

| ID | 事实/判断与像素 | 最小返工及复验 |
|---|---|---|
| FR04-V01 / major / AI构图判断 | interwoven_inner 前后都13目标同屏。v14 interwoven_hollow_b 位于(724,382)，根从玩家脚下平台(724,477)竖起约95px；interwoven_crown_side_ring 位于(592,58)，从平台顶(592,189)竖起约131px；lower_fork__relay_a(976,84)同样向上挑。细长果梗像支杆果牌，仍未建立枝冠归属。 | 保留小果剪影；优先用2–3个真实推荐点组成可读的枝侧/下缘短弯挂点，再看完整屏。若需移动目标，应在显式新布局内改并实际重验 Motor/捕获/失败恢复；不得因128wu距离合同通过签美观。 |
| FR04-V02 / major / 已观察未解决 | interwoven_deep_basin 两张像素没有实质改变，interwoven_deep_descent_ring(472,58)、interwoven_deep_a(496,286)仍悬浮旧铜环，空旷负空间没有建立层次和所属枝干。 | 可保留 pending 阻止假果梗，但不能称全森林摆位完成。后续独立方案需真实可行支承与路线空间。 |
| FR04-V03 / moderate / AI构图判断 | root_landing 中 hollow__lower_window_ring(1024,400)从脚下平台向上长约77px细梗。 | 同V01；不因在真实矩形边缘就等同可信生长。 |
| FR04-S01 / moderate / 源码语义 | ThornForestRegionStage 无条件显示 HOOK THE BRASS RING；v14 的 crown_approach_ring_0 实际是gate果实。 | 按真实presentation选择果实/目标文案，历史v13铜环文案保留。 |
| FR04-E01 / evidence gap | composition report未绑定采集时源码SHA/命令/引擎版本，当前作者仍修改工作树。 | 冻结实际已运行源/原图/report/日志，不用当前hash回填旧采集事实。 |
| FR04-V04 / legacy | root_bay 旧入口提示与两行推荐路线提示在x214–580,y230–280叠印；前后都存在。 | 不阻断无关PR96整合，但应保留可读性缺口，不称全UI完成。 |

## 静态整合核对

- e7286da1 combined diff 保留 physical_contact 的同帧/actor_epoch/session 判断，未用矩形扩大替代真实碰撞；追加fall_plane下层落地逻辑，森林新增records明确surface/forest_thorn，未套平原坑面豁免。
- DemoApp保留bind_duel全碰撞尺寸，Windkeeper单独使用owner矩形provider；森林Boss恢复仍在configure_arena+bind_duel之后处理，未被平原分支覆盖。
- 旧regional_art_plan箱体绘制和capture_state保持PixelFormal表现，Underworld放置开箱图分流；未见静态丢失旧候选。
- stable_vertical_follow仅森林入口use_stable_forest_view启用；generic grounded/inspection分支保留，Boss route_focus独立；暂停沿PAUSABLE，重生沿session snap，保存布局仍version pin。未运行复现，以上只签源码存在与分支关系。
- AvatarPresentation恢复默认显示时识别PixelPlainsActor（UnderworldPlayer继承该类），隐藏CourierVisual锚点并在选择painted前隐藏默认身体。新增正式Home/Forest所有权用例保留拒绝和重复绑定；真正退出无泄漏仍待当前结果。
- v14 RETIRED_ANCHORS=[]；没有依赖静态“无动作引用”批删14点。路线职责来自fast/growth/available边和geometry anchor bindings，boss/gate/recovery优先；未将Manifest.routes推荐误称世界随机化。消融驾驶及冻结80结果尚待，不能签目标冗余定案。

## 未验边界

玩法价值、完整Motor路线/失败恢复、动画和音频、全图构图、map2和其他Seed、暂停/重生/保存真实运行、最终主线CI与退出泄漏、用户手感及设备均未验。第一轮拒绝保留；修后须新源新图复审，不以本报告签整体通过。
