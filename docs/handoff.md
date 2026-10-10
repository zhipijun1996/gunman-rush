# 当前交接：平原体验、类型差异与PR33家园

2026-10-10 UTC，分支`feature/plains-polish-home`，基于干净`feature/plains-ten-generated@680cf79`。实际fetch最新origin/main（64ec8bb）；前序工程尚在叠加PR，未覆盖main或自动合并。设计提交`f60ea4b`，当前实现提交见Git HEAD；PR地址将在验证收尾更新。前轮完整证据见[归档](archive/handoff_plains_ten_generated.md)。

## 已实现

用户九项反馈为D058；PR33源`feature/title-home-ui@aa7efff`选择性导入四PNG与规范，不合并旧工程。新Title→可操控Home，真实Controller/Motor/NPC交互与已有音符永久生命升级；出发门创建正式平原新局，死亡/大关完成回Home。开发3/10固定、模块/动态/Boss/整关预览全部保留。角色/成就没有真实服务，界面明确制作中，不编造解锁门槛。尚未打包中文字体，游戏动态文本英语。

加载：WASM37,902,138→gzip10,027,646字节，hash引擎/游戏包与有界SW缓存；存档完全不触碰。最终本地包99e75c94c91b，同PCK旧加载器baseline实测冷启动53,760,616→25,890,985字节（−51.8%），reload53,407,397→203字节，仅manifest。拒绝SW/损坏gzip真实回退成功，unsupportedSafari回退官方原WASM；不承诺真机墙钟速度。报告[加载](web_loading.md)。

表现：最新平原远景三层低饱和冷灰雾/5tap轻虚化，有限幅面不未验无限重复；镜头1.6倍与130px前瞻，不改碰撞。地面开火瞬间倍率0.65，空中反冲仍全力度，包括同帧跳射。慢时确定0.20。真实动作事件订阅有界跳跃/落地/枪口/尾迹/命中/合法拾取粒子（默认64），可关闭表现。正式HUD紧凑，INFO/F3打开调试/帮助。

生成：Manifest v7、plains-run-v2，正式固定左下(20,282)安全开局，局部模块反射/交换端口，不整关右起步。金币16–19模块开放探索，combat10–14爬升战斗，道具12–16挑战，商店/回血8段低压休整，Boss固定核心与随机入口。新增1080开放草甸、980双层探索平台，上层弱能力资源过滤。高左/低右出口相隔520px，无跳配置保底双低出口。实际空间仍为高低主链＋终端分叉，任意多分支/折返/方形图未实现。

战斗早/中/晚目标1/2/3独立敌人，在不同足宽安全平台；巡逻包络避机关，不足空间记录更少真实目标。全部目标死才完成，段回退保留实例/HP。正式接触出口锁路线、当前关奖励一次结算；道具二选一弹窗暂停并取消输入，唯一领取后切关。Boss死触碰金出口弹窗领取后回Home；同帧致死优先取消未提交项。固定开发消费者保留原显式交互回归。

## 已执行技术验证

Godot4.7.2.stable.official.ed1daf0bf Standard，所有命令有界。日志在忽略目录build/verification/。

| 命令 | 实际结果 | 范围 |
| --- | --- | --- |
| check_docs.py / check_painterly_pack.py | 退出0，64任务依赖/13原手绘PNG | 文档/来源，不是物理 |
| tests/home_ui_tests.gd | 24/0，退出0；failure-probe25/1退出1 | 真实Motor/组件；不是完整App |
| tests/home_app_runner.gd（90秒） | 19/0，退出0 | 实际Motor行走/NPC/真实Meta/出发/返回；物理Input held/release取消 |
| tests/player_feedback_runner.gd（60秒） | 16/0，退出0 | 地面100.1px/空中154px、同帧跳射、取消、粒子有界 |
| tests/painterly_skin_runner.gd（60秒） | 39/0，退出0 | 多分辨率背景覆盖/差速，非主观美术认可 |
| Combat+AirFocus独立（90秒） | 89/0，退出0 | 真实world/projectile慢时0.200 |
| tests/plains_ten_generation_runner.gd（540秒） | 3087/0，退出0 | 40布局/重放、新2模块正反射/局部镜像完整链/coin/service/1/5/8/Boss真实Motor |
| tests/plains_exit_routes_runner.gd（90秒） | 123/0，退出0 | 高左出口/75+75探索上层真实跳跃，全身扫掠 |
| tests/plains_weak_capabilities_runner.gd（60秒） | 496/0，退出0 | 零动作/弱能力筛选、两个可达底层出口和拾取；不是全链物理 |
| tests/plains_ten_app_tests.gd（120秒） | 138/0，退出0 | 十关/多敌人/出口弹窗/死亡批次；注入目标伤害/位置，不是十关触屏通关 |
| tests/polish_regression_runner.gd（180秒） | 130/0，退出0 | 原失败菜单/动态/Boss返回/镜头子集；包含在旧5703，不能重复累计 |
| build.py web / windows（各300秒） | 分别退出0 | 本地导出，不代表Windows运行或真机 |

旧完整suite首轮5703/6失败、退出1：4个旧Home/观看尺度期望和镜头/overview跟随。已合法更新为新Title/真实Home/1.6倍率，并保留原真实运动门槛；镜头原350px运动只移动29.8px，不降30px标准，前瞻改130后同测试通过。新完整回归在运行，未将其记录为通过。Meta存储39/0前轮同服务无变；九组CI专项会在本提交完整复验。

## 失败与修复

Home集成首轮测试用了不存在horizontal_axis与错误keyboard设备ID，异常后90秒超时；已改真实keyboard_mouse和axis，有失败日志。Title/Home不应有活跃Run token，初始化end现有lifetime，start明确重新开始。

浏览器实证发现焦点白字浅底（低可读性）及面板下Wkeyup丢失导致下一次交互被阻断；已修深色focus/pressed，恢复Home仅观察实际已松开的物理键，不重放仍按住键，19项App包含该边界。GUI测量还暴露固定800ms/固定行走时长的不可靠假设，工具正改有界实际画面就绪/提示轮询，不改验收目标，不将未进入平原算通过。具体[GUI报告](plains_polish_browser.md)。

生成首次3089/1失败：service/Boss一次抽成全平板，修为保证合法开放草甸；完整最终3087/0（路线长度不同造成计数变化，旧变体断言保留）。高左回程驱动误撞侧壁，真实两次失败保留，改实际落地后回走，目标/地图/物理不变，最终123/0。

## 暂定/待验证/下一项

D059镜头1.6/前瞻130/地面0.65/雾化粒子强度是可调候选；用户20%慢时、局部镜像/左下开局、出口弹窗是明确要求。音符即拾即永久/死亡保留与HP价格5/10/15仍D056，未新增兑换或正式精力消费。

Android/iPhoneSafari加载缓存/全十关/触控手感与粒子性能、Windows运行、美术最终认可、GUI游戏真正赚音符仍待验证。无新APK、完整Steam/续局/多人物/成就系统/任意图拓扑不声称完成。下一项优先本版本横屏真机反馈与运行读图，再制作真正分叉/折返大模块与更丰富机关组合，经真实Motor验收入池。不要后台无限迭代。
