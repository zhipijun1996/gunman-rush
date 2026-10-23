# TERRAIN-DENSITY-04 · 同母版粗细与47格实验

基线7f332fff1a51fb7439688f1cfb79252d2f6e498f，分支art/authored-terrain-density-study。沿用art-director与visual-director，用户已同意快速实机实验、不跑CI。用户尚未选择最终粗/细标准，本轮只是proposed样板，不替代默认入口或共享母版。

生成两次：第一张未保持原切片布局且绿包边过重，被拒并留build及artifact。第二张是同材质完整外框+洞口母版，实际1254方图；Godot离线工具按已声明crop取外边、四内角，nearest整理成原source_regions语义，47格×三种草沿。细版原生32px/32wu；同细版降采样得到粗版16px/32wu。不是把上一轮通用大岩纹盖到47格。每格连接和全局艺术认可分开，不能因141格资源存在签所有接缝合格。

最终五镜头×四版本20张真实Godot GUI定位静态图：reference原地形+暖光、terrain_coarse只粗地形且人物细、coarse全世界2wu、fine全世界1wu。暖光灯位/颜色/.85强度/遮光与小bloom固定，代码逐镜头断言记录一致；粗世界版最终光照颗粒也降至2px。日志[capture.log](capture.log)退出0、完成20且无Shader/Script/ERROR。源绑定/精确Prompt/参考及原图SHA见[source_binding.json](source_binding.json)，仅动态导入不代表导出验收。素材模型和价格unknown，不伪造。

实际[度量](verification.json)：coarse源恰好fine奇数位置2×降采样；tile-only控制的屋窗和人物ROI与fine逐像素相同；灯记录一致；真实TileSet141格。只证明隔离和资源组织，不证明高级感。[独审](independent_review.md)支持继续细版路线，同时保留草沿厚/重复、石包边与岩体体量弱，单向台语汇仍不同；不签用户、动态、设备或全区认可。

首轮真实GPU有shader global non-constant编译错误，白边图虽完成15但失败。原错误保留[failed-shader.log](failed-shader.log)与build原shader。修成局部参数后r2与最终完整重采，不追认失败。只跑离线builder、必要editor import与真实截图，没有CI/Harness、Web发布、通关或真机；截图查看器不是可玩站点。

运行：`bash tools/godot.sh --path . scenes/dev/authored_terrain_study.tscn`；重建`bash tools/godot.sh --headless --path . --script tools/build_authored_terrain.gd`。采图追加`-- --capture --output=res://build/<fresh>`，需可用X11。下一步由用户判断颗粒方向，再细化草沿节奏/亮边和单向平台；不批量扩产未定稿材料。
