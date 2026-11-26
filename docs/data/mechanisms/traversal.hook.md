# 钩索锚点

放置真实钩索目标。`hang_enabled` 决定锚点可否悬挂。`material_family` 默认为 `inherit`，根据功能从区域清单读取 `bounce_texture` 或 `hang_texture`。缺省使用机械外观，实例可显式选择机械或根系外观。贴图共用相同的钩索判定。能力授予由上层进程持有。

C06 用一次正式 H 会话管理一个锚点。命中时进入占用，停留型可供悬挂，弹跳型在离钩时结束会话。离钩后等待 `cooldown_s` 秒重新参与 H 的目标选择；复明前按 `reactivate_warning_s` 显示预告。`initial_available=false` 要求设置正冷却。挑战恢复会解除旧连接并恢复初始资格。

弹跳钩保留向下的尖头，悬挂钩保留贯通的圆环。两侧销灯随钩索资格亮灭，复明预告在原位闪动。固定座读取本区域材料。

[行为与字段合同](../../../production/config/world_elements/behaviors/GrappleAnchor.json)

[版本和默认参数](../../../production/config/world_elements/definitions/traversal.hook.json) · [机关目录](../world_objects.md)
