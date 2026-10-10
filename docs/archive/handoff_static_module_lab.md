# 会话交接

2026-10-10 UTC。分支 **feature/platforming-module-lab**，由干净的docs/procedural-layout-design@56b70d9创建。重新fetch origin/main=64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226；PR20仍OPEN，本轮叠加其上，未自动合并/强推。前轮设计见[历史交接](../archive/handoff_generation_design.md)。

## 交付与范围

GEN-MODULES-01静态批次：四个独立Resource/场景 safe_hub、stepped_crossing、descending_switchback、recoil_shaft，实际StaticBody平台、危险数据与安全段起点。新增主菜单MODULE LAB，复用统一InputSetup/Router、PlayerController、唯一Motor位移入口、FrameDamagePolicy与SegmentRespawn；触屏/键鼠/手柄由已有适配器接入。四个按钮/RETRY明确新尝试，暂停/设置/返回确认复用DemoMenu，不污染Run/Meta。

端口检查真实剩余动作、速度、反冲爆发/冷却和站立面，定义深拷贝实例隔离。真实庭院无跳无枪、下降无跳无枪、踏桥1跳0枪、升井1跳1枪及3/3、庭院→踏桥跨接缝轨迹通过。完整身体安全出生与危险交叠检查，不靠传送完成路径；其他武器配置仅筛选，不能声称全面可达性证明。

存活环境伤害选择性回段，保留已扣HP/精力/冷却/已用补给/模块实例/计时；暂停清旧瞄准释放，零血优先回Home并取消待补给。超出固定练习边界视为环境伤害，不用隐形墙封接缝。练习CLEAR不发Run胜利或永久奖励。

## 检查与修复

Godot实测4.7.2.stable.official.ed1daf0bf Standard，版本沿用仓库锁定；没有换引擎或依赖原作动作。`python3 tools/check_docs.py`：29必需文档/39任务依赖，退出0。`git diff --check`退出0。

初次整套实际1208断言/0失败、退出0；最后补充三条边界与暂停断言后的最终套件另记录下方。独立真实Motor模块测试143/0退出0；练习场56/0退出0。日志位于忽略的build/verification/module-lab及build/verification/platforming-modules.log，不提交机器路径、安装包或二进制。

保留失败事实：初始练习场AimGuide引用名称错误产生脚本错误，改为现有DemoAimGuide并正确绑定controller，重新导入/测试。首次练习场暂停测试发现App父节点ALWAYS被继承，暂停时角色/冷却继续推进；ModuleLab显式PAUSABLE修复，完整测试保留暂停失败标准，没有删断言。下降模块落口初版宽度会阻断零动作下降，调整真实平台后重跑完整轨迹。

Web单独导出退出0，本地build_id fc600d515b9f；Chromium触屏模拟旧demo回归退出0：真实触屏移动、松手射击击败巡逻敌人、慢时黄边/透明中心、暂停设置/确认返回、十关入口与960×540菜单。浏览器favicon404仅静态图标请求，无脚本/Shader/Page错误；不能当真机通过。

## 未验与下一步

GEN-MODULES-01整体仍in_progress：动态timed_gallery/moving_transfer、square_loop与boss_approach未制作。下一批先节拍回廊和单移动平台，分别验证相位继续/平台携带/无慢时通路，再环路与Boss外围。GEN-LAYOUT继续依赖完整GEN-MODULES和LEVEL-02详细验收，不能提前宣称完成随机地图。

A50–A54完整生成仍未验：无横纵方形完整随机小关、大世界CameraRig、难度预算或完整生成Manifest重放。当前四个样片固定1280×720世界视窗。Android/iPhone实际触控/手感/性能、Safari、Windows实机、实体手柄各自待验证；本轮不导出新APK。SaveService/永久经济/剧情/完整Steam无新增。Q001–Q013未决、D041曲线暂定保持不变。

所有安装/网络/导入/测试有界超时；整套物理测试180秒、导入90秒，网络20秒。复现：`python3 tools/check_docs.py`、`python3 tools/run_tests.py`、`python3 tools/build.py web`、`python3 tools/build.py windows`、`python3 tools/verify_demo_browser.py`。最终提交/PR与CI/公开Web版本将在验证完成后追加，不把未完成部署记为成功。


## 最终本地验证

最终源码整套 `python3 tools/run_tests.py` 实际1211断言/0失败、退出0（原1012完整保留，新增143模块与56练习场），含真实SceneTree物理。导入无SCRIPT/Parse错误。`python3 tools/build.py windows`独立退出0；Windows实机仍未验证。Web/Windows当前包内容一致build_id fc600d515b9f，构建成功不推定设备可玩。

`python3 tools/verify_module_lab_browser.py`实际7项退出0：主页进入四模块练习场、触屏人物x118.8→232.3、四种真实几何布局、明确Retry回入口、暂停750ms画面/时钟完全相同、恢复与确认Home保持原摘要。已查看实际反冲井/暂停截图，未伪造效果或截图。报告明确Chromium mobile touch emulation，Android与iPhone Safari仍unverified。


## 提交与评审

实现提交 **12c929e**；[PR #21](https://github.com/zhipijun1996/gunman-rush/pull/21) OPEN，base docs/procedural-layout-design（依赖未合并PR20及之前叠加链）。未自动合并或覆盖main。文档CI38011980834 success；实现[推送Godot CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38011980824)与[PR Godot CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38011996265)独立跟踪。最终HEAD以本交接文档提交为准，下面另记录实际部署结果。


## 远端实际验证与部署

实现12c929e的推送Godot CI38011980824 **success**：日志实际1211断言/0失败，Windows导出/Web导出/Pages部署分别success；Android job **skipped**，没有APK证据。PR Godot CI38011996265 **success**（独立core/Web通过，Pages因PR事件skipped）。不以Web通过推断Android或Windows设备通过。

公开build-info实际 **588fa760a8f2**，与本地fc600d515b9f分别记录（不同环境打包摘要，不冒充同一包）。试玩：[MODULE LAB与固定demo](https://zhipijun1996.github.io/gunman-rush/?v=588fa760a8f2)。从主菜单点击MODULE LAB，选择四个模块；底部双摇杆/跳跃保留，升井提示AIM DOWN / RECOIL UP。公开浏览器检查结果另追加下方。

公开 `python3 tools/verify_module_lab_browser.py URL` 实际退出0，7项全部通过，实际页面build_id=588fa760a8f2；触屏x118.8→236.3，四布局、重试、暂停冻结、恢复和确认Home通过，无脚本/Shader/Page错误。仍有单资源404警告原样保留；真实Android/iPhone未验。最终交接仅文档更新，不重复声称文档提交的CI或部署已完成，现有实现验证对应12c929e。工作区将在交接提交后保持干净。
