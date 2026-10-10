# 平原钟械敌人候选

AI 原始 RGBA 图集，匹配用户认可的 windchime_plains 风格参考。原像素不修改，JSON 使用真实源像素区域；不要按四列等分代替 manifest：残骸和训练靶使用独立边界以避开串格。

- 巡逻无人机：body 与 rotor 独立；现有 EnemyPresentation 只选 alive/dead，旋翼动画应是表现层旋转，不能产生新的攻击。
- 训练靶：active/dead 静态状态。实际 CombatTarget 目前以矩形绘制，目标图片仅可替换表现。
- Boss：phase_1 青色、phase_2 红橙色，轮廓一致；dead 倒地残骸。保留原 BossPresentation 的血条和动态预警圈，不能以 VFX 的静态 warning_ring 代替当前 warning_progress 信息。

anchor_px 为裁切区域内部锚点。Boss/靶/残骸锚点靠近落地基线，无人机锚点为主体中心。collision_size、Health、攻击相位、接触范围与弹体继续归现有 Actor/Motor/Encounter，不由画稿外框决定。少量低 alpha 画笔余晕仍需要实际深色合屏复核。

此图集提供八个静态表现键，不是完整走动、受击或死亡动画，也未通过真实设备的最终验收。
