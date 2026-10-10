# 当前交接：D070 连续平原、正式风铃与主动敌人

分支feature/plains-branch-challenges，基线15789b8，运行提交36740ac（主体ff4fd36、躲避空间修复36740ac），继续[PR36](https://github.com/zhipijun1996/gunman-rush/pull/36)，不合并。上轮[交接归档](archive/handoff_plains_density.md)。用户明确否定旧版本趣味性和视觉协调；当前技术结果不意味着已获用户认可。权威见[连续平原](plains_living_routes.md)与用户风格板第一格，Godot4.7.2.stable.official.ed1daf0bf。

## 已实现

正式首关第二公共模块出现风铃教学，有界生成保底也保留；第三关起挑战支路出现井内风铃，先开门后通过或同发向下射击开门并反冲上升。稳妥支路不加铃门。共用真实弹体/ShotLatch，完整位置、配置与版本入manifest；回退保留、暂停/死亡/切关取消旧请求；精确输出同Seed重放并拒绝篡改。StageGenerator v8、branch7/blueprint5。独立Lab继续保留；暂无风铃声音。

地基v2覆盖薄实体石台、同高接缝合并，保护下层完整空间/井口/危险/运动包络；无法真实接地的台使用厚底机械木结构，薄单向板分别可读。岩体统一世界坐标采样，相邻站立面内端不再画cap，重叠草缘只绘一次，站立线下14px草根渐隐避免独立石砖条。实体支撑和纯表现各自管理，不用背景假石头冒充碰撞。

三类正式敌人：0.45秒预警的短冲甲虫、锁定方向后俯冲的飞虫、0.65秒预警后发一枚慢弹的草籽哨兵。完整活动范围/安全区入版本化encounter plan，窄台不塞冲锋种；统一Health/伤害/掉落，3HP/1基础伤害保持。怪物接触检测加1px覆盖物理安全边距，修复正面冲到玩家却不扣血。段回退保留HP/冷却，暂停与各类弹窗清旧攻击；已合法同帧伤害沿用原确定性批次，不改Boss/玩家死亡优先。

新原创甲虫/哨兵各六姿态（idle两帧+预警/攻击/恢复/死亡），飞虫分件加程序盘旋/俯冲。受击仅事件染色，未伪称绘制受伤帧。新窄木黄铜闸杆采用自然比例端帽/裁中段，不改门碰撞；提示加深色小牌避免被背景吞没，装饰拱门避开交互铃/门。原20张v3源图不变。新素材来源/SHA/region/脚底锚点见对应json；导出显式包含新配置和深层manifest。

当前角色260速度、平原一跳、0.55地面反冲、空中1100×0.14、0.20慢时保持。

## 技术验证

核心5940/0退出0；新增风铃真实18轨迹277/0、最终48完整路线12359/0、正式App/Manifest最终295/0，故意失败分别exit1；包含镜像、±0.05rad瞄准与两解法，不以传送完成路线。敌人专项41/0包含真实伤害/一跳躲避/墙阻弹/实际App暂停；密度347/0、App159/0；最后纯视觉接缝专项466/0且无脚本错误。首次完整专项在最后生成测试4960断言/3失败：井模块替代了原反冲升阶，部分后期路线不再含强制反冲。保留失败日志，按井→安全板→反冲升阶修复实际编排，不能仅放宽测试认定井可跳过也算强制反冲。修复后的生成终组5014/0退出0，48条完整真实路线12359/0退出0；最终32套专项发现密度无伤穿越347/1：金币房地面跳跃触发环境伤害回退；CI38072328790也复现347/1并阻止导出部署。具体是density-passage-3第2金币关，下路草甸上方84px处另一支路荆棘，普通大跳会碰刺；encounter v3改为按manifest中的跳跃能力保留起跳/跨敌空间，拒绝dodge_hazard位置，原种子/地图/角色/无伤标准均保留。剩余回归发现spatial版本字面断言仍v7，已同步实际v8并复跑，未修改几何标准。修复后密度354/0退出0，四条实际躲敌路线均HP5、活敌且抵达；新增7条原seed/回放/能力快照回归。最终运行提交36740ac的CI38072767444完整32套通过，具体报告见下。

首次新敌人接触skin不足导致冲锋碰撞不扣血、缺地fixture更新未同步物理帧、开发中类尚未完成的并发parse均保留失败日志，修复后重验，不将中间计数当干净通过。第一次网页因金色提示与远景对比不足，OCR未读出SHOOT BELL而失败；实际截图确认铃存在，已改深色提示牌并重新导出。第二次整幅风景OCR仍未识别已有清晰提示，缩小到实际固定首屏提示牌区域后能正确识别；检查仍要求真实SHOOT BELL→OPEN，不接受缺失或仅素材加载。

证据：build/verification/d070/下core/full-plains/web/living-browser及enemies、windchime；真实轨迹在generated-latch-trajectories；最终草缘专项在build/verification/d071/ground/edge-contract.log（目录名为子代理局部编号，属本轮D070）。文档33权威101依赖、世界16区、新12姿态素材与原图检查均通过。所有长命令有timeout。子代理早先两组误用PATH中4.6.3，已经tools/godot.sh明确4.7.2重跑295/0和5014/0，最终日志带-472后缀；旧日志不作当前版本证据。

## 最终发布证据

运行提交36740ac6c0482456a06080f8ceeb0f8b9a0a6aaa，主体ff4fd36。最终CI：[38072767444](https://github.com/zhipijun1996/gunman-rush/actions/runs/38072767444)，核心5940/0、正式平原32套全部通过，其中风铃295/0、敌人攻击41/0、密度354/0、空间2489/0、生成5014/0。Windows与Web分别导出成功，Pages部署success。最终日志build/verification/d070/ci-final.log。

[公开试玩](https://zhipijun1996.github.io/gunman-rush/?v=210af2c8fd25)：build210af2c8fd25，PCK25905696字节，SHA256 `210af2c8fd25788d9c62836f05ae77f6cbc049f89690588b8dadc8e60a75e824`。实际GET页面、build-info与完整PCK均一致且匹配CI；证据public-final.json。最终本地浏览器包606b742a7d2e的真实GUI操作与公开CI包校验是两项独立证据，不混称对公开URL完成了全流程。

命令/退出码：`python3 tools/run_tests.py` 0；`python3 tools/run_plains_ten_tests.py` 0；`python3 tools/build.py windows` 0；`python3 tools/build.py web` 0（以上最终CI）；本地`timeout 285 python3 tools/verify_living_plains_browser.py` 0；文档/世界/素材检查及git diff --check均0。版本Godot4.7.2.stable.official.ed1daf0bf。之后仅交接/任务文档提交，不改运行代码。

## 未验证与下一步

本轮Android未构建；本地最终Web导出退出0，build606b742a7d2e；其浏览器GUI复验退出0，实际首关射击OPEN、家园购买/刷新保留通过；本次短距离移动未实际拾音符，新增拾币刷新项未验证，不借用先前包结果。没有浏览器/脚本/着色器错误。此前同表现包e56a738d2f24实际GUI已通过首关SHOOT BELL→OPEN、家园购买/刷新存档与音符拾取。CI38072767444的核心/32专项、Windows导出、Web导出及Pages部署分别success；Android job明确skipped。不能用导出成功替代Windows运行或手机真机体验。Android/iPhone真机反应窗口、手感、画面协调、整体趣味性仍待用户试玩。当前地图仍公共路接两终端分支，不声称已实现空洞骑士规模的环路探索；下一步根据首关/井组合和三类遭遇的实际反馈调整节奏，再扩展围绕地形目的的可选绕路/短回环，而不是继续随机堆同类小平台。
