# 田埂反冲教学

从西田埂望去，视线沿田野水道到达对岸的钟架。主路横过灌溉断口，低处两条通道分别切进土层和石渠。实际可走轮廓见 [P02.json](../../../production/rooms/world/P02.json)，[剖面](section.png)显示大形体和退台。

[构图底稿](composition-guide.png)随真实断口和平台高度绘制。以底稿和平原既有美术为参照，用 ImageGen 绘制单幅灌溉田野远景。[远景原稿](irrigation_panorama_master.webp)保留原画；运行版本按 1392 × 662 像素、144 色调色板导出为无损 WebP。天空、田间风车和犁沟共用一个透视关系。远景独立随镜头视差移动，近处能落脚的田埂和石渠固定于世界坐标。

西涵木楣、根系和东涵的砌石取自[涵壁原画](bank-walls.webp)。[剖面绘制脚本](build_bank_art.py)读取房间碰撞轮廓，保留 TileSet 草沿，把土层和石材限制在承重体内。装有 Pillow 和 NumPy 时，从仓库根目录运行 `python3 art/rooms/P02/build_bank_art.py --out /tmp/p02-art` 可重建三张墙体与覆面。草帘采用[芦苇母片](reed-screen-master.webp)，钟架沿用平原原生三铃。五件运行素材的尺寸、用途与校验值见[源件清单](bank-art.json)。
