# 当前交接：D066 镜头舒适性

分支feature/plains-branch-challenges，延续[PR36](https://github.com/zhipijun1996/gunman-rush/pull/36)，不合并；起点6aa6b75，运行实现提交0a10cf6。最新origin/main仍64ec8bb，保留已在开发分支完成的平原玩法；此前D065见[归档](handoff_plains_playful.md)。本轮仅表现和相机测试，不变角色速度/一跳/两射/反冲力度/慢时0.20/碰撞/地图/奖励。

## 实现

StageCameraRig增加42×72死区、48单位前瞻（旧130）、75单位/秒前瞻变化上限。前瞻不采样反冲；横纵分别0.28/0.36秒响应参数的精确临界阻尼。高速移动有角色可见边界保护，因此并非任何情况下都限制镜头绝对速度。切关与段回退利用Controller session清空动量并切到角色，无跨关快速扫镜。正式随机平原与RANDOM STAGE共用。家园固定镜头不改。详细参数与来源见[视觉手感](../visual_and_gamefeel.md#d066-镜头舒适性)。

## 验证与证据

Godot4.7.2.stable.official.ed1daf0bf，命令均使用tools/godot.sh并有超时。相机专项831断言/0失败、退出0；故意失败832/1、退出1。真实Motor弹道加向下射击，前35tick上移峰速旧808.85、新315.48世界单位/秒；这是固定轨迹对照，不能推广为全部动作或主观防晕结论。另测30/60/120Hz定目标一致、转向、慢时、边界、暂停、回退与反冲不驱动前瞻。

核心首次5809/1退出1：旧试玩测试停步后只等8帧，新阻尼此时镜头已移22.1但未达原30单位阈值。保留原30距离要求、允许30帧观察后，核心5809/0退出0。没有修改物理或删断言。源码检查无解析错误；编辑器退出0时附带ADB daemon连接提示，Android本轮未验证。文档33权威/90依赖、世界16候选区检查通过；归档链接初次两处失败已修正再检查通过。

Web导出退出0，本地包eaf48e49400f；Chromium移动模拟真实GUI、家园购买/刷新/出发/三指跳射与拾取存档9项通过、退出0，保留一条HTTP404，无脚本/Shader错误。已查看实际开火截图；不把截图当连续镜头舒适性验收。完整25专项32175/0、退出0，含新增相机831项。源码0a10cf6的线上[CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38057687342)已success：核心5809/0、25专项、Windows独立导出、Web导出与Pages部署全部通过，Android跳过。公开[试玩](https://zhipijun1996.github.io/gunman-rush/?v=ea7ae2c99906)的HTML/build-info与实际下载PCK一致，SHA256为ea7ae2c99906bcfe69ac58002976d4fa226d8700b2598259c03c6e480a267cb4，与CI构建日志一致。公开GUI未重复本地9项操作；后续证据文档提交不改变运行实现，也不声称该文档提交的CI已经完成。日志保存在忽略目录build/verification/camera-comfort；安装包不提交。Godot官方源码XML成功读取；官方HTML与Scroll Back文章HTTP403，未冒充已获取文章正文。

复核命令：`timeout 650 python3 tools/run_tests.py`；`timeout 900 python3 tools/run_plains_ten_tests.py`；`timeout 45 bash tools/godot.sh --headless --path . --script tests/camera_comfort_runner.gd`（加`-- --prove-failure`预期退出1）；`timeout 180 python3 tools/build.py web`；`timeout 270 python3 tools/verify_floating_touch_browser.py`；`python3 tools/check_docs.py`和`python3 tools/check_world_design.py`。成功项均退出0。

## 待验与下一步

CAMERA-COMFORT-01为awaiting-device：手机横屏实际跑停、反向、向下射击、连续攀升/坠落及环境回退仍需用户主观验收；自动测试不证明不晕。Windows实机/手柄、Android与iPhone设备本轮未验证。下一步按真实反馈调整死区/阻尼，同时继续D065待办的折返/汇合编排，不因镜头修改重新调低人物速度。
