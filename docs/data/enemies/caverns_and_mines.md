# 蕈灯地穴与回声矿井的普通敌人

| 物种 | 玩家辨认的攻击 | 运行定义 |
| --- | --- | --- |
| 孢囊虫 | 观察起跳，在落地前选择让路或反击 | [enemy.spore_larva](../../../production/resources/enemies/spore_larva.tres) |
| 菌壳兽 | 在地面蓄势冲撞，换层可避开冲线 | [enemy.mycelium_shell](../../../production/resources/enemies/mycelium_shell.tres) |
| 矿轨爬机 | 沿地面冲向玩家，轨道边和作业台影响站位 | [enemy.rail_crawler](../../../production/resources/enemies/rail_crawler.tres) |
| 失控采掘机 | 地面机体发射扇形弹幕，观察间隙再通过 | [enemy.stray_excavator](../../../production/resources/enemies/stray_excavator.tres) |

每房的敌人实例与掉落档案由该房的 content_bindings.enemy_instances 指定。独占首领另用遭遇胜利收据。[当前世界绑定](../../../production/config/imported_world/bindings.json)
