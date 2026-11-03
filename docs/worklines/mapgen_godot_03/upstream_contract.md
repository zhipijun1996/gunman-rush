# 给 map-gen / map-edit 的宿主约束

以下分实测和后续要求，范围是锁定0.3.0候选＋模块1.1.0的受控入口，不是完整地图开放。

## 已实测的宿主路径

主游戏固定Godot4.7.2 Standard custom gunman_sd1，使用同锁导出模板。原15个addons/mapgen脚本不改；不把solver、Python或原参考App移入业务代码。输入是本地`res://resources/mapgen/module-pack-1.1.0.zip`，原SHA5ad5a7871941b2c1ffa759b18f7b1e80f2fe7e571b72f95d1e0ef26031f08723；原DataJSON解析request/config，保持整数seed与binary64语义，不先用Godot原JSON解析器处理算法请求。

公开包API是ModuleArchive.open_zip→GenerationJob.create/advance/progress/is_done/result/cancel；没有另一个同步generate入口，禁止复制求解器。宿主每process tick调用一次advance(128)，同线程调用不操作SceneTree；原模块节点只由宿主主线程现有LevelRuntime创建。budget是操作数，不是毫秒。当前包原验证和主项目实际调用均已在4.7.2运行，不继承上游4.6.3证据。

宿主Provider文件入口仍是9参数load_level(request,map,content,ids,spawn,source_sha,bindings,source_record,binding_id)，内存入口是load_generated_level(request,result,ids,spawn,bindings,provenance,binding_id)。两者只进一个内部Plan转换器。上游旧六参数示例不能直接复制，也不能给内存结果伪造map.json字节SHA。原request_fingerprint一字不改；该候选930001实得9a5c671e93a6cbe2a11dde3e54fe2e722810bb5745d694f1b59921f6444639d7。

坐标契约严格要求已物化、owned_rectangle_pixels、x-right/y-down、block128；宿主只平移origin_blocks*128，不再应用mirror或source_affine。INPUT/OUTPUT/INOUT为唯一公共权限词汇；宿主当前连接仅INOUT/ROCK，合法单向/ONE_WAY连接不冒称支持。M35只装一个原模块，三个真实邻居没有装配；不造地板、封口或邻居替身。

## 来源、取消与恢复

安装锁记录发行head93c5221a9708d079c2864f3c14b415e81bb5de07、包内实际source508b558e8a9925862e8a26c20fea008b9a772007、ZIP SHA9ea87854c96cf7c2189b4c6ad25a8056454a3150721bead79c335aca8678acd0、全部15文件及真实模块包/请求/配置SHA。完整候选ZIP、Python参考包、测试包和开发证据不进PCK；仅明确的一份模块ZIP允许导出，实际PCK读回而不依赖文件名猜测。

宿主opaque job handle绑定真实owner WeakRef、实际lifetime对象及run/stage/actor token和当前请求serial；每tick/take/commit重验。取消、换请求、actor变更、离场后结果拒绝，节点装配与提交分开；需要physics的M35在Actor inactive期间等真实碰撞注册、安全准入，失败丢弃provisional Stage。无后台SceneTree写入。cancel只能在原同步原子调用之间执行，不能中断已经运行的open_zip或advance。

生成指纹、完整map/content数据身份、所选scope＋实际bindings＋宿主adapter的装载身份分别记录；timing只进原result receipt，不改变恢复身份。生成装载adapter升/2以隔离旧错误初始定位实现；旧v1状态明确拒绝，Frozen旧身份不变，不修改永久存档schema。

## 已知限制与建议（未实现）

- 原archive会同步核657成员hash并解析232份JSON；原生预载约3秒，128单位advance实际出现约0.2秒以上长调用，4096可超过4秒。此接口尚无硬16ms保证。Web开启线程/专用音频线程不代表算法已运行在worker。要支持活动游戏中的平滑生成，建议上游细分预载/prepare/export/result复制的原子工作，提供可度量的checkpoint；线程方案需另验，当前不声明已支持。
- 当前time_limit_seconds包含宿主暂停/帧间等待；不要为掩盖慢帧放宽90秒配置。长暂停应由宿主取消并明确重建，后续可由上游定义主动CPU预算与墙钟预算的区别。
- 原输出GDScript点赋值产生StringName文本键（如anchors.start_departure.validation/content.coordinate_frame）。宿主只在内存边界复制键为String，保scalar类型值与原结果；建议SDK后续直接提供String键的data-only字典。不能JSON往返来“归一化”数值或重写指纹。
- 普通请求已从真实controller、effective tuning、maximum_jumps、装备/武器反冲路径及实际Rectangle碰撞投影；conformance四能力请求仅供一致性，不授予grapple。当前协议缺量化动作距离/时序、武器特异运动、资源可用性与能力获取/区域路线状态；nominal tags不是物理通关证明。任意seed/controller布局还没有自动的安全出生/内容完整准入，固定selection/binding不能作为通用整图spawn策略。
- M24/idea-orbit-choice-001的reward center[340,18]仍在unused TOP-C seal[256,0,128,32]内。需要map-edit修正模块内容与端口/奖励占地，map-gen加入物理内容有效性约束并明确失败；不能只依据图连通/语义PASS开放整图。原内容不在宿主偷偷挪奖励/删封口。

## 第二轮接入清单

从受控切片到整图：真实spawn/Boss绑定、所有合法连接权限与ONE_WAY、完整机制/敌人/奖励服务映射、区域选择与能力获取状态、全图边界、返回/保存/重载/任意phase、真实Motor路线与M24修复。复用既有Actor/Reward/Item注册表，不建平行权威，不把旧Manifest全部强塞v2。

从当前加载阶段调用到正式运行时：算法包稳定发行/可取消预载与细粒度调度、能力快照协议补齐、安全初始点解析策略、跨任务/场景worker若采用需独立证明、Web/手机长帧与内存实测。首轮参考包后续只按同协议换锁输入，不另设计宿主协议。M35两台实际搭乘、暂停/恢复/重新装载相位与邻接C008仍单列未覆盖；不因Provider/节点运动PASS签整图可玩。
