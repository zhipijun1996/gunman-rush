# 七项武器反馈 V2：冻结候选与交付

本轮实际运行源 **3254984dcc4f0fc2c3c69b463fe5515f81d69010**，Web build **6952e7d0d356**，开发分支 feature/player-presentation-01-motion-candidate；不是已合入main。共同main基线 e9ab0e0743466b8983e34cc7de17bab1abf9d53a。原动作M1、旧run/握持REWORK及全部角色/动作/死亡链仍未完成。

七项反馈对应：

1. 原枪声表示真实已接受开火，额外hit层只消费原结算成功、session/epoch有效的weapon_damage_committed；墙面独立terrain_impacted软材料声，打空不猜造命中声。
2. 使用固定Freedoom BSD-3-Clause游戏PCM；14家族×3变体共42WAV，原始包、完整许可/Credits、处理/输出SHA、42个PRIMARY资产记录均保留。不是声称实录枪械，未签听感自然或用户认可。
3. 回旋使用可见高速旋转刃体、两层残影和局部短尾，末端随真实Underworld绘制手点并淡出。仍是既有当tick世界扫掠/伤害/接刃之后约.14秒的视觉echo，没有延迟原结算，也没有新增自然接刀身体动作。
4. 炸弹用实际爆炸声主体和尖火瓣/余烬/烟。磁雷与magnetic_storm的实际Definition新增6秒mine_fuse_seconds，从实体创建计（含飞行/附着），旧4秒无声消失寿命延至6秒。到期调用原explode一次；失宿主/退出/epoch无效先取消，暂停冻结。滴声/LED只读age/fuse，由慢到快，不决定爆炸。
5. 离子start/真实持续loop/tail，蓝束沿原beam真实端点画明芯、通道、9个移动包与阻挡端火花；炮技能只在原accepted束出现时发声，取消蓄力不冒充发炮。
6. 奇点独立blackhole持续声/尾爆、角色后29–33wu暗核、环带/内吸粒子/潮汐弧；坍缩为紫色内吸碎片，区别橙色爆炸。
7. 普通枪/机关枪使用相应Freedoom短枪声变体，同帧齐射合并；仍使用原12voice池，最多8个新武器声，预留4格给旧受伤/死亡/警示/UI。循环由真实phase拥有，暂停/切装/卸载停声；每Runtime音频hook，不全局按cue名称拦截。

## 写集和消费者

任务新增V2 scene/profile、weapon_audio_v2/weapon_feel_v2/weapon_vfx_v2/weapon_preview_v2、声音bank及专项测试/驱动。V1默认工厂及声音仍保留。最小共享增量为PlayerController提交信号、Projectile墙事件、Runtime可选音频/表现hook，以及上述明确授权的磁雷时限；需总控独审采用并安排完整受影响Integration。无Motor/输入/伤害公式/资源/授予/全局GameAudio改动。受保护Underworld脚本及3件body资源SHA均未变，没有改PNG后自刷style绑定。DemoApp/正式场景/共享配置/Harness未改。

完整消费者清单见 [17项清单](../../evidence/PLAYER-PRESENTATION-01/weapon-v2/consumer-inventory-weapon-v2.json)：保留原15项，加实际Home/Plains V2。Home正式创建UnderworldPlayer；pixel禁用Adapter、隐藏Courier身体但保留锚点；不是只测ActionStudio/Courier。采片使用实际Home主角/原几何和显式静止TRAINING柱，不注入主角位置/HP/资源/授予。Web完整游戏入口、Home/Plains重进和15装备选择保留；Home仍可用原外观选择。

导出原工具拒绝旧Foundry basis，按既定project-integration Skill运行原foundry build --count 24 --promote。首次base24和doublejump6短语通过但1条连续重放位置差10.378845失败，未promote；相同seed/参数/输入/阈值仅隔离重试一次，36短语及18条连续itinerary全通过才promote development-only池，并用原export stamp生成basis 7c8fc2cd8b24c9d7e69adcb87e4538935d876755d99eb4b0965fc27a5cc2726b。生成资源作为导出必要衍生写集交总控；不改正式池/几何算法/config。原池ZIP和原失败都在证据包，根因/稳定性未签。空的foundry-before-source.tar.gz只是被中断的历史探针，不算备份。

## 实际验证与来源

- 最终325原生配对：每段21.7秒、1302帧、1280×720/60fps、48k立体声；1294样本/3914检查各零错，28字段及全部accepted事件相同，整轮source clean/stable。音频两边0drop/0preempt。
- 最终325全武器专项：15normal+6真实攒资源技能，4781样本/14455检查各零错，28字段及事件相同；ON 0drop/61preempt，OFF 0/0。旧fc压力用例4drop/66preempt保留，不以最终通过抹去。
- feedback281样本/868检查、真实AudioStreamWAV银行458检查、磁雷反例123检查、旧V1生命周期3175检查均零错。磁雷失宿主同deadline曾123/4失败，改守门顺序后123/0；初次feedback无效0HP测试fixture及过严pause期望曾4失败，原件保留。
- 原Harness完整外报告20261023T003230.076560Z：all-weapons2381、weapon-feel1224、action-budget7305零错；20261023T003200.437857Z：旧Underworld projectile2450零错。这些绑定fc55，后续仅V2视觉/Preview和development Foundry衍生变更，不能重标325。初次outer source_changed及中断无outer报告均未记通过。docs缺历史稀疏依赖失败保留，不签完整Development计划或完整Integration。
- 最终325实际ZIP解压、完整PCK重构SHA及每个文件验证通过；实际Chromium15指针选择+1DOMtouch选择、真实虚拟摇杆位移、开关/Plains restart/Home/reentry通过。Space后AudioContext running不是听音。generic404缺URL及autoplay提示保留，不签网络全零/实体触屏。
- 独审实际看最终32原尺寸native帧及9张Web截图，独立重算两组28字段/events；engineering限域ACCEPT，runtime总体UNVERIFIED。未全速/未听音/未签用户/真机/全部技能GPU美术。

首轮fc55真实短片暴露回程末端滞留旧手点、暗核弱、内火瓣过圆；388ce50仅改末端跟手/淡出、暗核和火瓣并带实际开发池衍生，325补官方export_basis。旧fc片/trace及失败像素保留，最终电影/Web均重新冻结325，未追标旧片。

证据：[原始包及逐成员SHA索引](../../evidence/PLAYER-PRESENTATION-01/weapon-v2/evidence-index.json)、[独审工程](../../evidence/PLAYER-PRESENTATION-01/weapon-v2/engineering-review.json)、[独审运行](../../evidence/PLAYER-PRESENTATION-01/weapon-v2/runtime-review.json)、[试玩收据](../../evidence/PLAYER-PRESENTATION-01/weapon-v2/package-final.json)。复验：godot --headless --path . --script tests/player_presentation_01/weapon_trace_v2.gd -- --output=build/new-on.json；OFF加--candidate=off，完整装备加--comprehensive。配对录像：python3 tests/player_presentation_01/capture_weapon_v2.py --output build/new-weapon-capture（要求干净冻结源码、全新目录）。其他反例见tests/player_presentation_01/weapon_feedback_v2.gd、weapon_audio_bank_v2.gd、mine_fuse_v2.gd。

## 可下载结果与阻塞

[最终公开21.7秒片](https://raw.githubusercontent.com/zhipijun1996/gunman-rush-previews/b543242d28bb9c10aa375b002b081970d3929210/site/deliveries/PLAYER-PRESENTATION-01/3254984dcc4f0fc2c3c69b463fe5515f81d69010/33e0fa062314/after.mp4)；同目录comparison.mp4为43.4213秒先before后after。三部电影及完整Freedoom许可/Credits均匿名HTTP200全量下载、SHA匹配；这是不可变Git文件验证，不宣称Pages workflow已完成。

可操作独立包：build/player_presentation_01/weapon-v2/player-weapon-v2-preview-6952e7d0d356.zip，167358133bytes，SHA62996c3eddd1fc6a00d204ae8a64e68da904a798be7c52f14e0fb667e6a2aad6。解压后运行python3 start_preview.py，在浏览器打开输出地址，无需安装Godot。

新版public Web实际被900MiB共享站预算拒绝。当前保留此前活跃入口，不能用旧URL签本版试玩。其他线并发发布使媒体站也超限时，仅将本轮尚未交付的fc55中间电影完整无损归档至host archives/PLAYER-PRESENTATION-01/fc55-first-iteration.zip，核每成员SHA/CRC，live中间页保留不可变原Git媒体链接；V1、既交付历史和其他工作线入口不删除。正常合并并推送host b543242，最终site934587597bytes通过原预算守门。容量协调/新独立公开试玩仍归总控，不绕开预算。

用户听感/审美/手感和实体设备保持未验；全套动作/M1及正式采用/完整Integration没有因此完成。中央tasks/current_state/handoff由总控维护，本线只更新任务记录，不以中央planned误标本线尚无实现。

最终记录检查：quality.py check 本卡errors=[]、一致性通过，但task/content_complete=false、整体REJECT（未完成维度如实保留）；check_quality_diff通过435文件，git diff --check通过。全库check_quality.py失败于稀疏未下载历史证据及中央任务索引仍planned与本卡in_progress不一致；原日志保留，不改中央索引或伪称全库通过。精确提交证据树检查在最终证据提交后执行。
