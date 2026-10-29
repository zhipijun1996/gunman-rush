# AUDIO-HOME-01 · 前置与局部阶段独审

审查者`/root/ambience_review`只读生产实现，没有运行Godot，也未人耳听音。基线/前置为7b28301f活跃Audio Director工作线；authority明确main45e98和PR113依赖，不冒称这些候选已进main。

## 前置结论

用户明确要求家园有平原的平静与NPC生活声，足够授权本轮开发试听；此前“两者都选A”只绑定quiet-02平原/森林两床，不推导家园额外−2dB或生活声已被接受。借用已选plains_a原字节、只给Home运行层−2dB，保五BGM/0.16增益和两区选择，是合理的小样起点。

四个实际静态keeper所在地分别为织时匠布料、维修木件、武器轻工具、档案纸页；没有动作帧信号，称所在地/室内稀疏拟音，而非可见NPC挥锤、翻页同步反馈。不得借声音新增交互/交易结果或人群常驻loop。后续native需明确哪几个来源真的到过/发过声，单声库8件不等于全部NPC路线已听到。

## 真实宿主与生命周期

源码核实：arms原JSON未激活，实际UnderworldHomeWorld.configure会激活并赋artisan，因此观察器必须读运行时specification和真实Sprite。当前实现发现4个active keeper，以Sprite现有home_root经world.to_global定位，未错用贴图左上/label位置。通过弱引用、实际可见/屏幕/距离条件准入；12–22秒每源、全局6秒间隔/最多一个生活声、过期请求丢弃不补播、独立presentation RNG，复用GameAudio/GameAmbience原池与衰减。面板、pause、离场、controller死亡、original、重配需保明确语义。

首轮只读发现的两处具体问题已在新helper修复，未动共享引擎：

1. 同帧input_blocked+tree.paused时，旧代码先pause return，未停止既有点声，关闭面板会续尾。现先处理input_blocked并清尾，再处理pause。
2. 从audioA重绑audioB、旧Home仍活着时，旧代码覆盖引用但留下audioA床/点声。现新配置成功后、覆盖引用前清理不同旧owned组件，失败提案保原状态。

主控runtime-03严格收据实际60/0、退出0、12.385秒；包含同帧面板/暂停、真实双service失败/成功重配、真实Controller.die active真→假、owner tree exit。审查者读取该收据/测试源码，没有冒称独立执行Godot或自然战斗死亡。runtime-01解析失败与02的空槽stream_paused断言失败保原件；修后明确要求实际非空床原本在响、非空床数量保留且每条暂停，空槽不作为声音，不删除有效床断言。

## 素材、闭包与局部实证

独立实际运行新8项加工测试全部通过（18.730秒），含原件/许可/选择锁定、继承来源元数据、输出与加工器漂移、身份映射、渲染中原件漂移不覆盖旧产物、精确可复现；[日志](review-design-tests.log)/[退出收据](review-design-tests.json)。

7条原件的实际SHA与原许可页SHA均独立匹配，页面许可字段均为CC0；新布料Iochi Glaucus，木/金属/书页继承rubberduck原记录。证据[review-source-license-check.json](review-source-license-check.json)。这不证明录音方法或听感，keys可作轻工具材质，但不得改写原文件名/授权或冒称真实挥锤原声。

8个DETAIL_PATHS是实际validate_manifest按ID/path消费的字面量白名单；独立在真实工作区调用原known_asset_consumers，home目录恰新manifest+8WAV，借用plains_a已知，旧共享有限闭包仍恰9；无需扩大旧目录特免或新造适配框架。[实际inventory](review-static-consumer-inventory.json)。

独立复制夹具5反例：真实未引用sibling不加入known；缺白名单文件拒绝；陌生目录prefix caller仍拒绝；runtime detail指向sibling拒绝；home床偷换forest拒绝，全部通过。[反例](review-finite-path-counterexamples.json)。未改正在生产的文件。

原GameAmbience SHA344eee、两区manifest70ec7a、配方bb8e68、选择8eb9d5保持，不刷新旧用户选择/旧工程证据。formal HomeScene/DemoApp/全局style不在写集；其未修改证明应随最终源继续核。

## 阶段决定

**前置方向与上述局部工程范围可继续制作；完整内容仍UNVERIFIED。** 已发现的两处生命周期问题在源码和主控有界专项范围解决。真实Home路由/采集、实际BGM与−2dB/生活声幅度、代表合屏、手机/Home子页、新旧站字节/选择隔离及完整发布身份仍待最终实证；不由本阶段Python/信号测试代签。实体设备、用户听感和商业品质仍须实际试听确认。

原scene-smoke-01 typed-array分支失败及修后后续收据分别保留，不用局部技术通过追签失败、完整CI或正式推广。
