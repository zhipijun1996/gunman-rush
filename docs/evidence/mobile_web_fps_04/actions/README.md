# 大地图跳跃／攻击慢帧调查

用户反馈上一候选难以感到差异，偶发卡顿集中在大地图跳跃／攻击。本轮以已发布 `1394d114df73`（源5caf4d4f，收口6858b0bb）为基线，保留真实 `demo.tscn`、1280×720内部画布、CSS853×290、DPR2.5、正式线程音频和地图种子 `mobile-fps-04`。原主页main5f不变。云端Chrome使用SwiftShader，所有FPS仅属于软件渲染环境，不是手机模拟器性能。

## 方法与边界

真实Start→Home→输入seed→Explore，加载完整平原后在入口站定，先向上瞄准、保持瞄准并跳跃、同时松开。四个五秒动作周期；原生30秒，输入必须27秒内结束。没有改位置、生命、敌人、时间、RNG或地图。该窗口覆盖大地图已加载情况下的入口空中攻击，不代表深入地图、敌群战斗或长时稳定性。

原始报告保留全部RAF、帧时间、process/physics监视器、draw calls/objects/primitives、对象／资源数、逐帧玩家位置/HP/动作cue和inclusive方法差分。计时窗口不截图、不抓音频；这些观察本身有开销。父子方法、`observe:<script>`和`_observe`不能叠加。`heavy_landing`仅是参数命中，不能证明shader实际绘制。GameAudio计数不等于浏览器可听输出证明。


## 相同动作的A/B/A实测

[完整身份审核和数值](comparison.json)通过：相同runner／probe／输入方案／初始角色相机视口／manifest／保护计数；唯一生产差异是foreground。三组均四跳、四枪、四次实际空中发射、无掉血，节点1441→1441。中间轨迹与敌人相位不保证逐帧相同，输入仍有实际调度延迟。

以下均为云端软件GPU原生30秒窗口，单位毫秒；**不是荣耀手机FPS**。

|顺序|FPS|P50|P95|P99|最大帧|前景observe总耗时（12次）|
|---|---:|---:|---:|---:|---:|---:|
|原版A|7.66|130.2|171.0|190.8|301.6|44.29|
|候选B|7.78|123.5|185.0|214.5|230.7|8.20|
|原版反序A|7.47|123.8|189.9|321.4|557.5|11.04|

整体帧率／P95没有足够证据证明稳定改善。原版自身尖峰波动明显，不能把第一次35ms枚举峰值的全部下降归因于修改。局部减少属性字典分配由精确输出和正反微基准支持；Web候选observe总耗时低于两次原版，但仅4枪、12次节点观察，不报告其为稳定百分比。draw calls平均92.55–92.60，画质／功能未删减。

## 定向修订

唯一新增生产改动在 `UnderworldForeground`：精确原生Node2D的普通GDScript弹体读取当前Script属性表，避免枚举Node/CanvasItem全部原生属性字典。保留基类字段、顺序、重复项、空数组和完整跟踪；每次读取，无schema缓存。动态`_get_property_list`／继承`_validate_property`、其他原生类、无Script均退回原实例枚举。后续实时trail读取、保护矩形、Shader、画面、音效和碰撞全部不改。

六种真实脚本及继承／动态provider／validator／相同Script热重载／Sprite2D回退／数组独立与清理的精确对照，加原383项共444项通过。首轮原生报告见 [native-property-01](native-property-01/report.json)。六类每模式64次，原loop正反两轮190.6／222.6微秒，helper44.9／53.7微秒；均值206.6→49.3微秒（约76.1%减少）。这是有界原生方法微基准，不是整帧或Web提速百分比。

## 保留的失败

- baseline-run-01：较复杂移动输入超过27秒，角色跌落掉血；不能作为有效A/B。其节点创建曾记录约28.9ms前景枚举，作为进一步定位线索。
- baseline-run-02：四次跳跃和射击成立、HP/位置正常，但所有射击均在落地后；airborne守门拒绝，原报告不追签PASS。
- formal-source-change-rejected：原96和新444检查实际clean通过，但测试期间另一个agent改了动作runner，Harness源稳定性守门拒绝。保留失败，以全部源码冻结后的fresh Harness作为正式通过证据。
- 旧PR头6858完整CI：parallel通过；serial `forest-depth-region`原600秒预算超时，affected拒绝。本轮不放宽预算、不称完整165通过。

## 未解决范围

局部反射优化不等于全部偶发慢帧根因。`_shot`还包含selected音频同步load/赋stream/play和leaf入树；没有分段测量前不把它们定为根因，也不改音频。不降低分辨率、不删光照，不做美术或玩法重构。手机FPS与长时体验保持未验证。

## 当前交付

[新试玩 f94fd4124f5f](https://zhipijun1996.github.io/gunman-rush/perf-actions/?v=f94fd4124f5f) · [旧候选1394](https://zhipijun1996.github.io/gunman-rush/perf-04/?v=1394d114df73) · [原主页](https://zhipijun1996.github.io/gunman-rush/?v=ad78f8ae3998) · [PR120](https://github.com/zhipijun1996/gunman-rush/pull/120)。运行源eec08e9b；正常导出不含诊断probe。deploy41003568533成功，四入口metadata与新候选7个完整公网文件SHA／长度实际核对通过；旧入口prepared文件无改动，本轮未重下载旧PCK。

冻结源[fresh Harness](formal-harness/report.json)通过原96＋扩展444，exit0、原预算、严格退出、源稳定性均保留。正常Web bundle／缓存策略通过；包内3260项payload相同，变化精确为foreground.gdc与两份Godot索引。实际包比对首轮旧pack路径已被构建清理、次轮guard误排除预期foreground.gdc的失败保留；最终精确三路径检查通过。

公开真实GUI进入家园与平原并实际触屏跳跃／射击；两个8秒混合PCM均352800非零帧、无clipping。工坊shot_pulse_a与输出相关0.432／0.856，距原生start均约0.045ms；家园混合结果相关较弱，不能单独签强资产识别。平原实际所选音效匹配成立；混合非零不证明全程无音频断续，手机与长时仍待验证。[交付明细](delivery/summary.json)。

文档守门首轮因稀疏工作区缺少已跟踪的build／preview导入隔离标记失败；从原HEAD恢复原字节后，原structure检查通过，随后重跑docs。它们未改变生产源码。已单独核对正常包两份global class cache：全部类定义集合相同，仅顺序不同，无临时类进入运行索引。

最终冻结源fresh原生复测（[native-property-02](native-property-02/report.json)）两轮均值191.4→51.0微秒，减少73.4%；与首轮76.1%的局部结果同方向。仍不外推整帧或手机。

第二轮docs在全局quality处发现历史音频／动作等证据缺件，失败保留。按原`cloud_inputs --profile docs --materialize`恢复约1.016GB被选中的原提交输入，status ready、无blocker，未改变稀疏规则或放宽检查；原quality runner随后通过。

最终[docs Harness](delivery/docs-harness/report.json)33项全部fresh通过，原失败与恢复记录保留。远端eec08e9b parallel另因任务索引／质量卡状态不一致失败；收尾记录已统一awaiting-device，本地global quality及docs33通过。该修正不改变运行包，完整新head远端CI仍未代签。
