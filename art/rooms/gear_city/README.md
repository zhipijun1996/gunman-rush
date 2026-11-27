# 齿轮工城

下文记录 v27 的关卡构图与验证。请在[冻结版本](https://github.com/zhipijun1996/gunman-rush/tree/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b)复现旧房；区域像素母库和角色、机关素材继续供重做使用。

38 份正式房间位于 `production/rooms/world/G*.json`，包含交班值守室 G_IN01。G23 的水泵阀恢复 G22 载台。通过维护井进入 G07，检查机停机后可受击，击败后在场内确认首胜，再到 G08 工台领取攀壁装置。G08 高架另一端的闩锁打开通往 G04 的返程。

地形使用 gear_city 原生 32px 邻接地块。近景的检修台、管接、齿带、灯具取自 `art/world-art-v2/assets/pixel` 下同名图。运行资源为 `production/assets/scenery/gear_city`。远景分为车床大厅、泵廊和运输街，开放栈道后方的支架依真实平台位置绘制。现行 `build_backdrops.py` 可重建三区背景和捷径门体。旧房逐台支架的烘焙配方在[冻结脚本](https://github.com/zhipijun1996/gunman-rush/blob/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b/art/rooms/gear_city/build_backdrops.py)。

使用 `bash tools/godot.sh --headless --path production --fixed-fps 60 --script res://tests/gear_city.gd` 重走泵、胜利、领 W、蹬墙及返程闩锁。通用正式房间回归还会逐门测量空间和接收点。
