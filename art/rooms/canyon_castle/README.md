# 风蚀峡谷与月冠古堡

下文记录 v27 的关卡构图与验证。请在[冻结版本](https://github.com/zhipijun1996/gunman-rush/tree/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b)复现旧房；区域像素母库和角色、机关素材继续供重做使用。

两区沿用各自正式 47 邻接 TileSet。天空、风向片、承石、断桥和轮架来自像素母库的 windswept_canyon 组；王冠窗、仪甲台、镜片、断层阳台和旗帜来自 moon_crown_castle 组。运行房通过各自 scenery 指定实际图层与承托位置。[原始区域像素件](../../world-art-v2/assets/pixel/) · [区域扩展件](../../world-art-v2/assets/pixel/v2/)

两只首领的透明母图由本轮 ImageGen 新绘。左侧石冠巡崖机以四足砂岩装甲、顶端风旗和铜轴承表现换面扫击；右侧月冠星仪守卫以月牙镜环、折扇和靛青仪袍指示扇射方向。裁切脚本按原图轮廓提取两只角色，缩至各自碰撞体的画面尺度。警示、核心开闭和攻击范围由运行时的同一攻击状态驱动。[透明母图](arena_guardians.webp) · [复现裁切](slice_guardians.py)
