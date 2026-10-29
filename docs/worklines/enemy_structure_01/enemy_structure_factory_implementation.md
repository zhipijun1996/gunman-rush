# ENEMY-STRUCTURE-01：普通怪创建／校验／策略与只读状态移交

已停止扩范围。所有本组生产修改均已写共享目录；未运行Godot、未git commit、未改资源/图片或表现文件。root统一import/原回归后才判实际通过。已读AGENTS及project-integration skill，保原AI时间、保护点、并发、碰撞、HP/资源、RNG、奖励和保存算法。

## 文件

新增：

- `scripts/enemies/enemy_behavior_registry.gd`
- `scripts/enemies/enemy_factory.gd`
- `scripts/enemies/enemy_attack_strategy.gd`
- `scripts/enemies/charger_attack_strategy.gd`
- `scripts/enemies/diver_attack_strategy.gd`
- `scripts/enemies/hopper_attack_strategy.gd`
- `scripts/enemies/sentry_attack_strategy.gd`
- `scripts/enemies/fan_sentry_attack_strategy.gd`

修改：`enemy_actor.gd`、`enemy_definition.gd`、`forest_enemy_definition.gd`、`forest_bible_weaver_definition.gd`、`enemy_attack_behavior.gd`；候选入口`ModuleEnemyPrototypes.setup`／`ActionStudio._spawn_candidates`；`GeneratedDemoStage._spawn_enemies_from_plan`仅开头创建/Definition overlay块。root在ActionStudio Boss函数、Generated ready Boss行有独立并行改动，本组没有覆盖那些函数。ThornForestStage由root迁移场景查询，不属本组写入。

## 最终API

`EnemyBehaviorRegistry`是唯一有限行为登记：14个行为（patrol无attack）对应原Definition/scene/Behavior脚本与验证family，五平原策略也登记在同一行，无第二份策略白名单。

- `behavior_ids()/candidate_ids()` → typed StringName arrays。
- `supports_behavior(id)`、`validation_family(id)` → base / forest / weaver / 空。
- `definition_path(id)/scene_path(id)` → res://完整路径，未知返回空。
- `definition_error(behavior,stable_id)` → 空或unknown_behavior/candidate_behavior_mismatch，无push_error。
- `behavior_script_path(behavior,stable_id=&"")` → 原具体Behavior脚本；候选moth选PrototypeMothBehavior，但它的Definition.behavior_id仍sentry。
- `create_behavior(definition: Resource)` → 原EnemyAttackBehavior派生实例，验证不合/未知/null/patrol返回null，不静默退到通用Behavior。创建正常Actor时patrol早返回，其他创建失败由Actor显式push_error。
- `create_attack_strategy(behavior)` → 对应小策略；未知null。普通派生forest/root用公共无运动默认策略，仍运行自己原advance算法。

`EnemyFactory`只创建**未入树**且Definition/receiver已完成的Motor；位置、入树、policy绑定、最终presentation/style归caller。

- `scene_path_for_behavior` / `definition_path_for_behavior`。
- `override_error(overrides)`：仅允许现有实例字段patrol_half_width、aerial、dive_depth、initial_direction、patrol_speed；错误有明确字符串，无副作用。
- `definition_for_behavior(behavior,overrides={})`：加载原资源duplicate(true)，保原类/Health，再应用合法覆盖并调用原is_valid。
- `create_for_behavior(behavior,overrides={})`：原scene实例，配置Actor.definition，失败null。
- `candidate_recipe/candidate_definition/create_candidate(identity,context=&"lab")`；`configure_candidate(motor,identity,context)`仅未入树可用。
- recipe返回identity/context/source_context/behavior/guard/definition_path/scene_path/overrides/admission。

候选差异明确保留：Lab/Review半径120、activation360，moth速度45；Studio半径100、原基础activation180，moth原sentry速度0。两处原碰撞32×36、telegraph0.8、attack guard0.65/moth1.1、recovery1.1及原receiver.guard均未变。review是lab recipe的明确别名，不把Studio改成Lab。

`EnemyDefinition.has_valid_identity()`只抽公共stable_id/version/faction/Health/collision/direction校验；三种Definition的专属数值条件保持原有：base原有限fields，forest各原spider/bark/swing/crossbranch阈值，weaver原固定根/有限线阈值。family查表替代分散行为名单。已知两个candidate稳定身份不能配错底层behavior，未知普通自定义stable_id仍不强绑资源名。

`EnemyActor.presentation_state()`返回只读字典，**所有嵌套Dictionary/Array也复制并make_read_only**，invalid同样只读：

- valid/reason（未初始化时false），state/state_time、phase_durations{telegraph,attack,recovery}/phase_duration。
- facing、实际Motor global position/velocity（Vector2）、HealthState epoch、terminal、stable_id、behavior_id。
- source_phase、source_kind(behavior/patrol)、source_behavior_script。
- 无attack_behavior时state=idle，source_kind=patrol，保持原motion默认idle；不新增玩法状态或时钟。
- Behavior可选同名`presentation_state()`提供state/time/phase_duration(s)只读细节；不能覆盖identity/epoch/Motor位置/terminal权威。当前原Behavior未新增该方法。

## 算法机械拆分

`EnemyAttackBehavior`继续独占原state/cooldown/state_time/home/actor_epoch/serial/并发/安全点与LOS、真实射击创建及policy提交顺序。只把原局部公式提取为策略hook：

- Charger：同一home±radius目的地、attack_speed限长、require_floor=true。
- Diver：同一sin(state_time*1.8)/cos*8 orbit、原速度/转向、同一锁定目标俯冲、原回home与blocked判据。
- Hopper：锁定目标home.y、同一sin(PI*t)*90抛物线、原回home。
- Sentry：idle不巡逻，切到attack原时刻调用原`_fire()`。
- Fan：仅原角数组[-.18,0,.18]；其它发射事件/id/序列仍归原基类。

`_attack_strategy()`在configure/advance/_fire按当前Definition.behavior_id懒解析，支持旧真实fixture直接`EnemyAttackBehavior.new`或赋字段后`_fire`，不要求新factory独占创建；换behavior_id也重取。未知不静默fallback。PrototypeMoth原super.advance、错拍0.5阈值、两次±0.35锁方向及super._fire都原样保留，取sentry策略；RootBell/森林原advance未改。

已git grep核current脚本/测试/工具直接new和_fire：audio_director_lab_v2、quality_review_runner、underworld_projectiles、item_v5_defense_time、hit_template_pixels、draw_culling、enemy_all capture等。没有迁移旧断言或删测试来适配本组。

## 本组实际静态检查

- `git diff --check` exit0。
- gdtoolkit4.5 parser仅语法解析本组15文件成功（Actor/Definition/registry/factory/策略/ModuleLab/GeneratedStage），**不是Godot类型/导入/运行通过**。
- ActionStudio整文件gdtoolkit在原HEAD已有的多行普通引号HUD字符串处同样解析失败；本组没有更改那段字符串，不为工具限制改原HUD。新候选块需root实际Godot解析。
- 引擎租约未使用；未报告HP/动作/保存/回归或画面PASS。新class的UID/import由root统一处理。

## root优先验证建议

先统一import（验证registry↔Actor↔Strategy类型/动态load闭环），再由独立runner实际创建14种+两候选及Lab/Studio两recipe，核scene/Definition/receiver/Behavior/策略真实类、未知/错配拒绝、snapshot递归read_only、暂停initialize与真实phase读取。

原回归应至少包括core enemy tests、现有五feedback/尸体保存、root-bell-current、森林ecology/depth/weaver/crossbranch及原formal消费者；新strategy比对原phase/state_time/位置/攻击goal/shot角与serial/双方HP/event/epoch，不只测注册表自报字段。保全部原预算和失败，不以新结构通过签成品美术。
