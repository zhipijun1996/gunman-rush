# 会话交接

2026-10-10 UTC。分支 **feature/dynamic-platforming-modules**，从干净feature/platforming-module-lab@3c0ca91创建。重新fetch origin/main=64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226，PR21仍OPEN；本轮叠加其上，未自动合并/强推。前轮四静态模块/1211测试证据见[历史交接](archive/handoff_static_module_lab.md)。

## 实现范围

GEN-MODULES-01第二批：timed_gallery单往返锯轮、固定观察等待台；moving_transfer两岸固定台、抬高40px的单平台、端点停靠。两个模块是固定灰盒样片，未接入随机生成器/CameraRig。主菜单MODULE LAB扩为六按钮单行，避免第二排遮住下降入口。使用原创几何、锯轮图形/轨迹/操作提示，没有复制原作地图或素材。

ModuleSawDefinition/ModuleMovingPlatformDefinition配置轨迹、周期、初始相位（0≤phase<1），PlatformingModule.clock按游戏delta独立推进。动态实例与Definition深拷贝隔离；显式RETRY才重建实例/phase。FrameDamagePolicy处理完整身体相对扫掠ENVIRONMENT，actor_epoch变化重建接触基线；runtime_source_id限定模块实例，避免多个同类对象去重冲突。world_static_dangers仅实际静态接触，world_dangers另含锯轮全运动包络用于安全点验证，不能整个包络变伤害。

AnimatableBody2D平台由引擎碰撞携带，经现有Motor唯一move_and_slide；没有直接移动玩家或添加第二位移入口，未修改调参JSON。入口/出口固定岸与安全锚点全身体+8px余量避开所有危险/平台运动包络；摆渡入口声明至少一跳并实际检查剩余/能力。两端口任意相位安全，不限制到达时机，离开等待区要观察可行窗口；动态initialphase属于模块内容定义，未来Manifest必须保存，本轮没有生成Manifest重放证据。

## 检查、故障与修复

`bash tools/godot.sh --version`实际4.7.2.stable.official.ed1daf0bf Standard，导入退出0无脚本错误。`python3 tools/check_docs.py`29必需文档/39依赖、退出0；`git diff --check`退出0。网络命令20秒、导入90秒、导出180秒；物理新增四phase真实轨迹实测约一分钟，整套测试上限由180明确调整为240秒以容纳新增组/较慢CI，失败仍非零退出，不删断言。

首次独立动态物理测试112断言出现3失败：phase0.75仅以锯轮位置较高作为出发条件却赶上回落，改为实际观察向上离开的窗口；摆渡定义声明1跳但入口min_jumps遗漏使禁用/耗尽跳跃仍被接受，补入口min_jumps=1。没有降低无损/无慢时验收。初始平台与岸同高可直接走上，制作时抬高40px使1跳需求有实际几何依据。一次计时包装尝试调用不存在/usr/bin/time退出127没有运行测试，改用Python monotonic/subprocess并保留有界超时。最终实际结果另记录下方。

独立动态练习场41断言/0失败、退出0：真实锯轮接触扣1HP且安全回段、相位与补给保留、实际动态位置推进、暂停同时冻结玩家/锯轮/平台/冷却、Engine0.25倍率同步世界/伤害保护时钟、重试新实例与致命Home/旧token取消。初次慢时测试混入改变time_scale前一帧造成2个测试时间窗口失败，等待已完成物理帧后重新测量通过；生产逻辑未改，保留精确倍率标准。

本地Web与Windows独立导出均退出0。首次六模块Chromium触屏模拟9项实际通过（pack feb91e354099，早于入口min_jumps修复，不能称最终包验证）；实际查看节拍回廊与摆渡动态截图。最终Web重新导出以包含入口修复，公开发布与验证结果另记录下方。不是Android/iPhone真机或Safari/Windows设备证据，本轮不生成新APK。

## 未验与下一任务

GEN-MODULES-01整体仍in_progress：六样片分批实现，square_loop/boss_approach仍未制作。下一批先环庭双路（两路均有合法返回/汇合），再战前缓冲廊与既有Boss固定核心的外围边界，保留金奖励一次与同帧死亡政策。完整GEN-LAYOUT仍依赖GEN-MODULES和LEVEL-02详细设备证据；尚无横纵方形完整随机小关、难度预算、CameraRig或生成Manifest重放。不能用单样片初始phase验证冒充全图Seed复现。

Android/iPhone实际触控/手感/性能、Safari、Windows实机和实体手柄各自待验。Q001–Q013待决策，D041暂定曲线；SaveService/永久经济/剧情/Steam无新增。当前Cloud状态spec66 connected/observations_current=true，但network_policy.state=unknown，不声称策略已enforced；正常有界Git/gh网络调用成功，没有读取/输出凭据或改权限。

复现：`python3 tools/check_docs.py`、`python3 tools/run_tests.py`、`python3 tools/build.py web`、`python3 tools/build.py windows`、`python3 tools/verify_module_lab_browser.py URL`。最终套件、提交、PR与部署证据随后追加；不假装未完成验证已通过。

独立最终动态模块 `tests/dynamic_module_tests.gd` 实际114断言/0失败，47.27秒，退出0；两模块各四个配置初始相位，以真实输入、完整身体扫掠和真实引擎携带完成路径，未传送通过。四个phase样本不是所有连续相位/任意参数的数学证明；多平台/竖向变体/额外机关组合仍需另验。完整套件结果待实际报告。

最终本地Web包d0f5e1543989（包含入口修复），`python3 tools/verify_module_lab_browser.py`实际退出0、9项通过：六模块独立实际几何、触屏x118.8→227.4、平台真实位置推进、暂停动态与时钟冻结、重试/恢复/确认Home。已查看实际渲染截图。日志保留单资源404（未确认具体请求目标），无脚本/页面/Shader错误；不是手机真机验收。Windows独立导出退出0。

最终整套 `python3 tools/run_tests.py` 实际 **1366断言/0失败、退出0**：原1211完整保留，新增动态114与练习场41。导入无SCRIPT/Parse错误。当前技术回归不推定所有phase/未来组合/手机设备通过；GEN-MODULES仍in_progress，剩下环庭双路与战前缓冲廊。


## 提交与评审

实现提交 **a7eee46**；[PR #22](https://github.com/zhipijun1996/gunman-rush/pull/22) OPEN，base feature/platforming-module-lab，依赖PR21及此前未合并链；不自动合并。实现文档CI38013550563 success，推送Godot CI38013550616与PR Godot CI38013571021实际结果另记录下方。最终HEAD为交接文档提交，不能把实现CI说成后续文档提交已完成的CI。

远端查询中一次gh返回HTTP401 Bad credentials，随后正常gh auth status/公共API及同一gh调用恢复，不更改或读取凭据。Cloud重查spec67 observations_current=true且network_policy.state=enforced；与启动spec66 unknown分别记录，不倒推初始已enforced。CI轮询每次watch上限55秒，超时124只是轮询窗口结束，不表示CI失败，后续读取真实状态。


## 远端实际验证与发布

实现a7eee46的[推送Godot CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38013550616) **success**：完整日志实际1366/0，Windows/Web导出分别success，Pages部署success。独立[PR Godot CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38013571021) **success**（core/Web通过，PR事件不部署）。Android job两者均skipped，不生成或声称新APK。

公开build-info实际 **9d42f33c73be**；本地d0f5e1543989与远端摘要分别记录，不把不同环境的包当同一个。试玩：[六模块MODULE LAB](https://zhipijun1996.github.io/gunman-rush/?v=9d42f33c73be)。进入MODULE LAB选择TIMED GALLERY（观察锯轮向上离开再穿过）或MOVING TRANSFER（等平台靠岸、跳上、站稳随行、走到岸边）。默认原型仍可配置二跳/二射击，自动最低通路分别零动作/一跳零枪；不把样片minimum当玩家上限。

公开浏览器验证结果另记录下方，实际Android/iPhone仍待用户试玩与性能验收。后续最终交接提交仅文档，其新CI状态独立，不把上面实现CI结果冒充新HEAD验证完成。

公开 `python3 tools/verify_module_lab_browser.py URL` 实际退出0，**9项全部通过**，实际页面build_id=9d42f33c73be；六布局、触屏移动x118.8→236.3、平台推进与暂停冻结、重试/恢复/确认Home通过，无脚本/Shader/Page错误。保留一次资源404原始日志（未确认目标）。Chromium触屏模拟不代表Android或iPhone Safari真机。最终工作区在交接提交后干净，下一任务square_loop再boss_approach。
