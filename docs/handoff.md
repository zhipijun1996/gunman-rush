# 当前交接：D080 平原探索与操作差异

运行代码提交 **5fbbb459733fd77526f477a0b5a4fe3d03e0d5ea**，分支 **feature/plains-exploration-expansion**。其后提交只补本文和发布证据；公开游戏运行的是上述实际验证提交。[PR49](https://github.com/zhipijun1996/gunman-rush/pull/49) OPEN，base 为 feature/plains-experience-energy，不自动合并。

本轮基于最新远端 D079 91d3ef45e267944a22fb3bc09b1c93ca16ebb9f6；初始工作区干净，main ab51fca，PR41–48保持OPEN。未覆盖用户改动，保留此前有效修复。[D079归档](archive/handoff_plains_experience_energy_d079.md)、[实现](plains_exploration_expansion.md)、[验证证据](evidence/plains_exploration_expansion/verification.json)。

## 公开试玩已更新

[新版试玩 a458b0726b40](https://zhipijun1996.github.io/gunman-rush/?v=a458b0726b40)。[发布CI38197478858](https://github.com/zhipijun1996/gunman-rush/actions/runs/38197478858) success，直接读取公开 build-info 的 source_commit 与运行提交一致；实际下载游戏包31539732字节，SHA256 a458b0726b4056ae3200d3b9197d09008a02c29732cbc921a33aea235556ab13，与版本号前缀一致。不是只推PR或只查HTML版本牌。

公开网页通过三套普通GUI输入：Title→Home→正常出发→20/23节点随机图、迷雾地图放大拖动关闭、跳跃/反冲；练习道具图标说明→选择真实降耗→库存持有→普通射击命中回能/未命中扣能；两个Boss独立入口与各自开场名、小Boss真实鼠标瞄准铃芯16→15、13帧飞行弹道、大Boss36HP与变化动作。线上全部报告failed=0、build_id相同，无游戏状态传送/HP/弹药注入；Home仅在隔离profile一次安装9音符存档fixture，不能声称实际获得音符或完整地区通关。实际WebAudio输出在本地普通GUI独立测得peak0.2769；线上该项未开探针，不扩大结论。图片与录像保留 build/verification/d080-local 和 d080-public，报告正文在证据JSON。

## 实现及契约

生成 plains-region-v6 / region随机流v2 / items-v2：不同空缺足迹、截断横廊、单向井与独立攀升回程，第一图20、第二图20或23节点，不固定三条贯通高度路线。十类实际操作组合覆盖齿轮相位、顺序铃、跨坑限时、反冲横渡、起跳点、救场选择、相对运动摆渡、低顶控高、双齿轮节奏、空中向下瞄准井铃。低拱满按也能通过但撞顶；顺序铃推进不是独占站位，不能把动作签名当互斥必需操作。

正式关键窗口增加fan_sentry三向慢弹、hopper真实预警锁定跃扑；摆渡扇射和俯冲错位，不要求清怪。独立真实压力对照：港口硬等HP5→2，退回安全接近区读船相位再登船HP5→5，敌人存活、三轮实弹与真实出口。修复升降台压人跌层、销毁敌弹后再次开火的typed filter错误，失败原文保留。

小Boss独立场地清出名义铃芯上侧射线；没有“只能从下面攻击”设定，大Boss二阶段上侧规则保持。每Boss分别记录本局开场，练习也显示真实名字；八来源实际弹体专项通过，真实平台和护甲仍挡弹。

新增六个实际道具，共20：地面稳定性、落地回能、开火间隔、刹车、回能等待、生命上限。六个新AI图标原PNG未编辑，与旧九图标源SHA/消费者完整校验。宝箱可选择金币、当前回血、永久音符；地区资源保守预算122/11/8，满血替换回血，不丢唯一可用道具。保存失败弹窗提示重试同选项，稳定ID/账本、双击幂等、真正伤害批次后提交、死亡优先均保留。

PlayerMotor、config/player_tuning.json、config/input_profile.json与D079逐字节相同，SHA在证据中；保持一跳/未命中基础两发、正式精力与命中续射、镜头、永久存档、商店和Boss规则。只平原两张随机图，第二Boss后仍为明确后续开发边界与安全返回，不发未实现能力，不开放森林。

## 验证与待验收边界

四轮独立严格审查：前三轮否决并整改，第四轮技术ACCEPT；原否决/实错/对照在 evidence/plains_exploration_expansion/review_round1–4.md 和 review_probes。不同操作/风险/回程有实际消费者与真实输入证据，不拿模块数量替代趣味。

本地及发布CI通过：核心5942/0，旧流程43套，地区9套（压力6/0、模块195/0、扩充2666/0、精力528/0、Boss压力47/0、两图3305/0、几何4242/0、生命周期27/0、Boss22/0）；100图操作语料无回退，最多重复动作占比0.2223。文档33份/126依赖、美术98资源、15个AI图标/20道具检查通过；Web及Windows导出成功。

日志不全为零错误：退出仍有ObjectDB/resources in use；CI导出windkeeper.tscn的Parse Error: Busy/随后资源加载诊断在D079已有同样四条，本轮仍存在，导出随后存入场景且实际公开大Boss入口正常，完整证据保留export_diagnostics.txt。没有把导出进程成功写成诊断全消除。

完整双图真人通关、主观趣味/美术认可、实际手机/手柄/Windows设备仍待验收，任务保持review。后续设计重点：更明确家族中心空间、深层入口避免固定顶行习惯、连续区域地标、将中级箱挑战归属与风险关联、多种子敌人压力公平性。四轮技术ACCEPT不替代这些验收。
