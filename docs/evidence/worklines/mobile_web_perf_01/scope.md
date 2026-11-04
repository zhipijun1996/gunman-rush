# MOBILE-WEB-PERF-01

用户2026-10-29确认UI与画面已恢复，要求调查移动Web家园/关卡严重卡顿、菜单较流畅、BGM/环境音断续与动作音效缺失。既有设备信息荣耀60Pro/Chrome横屏，最新用户称华为手机，不推定新增真机已连接。

## 冻结基线

当前正式公开Web 2caa023125bd，运行源4707b9ef15fa7e89b09d3e33ef8206c0b12f64af，完整PCK SHA256 2caa023125bd6fcf2b960dcdf5ac60a6a7abdbfeb643ef0b661f80f6a15d5a31，208691576字节。源码759a828b包含其后仅证据/工具更新；main仍1b29932，PR115 UI修复待合但用户已认可，当前调查必须保留此已发布UI修复，不回退main旧低分辨率/比例实现。新分支fix/mobile-web-performance-20261029，未授权自动merge。

先读取scratch/gunman-performance与gunman-audio-diagnosis旧原件并保来源；旧618eb971低分辨率包的SwiftShader结果不当新基线。云端Chromium SwiftShader与原生headless仅定位候选，不代表Adreno/荣耀真机帧率。保同一引擎、1280×720内部RT、DPR/viewport、Seed、站位与有效渲染数量，记录帧样本数/预热/顺序/脚本嵌套成本，不把阶段包络与子函数相加。

## 独立A/B

1. ambience_off：停用SelectedAmbienceRuntime及它独有的Home life/selected床与点声，原BGM与SFX保持。
2. foreground_render_off：只关前景CanvasLayer可见性，CPU刷新/Shader参数上传继续，另报effective_drawn。
3. foreground_update_off：baseline预热至前景实际已显现后冻结其更新，保留可见居民/Shader与当前uniform，不从启动冻结alpha0空层。
4. shadows_off：只关动态灯shadow_enabled，保灯/颜色/bloom/PCF配置其余值。再独立lights_off剖析灯pass，保bloom。
5. hud_avoidance_off：只停DemoApp._layout_region_hud动态避让，资源/HUD文本/菜单输入继续；Home不调用此函数，作为负对照。

每组恢复baseline，重复/倒序识别温漂。Home与正式plains相同路径/Seed下记录FPS、P50/P95 wall frame、Godot process/physics、实际函数计时、draw calls/objects/primitives/纹理与buffer内存/灯/阴影/前景实体和mask数量，GL renderer及可用GPU timer（不支持明确不可测）。真实菜单对照独立，不把pause_tree_only当Home菜单。

## 音频与后续

触发、接受play、拒绝原因/voice占用、Web AudioBufferSource starts、STREAM播放器状态/浏览器AudioContext与实际PCM/AudioWorklet underrun分别采证；混合PCM不证明某音色被听见。自然路径与显式压力fixture区分。先基线与独立消融，再对证据热点剖析/修复，保原画质、功能与音频事件。无证据不删特效/换美术/降分辨率/降采样率。

交付可审查根因证据、修复前后同条件测量及可供真机点击的基线/独立开关/候选对照。对照必须清楚标诊断选项，标准试玩保原画质；不冒称真机稳定流畅已达成。可导出诊断数据供真机反馈；真机与玩家认可仍awaiting-device。遵循project-integration与game-quality-gate的小修风险检查，运行相关原生/渲染/音频/GUI和docs/web门禁，保失败与独审。

## 最新用户复核顺序（覆盖前述后续候选优先级）

用户重复明确以main1b29932c/Godot4.7.2为调查基线：先实际公开JS/WASM与main的版本审计，再独立启动单Master/原ensure_buses多总线、相同短样本Sample与Stream的实际destination PCM；单Master不得事后改bus。随后single Master内比较一次play后的无pause写入/每帧false/仅变化setter，记录browser create/start/end，不以GD play计数替代。先交付这些最小原件及真实demo.tscn四case正式A/B（original、bus_only、pause_only、ambience_off），分别报告帧时间与动作音效输出，再做生产修复；线程、SAMPLE整首BGM、透明片元等旧探索暂停，不把它们混成正式候选。

公开UI修复包2caa/source4707不是main1b原包618。GameAudio、GameAmbience、SelectedRuntime及demo.tscn在两源逐字节相同，但WebRT/UI/前景保护换算不同，绝不把不同画布策略的绝对FPS当音频修复收益。正式四组先从原main1b PCK618派生、仅测量包装及四case条件；JS/WASM及原画质在四组完全相同。用户认可的当前UI/网页不回退、不写生产修复。旧30+26组和Master事后修根路径仅保留preliminary来源，后者不是有效单Master启动对照，也不能修复整张已乱序总线。

## 最新真机反馈与已交付根因证据

用户补充“其实只是声音卡，动作几乎不卡；暂停页面声音也不卡”。主目标收敛到音频，不再以云端SwiftShader慢帧解释手机。已完成原main1b最小复现与真实demo.tscn四组A/B，并先向用户报告结果：原add_bus默认追加破坏Web Sample总线索引/路由；环境细节声每帧重复unpause导致native Source反复重建。两者独立，bus_only恢复真实家园/平原动作声的混合PCM，pause_only无法绕过总线故障。

据此授权内只修GameAudio的创建bus路径与GameAmbience暂停状态写入；不改声音素材/音量/循环策略/原五BGM/画面/玩法。公开修复版继承已认可UI；另保留同UI原2caa包供真实手机前后对照。最小和正式场景证据保留全部失败窗口和复核边界。正式合并main与完整CI另行处理，不把临时部署或云端录音签成真机BGM全连续。
