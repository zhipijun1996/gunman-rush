---
name: audio-director
description: 音效、事件声音、环境声及正式听感迭代。
---

# audio-director

## 适用任务

音效、事件声音、环境声及正式听感迭代。

## 操作

1. 从 `docs/audio_director/` 和 `config/audio_director/` 定位声音风格、事件、当前选择及许可；核对实际运行音频宿主。
2. 按事件区分起手、接受、命中、取消与结束，先交少量可听候选，再将选定版本接实际Godot事件。BGM使用用户提供素材。
3. 控制并发、衰减、优先级、重复抑制和Run／Stage／Actor释放；相同条件记录真实原声对照。

## 验证与交付

用相关音频Harness专项和正式入口连续试听，验证取消／暂停／退出及资源清理。交付音频文件、许可、事件映射、听感候选与用户选择状态。

任务使用 [现有设计卡](../../../docs/templates/iteration.md)。质量阶段、独立审查、证据与未验声明共用 [开发质量](../../../docs/development_quality.md)；验证选择见 [Harness](../../../docs/harness.md)，代码落点见 [模块导航](../../../docs/module_map.md)。
