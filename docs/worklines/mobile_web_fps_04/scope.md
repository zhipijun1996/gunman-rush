# MOBILE-WEB-FPS-04

用户询问当前帧率与保持质量的提升空间，并以“好的”接受先测 Release 对照、前景阶段耗时、再针对热点优化。

基线为当前 main 5f55716a838a754a938997920ff18cb3b17452b5，公开 ad78f8ae3998；此前音频修复及165项CI来源保留。荣耀60Pro Chrome 的当前数值FPS/P95未知，云端SwiftShader不代签手机。

固定真实 demo.tscn、1280×720内部画布、原DPR/画面比例、同种子与真实菜单进入。先用同一原PCK对比官方4.7.2 threaded Debug/Release引擎；这是引擎模板单变量，不冒称完整Release导出。诊断包只追加有限计时/观察，不更改角色、RNG、世界、灯光、遮罩或音频状态。记录实际样本数、帧间隔P50/P95、process/physics、绘制计数和前景分阶段inclusive耗时；嵌套耗时不相加。

热点确认后仅做可证明画面/行为等价的局部修订，保原前景保护、过渡、灯光阴影、原PNG与全部声音。没有可靠收益则不采用。验证真实当前消费者和边界、对照像素/状态、音频回归及独立审查，保留失败与测量噪声。开发结果按既有快速路径提供明确试玩入口，正式入口与旧对照保留。此新工作线不自动沿用上一轮PR117合入授权。

使用 game-quality-gate（small_fix）、project-integration。root拥有唯一Godot/浏览器租约与生产修改；独立agent分别负责纯Python引擎配对与浏览器runner，验证前冻结源码。任务保持in_progress/awaiting-device，质量维度只按实际证据填写。
