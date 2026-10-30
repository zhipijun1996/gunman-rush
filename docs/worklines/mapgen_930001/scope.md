# MAPGEN-930001-01 · 固定交付地图接入

基线 main `840108da9ae91e412dc9f1d8a38ccdad0229bb11`；分支 `feature/mapgen-delivery-930001`。
本轮只消费 map-gen 0.1.0 / seed 930001，不移植生成器，不补 Route、不降低目标，不改 PlayerTuning。

root 负责 `scripts/mapgen/`（Boss binding 由 host_flow 实现）、`scenes/mapgen/`、`config/mapgen_930001.json`、`third_party/mapgen/` 及任务/交接。physical_tests 负责独立测试 runner；review 只读审查，报告单独保存。Godot 始终由 root 独占运行。

采用仓库 project-integration、game-quality-gate、level-module-creator；已有 Boss 仅适配现有正式系统。当前属于工程接入和物理诊断，用户与设备认可不由 AI 代签。

交付 ZIP 来自用户指定提交 23047fa0d32c1e7e7c5bb7b2d93b76a5a9d4b12f，SHA-256 `1c190a0a3918ece39e3a3aac7d35dbc855b9f4c87ebafbaa11f32c820a333b25`。解压前核 SHA，原始目录运行包内 verify_delivery.py。third_party/mapgen/.gdignore 阻止编辑器在原包内写入导入产物；运行脚本显式预载，不实例化原场景地形。

构建次序：核 manifest 全部文件 → 物化内容在 ready 前注入独立派生入口 → 唯一地形 → 全部实体封口 → 原生 bind_player。只应用 Block 实例平移，不重做镜像或来源偏移。原生椭圆安装器遗漏 ellipse_x_sign，由独立适配定义修复；其余机制沿原模块行为。

出生候选配置 M01 (96,206)，将以真实完整玩家落地/射击开铃/跨 exit→M02.R 确认。开发入口只在新玩家出生时授予 scoped routes 所需的原生 grapple，基础 jump/shot_recoil 及所有物理参数沿主游戏；不在接口授予能力或资源。此入口为开发地图，不替换正式两区进度解锁。

Boss 采用当前正式 windkeeper_storm，原生 WindkeeperArena 的旧支撑坐标与 M40 不兼容，因此从实际物化平台推导站点，仅在第三阶段更换原生断桥地形，不复制初始地形。战胜后本局结算显示已有钱包并结束 lifetime，Enter 返回主游戏标题，F5 新一局；初始封闭 exit 保持封闭，不伪造战后连接。

验收分栏：交付静态核验、运行实体清点、真实 Motor 局部碰撞扫掠、带显式初态 fixture 的交互/战斗、连续自然游玩。任一局部结果不得升级为全图通关。完整自然主路、六奖励往返、Boss 全战和不同相位若失败/未执行，保留具体 ID/机制/原日志。
