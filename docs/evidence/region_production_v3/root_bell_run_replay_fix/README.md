# RootBell v11 RunManifest 回放：正式兼容修复

实际完整region15首先发现未修改的 campaign_map 在3705断言中有3项失败：首图JSON回放、两图JSON回放、native StringName modifier回放均null。原失败全文 `original_region15_failed.log` 保留。

## 根因与最小正式修复

RootBell准入后的生成器已真实输出 `plains-region-v11-root-bell-v2` 的 stage_generator、generated_layout 和 enemy_layout；RunManifest 的根版本和验证仍硬编码v10，拒绝自己的正式输出。

现有 enable_plains_region 增加可选明确内容版本，仅允许原v10与已实现v11；默认仍v10，未知版本返回false且不修改原数据。DemoApp仅在首图用真正生成结果绑定RunManifest。验证用同一明确根版本约束每图stage_generator、generated_layout.version、enemy_layout，原配置/能力/合法modifier/时序身份/完整重生成/hash检查保留。不接受混合版本或任意未来版本，不改schema、RNG、资源、存档和物理规则。

旧40个v10正式Manifest原字节对照、10个物理拒绝和21actor旧mapState loader函数全文作为新专项的原字节前缀保留。原campaign_map文件与base字节一致，全部3705断言原样。旧显式map2/stageState兼容证据不追认为完整RunManifest回放；新增完整两图回放另取真实快照。

## 实际验证

- audit_03：真实原40rows/1eligible/0failures；旧10物理拒绝与旧loader全部通过；新5项正例和9项负例通过。当前v11与明确固定的旧v10各自真实DemoApp首图native/JSON回放、两图native/JSON回放、实际StringName合法modifier、每图逐字节重新生成全部成立。已准入seed的v11第二图真实含1个RootBell，v10含0。
- 新负例：未知根版本、根版本混配、stage_generator混配、重哈希后manifest.version混配、enemy版本混配、重哈希并同步enemy_layout的敌人位置/RootBell行为篡改、无来源空中资源数值篡改，以及未知enable版本原子拒绝。
- campaign_01：原3705断言/0失败，实际exit0，source_before/after完全相同，没有ERROR或泄漏诊断。

新两图fixture采用既有明确mini-Boss outcome fixture切图，并通过真实BuildState加入合法brake_boots Definition以验证modifier表示；这是回放/序列化测试，不是假称输入打赢Boss、正常获取奖励、完整通关、磁盘存盘或设备体验。native与JSON各自重载需精确保留其输入表示；JSON解析原本允许整数变浮点，不能错误要求跨表示canonical字节相等。

## 真实返工与未验

audit_01因新增测试局部类型推断编译失败，停止实际PID285517，退出143；失败源、log、终止收据全保留。audit_02完整执行，但新增测试错误地要求native和JSON解析后canonical跨表示完全同字节，导致正例误报；真实诊断确认v10/v11均accepted且保留各自输入。仅修新增测试局部注解与正确的逐输入表示比较，未改旧断言或放宽RunManifest。原两次失败没有改签。

audit_03真实有20 ObjectDB/17 resources仍在用的退出诊断；本包不签clean生命周期、性能、玩家或设备认可。campaign_01无此诊断。没有改其他测试以消除红字。不同代理只读独审另行保存，本实现者未提交。

## 来源与复现

actual_native_originals.zip和索引保留所有原生原文件；before/两轮失败源/after/完整diff/冻结SHA保留真实修复链。四份完整source_before/after均各806项且各自相同，source_reconstruction把全部SHA逐项重构为事后选定Gitbase `7e5dc0e256efdc04aad742bbd485b78e571a495b` 加5个实际dirty源码（本包四个与父任务pressure fixture）。启动helper未记录startup HEAD，不能倒填为当时HEAD；这里明确只将该base用于可复核的字节重构，未改原receipt。

实际入口为 `GODOT_BIN=.../build/region_production_v3/godot_locked.sh bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/root_bell_formal_runner.gd -- --output=res://build/<new>/audit.json` 和相同引擎参数运行 `tests/plains_campaign_map_runner.gd`。应使用新的输出目录，不能覆盖这里的失败原件。五次实际Godot调用（含一次编译失败和一次只读诊断）无图生、无新增原host模型名额。
