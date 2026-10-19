# 冻结候选最终实机采集

运行字节与source `32200d04fe233bda16cf50f678aabee51a9715e5` 一致；相同布局/镜头1280×720。实际执行 `DISPLAY=:99 python3 tools/run_style_exploration_tests.py --capture --output build/style_exploration/final_capture` 退出0。

9环境×4seed=36张场景、9张actual region palette目录，共45张，所有原生日志exit0且无脚本/着色器/退出资源错误。每图都有原始.json收据明确 `camera_only_art_capture` 和 `traversal_claim=false`。镜头定位不代表玩家到达；真实往返见runtime_v2及本次runtime_report。

4/5的三个地区是相同TileSet边界拓扑的调色profile与独立新景层/道具，其他3风格仅平原。目录已应用相同shader，因此Cavern不再错误显示所有紫源；这仍不是9套新绘制地形。

portable_index.json保留所有原图SHA；receipt内绝对路径为当时执行器真实输出，index提供仓库相对可携带路径。summary.json中log旧build路径同属原命令事实，原log文件字节已一起归档。
