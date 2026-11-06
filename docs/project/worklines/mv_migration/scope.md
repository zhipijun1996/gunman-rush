# 固定世界当前交接

## 基线与范围

唯一基线为PR137合入后的 `main@83a149558e670fc78a177d8f4662a0ec079b4cbf`。当前清理分支 `chore/mainline-context-convergence`；进度只见 [任务表](../../tasks.md)。本次开始时的其余57个旧PR及对应功能分支已关闭/删除，独有成果放弃，不再审计择取；基线内代码和素材按真实用途复用。Git历史未重写。

本阶段收敛管理、数据依赖与工具，不开发新世界运行时。运行事实见 [当前状态](../../current_state.md)，代码入口见 [模块导航](../../module_map.md)。

## 运行事实与依赖

- 入口仍是project.godot → DemoApp → 旧Plains/Forest Provider。PlayerMotor、战斗、工厂、表现、收据及存储可靠性可复用。
- LevelRequest/Plan仍以region/map为主，LevelRuntime绑定旧Stage/Assembler；RunSession仍清地图、Build和钱包。新房间身份、跨房入口及永久/周期边界未接入。
- 世界唯一输入、生成关系与按房查询见 [世界输入](../../../data/world/README.md)。使用 `python3 tools/world/room_context.py P-R03`，不全文加载大JSON。scene_ref仍是计划路径；v03派生依赖在证明生成等价前保留。
- 历史证据目录已删除；必要来源与测试输入由各消费者独立维护，不作为任务上下文前置。
- 实际部署分支 `prepared/mapgen-plains-home-9c5a54c99d13` 保留；线上build 9c5a54c99d13未替换。它只用于已有站点交付，不是开发基线。

## 验证与阻塞

清理已通过最小CI四项、文档/Skill导航、世界导入与按房查询，以及森林两套控制器夹具、Root Bell当前准入和平原遭遇专项；通用执行器与受影响Python回归通过。具体命令、覆盖及清理结果见 [PR138](https://github.com/zhipijun1996/gunman-rush/pull/138)。日常使用 `python3 tools/ci.py`，文档使用 `python3 tools/check_docs.py`，专项按任务选择。所有新日志、截图、录屏及报告写入忽略的build/或构建产物，交接只留结论、源码身份和可访问链接；本地build路径不保证跨会话存在。音频清单已在清理提交实读523个文件并输出build/audio_inventory。

保存验收保留当前版本的写入/读取、事务和损坏恢复；旧原型存档兼容不在目标内。

运行时阻塞：固定Provider、门台/进入侧、保存schema/content版本、休息周期及Q尚未实现。48件装备效果、价格及死亡金币政策待定。图状态检查不签收Godot实机、设备或完整美术/战斗。

## 下一动作：MV-RUNTIME-01

清理合入后从最新main开任务分支。先提取人工尺寸/门台/镜头/场景绑定及独立路线输入，证明合同生成等价后切换config/world权威与运行导出。先完成P-R03/P-R01/P-R06/P-R14闭环，再覆盖F-R04/F-R10、I-R05/I-R11、K-R16/K-R05、A-R04、S-R05。

接通真实门与进入侧落脚、镜头、永久/周期/挑战/动作状态；验证普通跨房不休息、危险失败回实际来侧、死亡保留永久、Q落地加2秒及危险过滤、唯一领取/购买幂等和存读档。完成代表样房真实运行后进入MV-WORLD-GRAYBOX-01的216房扩展。
