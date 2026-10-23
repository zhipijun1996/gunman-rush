# 2026-10-23 四条工作线集成

主体任务 `FOUR-LINE-INTEGRATION-01`：in_progress。用户明确授权下列四线整理后合入main；当前在 `integration/four-lines-20261023` 普通合并，本文记录的检查点为 `01e5183`，尚未完成组合验证、main合入或新公开发布。暂停的黄金切片 `68bd037` 不属于本次范围，未合入。

| 来源工作线 | 精确输入head | 本次范围 |
| --- | --- | --- |
| player-presentation-01-motion-candidate | `b1069762731e0cdb39f003f2dd2474ba5d8de058` | 新人物动作候选、武器／反馈音画及正式共享接口；原卡in_progress |
| enemy-feedback-01-accepted-sample | `080ac505f8fb6b6af6bd964348a952f73483ece1` | 两表现链的命中／受伤／死亡帧、粒子与尸体候选；原卡review，视觉缺口保留 |
| demo-ui-01 | `ea2d6fd7c9d11c226ce52fe8885443137cdc077e` | UI、HUD、菜单及家园交互；原卡review |
| art/formal-fine-depth | `02031d718d5b24f32ef0a257c048121d93ed756b` | 用户选择的细粒度、正式材质、根基、背景／前景、地标及共享森林表现；原内容卡review |

旧美术949d884不是本次新美术线，未用它覆盖当前实现。各线的原始来源、失败、限定独审与历史媒体保持原SHA，不将分支局部证据追认为本轮fresh。`ART-SESSION-CLOSEOUT-09`的done只签文档／skills归整，不签美术完成；`CLOUD-EFFICIENCY-01`现有v3 done及A1完整146项证据已保留在Git树，属于此前提效基线，不是本次四线组合通过。

## 冲突与正式消费者

合并顺序为enemy→player→UI→art。`DemoApp`、`HomeScene`保留UI行为与美术组合根attach／parallax可见性／实际HUD尺寸保护；资产清单按新增内容合并，避免整文件覆盖。Animation Skill同时保留人物实证与当前细粒度入口。无文本冲突的父子材质、受伤flash、前景保护和保存仍须真实消费者验证。

尸体保存修复 `f38c608` 已将原严格66/1复验为66/0；原失败保留。EnemyFeedback01Frames改为显式manifest路径及4个PNG资源声明，区域／锚点仍从原manifest读取；原资产消费者守门已自然识别全部真实文件，未豁免动态加载或修改通用验证器。新来源登记保留unknown／not_exposed和视觉未验，旧death音按仍有preload的legacy用途登记。manifest及人物JSON已加入3个导出preset；实际导出仍待组合验证。

当前[style-v6](../creative_direction/bibles/style-continuity-20261023-v6.json)仅因正式Stage尸体表现保存接口版本化重绑一个引用，保留其他19项和v5像素字节，限定独审已ACCEPT；原v5不回写。下述新默认人物会新增正式适配与绑定工作，不能把现有v6结论提前签给后续运行源。

## 新增授权与进行中的适配

用户提供的5首原MP3已接入家园、平原／平原Boss、森林／森林Boss；原字节与项目内授权见[来源](../../assets/audio/bgm/provenance.json)，没有生成／重采样或声称CC0。BGM提交 `01e5183` 已cherry到集成树；独立私有树89项定向通过，最终组合尚未验证。音乐切换、暂停／重载／Boss退出及浏览器真实播放继续检查。

用户又明确要求新人物作为默认，并在家园“织时匠”更换外观，保留现有id及位置。正式适配已由3d0dce2接入：新人物为courier默认，courier_classic用原UnderworldPlayer身体，p1历史定义保留，织时匠提供实际选择，当前选择跨本次游戏进出地区／死亡回家／重新开局保持；刷新网页回新版默认。单一PlayerWeaponFeelAudioV2同时作为BGM总音量来源。style-v7保留v6全部引用并绑定真实新增消费者；私有235项通过，最终组合回归与独审另列。

## 验证与交接

先冻结最终源码、物化选定必要输入，再执行一次组合CI；当前尚未运行完，不能预签全部passed。重点覆盖：固定Godot导入／UID／资源引用、原质量diff与证据守门、尸体支撑保存／epoch、正式新人物与换装、受伤／死亡／声音、UI实际指针／触屏／手柄、前景与HUD保护、5首BGM切换、Web／Windows导出及真实公开包身份。按原正式门槛执行，不因本次合并删断言、放预算或以局部结果替代Release。

下一步由总控接收默认人物适配，更新绑定和任务卡，冻结组合版本后跑唯一正式验证；失败、未执行、用户审美／手感及实体设备分别保留。所有main／部署状态以实际PR、Git与公开构建元数据为准，本文没有新的CI号或发布URL。

首次组合检查保留真实失败：正常时钟的enemy support199/1，恢复作者固定60帧运行条件后重验；正式66/0仍有菜单实例释放后的_restore_focus coroutine ERROR，生产代码已改为随Menu销毁断开的单次信号回调，未修改原测试断言。最终7项与全CI尚未完成，不能引用初次summary作清洁通过。
