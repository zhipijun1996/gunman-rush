# HIGH-DENSITY-TERRAIN-03 · 快速方向实验

基线0c1d1e5，分支art/high-density-terrain-study。用户要求提升tile密度、保留背景和角色细节，快速出实机图，不运行CI。本轮使用art-director/visual-director作来源与合屏审查；不作全区定稿或玩家认可。

## 结果与边界

原生32px/32wu TileSet，47原邻接坐标，实际TileMap scale1；边界与核心共享世界连续材质。原生图像nearest整理并生成边缘数据，不用代码凭空画替代素材。只换Lab的solid和one-way顶沿；危险物/移动平台保持原生，未完成全游戏统一。1280×720、1wu采样、整数显示缩放只是提案。默认入口和project设置未修改。

最终20张实际Godot GUI定位冻结图，同五窗口、四版本；退出0，完成标记及日志见[capture.log](capture.log)，Seed/Manifest和镜头见[capture.json](capture.json)。[像素度量](density_measurements.json)说明角色建筑细节保留、岩面不再锁2×2，但不能证明美术高级感。[源绑定和生成来源](source_binding.json)保留精确修订Prompt、原图/派生物SHA与参考SHA。image_gen两次调用，模型/价格未公开；首轮Prompt未留存，不伪造。第二轮请求1024，实际1254，原始文件完整保存。

暖灯和收低对比让视觉主次改善。独立只读代理实际看前轮六张、最终三张，确认更克制；仍有重复斜纹/矩形岩墙、铜绿弱，不能签地区身份或定稿。建议后续使用侵蚀轮廓、少量嵌岩铜结构与受光关系建立来历，停止堆碎纹。

## 失败与未验

第一张通用碎石被用户否定，原件留artifact和build，不进入runtime。X11首轮实际失败见[failed-x11.log](failed-x11.log)；重启display重新捕获。r2镜像万花筒/侧面绿框留build，已改无镜像重复和仅顶部草沿。之后.72对比仍太重，最终.32重新完整捕获。未跑CI/Harness、连续运动、通关、Web发布、真机性能；截图查看器不是试玩，不替换旧网站。没有把离线builder的Image.load_from_file用于游戏runtime，实际runtime使用预导入PNG；未做导出验收。

恢复：`bash tools/godot.sh --headless --path . --script tools/build_high_density_terrain.gd`，必要import后 `bash tools/godot.sh --path . scenes/dev/high_density_terrain_study.tscn`。采图追加 `-- --capture --output=res://build/<fresh>`，需要可用X11。下一步等待用户判断这条密度路线，再决定是否设计结构性样板，不批量迁移当前通用岩纹。
