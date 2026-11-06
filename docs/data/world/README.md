# 固定世界输入与来源

唯一人工拓扑源为 [world.json](../../../config/world/world.json)，拥有房间/分区、连接、资格及永久事件身份。原导入包已退出日常生成与运行依赖，只供来源追溯；不再修改其中的世界或生成物。

| 所有权 | 当前入口 |
| --- | --- |
| 世界拓扑与动作 | config/world/world.json；保留原有稳定ID、条件和奖励所在房间 |
| 人工施工 | [construction.json](../../../config/world/construction.json)：尺寸、门台/入口、场景绑定、镜头意图；手工场景拥有实际地形、休息/奖励锚点和局部放置；合同position_candidate仍是施工候选，不作为实际站位 |
| 收集规则与来源映射 | [collections.json](../../../config/world/collections.json)；完整48件效果和价格仍待决定 |
| 起始攻击参数 | [player.json](../../../config/world/player.json)：当前仅普通枪首档试制值，不改变玩家运动参数 |
| 路线回归输入 | [routes.json](../../../config/world/routes.json)；与重新生成的路线报告分离 |
| 合同与运行导出 | `python3 tools/world/build.py` → ignored build/world/contracts.json、runtime.json；不写手工场景 |
| 导出消费者 | tools/build.py先生成；raw_exporter核输入及场景SHA后加入PCK。游戏只读runtime.json和实际场景，不读docs或config/world人工源 |

已接入P-R03、P-R01、P-R08、P-R06、P-R14五个手工样房；其余仍为计划接口。P-R08是原拓扑的必要连接。P-R14按既有牧风者完整场地校准为1760wu宽，保留原门ID/分区并独立预留前庭；施工候选变化不改世界拓扑。

`python3 tools/world/room_context.py P-R03`按房提取，`--contract`读取目标房完整合同。生成器在工具目录独立运行，不再读v03、source_inputs或上次报告作为人工源。输入提取时全部216房合同与原包语义相等；此后实际样房的场景绑定和必要施工校准以当前construction为准。

验证：`world-build`检查无导入包环境下的构建、手工场景保留及缺件拒绝；`world-migration`检查身份/引用；`world-routes`重跑A/B/C/D图路线与反例；`world-pack`在空项目加载已导出PCK；`world-loop`走真实玩家教学、战斗、H领取、返回，并在独立进程继续。图路线通过不能代替物理运行。

原样导入52文件及MANIFEST仍可用 `python3 tools/world/verify_import.py`核来源。原CODEX_START_PROMPT和迁移附件不是默认任务上下文；当前顺序、检查和后续缺口只见 [当前交接](../../project/worklines/mv_migration/scope.md)。临时报告、截图和录屏只进入ignored build/或构建产物。
