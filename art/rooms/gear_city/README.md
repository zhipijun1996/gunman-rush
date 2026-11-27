# 齿轮工城

38 份正式房间位于 `production/rooms/world/G*.json`，包含交班值守室 G_IN01。G23 的水泵阀恢复 G22 载台。通过维护井进入 G07，检查机停机后可受击，击败后在场内确认首胜，再到 G08 工台领取攀壁装置。G08 高架另一端的闩锁打开通往 G04 的返程。

地形使用 gear_city 原生 32px 邻接地块。近景的检修台、管接、齿带、灯具取自 `art/world-art-v2/assets/pixel` 下同名图。运行资源为 `production/assets/scenery/gear_city`。远景分为车床大厅、泵廊和运输街，开放栈道后方的支架依真实平台位置绘制。运行 `python art/rooms/gear_city/build_backdrops.py` 可从原图重建。

使用 `bash tools/godot.sh --headless --path production --fixed-fps 60 --script res://tests/gear_city.gd` 重走泵、胜利、领 W、蹬墙及返程闩锁。通用正式房间回归还会逐门测量空间和接收点。
