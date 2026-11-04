# 森林地块场景语言

本轮用户反馈：地图小、空中连续动作不足、生态单薄、地块没有树／根地／荆棘／树洞身份。本页只负责第四项与空间生态接口，不能以绘制变化代替其他三项。内容为玩法可读原型，未获精美美术、玩家和实体设备认可。

## 正式接口与旧版本边界

`ForestSceneLanguage.annotate(manifest, overrides = {})` 只由新内容生成器在最终 `manifest_hash` 之前调用，不修改碰撞、钩点、危险体积、Player、随机流或资源。新记录写 `scene_language_version = 1`；所有平台写 `scene_kind / structure_id / surface_role`。`validate` 验证语义、平台归属与危险朝向，不能证明画面可读或好看。

`overrides` 以平台 ID 为键，可显式指定三个字段；行上已有语义也被保留。新扩展应先决定每块是什么再生成几何，不能依靠通用 fallback 认定设计完成。默认仅为现有几何迁移：单向薄台为树枝，矮实体为根土，高实体为树洞壁。后续新结构须显式指定倒木／树冠，不按名字字符串猜材质。

`geometry_instances.platform_id_map` 把同一几何结构的平台归为一个 `structure_id`，结构可能是树洞、倒木或空中枝桥。当前 `ForestExpeditionLayout` 用 `scene_structure_kinds` 显式声明结构身份，`ForestSceneLanguage.annotate` 将声明写入 `scene_structures[].kind`；不再把所有 geometry instance 当作树洞。结构类型与平台材质分开：一个根地结构可以包含真实倒木平台，一个倒木结构也可以包含接收叶托和根土恢复岸。

| structure kind | 当前显式结构 ID | 空间身份 |
| --- | --- | --- |
| hollow_tree | hollow、western_hollow | 有真实窗口和洞腔的树体 |
| fallen_trunk | fallen_chain、fallen_giant、east_broken_log | 倒木／断木承载的横向路径 |
| bough_relay | crown_relay | 空中枝条接力，不暗示包围空域的洞壁 |
| river_boughs | river_chain | 河谷枝条与落岸关系 |
| canopy_arch | western_bridge | 西侧树冠拱桥的连续空中路径 |
| root_hollow | root_grotto | 根部凹穴与朽木地面 |
| rootland | old_tree_undergrowth、western_underbridge、river_root_basin、old_tree_west_root、forest_roots | 根土岸、下层回路和恢复地面 |
| bough_group | forest_boughs | 未另命名的枝条归组，不冒称独立树洞 |

`root_group` 仍是 helper 允许的结构类型，但当前 expedition 显式映射用 `rootland`。没有显式类型时，geometry instance 只有具备实际 `windows.clear_rect` 才回退为 `hollow_tree`，其余回退为 `bough_group`；普通平台归组也回退为 `bough_group`。新扩展仍应显式设计类型，不能把 fallback 当作场景设计完成。

`local_geometry.windows.clear_rect` 经原 translation 转换为明确可通行的暗内腔。背景只绘制这些实际窗口的低对比暗面；结构类型标签本身不生成暗腔、墙或碰撞。没有窗口的接力枝桥不会凭类型获得假树洞。

当前 `fallen_chain` 的 `arch_four` 几何中，`root_arch` 平台已显式使用 `fallen_log`，修正为倒木材质；其他布局的该平台仍使用其明确的树皮材质。`western_fallen_log` 也显式为 `fallen_log`，虽归属于根地回路 `western_underbridge`，不会因此改画根土。实际平台材质由 `scene_kind` 消费，结构身份由 `scene_structure_kinds` 说明，两者不互相覆盖。

`ThornForestRegionAssembler._draw` 仅对 version 1 且有语义的平台调用 `draw_surface`，碰撞仍走原 build。旧 Manifest 未增加字段，仍走原绘制，旧版本完整 hash 和存档不得回填改变。

## 地块词汇与轮廓

| scene_kind | 场景语言与真实功能 | 原型画面 |
| --- | --- | --- |
| root_earth | 根土宽岸、恢复／观察；只适合实体 | 水平土层、向下分叉的根纹、全长真实站立边 |
| hollow_bark | 同一树体的实体洞壁／厚树皮 | 纵向曲折纤维、内侧断面边；真实空腔暗面与实体明暗分离 |
| living_bough | 从树体伸出的薄枝，可穿单向下方 | 横木纹、末端年轮弧、边界内分叉；不在下方填壁 |
| canopy_perch | 开阔树冠叶托与目标岸 | 木质横纹承托向上的叶片三角，叶片限真实平台内，不盖落点 |
| fallen_log | 横向倒木／断木 | 横向纤维、端头截面与内缘；无真实空腔时不画可穿树洞 |

`surface_role` 标示 `root_top / inner_bark / bough_top` 或调用方明确给的具体用途；它说明结构内的角色，不产生新碰撞。单向平台不可标 `root_earth / hollow_bark`，以免暗示可碰撞侧壁。

危险不是额外安全材质。`danger_presentations` 保持原朝向和索引，加 `scene_kind=thorn_growth / host_structure_id / host_support_id`；上下刺仍由 assembler 从同一真实 hazard rect 绘制，完整淡色伤害包络和外边界保留。不能让刺尖之间看似安全、不能缩小伤害体积配画面。

## 真实合屏需求

必须由正式区域消费者采集：根盘→树洞入口→内部通道→出口树冠的正常速度过程，包含真实HUD、玩家、H目标、敌预告和危险相位；至少两张图及回望方向。检查纵纹／横土层在真实缩放可辨、暗腔不被误读实体、叶纹不盖锚点、单向薄枝不呈厚墙、危险全包络与真实碰撞一致。

只读源码和接口不能签画面通过。本页不新增资产生成预算或平行质量流程；沿现有 scene-composer / art-director / encounter-director 和同一任务的门槛。未实际观看的影片、未听音轨及实体手机必须分别保留 unverified。
