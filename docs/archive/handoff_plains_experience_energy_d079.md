# 当前交接：D079 平原多维体验、道具与射击精力

分支 feature/plains-experience-energy 基于最新远端 D078 的 906c3805dc8d06808941dce76ebeacedfb390e74，初始工作区干净；main ab51fca 与 PR41–47 OPEN，继承全部有效修复，不覆盖用户改动，不自动合并 PR。[D078归档](handoff_plains_spatial_combat_d078.md)、[本轮实现/15维审计](../plains_experience_energy.md)、[验收证据](../evidence/plains_experience_energy/verification.json)。[公开试玩](https://zhipijun1996.github.io/gunman-rush/?v=3bcca0db5328)已更新为3bcca0db5328，运行提交b84de0f4a15d81e6b43281bc385e85b7adeb2bf1；[发布CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38165033235)成功，线上build-info/source_commit、canonical root及实际下载PCK SHA实查一致。[PR48](https://github.com/zhipijun1996/gunman-rush/pull/48)以D078分支为base，保持OPEN；最终跟进提交只更新文档、证据与GUI观测，不改变已发布玩法。

最新用户明确授权射击消耗精力，覆盖旧“用途未定”。正式平原 ShotEnergyDefinition：100容量、每发20、真实提交命中20；0.35游戏秒停射后地面30/秒，空中不被动恢复。空中有效命中返还一发、下一Actor帧应用、仍封顶已有基础两发，不返还跳跃。独立弹体/扫掠/枪口快照、真实伤害提交后回调；墙/护甲/未选中伤害/重复/旧epoch/死亡同帧不返还。Focus使用独立旧原型资源，重置不偷补射击精力；原Motor/物理与输入配置保持D078字节。

统一AI九图标原母版保留哈希/透明/来源；14实际道具都有双语名称、介绍、效果，奖励/商店/构筑共用卡片，成功获取toast。新节能/回能/反冲选择由独立region_items流按蓝/紫/金档抽两项不同内容；生成v5、plains-items-v1，位置/总预算与原随机流不变，无二段跳大能力。商店改成图标/效果/价格/库存预览后确认，不直接扣币；稳定账本不变。实际HP小数、路牌动作成本、俯冲锁定落点/炮台射线、Boss真实开放剩余时间/圈、绿色回能火花/CC0音效接入。

仅平原两个非线性随机地图/三骨架、第一小Boss16HP、第二牧风者36HP/三阶段与侧风/上侧弱点、迷雾地图与缩放拖动保留，Boss后开发边界安全回家。ENERGY & ITEMS为显式ModuleLab练习，用真实伤害/RewardService/BuildState，一次fixture选择、重试/离开丢弃，不是正式掉落或永久获得。

本地Core5942/0、旧43套、本地地区六套489/47/3484/4988/27/22零失败，发布CI最终六套510/47/3484/4988/27/22零失败；最终能源扩展510/0包含实际扫掠墙/护甲、默认App消费/商店预览、实际练习选择/幂等、14项字体、连续8空中命中，证据air_hit_loop.json。两图连续行程在正式精力下完成环路、双向返回、捷径与困难挑战，不重置资源/传送。Web/Windows导出与文档33/125、世界16/29/6、目录97、AI道具源包检查通过。

本地实际浏览器普通键鼠/点击：道具选择真实成本20→16，构筑图标/说明/效果返回再打开保留，训练敌人20→19HP、命中回能，未命中显示92/100后地面恢复；默认Title/Home购买/刷新持久化→正式第一地图、迷雾/缩放/拖动/关闭与实际音频通过。训练道具明确fixture；Home隔离9音符不是实战赚取。Boss窗口/弹道浏览器回归已通过：普通指针瞄准开放铃芯16→15、13实际合成帧飞行弹头/尾迹、16/36HP练习实绘。公开三组GUI均通过：实际道具成本20→16、20→19HP、6绿色返还帧；默认入口/保存/正式迷雾地图/音频；普通铃芯16→15与11飞行合成帧。公开版3bcca0db5328与b84de0f实查匹配；不声称完整真人通关或手机/手柄/Windows实机、主观趣味/画风认可，任务保持review。

复现：python3 tools/run_tests.py、run_plains_ten_tests.py、run_plains_region_tests.py、check_docs.py、check_world_design.py、check_art.py、check_plains_spatial_art.py、check_plains_item_art.py；python3 tools/build.py web/windows。GUI：GUNMAN_RECORD_GUI=1 python3 tools/verify_plains_energy_browser.py [URL]；GUNMAN_RECORD_GUI=1 GUNMAN_AUDIO_PROBE=1 python3 tools/verify_plains_region_browser.py [URL]；GUNMAN_RECORD_GUI=1 python3 tools/verify_plains_pressure_boss_browser.py [URL]。完成发布后核对source_commit/版本和实际页面；不合并PR，不扩展森林/整套能力。

失败取样保留：奖励标题浅底低对比、typed空数组调用、HP整数兼容、练习目标贴平台挡弹、构筑Back需要正常滚动和新测试循环preload已修正/验证；Boss首次浏览器取样并发导出时超时，稳定包正常输入重跑通过，不改开放窗口/弹速/碰撞或伤害断言。本地最后回能流采样12帧/5绿色帧，未命中84/100；公开取样数见验收JSON。既有headless清理资源警告、favicon404保留。下一步为玩家完整两图通关、趣味/画风和实机验收；本轮技术与已授权试玩交付已完成。
