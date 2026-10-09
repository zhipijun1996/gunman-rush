# 模块化生成与内容复现

正式小关地图随机是产品设计；实现推迟P5（GEN-01），先通过固定新伤害/路线/Boss链与LEVEL-02手机验收。P4缩短3关固定测试不冒充随机或正式10关。

LevelGenerator.generate(BiomeDefinition,StageTypeDefinition,capability_snapshot,map_seed)输出LevelDefinition+StageManifest；类型规则不写进通用Loader。先5–8个验证模块，RoomDefinition记录id/version、尺寸/ports、难度/战斗/资源标签、动作入口速度与跳跃/射击约束、安全落点/SegmentAnchor、危险相位/补给/奖励对象稳定ID。

验证：几何连接→实际动作轨迹/资源搜索→动态时间窗/敌人攻击/安全出生→批量回放→真人触屏。状态含位置、normal/recoil速度、Health、各动作次数、冷却、机关相位与能力快照；正式精力用途未定，不假设每条路线必需慢时。能力/武器修改后重新筛模块与验证，撤销能力不能产生无可达出口。

生成重试有可配置次数上限，失败回退同主题/类型且能力兼容的已验证保底图；没有保底则显式报告不兼容，不无限循环或暗降验收标准。关卡类型奖励/两个出口/10关Boss规则在生成后统一验证。

独立map/route/reward/shop流，增加奖励抽样不能改变地图；完整版本化RunManifest字段与重放语义以run_and_routes为准。除了Seed记录实际房间/端口/对象配置/初始相位/路线选择/奖励候选与领取/商店报价/成交、算法版本、内容/物理hash与每关能力快照。旧版本内容不可用明确失败，不能重新随机伪装重放。

Boss地图不是无约束随机：固定核心/躲避区，入口与经验证外围随机；可影响战斗的布局从匹配Boss攻击模板池选择，Boss阶段/攻击流不共享map RNG。固定和生成地图实例化相同世界对象与DamagePolicy，玩家不认识生成器。
