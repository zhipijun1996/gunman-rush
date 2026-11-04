# ITEM-V5-01：表格72件道具

用户指令：实现附件《道具v5.xlsx》里的道具。基线main为879b39eaa869be70cb799dedd1bb6ffc35e0b92f；分支feature/item-v5-catalog，不自动合并。附件原文、SHA、72有效／21删除、16件可成长、价格／负荷和原子参数须可追溯。用户已确认按03表H当前建议值实施，仍为配置候选，01文字不一致项单列；不是玩家平衡认可。

目标：72件具有正式消费者的效果、重复升Lv1→2→3不增加负荷、满级排池、前置过滤、主动装备输入、破损维修、共享盾／锁装／禁疗／一次性换血、时间域、召唤与派生归因；保持本局钱包／永久音符独立及原物理、伤害、交易、Run/Stage/Actor epoch。正常装备不补HP／次数／共鸣，心契唯一明确例外有一次性收据。删除21项不入新正式池，历史资源保留。

Skills：game-quality-gate统筹，ability-creator、weapon-creator负责实际能力与武器消费者，project-integration负责PR交付，gameplay-reviewer独审；沿现有Harness，不建万能事件总线或重做无关美术。实体设备与用户认可单列未验。

## 写集所有权

- catalog：附件无损快照／导入器、config/items_v5.json、ItemCatalogV5、ItemDefinition/ItemEffectComponent。字段合同见下。
- inventory：RunItemInstance／RunInventory／EquipmentService／BuildState、成长／状态／锁装；不写catalog定义及controller。
- combat：武器和弹体消费者、scripts/items/v5/item_combat_effects.gd；不写controller/app及其他效果模块。
- defense_time：防御、护盾、治疗、停时模块及其最小既有消费者；不写controller/app，涉及所有权须先协调。
- actives：主动投具／无人机模块与其专用实体；不写controller/app/input。
- economy：经济／磁吸／维修／商店刷新模块、ShopService；不写app/input。
- root：PlayerController、DemoApp、输入／菜单、公共ItemRuntime、正式投放、公共资源接口、文档／Harness／质量／集成及验收。

## 最小共享接口（实现时保持精确，变更先通知root）

定义：ItemDefinition新增 `catalog_version:int=0`、`max_level:int=1`、`shop_price:int=0`、`effect_parameters:Dictionary={}`、`parameters_for_level(level:int)->Dictionary`。`*_by_level`按等级取值并去后缀；其它键保留。稳定ID严格用表内B03/P06/G01/N01等。效果组件支持真实参数而非强制空modifier。`ItemCatalogV5.all_items()->Array[ItemDefinition]`、`get_item(id:StringName)->ItemDefinition`。不把72个空实现注册成功。

持有：RunItemInstance新增 `level:int=1`、`effect_state:Dictionary={}`，copy深拷贝；RunInventory重复合法奖励原子提升同一实例等级，同source幂等并保原定义指纹；满级拒绝；状态修改有明确方法与收据，跨图不清。BuildState效果源带level和parameters，仅已装备实例参与。

模块均RefCounted，`configure(host:RefCounted)`保存WeakRef，避免循环类型。公共host为root的ItemRuntime，PlayerController字段`item_runtime:RefCounted`。模块按需调用以下实际方法（缺项通知root）：

- `actor()->PlayerController`, `build()->BuildState`, `effect(id:StringName)->Dictionary`（仅已装备且未损坏；已按等级解析），`has(id)->bool`, `instance(id)->RunItemInstance`。
- `state(id)->Dictionary`／`patch_state(id,patch:Dictionary,receipt:StringName=&"")->bool`：实例持久状态快照／提交；不能卸装重置计数。
- `map_key()->StringName`, `now()->float`：唯一地图实例／不含菜单与失焦的真实活动秒。
- `base_damage()->float`：当前武器的D，不包含道具加成；`skill_cost(base:float)->float`：P02折扣，最低15。
- `targets(point:Vector2,radius:float)->Array[Dictionary]`：真实shape查询，按距离／ID稳定排序，每项node:Node2D和receiver:Damageable；`clear_line(a,b)->bool`。
- `deal(receiver:Damageable,amount:float,key:StringName,origin:StringName)->bool`：amount为绝对伤害、原FrameDamagePolicy提交、副伤永不走主攻回能／再派生。
- `burst(point:Vector2,radius:float,ratio:float,origin:StringName,receipt:StringName)->int`：D倍率、真实LOS与逐敌幂等；`cue(kind:StringName,point:Vector2,detail:Dictionary={})`真实事件的轻量机械表现。
- `spend_energy(base_cost:float,receipt:StringName)->bool`／`grant_energy(amount:float,receipt:StringName)->float`，遵循原账本与容量；`heal(amount:float,receipt:StringName)->bool`经过禁疗；`barrier_grant(amount:int,receipt:StringName)->int`共享上限3。
- `world_root()->Node2D`, `is_live()->bool`, `selected_active()->StringName`。地图切换实体清理但owned状态保留，真正run结束重置。

回调为显式方法，不广播任意事件：`sync()`、`advance(real_delta,world_delta)`、`map_entered(key)`、`on_hit(event:Dictionary)`、`on_damage(event:Dictionary)`、`on_energy_spent(amount,receipt)`、`activate(id,direction)->Dictionary`（按需）。hit含session/packet/shot/airborne/skill/receiver/point/direction/amount/weapon_id/tier；只消费已提交且当前epoch命中。root归属controller接线。伤害/能量接口的具体插点由各模块先提出最小方案，禁止重复接同一回调。

## 证据与交付

原Harness的最小必要专项、正式平原／森林消费者、组合反例、键鼠／手柄映射／触屏原生GUI、真实Godot操作片和可玩交付。全武器15节点兼容、72定义逐件可证伪检查；模拟单元不冒充自然通关。技术ACCEPT与用户／设备／平衡认可分开。
