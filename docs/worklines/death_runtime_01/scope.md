# DEATH-RUNTIME-01

基点5d3303b78d4db374300d4a0266bde8eb1a6de5b2，运行基线b5c7bf65／公开9dd3a9a2ecd8。用户反馈比之前好很多，但大部分怪物死亡仍卡；本批保留现有死亡动画的画面、时长、轨迹和所有玩法/图声规则。

采用animation-vfx的实际身体/生命周期检查、game-quality-gate小修门槛和project-integration快速试玩路径。不新增内容方向或美术，不用降网格、抽帧、缩短动画代替优化。

候选涉及Pose、Ground、Flora、Skin：Hopper/Sentry/Fan同draw重复的死亡曲线/骨点/IK提前准备，Ground死亡绘制复用冻结的活体顶点前缀。缓存限定每个rig，按原始姿态、air、kind、bounds、texture、点/UV内容与既有只读anatomy数组身份失效；不保存Actor/Stage。只读数组不深冻Weights对象，沿现有canonical anatomy不可修改契约，不新增任意mask编辑能力。保原point相关操作、Vector2浮点运算及最终lerp顺序。旧静尸、拓扑、权重和Root准备已存在，不重复实现。

PlainsStageVisual仅共享本stage的同一无uniform掉落材质，各Sprite纹理/颜色独立；不采尚未完成Web A/B的额外预热。真实App掉落/重载与两个Skin测试override一起迁移。扩充原冻结Oracle的实际draw和缓存失效覆盖，保原所有断言、fixture与预算。候选先放外部，原frozen oracle与实际draw基准成立后再应用；后继技术绑定随实际源版本化，不放旧断言/预算。

死亡瞬间与播放期间用户均报告卡顿。原生固定时刻掉落像素/独立颜色/释放检查通过，原Web baseline首掉落确有LOOT lit/unlit编译绘制；candidate采集因worker观测超时未运行，失败保留，不将此当手机或自然死亡根因。Task保持review；当前技术／发布结果见results，设备与用户仍未验。
