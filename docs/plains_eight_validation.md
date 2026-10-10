# 平原八关验证记录

运行源提交679660e，分支feature/plains-eight-room-graph，[PR35](https://github.com/zhipijun1996/gunman-rush/pull/35)叠加PR34，不自动合并。Godot4.7.2.stable.official.ed1daf0bf Standard。所有调用有界，测试日志位于忽略的build/verification；不提交引擎/SDK/导出产物。

## 当前技术证据

| 命令/范围 | 实际结果 | 边界 |
| --- | --- | --- |
| python3 tools/check_docs.py / check_world_design.py | 退出0，32权威文档/70依赖、16候选地区/29边 | 文档，不是未实现地区通关 |
| tools/run_tests.py（外600、内540秒） | 5698/0退出0 | 本地在最终App批次修复前，最终提交完整回归以远端CI结果另记 |
| challenge_recoil_runner（180秒） | 120/0退出0 | 默认与145.336px门槛附近两镜像；三枪/全身扫掠/无枪负例；包含在核心，不重复加总 |
| plains_spatial_runner（240秒） | 1529/0退出0 | 三家族主路、草甸分支、四锯轮相位；90请求/3族/12实际AABB；无限任意图未实现 |
| plains_ten_generation_runner（540秒） | 2770/0退出0 | 文件名为历史ID，当前8关；代表完整Motor路线与JSON重放，不等于所有Seed |
| plains_ten_app_tests（120秒） | 127/0退出0 | 实际八关App/Boss/金奖一次；位置与目标伤害注入，不等于用户手动八关通关 |
| generated_exit_confirmation_runner（90秒） | 37/0退出0 | UI Enter/Stay/重武装/唯一结算/死亡取消 |
| stage_batch_epoch_runner（90秒） | 54/0退出0，探针55/1退出1 | 旧Policy/切关间隙不能完成新关；段回退后真实伤害仍结算 |
| jump_height_measurement_runner（100秒） | 3/0退出0，探针3/1退出1 | 新旧真实轨迹，大跳−7.70%，小跳不变 |
| player_feedback / painterly_skin / refresh_art | 26/58/19各0失败退出0 | 实际资源/事件/动画状态，不等于用户美术认可 |
| Web / Windows独立build.py | 各退出0 | 原生Windows输入/设备试玩未验证；本轮不构建APK |

最终本地14suite整组实际5195/0，退出0（tools/run_plains_ten_tests.py，外1500秒/各套件60–540秒），源679660e。最终源码Web/Windows分别导出退出0；本地公开前Chromium GUI8/0，PCK f0f43b5f1cdb，实际赚音符4→5、返回与刷新仍5。远端证据见下节。

[实际Seed4碰撞/路线图](figures/plains_spatial_seed4.svg)：直接从当前生成结果导出几何，不是手绘草图，也不代替真实Motor证据。

## 失败与修复

首次import进程退出0仍含类型推断SCRIPT ERROR，修复并由wrapper检查诊断，不能算首次通过。真实GPU先发现水平天空缝，再发现底缘拉丝，改为Atlas区夹紧和空气雾渐变后实际新包画面无这两项缺陷；最终视觉仍待用户。

大跳降低后旧280×3反冲攀升57项失败：同步几何260×3/定义版本2、验证145.336边界，没有删除全身扫掠/真实弹体/资源/负例标准。空间固体顶棚、过短折返端口与小锯轮最高相位擦碰均保存失败记录，改为内部单向台/安全接缝/经四相位验证的微模块。

八关App6项失败揭示旧伤害批次误完成下一关，修复Policy与Run/Stage epoch归属（不绑定Actor epoch），确定性回归验证加载间隙、旧终结目标、Boss与段回退。

## 设备与后续

Android/iPhone Safari真机八关操作、触控/性能/手感、美术最终认可、Windows实际运行及手柄仍待验证。当前是空间模板与微模块端口装配，不声称任意全局分支/环路搜索完成。后续优先用户八关试玩与节奏调整，再更多动态连续模块/细粒度空间装配；爬墙GOLD、其它地区、剧情、完整Steam按已有任务。

## 最终源码远端证据

[源码CI38038772320](https://github.com/zhipijun1996/gunman-rush/actions/runs/38038772320)，提交679660e，core/Web/Windows/Pages均成功。远端最终源码核心5698断言/0失败，14专项逐套件合计5195断言/0失败；两组均退出0，不把本地修复前核心当最终证据。Android job skipped，不能记通过。

公开build-info通过HTTP读取，build_id `be8213f73a3d`；实际下载PCK SHA256 `be8213f73a3d6c2cffc38e499158d9f8b720368e9b6ab8d48dbaa1059e268d47`，与CI Web导出日志一致。远端和本地PCK哈希不同，各自实际记录，不声称字节相同。[公开试玩](https://zhipijun1996.github.io/gunman-rush/?v=679660e)。

实际公开Chromium触控模拟8检查/0失败退出0，build_id be8213f73a3d：家园升级购买/刷新持久化、真实进入1/8、普通移动与短跳、金币0→1、音符4→5、确认返回家园并刷新仍5。实看公开截图地景清晰、此前天空缝/底缘拉丝已消失。日志无SCRIPT/SHADER/PAGE ERROR；另有一个未定位HTTP404资源请求，不将其描述为全网络零错误。验证范围是首关/家园，非八关全程、真手机或手柄。
