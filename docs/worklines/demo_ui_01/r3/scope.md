# R3：时间能量与无框战斗 HUD

2026-10-23，反馈轮基线 `2cf83fa07e0b7aab0e36d44c25c2aaaf38a32d62`；原主线基线 `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`。继续独立 feature/demo-ui-01 / PR105，不合 main。

用户本轮明确授权覆盖旧资源冻结：枪械不消耗精力；只有空中枪械/钩索瞄准触发的慢时消耗时间能量；基础空中弹药一发。HUD 无武器、无背景框，人物头像右侧爱心，爱心下面共鸣；已解锁二跳/钩索以真实可用资格显示，使用隐藏，实际恢复重新显示。慢时环围绕当前人物，只订阅状态。

最小共享变更：PlayerController.enable_shot_energy 可显式注入历史 Definition，正式默认 v2 共享 AirFocus 唯一 stamina；ShotEnergyPolicy 新版不扣/返能，只保留已提交命中补弹；激光持续耗能只保留在显式历史政策；JumpAbility.can_air_jump 只读真实飞行 cap；默认 config 一发；BuildState 接受现有慢时参数，5个旧耗能道具迁移为真实慢时作用与 v2 文案。地图拓扑、Motor、伤害、授予路径、RNG、存档不改。生成 manifest 仅更新真实资源政策标记；Foundry 按原验证重采，不手换 SHA。

保留原落地/成功钩索到达、蹬墙、实际空中伤害的能力恢复事件；取消/暂停不补资源。时间能量沿用真实秒预算、累计空中上限、接地渐回及耗尽再武装门槛。新规则不凭空增加能力。

历史 D079 两发/射击耗能保留显式 fixture 和原断言；正式 v2 另验。开发只做受影响专项，production_plan 因共享配置标记完整集成需求，完整 Integration/Release 交总控；不修改守门预算。用户美术/真机保持未验。
