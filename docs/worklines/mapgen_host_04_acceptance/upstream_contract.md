# 阶段A给map-gen / map-edit的具体反馈

SDK0.4.0、模块1.1.0、runtime-map/v2继续冻结，原18GD字节不改；本轮不混0.4.1。

实测：宿主只消费原SDK DATA结果，经共享selection→Provider→Plan→Stage→Runtime，SceneTree创建主线程；同一玩家/服务、同一碰撞与时钟/伤害权威。宿主job以实际owner/run/stage/actor lifetime守门，旧/重复/离图结果不能提交。已验模块DATA独立于job生命周期保留；每个PreparedLibrary/RNG/结果必须请求独立。宿主只处理装载、调度、采样、来源摘要，不复制求解器。

实测与限制：主Godot4.7.2及其原Web模板；FileAccess/ZIPReader从PCK读精确路径，唯一模块ZIP允许，Python/整个候选测试包/开发证据排除。当前合作式advance主线程运行；8ms软目标不能约束单单位/最终验证长段，取消要等主线程重新得到调度。浏览器软件GPU/全新context测试不签手机。新f547包与旧512c不能因同源码/长度就称同包。

建议给map-gen：

1. 当前库缓存通过私有Archive._json/_files实现只读保护，版本锁防漂移；请SDK提供公开、可验证、不可变的预载library借用接口，保持每请求prepare/RNG隔离和明确取消语义。后续修改须新版本+SHA，不在主仓偷改vendor。
2. 当前真实样本内growth+goal-aware-terminals占主要advance时间，catalog/module JSON占冷预载主要执行时间；请先在SDK内profile/优化这些路径和长工作单元，并交同请求/模块/结果身份对照，不把Web整段超时直接说算法失败。
3. 请提供分开I/O、hash、ZIP、JSON、有效搜索/验证/快照的公开profile与调度边界。现phase按advance入口计费，跨phase单位可能计入前一phase；不得把执行elapsed冒作独占CPU或残差全叫算法。
4. 当前仍无硬帧、后台线程或完整map可玩性保证。能力快照只能描述已有controller/tuning/shape/实际授予；示例grapple tag不授予能力，数值/动态能力/形状偏移等缺口仍要正式合同，不伪造旧Manifest字段。

建议给map-edit：既有0.4覆盖表来自旧f6同算法实际结果；本轮未改布局/内容、未扩机制，不能把source/cache收口当全表物理通过。继续用module_id/content_version/role/实际连接关联；不是M号。后续多端口body-staging/落脚和已使用Port的准入缺口单独处理，保原helpers/seals；本轮无B代码，不能删封口/平台或跳验证凑成功。

完整PCK/WASM加载与编译独占CPU、精确boot墙钟仍未分离；仅有历史自动/工具计时和带覆盖限制的Chromium PID累计CPU，不提供伪精度。宿主/SDK大段执行及整图入口迁移仍需后续明确任务。
