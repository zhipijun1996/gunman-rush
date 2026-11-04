# Sound Lab V2 · 放回游戏里听

任务 AUDIO-DIRECTOR-02。用户拒绝v1 A/B，认可原起跳/落地；本轮只重选UI、拾取、命中与受伤，未要求的原动作/枪/钩索/死亡与五首原BGM保留。三套新候选均为awaiting-user，不能把本轮工程通过写成听感批准。

[候选与来源](candidates_v2.md) · [真实工作线](../worklines/audio_director_02/scope.md) · [实际证据/最终网址](../evidence/audio_director_02/README.md)

## 比较方法

先选界面、拾取或战斗，载入真实Godot场景。用原版看/听一次，再在同一场景切方案1、2、3并重复；音乐可选原五曲或关闭。换方案只改变声音，示范重新建立相同的明确开发初始条件，便于反复比较。保留原起跳/落地，不重新考察已经喜欢的基础动作。

- 界面：实际按钮点击，以及原ShopService的接受交易和余额不足拒绝；不是只放一张菜单图片。
- 拾取：原主角通过真实Router行走，与可见拾取Area接触，调用原金币、生命和普通奖励服务；不是按按钮直接播放声音。
- 战斗：原主角弹体/敌人/损伤服务发生真实HP变化；受伤示范通过敌人真实弹体。敌人命中与敌伤是同一伤害中的不同反馈层，工坊默认单事件焦点避免双响；焦点对原版和候选一致，正式游戏默认不调用这项隔离。

这些是开发试听fixture，物件位置、训练对象与重置条件有意固定；不代表自然进度、完整AI、Boss战或全游戏混音验收。界面直接展示当前上下文、已确认套装、最近实际事件；按“演示此场景”或进入游戏画面自己操作。手机横屏/全屏便于看动作；首次网页音频可能需点一下场景内解锁按钮。

展开单声区可听每个事件的原版和三套候选，查看原素材/作者/许可/加工版本。单声与场景互斥，只有场景确认静音后才启动单声，防止两边叠放；停止/切场景/页面后台会取消待播放回调。

选择只存当前浏览器，导出JSON后可回传。ID、版本、上下文与备注会保留；不声称已经远程同步偏好。离线比较ZIP包含单声、五原BGM与许可，游戏PCK另由站点加载；ZIP会禁用缺失的游戏入口，避免离线404冒充场景。

## 生产与重现

```sh
python3 tools/audio_director.py brief '优化命中和受伤声音'
python3 tools/audio_candidates_v2.py build
python3 tools/audio_candidates_v2.py validate
python3 tools/audio_lab_v2.py build --output build/audio_director_v2/listen-FRESH
python3 tools/audio_lab_v2.py stage --bundle build/web --output build/audio_director_v2/site-FRESH
```

真实Web核验可运行 `node tools/sound_lab/verify_context_v2.cjs http://127.0.0.1:8773/ build/audio_director_v2/web-actual EXPECTED_BUILD`，需先用HTTP服务托管本轮stage目录；它执行真实iframe、20组事件比较和非零音频后台观测，软件Chromium不能代签听感或真机。

`stage`先验证原Web报告与精确PCK，再把本轮真实场景作为入口；已有Sites大资源沿项目原ServiceWorker逐块SHA重构，显式要求现代ServiceWorker/DecompressionStream，不冒称raw fallback。新游戏源变化必须重新导出，不复用v1包冒充V2场景。
