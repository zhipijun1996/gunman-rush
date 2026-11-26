# 区域机关五金

区域依照 `art/world-art-v2/region-catalog.json` 的顺序排列。原图 [bearings.png](bearings.png) 为本项目以已认可的 32px 地形与道具为参考生成的独立像素轴座母图，按从左到右、从上到下读取。16 个轴座各自使用区域结构，如木轭、藤结、菌褶、绞盘、冰晶和天文仪。烘焙按前景透明度和连通轮廓分离母图的摄影底。

[bake.py](bake.py) 从每区资产中选择原生顶饰、灯和危险饰件，从同区 47 邻接地形的实体及上表面取得承重面的纹理。五个区域依次从横坐标 0、24、56、84、116 开始，整张图为 148 × 36。构件的贴图切片、缩放和铺排由 [MechanismRegionArt](../../../production/game/presentation/world/mechanism_region_art.gd) 管理。普通房区域档案指向最终图集；预组共享成员的区域外观和功能状态。

在已安装 Pillow 的环境从仓库根目录运行 `python3 art/mechanisms/regional/bake.py`，再用项目锁定的 Godot 导入。共同黄铜构件从已有风铃门资产取得。
