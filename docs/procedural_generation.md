# 程序生成预留

M4 前只设计，不实现。先从固定挑战提取 5–8 个已验证模块，入口出口含位置、可接受速度范围、跳跃/射击资源最低要求、落点安全窗口。

RoomDefinition：id、version、尺寸、ports、difficulty、tags、预计时间、required_abilities、入口资源约束、补充点、检查点、机关周期与相位约束。模块选择控制难度起伏，不连续抽极难组合；失败尝试有上限并回退到已验证路线。

验证分层：几何连接 → 动作状态轨迹搜索 → 动态时间窗 → 自动批量回放 → 真人触屏。A* 只检查空间，不能保证通关。验证器状态含位置、速度、跳跃/射击资源、冷却及机关相位。

RunManifest 保存 seed、generator_version、content_manifest_hash、physics_config_hash、能力配置、房间顺序与相位。旧内容变化后同 Seed 不保证重现，回放优先使用完整 manifest。

固定与生成模式都输出 LevelDefinition；玩家不认识生成器。新增能力时按标签和版本筛选适配模块，再重新验证可达性。
