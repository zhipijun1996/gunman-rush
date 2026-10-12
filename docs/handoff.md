# 当前交接：D081 平台机关与跳跃Boss

运行提交 **0eafe6488f6eeadab8203dc41acc072158256959**，分支 **feature/plains-interactive-platforms**。[PR50](https://github.com/zhipijun1996/gunman-rush/pull/50) OPEN，base为feature/plains-exploration-expansion；后续提交只补验证工具/证据和文档，不更改游戏。没有自动合并PR。

初始工作区干净，已fetch检查最新远端；基于D080文档提交872aa221（运行5fbbb45），main仍ab51fca，PR41–49保持开放关系。未覆盖用户改动，保留此前物理、精力、镜头、弹体、音效和账本修复。[D080归档](archive/handoff_plains_exploration_expansion_d080.md)、[D081实现](plains_interactive_platforms.md)、[验证JSON](evidence/plains_interactive_platforms/verification.json)。

## 公开试玩已更新

[新试玩 6172b59d8a92](https://zhipijun1996.github.io/gunman-rush/?v=6172b59d8a92)。[发布CI38205674732](https://github.com/zhipijun1996/gunman-rush/actions/runs/38205674732) success；公开build-info的source_commit与运行提交一致，实际PCK下载32196276字节、SHA256 6172b59d8a92d7bae54e815c5390a9f6ae2f634552ea1879c2c8e648ab60b0f1，与版本前缀一致。版本化PCK/引擎与缓存流程保留；不是只改PR或HTML牌。

线上四套普通GUI输入全部failed=0/build_id一致：默认家园正常出发、随机连通平原1/2入口和迷雾地图缩放拖动；AI道具卡/真实降耗与命中返能、未命中消耗；小Boss独立名字/16→15真实鼠标命中/可见飞行弹体、大Boss36HP；新四模块入口、远铃OPEN、渡台MOVING→PARKED→MOVING、II/III明确练习入口的不同AI形态与提示。无HP/弹药/传送等游戏状态注入；II/III初始24/12是显式开发fixture，不称自然打出的阶段；Home在隔离profile安装9音符仅保存fixture，不称实际赚到。真实WebAudio输出峰值0.2816791236400604。实际截图与录像保留build/verification/d081-local和d081-public，报告收入证据JSON。

## 实现与主动玩法

荆棘通过真实平台索引/方向/范围/深度附着，五格草台左两格红刺、其他三格可落，墙面刺与墙顶分开，四方向镜像保持危险范围。AI重绘素材与已有羊毛/黄铜/苔石统一，原PNG不编辑、源SHA/测量区域记录。坑底传感器保留危险碰撞但不画成浮刺。

正式生成v7/region随机流v3/items-v2，14类局部操作组合，新增安全格落点、刺墙越顶、荆棘接齿轮、远门预开和射铃控船。远门可地面射铃耗能，也可关门时走上层真实双向零射击绕行；不是名义三路。配对AI符号/颜色/唯一LINK编号、真正弹体开关、传播粒子；启停船保存motion_clock/running，暂停重载位置立即还原，不重抽或归相位。新增落点hopper仍有冻结跃扑预警、不强制清怪；遭遇与奖励预算保持。

牧风者三形态与0.9s渐变、阶段过场目标、吼声/最多28叶片、短相机offset震动。一阶段地面可攻颈铃，二阶段上侧背铃，三阶段先踩亮当前高台再起跳下射顶铃，窄方向窗口和三草台往返。实际踩台资格在射出时捕获，落地后到达的弹体仍可命中；32条上限、取消/重载旧资格清除。修复旧左岸跳射漏洞，但允许慢等同一台下一轮窗口，不隐藏“必须三台打卡”要求。

主动修复真实铃芯射击被未来地面吞弹的形状查询错误：初始/首次接触查询零motion，移动仍cast_motion，薄墙/护甲正常挡弹。修复合法稳射等道具改变参数后两图manifest恢复被误拒：按已记录ItemDefinition/堆叠重算合法Modifier，再逐项核对，非法参数/未知道具/畸形记录仍拒绝。独立审查推动修复贴图方向、II误提示符印、暂停载入平台原点显示；全部原反例保留。

PlayerMotor、基础Tuning、InputProfile与D079/D080逐字节保持，SHA见JSON。一跳、未命中基础两发、射击精力/命中续航与原碰撞规则不变；只平原两张随机图，第二胜利后明确后续开发边界和安全返回，不发未实现能力、不开放森林或算全游戏完成。

## 验证与边界

四轮新的独立严格审查，前两轮否决整改、第三/四轮技术ACCEPT；报告和失败/反事实探针在evidence/plains_interactive_platforms。独立100图568/0、14动作全部正式出现、零重试/保底；3条完整复合连接双向连续。正式船心站等会受俯冲，读预警真实起跳HP5→5/fan9发/敌人存活；同版本反事实去掉起跳5→4。自然三台攻击只证明左→中→右3命中（Boss12→9、玩家5→4），不称全Boss/无损/完整返程。

本地和发布CI：Core5942/0，旧流程43套，地区12套（109/21/18/6/195/2672/528/47/3714/4085/27/22零失败）；新增死亡批次、暂停卸载恢复、发射快照、双向无射擊旁路，旧测试不删。文档33份/127任务、美术99、AI图标/实际20道具、世界设计及Web/Windows导出通过。最新CI确切计数见verification.json。

日志保留ObjectDB/resources/RID退出清理诊断。发布CI的Windows/Web导出仍各两条windkeeper.tscn:13 Parse Error: Busy，与D079/D080已有四条一致；随后场景成功存入导出，实际公开36HP及II/III形态消费者正常，原文在export_diagnostics.txt和publish_ci.txt。不能把导出成功写成所有诊断消失。发布辅助长轮询曾遇短暂401，CI继续完成；通过独立公开API和实际PCK/GUI核对发布，不重新登录或重发工作流。

完整真人双图通关、主观趣味/画风、手机/手柄/Windows实机仍待验，PLAINS-PLATFORM-PLAY-01保持review。下一轮值得做有风遮挡的背风窗、可中途停车支岸、投入挑战前先开撤离桥，并继续逐种子检查落点hopper公平性；这些是候选，未伪称本轮已实现。以实际操作与压力变化验收，不以模块数量或签名替代趣味。
