# 平原角色最终素材

当前正式版本为八类普通怪的原生动画，以及两位 Boss 的骨骼动作。资源与来源只保留一份；审稿拼版、光流／整身补帧原型和旧预览不属于当前交付。

- `atlases/`：小怪基础页负责攻击、前后摇、受伤和死亡；`*_motion` 页负责待机和移动。两者由 `PlainsActorSkin` 共同消费；飞羽铃哨使用单页七状态、每状态八帧，不再保留重复motion页。
- `static/`：保留十张已批准造型，原扇射站姿重归地面行枝铃哨；新增飞羽铃哨参考取新动画首帧，不声明已获用户视觉批准。Boss参考用于骨骼来源追溯。
- `source/`：小怪动画生成原图、提示词和采样参数；`source/static/` 保存静态参考唯一原图与哈希。来源目录由 `.gdignore` 排除运行导入。
- `../plains_boss_rigs_142/`、`../plains_boss_fx_142/`：当前 Boss 分层部件与战斗特效。可编辑场景位于 `game/presentation/actors/art/`。

重建与检查：`python tools/art/build_plains_enemy_static_142.py --check` 校验十张静态参考逐字节可复现；小怪、骨骼部件和特效分别由 `build_plains_actor_animations.py`、`build_plains_boss_rigs.py`、`build_plains_boss_fx.py` 维护。

`package_plains_actor_animations.py` 生成唯一检视页与两种交付 ZIP；`capture_plains_actor_combat.gd`、`capture_plains_enemy_combat.gd` 和 `tests/windkeeper_pounce_142.gd -- capture` 录制正式战斗。临时录制和诊断写入 `build/`，交付后只保留最终独立 MP4、检视包和必要验证记录；历史通过 Git 追溯。怪物原批交接见[角色素材](../../docs/project/worklines/plains_enemy_static_142/scope.md)，三铃地空分种与当前试玩见[平原交接](../../docs/project/worklines/plains_bible_v2_01/scope.md)。
