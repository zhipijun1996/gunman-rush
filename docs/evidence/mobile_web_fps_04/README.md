# MOBILE-WEB-FPS-04：保持画质的性能调查

[最新试玩f94fd4124f5f](https://zhipijun1996.github.io/gunman-rush/perf-actions/?v=f94fd4124f5f)。最新续查见[大地图跳跃／攻击A/B/A](actions/README.md)：已增加无schema缓存的弹体属性发现优化，原生局部耗时约减少76%，整体FPS稳定收益仍未成立。下文保留前一候选的测量与发布历史。

当前结论：未取得荣耀60Pro的FPS/P95，不能报告手机已稳定60帧。官方Release引擎没有显示可靠的整体收益，本轮不切换导出模式。固定几何保护缓存能减少静止镜头时的重复CPU计算，但整体Web帧率收益尚未确立；移动镜头时还有少量缓存失效成本。候选不自动合main。

## 已发布对照

[候选1394d114df73](https://zhipijun1996.github.io/gunman-rush/perf-04/?v=1394d114df73) · [原版ad78f8ae3998](https://zhipijun1996.github.io/gunman-rush/?v=ad78f8ae3998) · [草稿PR120](https://github.com/zhipijun1996/gunman-rush/pull/120)。候选是源 `5caf4d4f` 的正常Web导出，无本轮计时probe；正式入口和旧audio-before原文件保持不变。发布run40991030714成功，15个完整公开文件SHA/长度核对通过，详见[交付收据](delivery/summary.json)。

真实公开GUI已进入Home/Plains、触屏跳跃/射击；官方线程共享音频环实际启用，两段各8秒PCM全部352800帧非零、无clipping，所选 `shot_pulse_a` 与输出相关系数0.801/0.805且距原生start约0.045ms。此为短窗浏览器输出证据，不能代签真机听感或长时完全无断续。导出3260项payload保持相同，仅foreground字节码及两份Godot索引缓存改变；原音频、图片、Shader与项目配置未变。

首个公开GUI尝试超过原180秒加载限时，失败保留；单独加载观察在20/40/60秒持续下载127/162/235.6MB，80秒进入标题。最终原verifier在原180秒预算内完成，未放宽门槛。不把一次冷加载超时冒称进入游戏后的帧率问题，也未证明其精确网络根因。

文档首轮因稀疏工作区缺历史输入失败，按原输入工具实际物化后，原docs Harness重验通过。Web bundle、原缓存测试、quality记录一致性与完整base diff守门通过；所有相关原件见delivery目录。质量仍待真机与整体性能接受，完整候选CI未代签。

## 基线与可比范围

- 正式源：main `5f55716a838a754a938997920ff18cb3b17452b5`；公开PCK `ad78f8ae3998`，官方Godot4.7.2线程供音。保留上一轮已修复的UI、1280×720逻辑/纹理视口、画质、光照、工坊音效。
- 使用原导出 `demo.tscn`，真实触屏Start→家园→填写 `mobile-fps-04`→Explore。没有用 `DemoApp.new()` 代替正式Web场景，也未注入角色位置。
- Chrome/SwiftShader云端软件渲染，CSS 853×290、DPR2.5，实际canvas2132×725。它不是手机GPU，也不是荣耀60Pro模拟器。
- 同一原PCK的官方Debug/Release引擎配对只改变引擎模板，不等于完整Release导出。诊断包追加同一计时probe；候选诊断包仅foreground内容不同。
- 每场景两次10秒原生窗口，5秒预热。原生窗口位于浏览器RAF窗口内，两者不是同一时段；计时wrapper有观察开销，父子方法耗时不能相加。
- [身份与初末状态审核](profile-comparison-audit-02.json)核对了引擎/包元数据、正式manifest、相同player/camera/viewport及保护矩形数。并不保证整个窗口的敌人时钟逐帧一致。配对工具由root另作源码审查；其作者没有自签独审。

## 实际结果

下表是云端软件渲染的原生窗口，**不能转述成手机FPS**。FPS为两窗口总帧数/总时长，P95保留各窗口，避免平均百分位。

| 组别 | 家园FPS | 家园P95毫秒 | 平原FPS | 平原P95毫秒 |
|---|---:|---|---:|---|
| Debug原版首次 | 4.48 | 242 / 358 | 6.17 | 588 / 169 |
| Release同PCK | 4.48 | 258 / 260 | 6.51 | 327 / 198 |
| Debug缓存候选 | 4.91 | 253 / 267 | 8.88 | 136 / 156 |
| Debug原版反序复测 | 4.67 | 350 / 224 | 8.69 | 141 / 152 |

原版自身两轮差异明显；候选与反序控制的平原差异只有约2%，不能把第一次对照的变化归因给缓存。家园也没有足够样本证明稳定增益。

前景 `_protection`：原版首次Home3.3–4.0ms、Plains7.6–7.8ms；候选3.5–3.7ms、4.7–4.8ms；原版反序3.0ms、5.1–5.6ms。固定几何前缀确有重复计算，但不是所有帧时间的解释。关卡还测到每物理步的 `capture_state` 和敌人/玩家逻辑开销，低FPS下多个物理步被累积到一帧；不能把该每帧值套到60FPS手机。动态光照选择的脚本时间较小，暂不改光照/阴影。

真实场景快照：Home有32个固定世界矩形、183个跟踪节点；Plains有481个固定世界矩形、669个跟踪节点。Web Home最终16个保护矩形、2个可见前景、4个实际绘制遮罩；Plains为9、2、2。Shader的64是上限，不能称每个前景都跑满64。

## 候选修订与功能验证

唯一游戏修订是 `UnderworldForeground._fixed_protection()`：完整有序固定几何、camera/canvas变换与viewport精确相等时，复制原算法的固定前缀结果；否则仍执行原loop。其后的角色、UI、碰撞、敌人、弹道、拾取物保护和合并次序逐帧不变。保存过程中置位的overflow，不从最终矩形数量重算。原Shader/PNG/灯光/音频/物理/风动/淡入淡出未改。

[原生报告](native-cache-1793326121-6939431/report.json)：真实demo Home/Plains、合成边界共383项通过，包含输入增删/修改/重排、相机平移/缩放、视口变化、动态/UI变化、缓存别名污染、暂停/同步恢复、超过64后被合并的sticky overflow。同步恢复比较不是菜单关闭后稳定画面的验收。

两个正反顺序微基准共每组64次，仅测固定前缀CPU（含共同reset）：

| 原生场景 | 原loop | 缓存命中 | 移动原loop | 移动候选 |
|---|---:|---:|---:|---:|
| Home | 35.0μs | 3.2μs | 27.1μs | 36.7μs |
| Plains | 134.5μs | 4.1μs | 157.0μs | 202.3μs |

这些微秒值属于原生定向fixture，**不是Web毫秒或整帧收益**；移动时会miss且多复制快照，成本如实保留。

[正式Harness](formal-harness/report.json) fresh通过既有 `underworld-formal`：原两图96项和新增383项，严格退出与音频释放通过，共享原120秒内部预算，外层150秒不变。这里只完成相关专项，不是完整165项/最新远端CI或实体设备通过。独审见[审查记录](../../worklines/mobile_web_fps_04/review.md)。

## 测量失败与边界

- 旧vanilla observer可能漏掉末尾尚未提交的长RAF；原始两组报告保留，未拿旧FPS作优化验收。Release旧平原窗口有约8.6秒尾部缺口，不能丢弃后声称提速。
- [第一次边界自测](frame-boundary-selftest.json)失败；[修正自测](frame-boundary-selftest-02.json)实际保留383ms末尾间隔、覆盖约98.3%。最终profile均采用修正runner。该测试不证明LongTask事件完整性。
- [汇总首版拒绝](profile-comparison-audit-01-failure.json)：首次Debug平原窗口RAF初始缺口2.95秒、覆盖77.7%，不参与代表性的RAF间隔比较。原生窗口独立计时，原始数据完整保留。
- [首轮wrapper失败](formal-cache-01.log)：原生96/0和383/0之后，成功marker带output字段而包装器旧正则不接受；真实拒绝保留。修正正则后重新执行上述Harness通过，没有削减断言/预算。
- 当前main合入后CI run40946370804原本已有两项失败：[只读核查](baseline-main-ci/read-only-findings.json)。parallel历史git对象在浅检出缺失；serial forest-depth-region真实600秒超时，不能称80项全过。这不由新候选引入，也不被旧PR117同树全165通过冲销；本轮不绕过其红灯。

原始报告与SHA见[归档1](archive-index-01.json)、[归档2](archive-index-02.json)。没有降低分辨率、删灯光、删特效或重做音频。下一步是否采用候选，仍以真机实际收益和游戏操作为准；保持正式入口可回退。
