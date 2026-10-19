# Trailing-bud02：REVISE，机会与价值均未证

只读实际dirty候选，基线fb2c310659a17355c3544d90cf05785b55653a8b＋batch02/source_before逐源SHA，非immutable晋升。独立读两份完整raw和原receipt，所读源与actual before哈希全部一致，已选保selected-source。未运行engine/browser、未改tracked，也未照抄作者分析。01编译FAIL保留；02purpose真实3FAIL／control strictPASS不重签。

## 此次失败实际说明什么

双方前165帧完整字段一致（仅case不同），真实固定A→射击R→固定B入场。purpose随后120观察帧，没有一次trail_cast_request；全段hook free，PC仍带+1轴向右到947.925，bud在左后。

独立重算**全部120帧**PC固定hook origin到bud最小距离244.131px（258），已经超driver允许231+12=243；下降/free/flight条件只会更严格。因此此轮没有发H请求，更谈不上目标命中、身体到达、反枪失败或已证明无恢复路径。purpose285停止，Queen17／Player5／E80，三个失败分别是预定动作链、完整恢复、24commit未成。不能把未接近机会的驾驶说成物理不可能。

control始终只用固定锚／枪／常规恢复，935真杀／HP5／E100，946支持12；24实际Boss提交均projectile、无玩家Policy。它保留了很强的安全完整打法，但不是零H对照（共同A/B真实存在）。purpose7次实弹伤害与control24次，尚无trailing独有输出／安全角度／资源取舍可比较。

## 与本体group相比，底层改变是真实的

bud是world sibling、Area锚、无Damageable、不复制Queen血量；原本体grapple group已移除。两raw所有帧均无本体group／无body target protection，未观察到hook伤Boss；原24H刷伤条件因此不能直接套用这版。不能据此自动说新锚已有趣：它需要空间机会和身体脱离，而非只有移动坐标／长系绳。

## 180°重合不是纸面猜测

当前按已承诺整条闭环弧长回溯120，欧氏距离不保证120。pathC在(426,110)反向，身体返向60px时bud正好位于同一点。control原raw **tick561确有Queen=(486,110)、bud=(486,110)，欧氏距离0**；purpose首转角189已仅33.379。弧坐标连续不等于安全身体分离。

此重合时实体Queen会挡钩头／拉近，且bud sibling不为Queen提供grace；若玩家正在借它到达，潜在不可读接触或失败值得修正。当前控制没有在561借bud，所以不是已观察到的玩家受伤／已证普遍不可避。不能通过给bud继承Queen全场保护、缩碰撞体或改射程绕过风险。

## 限定决定

**REVISE，不准入，也不宣判此方向物理不可能。** 可保留无伤害world-sibling锚与动态路径实现的技术事实；本轮机会未被实际消费，完整H→反枪→身体恢复与相对固定锚强解的新价值皆未证，180°实际重合须作为内容问题处理。若后续仍只是把观察起点搬近／调120距离凑到一次H，未形成可读新进入关系，则应DROP而不是累加成功次数。任何重做应先说明玩家为何追这个锚、到达后如何避开真实身体及能放弃去哪里的取舍，保最强普通合法；本审不授权无限重采。

原默认v10几何未改、参数trailing_bud_distance默认0，opt-in未进入Manifest/save。没有正常影片／正式App／生命周期／趣味证据，不能凭默认关闭或当前无泄漏就签生产整合。
