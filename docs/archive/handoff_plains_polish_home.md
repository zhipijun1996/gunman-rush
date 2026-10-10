# 当前交接：平原体验、类型差异与PR33家园

2026-10-10 UTC，分支`feature/plains-polish-home`，基于干净`feature/plains-ten-generated@680cf79`。实际fetch最新origin/main（64ec8bb）；前序工程尚在叠加PR，未覆盖main或自动合并。设计提交`f60ea4b`，实现`3832bfa`，实际GPU着色修复`f1105db`，测试/错误退出修复`6c50876`；[PR34](https://github.com/zhipijun1996/gunman-rush/pull/34)叠加PR32。前轮完整证据见[归档](../archive/handoff_plains_ten_generated.md)。

## 已实现

用户九项反馈为D058；PR33源`feature/title-home-ui@aa7efff`选择性导入四PNG与规范，不合并旧工程。新Title→可操控Home，真实Controller/Motor/NPC交互与已有音符永久生命升级；出发门创建正式平原新局，死亡/大关完成回Home。开发3/10固定、模块/动态/Boss/整关预览全部保留。角色/成就没有真实服务，界面明确制作中，不编造解锁门槛。尚未打包中文字体，游戏动态文本英语。

加载：WASM37,902,138→gzip10,027,646字节，hash引擎/游戏包与有界SW缓存；存档完全不触碰。最终本地包39edfde252ed，同PCK旧加载器baseline实测冷启动53,760,824→25,891,193字节（−51.8%），reload53,407,605→203字节，仅manifest。拒绝SW/损坏gzip真实回退成功，unsupportedSafari回退官方原WASM；不承诺真机墙钟速度。报告[加载](../web_loading.md)。

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
| tools/run_tests.py（600秒外界、540秒内部） | 5703/0，退出0 | 完整回归，包含130子集 |
| tools/run_plains_ten_tests.py（1100秒外界、各套件60–540秒） | 9套件3981/0，退出0 | 新专项实际整组完成 |
| verify_web_loading.py（190秒外界、180秒内部） | 退出0，cold−51.8% / warm203B | 同包39/实际SW拒绝与损坏gzip恢复 |
| verify_plains_polish_browser.py（260秒外界、240秒内部） | 8/0，退出0 | 实际Home购买/出发/拾取音符后返Home/刷新 |
| build.py web / windows（各300秒） | 分别退出0；PCK均39edfde252ed | 本地导出，不代表Windows运行或真机 |

旧完整suite首轮5703/6失败、退出1：4个旧Home/观看尺度期望和镜头/overview跟随。已合法更新为新Title/真实Home/1.6倍率，并保留原真实运动门槛；镜头原350px运动只移动29.8px，不降30px标准，前瞻改130后同测试通过。修复后完整复验5703断言/0失败、退出0，日志full-tests.log；不把130子集重复累计。最终九组专项3981断言/0失败、退出0（含Meta39与Generation3087），日志plains-ten-suites.log。旧完整5703＋专项3981=9684，证据范围不等于人工通关。

## 失败与修复

Home集成首轮测试用了不存在horizontal_axis与错误keyboard设备ID，异常后90秒超时；已改真实keyboard_mouse和axis，有失败日志。Title/Home不应有活跃Run token，初始化end现有lifetime，start明确重新开始。

浏览器实证发现焦点白字浅底（低可读性）及面板下Wkeyup丢失导致下一次交互被阻断；已修深色focus/pressed，恢复Home仅观察实际已松开的物理键，不重放仍按住键，19项App包含该边界。GUI测量还暴露固定800ms/固定行走时长的不可靠假设，工具改有界实际画面就绪/提示轮询，不改验收目标。最终39包真实GUI8检查/0失败、退出0：Title/Home/行走购买9→4且升级1/刷新4与1/出发COMBAT1 of10/移动短跳实际捡音符4→5/确认返Home及真正刷新仍5；没有注入游戏奖励或传送。具体[GUI报告](../plains_polish_browser.md)。

实际GPU发现远景fragment COLOR已乘原纹理，shader再次相乘恢复强蓝；改用vertex tint后，实拍区域平均RGB通道跨度102.97→16.63，灰蓝雾化成立。云块约移动10px、同平台约245px，实际差速视差；角色屏幕约55px。属于本地Chromium软件GPU，不是手机GPU或用户美术认可；独立枪口粒子视觉待验。

专项wrapper首次90秒超时：高左出口手编fixture缺少新service规则必须含开放草甸，非法manifest后Nil异常未退出；不是物理路线失败。修正测试图满足同一生产validator并保持全部真实Motor断言，合法图123/0退出0；原非法图0.23秒1/1退出1，不再挂起。run_engine超时保留前置输出，不提高90秒上限或降低生产规则。旧timeout/异常日志保留。

生成首次3089/1失败：service/Boss一次抽成全平板，修为保证合法开放草甸；完整最终3087/0（路线长度不同造成计数变化，旧变体断言保留）。高左回程驱动误撞侧壁，真实两次失败保留，改实际落地后回走，目标/地图/物理不变，最终123/0。

## 暂定/待验证/下一项

D059镜头1.6/前瞻130/地面0.65/雾化粒子强度是可调候选；用户20%慢时、局部镜像/左下开局、出口弹窗是明确要求。音符即拾即永久/死亡保留与HP价格5/10/15仍D056，未新增兑换或正式精力消费。

Android/iPhoneSafari加载缓存/全十关/触控手感与粒子性能、Windows运行、美术最终认可与独立粒子视觉仍待验证；本地及公开HTTPS实际赚音符并刷新保存已通过。无新APK、完整Steam/续局/多人物/成就系统/任意图拓扑不声称完成。下一项优先本版本横屏真机反馈与运行读图，再制作真正分叉/折返大模块与更丰富机关组合，经真实Motor验收入池。不要后台无限迭代。

## CI与公开交付

验证源码`6c508764c308128eb5bb66a18d2d52adea711db4`，push [38034828882](https://github.com/zhipijun1996/gunman-rush/actions/runs/38034828882) 与PR [38034832040](https://github.com/zhipijun1996/gunman-rush/actions/runs/38034832040) 均success：完整5703/0、九组3981/0、Windows与Web分别构建；push Pages部署success。Android job按配置skipped，没有新APK。已取消被shader/测试图修复替代的3832/f110旧构建，不把取消记录算通过。

公开试玩：https://zhipijun1996.github.io/gunman-rush/?v=6c50876 。公开PCK `5f12c2d13996`，15,507,824B，完整SHA256 `5f12c2d13996fb2c016369a78312c638bcb5604628d2d13d1525e6211254bee9`，直接下载实测与CI导出日志一致。CI Windows PCK `7bef2a6aad4cc8d10822ed6c64021a4d9491acb1b72105d3c8291394a19c8d63` 单独记录，不推断Windows已运行。

公开URL单次有界GUI8/0、退出0：9fixture→真实购买4/1→刷新仍4/1→出发第一关→真实赚音符5→返Home/刷新仍5，同包5f12核实且无script/page/shader错误。公开GPU灰雾通道跨度16.6305，远云约9px/同平台235px差速，角色约55px。报告/截图在build/verification/plains-polish-browser-public；本地8项整个目录保留plains-polish-browser-local-final。[浏览器证据](../plains_polish_browser.md)。

本地39包与CI5f12包哈希不同，未冒称同包：625条路径一致，所有GDScript/配置/PNG的导入CTEX/shader相同，574项逐字节相同；49项导出资源（40.scn与9.res）用Godot4.7.2只读加载，递归存储属性除PackedScene随机node_ids/导出资源实例标识及路径外全部相同，余2为117条class缓存及221对UID→path缓存的迭代顺序，排序/解析后内容完全一致。9旧Resource省略/显式默认字段导致体积差异，没有玩法或素材有效属性差异。实际公开包独立通过GUI，加载51.8%字节对照仍明确属于本地39同PCK实验。目录差异报告在build/verification/plains-polish/pck-directory-comparison.json；完整语义对比日志pck-semantic-{local,public,comparison}.json，差异结论见web_loading。

收尾提交仅文档与证据同步，不修改已验证运行代码/资源；Git HEAD是该提交，运行验证来源保持6c50876。收尾push触发的新CI状态需据实观察，不能冒称已执行另一个源码版本全套。PR34以review状态交付，不自动合并。下一项优先真实横屏设备十关读图/手感/缓存与粒子性能，再扩分叉/折返模块；声音、角色动画与轻量镜头反馈是后续表现候选。

公开HTTPS单次冷热资源验证退出0：5f12同包，Page+Worker ResourceTiming覆盖量cold25,266,809B、warm803B，暖载PCK/WASM transferSize为0，探针保留、JS错误0。该API覆盖量含部分头、不保证覆盖SW注册校验等全部请求，不作为local39服务端完整响应体的替代表格；报告public-loading.json。
