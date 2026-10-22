# DEMO-UI-01 · 商业 Demo UI

- 基线：origin/main `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，2026-10-22 fetch。
- 分支：feature/demo-ui-01；独立工作区 /workspace/ui-workline。
- 模式：System Engineering → Long Production。阶段：首轮可操作方向，用户/实体设备未验。
- 使用 Skill：visual-director、art-director、game-quality-gate、project-integration；环境依 cloud-environment-runtime。
- 本线所有者：scripts/ui/demo_ui_01/、scenes/dev/demo_ui_01/、tests/demo_ui_01/、docs/worklines/demo_ui_01/、docs/evidence/demo_ui_01/、本任务质量卡；既有 DemoMenu/menu_theme 与地图/流程模态界面。
- 角色、怪物、环境、美术母版、Motor、伤害/资源/能力/存档规则只读。中央任务/current_state/handoff由总控维护，本线不改。

## 共享接入请求（给总控复核）

DemoApp 只新增 DemoGameHud 表现消费者：构造、与既有 start_demo 同时 bind、_process 末尾传真实 location/coins/notes、hide/cleanup 对称解绑。普通模式隐藏旧黑板与其三份重复文本；F3原调试仍保留。无字段回写到玩法。

输入接入只把手柄 Start 映射到既有 toggle_pause；地图 B 返回走既有 close_region_map；原 router.clear、暂停/恢复、取消与 epoch 不变。死亡/失败结果在既有结算、cleanup、return_home 后用只读报告开结果页；再次出发调用既有 start_plains，首次默认流程与规则不变。

HomeScene 仅将旧板/资源显示替换为同一只读 HUD，不改世界、NPC、输入或存档。最小调用与真实 diff 在 PR 列出，不进行共享脚本重构。独立 Cloud 无实时总控通讯，以上为任务文件交接和可评审接入候选；未合 main。

## 消费者与数据

正式 title → start_plains → DemoApp → PlayerController。生命：health.current/capacity；射击精力：shot_energy 存在时的 actor_resources.stamina；空中弹药：action_resources.shot_charges/max_air_shots；共鸣：combat_energy；慢时：独立 air_focus stamina_state/air_time_used；武器：shoot_ability.weapon；能力：action_resource_view/traversal；金币 wallet.balance、音符 meta.snapshot.notes。地图保留 PlainsRegionMap 真正迷雾，不造路线。

ActorResourcesHud 被 Graybox/ModuleLab/FoundryLab/RandomStagePreview 与历史强断言使用，保留此兼容类与实验布局。本线新增正式 DemoGameHud，不更改原条形断言。

## 交付与验证

沿原 cloud_delivery 独立 Preview，先核 gunman-rush-previews 容量，再写任务/SHA路径；不改正式主站。真实 Godot 4.7.2 Standard（仓库校验安装），Web + 10–30秒真实电影；所有源码冻结与 SHA 区分记录。

Development 用原 planner 保存实际选择（未知共享接入会保守升级 full），本线按用户要求只运行相关专项；完整 Integration/Release由总控统一。模拟DOM触控/手柄与实体设备分别写。G5尚未取得，不宣称商业品质最终完成。

## 浏览器发现后的最小追加接入

设置页先聚焦再等布局完成后定位滚动，初次打开保留页首；输入字段使用稳定focus_key。真实Web浏览器暴露原提前滚动问题，保留首失败而不放宽检查。

scripts/dev/cloud_preview.gd 仅在 task_id == DEMO-UI-01 时挂接任务专属 preview_affordance.gd：完整游戏/菜单内隐藏遮挡文案的原开发条；访问开发实验室时保留原返回完整游戏按钮。其他任务默认不变，持久化禁用与生命周期归原bootstrap。此共享接入由总控合入时复核。

## 最终可操作检查点与证据阻塞

运行源码 `df5207ccc920f5d48813412a27d9d72dc79510ab`，Web `5ae16004975a`，后续恢复文档不改变运行包。[试玩](https://zhipijun1996.github.io/gunman-rush-previews/previews/DEMO-UI-01/df5207ccc920f5d48813412a27d9d72dc79510ab/5ae16004975a/) · [真实视频](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/DEMO-UI-01/df5207ccc920f5d48813412a27d9d72dc79510ab/93b03ef086fc/comparison.mp4)。完整范围、33行DemoApp接入、108×48触屏MENU几何、550+44+21实际观察、环境断连造成的未提交回执和恢复办法见[delivery.md](delivery.md)。

当前Draft评审候选；用户美术、实体设备、完整Integration／Release未签。原始550项／浏览器／失败归档受环境unavailable阻塞，不把会话摘要冒充原件。电影原始report／trace已从独立托管仓精确恢复。main不合并、不覆盖正式试玩。
