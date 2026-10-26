# AUDIO-DIRECTOR-02 · V2情境试听交付

[打开新版手机工坊](https://clock-audio-director-lab.silkyball18.chatgpt.site/?v=2&build=1048defde2ef) · [单声/BGM离线比较包](https://clock-audio-director-lab.silkyball18.chatgpt.site/audio-comparison.zip) · [独立PR109](https://github.com/zhipijun1996/gunman-rush/pull/109)

本轮按用户反馈重做3套现成CC0：A实体轻触、B轻响拾取、C短机械。9事件×3套×2实际不同原take=54 WAV，原音高/单原料/自然尾音，只裁外侧静音、淡边与受限增益；原起跳/落地、未要求动作及五首原MP3保留。v1 A/B的用户拒绝保持原判；V2听感、真机与商业品质均未签。

## 真实试听

选界面、拾取或战斗→载入真实场景→点击游戏内“开启声音”→原版/A/B/C同场切换→演示或手动操作。手机横屏/全屏；首次游戏资源约186MB，单声无需下载游戏。可同时听五首原BGM，按事件或场景记偏好，再导出当前浏览器保存的ID/版本/备注。

这是明确的开发fixture，复用正式Home/角色/ShopService/拾取Area/钱包、回血、奖励及EnemyActor/弹体/FrameDamagePolicy。角色真实行走接触拾取，UI真实交易与余额不足，战斗有真实敌我HP变化；不是静态图或直接按钮放音。拾取用合法初始4/5生命，静默准备，不夹杂额外受伤。武器命中层和敌伤层单独聚焦，原版与候选一致；不代表自然进度、完整AI或全游戏混音。

## 精确身份与检查

- 游戏运行源 `08df881cb3b84626f4c0fe638d86d2f86935cbe8`，build `1048defde2ef`；PCK185858020B，SHA256 `1048defde2ef0797cf2b7ada204d3af7783cba4ac82252e0a19552aae4c75a2d`。
- 网站源 `9a56f0279fa4ea258e708b46b69c153844fe3221`，Sites版本3；原owner-private受众不变。[原生发布成功收据](deployment.json)。这是明确的新版网址，不拿v1包冒充。
- [最终原生66/0](native-frozen/report.json)，严格runner退出0、30.490秒，原90秒预算，零运行/资源错误和退出泄漏；[运行输入指纹](native-frozen/provenance.json)逐项匹配冻结提交。另先前共享音频60/0、生命周期37/0保留原阶段身份。
- [最终真实网页20组](web-actual-final/report.json)：3上下文×4方案，加敌人/主角受伤2焦点×4方案；逐组exact实际事件、候选ID与HPscope。拾取每组严格coin/heal/reward；hurt来自实际敌弹。非零音频后台peak0.103271、零运行错误；真实pointer输入，无自动播放绕过。[可复用检查器](../../../tools/sound_lab/verify_context_v2.cjs)。软件Chromium不代签手机/Safari。
- [实际HTML63WAV/5BGM与协议检查](web-protocol/report.json)：单声/循环、停止、后台、延迟ACK、选择导出/持久化；桥部分为明确mock，不能替代上面的真实Godot20组。
- [10项加工反例](dsp-review-tests.log)与[54字节一致重建](dsp-review-receipt.json)；109来源/运行登记有效。独审另以临时ROOT独立篡改trace验证拒绝，原五曲SHA对main一致。
- [冻结docs profile](harness-docs/report.json)33/33，退出0、396.628秒、jobs1；原underworld152项152.501秒，预算180不改。随后只改交付文档/证据和Web验证工具，最终相关元数据检查另执行，不将其冒充完整Integration/Release。
- [独立限定工程ACCEPT](review.md)：R1–R6闭环。审美、设备与自然完整混音未批准。

## 保留失败与剩余项

[第一次Web](previous-web-first/report.json)是340b249b/build71031d53，拾取准备使用真实敌弹，确有非目标hurt；不是虚构回执。R5修复后以最终20组重验，不覆盖旧事实。[首次docs源漂移](previous-docs-drift/report.json)来自校验同时恢复Foundry输入；[第二次docs超时](previous-docs-timeout/report.json)保留。先单跑原runner152项145.860秒，再冻结源码独占原wrapper通过；未放预算或删断言。

已知非阻断UI问题：某些画面内pointer已解锁音频，但父页只在专门解锁回执后更新提示，可能继续提示开启；点专用“开启声音”按钮会同步。竖屏内按钮较小，提供全屏/独立入口。实际运行和听感分开，不能把后台非零音量当悦耳证明。

五曲与所有选用来源的许可在工坊/ZIP展示；ZIP不包含185MB游戏PCK，会禁用离线游戏入口，避免假装可运行。Sites托管沿原SHA分块重构，显式要求ServiceWorker+DecompressionStream；不声称raw fallback。未验证实体手机、Safari、耳机/扬声器、完整自然战斗/钩索或全量CI；默认游戏仍original，待用户选定事件后再按授权推广。不合main。
