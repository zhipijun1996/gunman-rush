# DEMO-UI-01 R3 独立审查 01

审查者 `/root/ui_audit`；R3 实现者 `/root`、`/root/menus`。本轮未写生产代码，未写 R3 测试，未运行 Godot。只读源码、测试、真实 Godot 原图及已有执行回执；本目录仅写报告。适用 gameplay-reviewer；依据 `docs/worklines/demo_ui_01/r3/scope.md` 与本轮明确授权。基线 HEAD 为 `2cf83fa07e0b7aab0e36d44c25c2aaaf38a32d62`，R3 为仍在修改的工作树；不能用该 HEAD 冒充已提交的 R3 构建。审查瞬间关键源码及原图 SHA256 见 `review-01.json`。

**结论：ui-first / 初始可用性源 REJECT。** 下列 3 项已及时通知实现者；审查结束时都看到了针对性源码更正，修正版尚需重新采证。当前更正版运行、动态环与公开预览为 UNVERIFIED。旧失败不能被后来的源码修正追认通过。

## 必修及复验

| ID / 严重度 | 反例及实际结果 | 最小更正 / 结束时状态 | 复验条件 |
| --- | --- | --- | --- |
| R3-I01 / P2 | 本次 flight cap=1、used=0，在土狼窗口获得 D：原 `maximum>1 && used<flight_cap` 把仅剩第一次跳显示为二跳资格。违反“不凭空增加能力”及显示真实可用性。 | `JumpAbility.can_air_jump()` 已补 `flight_cap>1`，只读不改跳跃规则。源码已更正，未独立执行。 | 构造旧 flight cap=1、used=0 的中途扩容；D 图标不可显示；正常真实落地/命中恢复后应显示。 |
| R3-I02 / P2 | 地面出钩落空、retract 后 free，`hook_used=true`：原 HUD 隐藏 H，但 `request_hook` 接地实际允许再次出钩。 | HUD 已改成接地或未使用。源码已更正，未独立执行。 | 真正落地碰撞后出钩落空并收回；H 可再出。空中已经使用时仍隐藏，实际钩中/落地恢复。 |
| R3-I03 / P2 | 原图 `ui-first/max-growth.png` 左上生命计数把 `4.25/13.5` 挤成 `4.25`、`/13.`、`5` 三行。心形可读，但精确值破碎，不满足数值增长适配。 | 原 Label 自动换行且最小宽24；结束时已改 AUTOWRAP_OFF / SHRINK_BEGIN。新像素待验。 | 相同 4.25/13.5 与手机窄画面重新截图；计数完整、心列正常换行、不越安全区、不覆盖右侧菜单。 |

## 真实消费者及规则检查

正式 PlayerController 初始化让 AirFocus 与 actor_resources.stamina 引用同一个 StaminaState；默认 enable_shot_energy 绑定 `time_energy_v2`，没有创建另一份当前资源。旧资源只有显式注入才分离，当前普通 App/模块消费者使用默认新版本。

正式 v2 的 ShotEnergyPolicy can_fire 不依赖精力、consume 不扣精力、advance 不恢复精力；已提交命中仍按原 shot/session 去重补一发。WeaponActionRuntime 的激光持续扣能及余额中止都受 `shooting_consumes_energy` 的显式历史 guard 保护，没有发现正式激光自身仍扣时间能量的路径。AirFocus 保留真实秒、接地渐回、空中累计上限及耗尽重启阈值；它是唯一当前时间能量消费/恢复者。基础配置已一发，容量中途增长不赠弹，原恢复事件保留。

五件原能量道具都是真实 v2 Definition，稳定 ID/stack 语义保留，文案与 modifier 对应：握柄 drain×0.8、铃匣 recovery+5、编绳 recovery×1.35、余响金 recovery+10、冷却鳍片 rearm×0.65。当前 BuildModifier 已允许这三个 focus stat，BuildState 从唯一基础重算、真实写回 AirFocus 所持同一 tuning，撤销走原重算；不是假反馈。初始白名单缺失的失败仍保留。测试作者的新专项对五件授予/撤销都有实际链断言；独审只核对其源码与回执，不代替复验执行。

历史保护已用 Python 独立核对：原 runner 与五件旧道具，6 项 preserved 文件字节、history.json 声明 SHA256、`git show 2cf83fa:original` 三者全部一致。显式旧 Definition + 两发 fixture 留在迁移历史入口；不把旧规则继续施加给正式默认。未发现为本轮删除原物理/资源断言或扩充预算过关。

## 实际像素与生命周期

实际打开了 `ui-first/` 的 formal-hud、touch-hud-844x390、hurt、pause-844x390、pause-960x540、pause-1920x720、pause-720x1280、max-growth、run-end 共 9 张原图，逐项 SHA 与渲染 viewport 尺寸在 JSON。未打开 title、map，本结论不覆盖它们。

正式 HUD 无旧大黑底板、无武器 widget；角色原图裁取头像左侧，爱心在右，真实共鸣置于心下。正式5/5与伤害4/5的层级、失去生命颜色可辨，头像没有挤占玩家动作，触屏图中位置文字与按钮可读。生命精确分数来自真实健康数值；heart strip 对实际 fraction 裁切，没有改半心或伤害规则。增长图的心形行数与残缺上限表达成立，计数存在 I03。Run-end 图 HUD 消失；暂停图展示真实分页、禁用装备项及窄画面滚动，没有见到伪可用装备。

时间环静态实现订阅实际 AirFocus reserve，只在 actor active、未死、focus active、未暂停时显示；锚点用真正 Motor CanvasItem 的 global transform 与 HUD inverse，半径读碰撞高度；解绑立即隐藏。未发现 Controller Node 冒当角色 CanvasItem 或重复计时资源。现有提供的 ui-first 原图没有慢时环，故不能签环的实际像素/连续生命周期通过。

文件名是目标窗口，不能当原图像素尺寸：touch844×390 实际693×390，pause720×1280 实际720×405，pause1920×720 实际1280×720。它们证明的是 Godot 渲染 viewport；完整操作系统窗口、黑边、设备安全区仍需完整窗口证据。

## 运行证据边界

引用实现方已保留日志：ui-first/assertions.json 为146项0失败；regression-v2/report.json 的旧能量迁移与 grapple focus 两入口退出0。energy-first/d079-first 曾失败，已保留。审查时 energy-v2 仍131项1失败并退出1（真实子弹命中恢复 D/H），已有 fixture 后续更正但没有新成功结果，不能签正式规则通过。该次日志还包含退出资源泄漏，后续必须看退出与原日志，不能只看断言计数。

本轮未独立操控真实 GUI；未观看连续录像/音频，未验公开 Web，新 ring 动态、修复后源/像素绑定、实体手机/手柄和用户认可均未验。地形/敌人/角色素材与动作不属本轮审查。AI 的布局判断仅覆盖已观看原图，不代表用户视觉认可，不替总控 Integration/Release。
