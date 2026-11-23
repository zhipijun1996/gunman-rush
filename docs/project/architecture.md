# 重做版运行架构

`production/project.godot` 定义独立资源根目录。房间宿主以 schema 3 文档启动。世界进度将由采用它的正式游戏入口持有；当前单房可独立运行并接受显式存储。根工程的玩家存档、世界编译产物和实验目录只服务冻结试玩。

| 所有者 | 输入与结果 |
| --- | --- |
| 内容生产者 / sync.py / WorldContentCatalog | 网页导出有版本的设计定义；开发期校验后原子切换锁，运行时离线读取同一包。错误更新保留旧锁，未绑定对象不能静默实例化 |
| WorldContentRoomBridge | schema 3 的实例引用稳定物种与掉币档案；不从网页轮廓生成碰撞，不限制候选敌群的数量或组合。逐只金币交给现有掉落事务，候选总额仅供预算复核 |
| WorldRoomDocument / WorldElementCatalog | 解析带版本的稳定定义和实例，校验引用、字段、端口类型、作用域和连线；装配前报告错误 |
| WorldRoomAssembly / TerrainComposer | 同一份几何生成碰撞和绘制；按明确的材质生成邻接、边界与接缝 |
| PlayerMotor / EnemyFactory / FrameDamagePolicy | 控制器消费输入，物种实例拥有行为与生命，伤害请求经统一仲裁 |
| WorldElementRuntime | 校验发送者与接收者后提出成组变化；持久状态写入成功后一起作用于房内节点。恢复时不重放命中 |
| OrdinaryRoomSession / WorldServices | 将被击败的实例与可拾取金币写入同一账本，拾取只入账一次。机关、金币及生命状态的存储由所属会话管理 |
| EquipmentCatalog / EquipmentRuntime | 永久 ID 连接来源、数值与装配界面。射击记录攻击包参数，装备效果由正式角色、目标和房间碰撞驱动 |
| 视听消费者 | 射击、受击、共鸣回复、开门和收币消费实际事件。特效与声音不能写回掉落或机关状态 |

新增机关扩充行为合同、定义及对象页；新增普通房只提交房间数据并挂到共享宿主。完整代码导航见[模块导航](module_map.md)，原架构说明保存在[冻结版本](https://github.com/zhipijun1996/gunman-rush/blob/4f2bb5e41573e930603789c64b52a0c15a6a3dc4/docs/project/architecture.md)。

世界拓扑、剧情和经济的设计定义由[网页内容通道](../data/world/content_channel.md)持有；游戏持有真实地形、敌人行为与实例、效果实现、存档和事务。网页审核存档不进入游戏。已接入单房的保存身份包含房间文档和内容包哈希；跨内容版本的存档迁移仍由正式世界宿主显式实现，导入器不替玩家迁移进度。
