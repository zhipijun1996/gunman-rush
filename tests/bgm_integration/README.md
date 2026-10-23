# DEMO-BGM-INTEGRATION-01

私有工作线 `feature/demo-bgm-integration`，基线 `759695c611d71dcd8f1350e22ff82e2b85ac22c8`（四线合成树）。用户本轮已提供五首 MP3 并明确要求接入，覆盖旧“BGM 待用户后续提供”的待办；未生成或改编音乐。采用 animation-vfx 的真实事件、音频生命周期和分层验收要求。

五首原件共19,552,233字节，均44.1kHz双声道，原文件名、SHA256、长度及游戏内用途见 `assets/audio/bgm/provenance.json`。仓库仅改ASCII文件名，MP3逐字节相同。作者/单独许可证未提供；asset_records记录本游戏使用授权为restricted，不伪称CC0或实现者原创，不推定额外授权。

`GameMusic` 是 App 本地双播放器，与GameAudio的12个SFX voice分离。Title/Home及无地区语义的开发实验室共用家园曲；真实平原/森林探索、Boss Encounter实际active/health状态选择相应曲。死亡/放弃回家、重试及debug两图沿同一正式消费者；不改规则、场景、Definition、伤害、RNG或存档。无新UI：读取本App原GameAudio总音量、沿用Master静音；暂停保留播放并柔和降6dB，恢复不从头重播。默认音乐增益0.16再乘原总音量，0.9真实秒交叉淡入淡出；同曲请求不重启，快速返回尚在播放的曲也复用原位置。Web等待首次实际输入按下再启动，不吞输入。

原MP3未提供专门循环接缝，Godot从原曲末尾循环到0；不修改音乐以掩盖接缝。曲间衔接、默认响度与循环听感仍待实际听音；Dummy音频通过不能签听觉品质。

定向恢复命令（从本工作树运行，使用隔离用户目录）：

```sh
source /workspace/scratch/integration-four-20261023/bgm-env.sh
bash tools/godot.sh --headless --path . --editor --quit
bash tools/godot.sh --headless --path . --audio-driver Dummy --script tests/bgm_integration/runner.gd
```

必须退出0并完整出现 `BGM INTEGRATION: N checks, 0 failures`；结构化实际状态在 `build/verification/bgm-integration/report.json`。每区两图使用真实App、生成stage、正式Boss和原伤害政策；只有出生/进入竞技场位置、Boss终结伤害、玩家终结伤害为明示fixture，不冒称自然通关。原生Window输入验证延期启动/取消及死亡页鼠标重试，原设置Control信号验证音量/静音；不是实体手柄、触屏或浏览器AudioContext认可。

本轮失败原件保留在build：首导入bool推断错误；first测试WeakRef推断错误；second的83项/3失败（未等待玩家真实保护期）；third的86项/2失败（原生指针缺motion）。未放宽断言、保护期、timeout或修改玩法；retry还要求新run epoch，避免旧IN_STAGE误判。fourth已88/0。新增正常owner退出反例首次89/1：测试await函数内get_stream_playback临时强引用阻止自身弱引用释放，改用非异步helper返回WeakRef；独立原生产退出probe实际14ms释放、退出0。最终定向回执另列。五份新增asset_record已单独通过原 `quality.validate_asset`，未跑全仓quality或恢复历史。

检查点：GameMusic和DemoApp最小挂接可供总控cherry-pick；真实App/MP3定向回执随本地build保留，提交SHA以Git为准。不自行PR、merge或deploy。GPU、听音、真实Web首次输入解锁、用户评价、设备和完整集成/Release均未验；由总控完成合成交付。中央tasks/current_state/handoff及其他工作线文件不在本线写集。

最终：`build/bgm-directed-final.log` 为 **89 checks / 0 failures、退出0**，正常退出弱引用反例也通过，无脚本ERROR/退出泄漏；`build/bgm-import-final.log` 导入退出0。`build/verification/bgm-integration/source.json` 保存被测运行文件/原MP3/导入metadata完整SHA，`report.json` 保存实际App/四Boss/播放器状态。此前失败JSON另存同目录，日志不改签。
