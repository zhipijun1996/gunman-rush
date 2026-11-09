# 《失序之钟》房间美术入口

PR141 评论的美术包已融入本仓库，无需重新上传。使用 [godot-room-art](.agents/skills/godot-room-art/SKILL.md) 制作和审查素材、拼装、景深、局部光照与动效；使用 [godot-recoil-level-design](.agents/skills/godot-recoil-level-design/SKILL.md) 负责动作、碰撞、遭遇与失败恢复。

- 地图、能力与收集来源以 [世界输入](docs/data/world/README.md) 为准。最新版整区设计已接替旧地图。
- 导入的 16 区构件、47 邻接与配方在 [art/world-art-v2](art/world-art-v2/README.md)，完整来源与原包身份由 [bundle-manifest.json](bundle-manifest.json) 记录。
- 本轮新绘人物、剧情动作、站台、收集物、机关、建筑与室内背墙在 [assets/plains_v07](assets/plains_v07/SOURCES.md)。母版、原生尺寸、裁切、锚点和哈希均可追溯。
- 平原实际可编辑场景在 `game/world/regions/P/rooms/`；逐房职责与体验设计在 [room_design.json](game/world/regions/P/room_design.json)。图片拼装和运行状态均不替代真实场景与 PlayerMotor 验证。
- 正式工程使用 `bash tools/godot.sh` 锁定的 Godot 4.7.2。素材包内独立样例仅用于对照，已隔离导入，不替换正式项目。

`python3 tools/art_bundle.py inspect` 核对集成清单；有意修改清单内文件后同步哈希。`python3 tools/art/bake_plains_v07.py` 机械重建新增原生素材，不重绘、不修改房间。只重建样例时才使用 `tools/art_bundle.py prepare-godot`，不要覆盖手工场景。

风格方向认可、候选素材、原生 Godot 画面和实际玩家操作分别验收。当前证据与剩余工作只维护于 [平原交接](docs/project/worklines/plains_bible_v2_01/scope.md)。第三方原素材、新绘素材与派生文件的来源分别保留，不将第三方素材重新标为 CC0。
