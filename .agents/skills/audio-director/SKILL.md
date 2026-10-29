---
name: audio-director
description: 为失序之钟设计或优化SFX、敌人声音、钩索、UI和区域环境声音；读取统一风格、事件和许可库，交付可听候选与真实Godot对照，不生成或替换BGM。
---

# Audio Director

从最新main独立分支，读AGENTS、当前状态和[音效入口](../../../docs/audio_director/README.md)。沿Cloud Production与game-quality-gate/animation-vfx/project-integration，不另建验收体系。

用户短指令如“优化钩索声音”：先执行 `python3 tools/audio_director.py brief '优化钩索声音'`，读取输出绑定的完整Style Bible、Event Catalog、source/recipe/runtime配置和当前候选。brief是上下文路由，不代表已生产或已验收。

1. 读真实事件调用与声音家族；确认用户要改善的触感、材质、时长与疲劳问题。既有反馈直接迭代，不让用户重写长Prompt。
2. 从已审查CC0选用原件或新来源筛选，逐素材保留URL/作者/原文件/许可全文或来源页面、商业条件/署名/日期/SHA。Sonniss为专有许可，禁止AI训练和独立素材再分发；未逐项核验不进入库，不能当CC0。
3. 更新明确版本的recipes，原候选与失败保留。`python3 tools/audio_director.py build` 与 `validate` 实际执行；输入指纹、参数、输出与加工器版本可追溯。不能用纯正弦/随机噪声充当主要素材。
4. 扩展现有GameAudio接口和共享12voice池，仅消费accepted事件；保伤害/物理/操作/资源/RNG/save。钩索/持续音在取消、死亡、卸载清理。正式默认原版，用户选定后再按明确授权推广；选择文件记录候选ID/版本。
5. `python3 tools/audio_director.py lab --output build/audio_director/lab-FRESH --game-url ACTUAL_URL` 建实际可听手机页面；复用正式Godot Lab/Cloud Preview交同源动作。新候选不能用旧Web包冒充。
6. 执行相关最小测试与独审，独立Preview验证实际URL、metadata和完整字节；不能部署时给真实下载包和准确阻塞。用户听感/真机维度未验保留，自动指标不签商业品质。

未来敌人/区域需要实际新选材和配方；brief不能自动完成创作。连续两轮不改善就更换原料/层次，不能只增强响度或数量。保留五首用户BGM原字节，试听真实混音。

## 当前试听迭代

用户已拒绝v1 A/B，原起跳/落地获得正面反馈。以brief输出的candidate_version和next_command为准；V2使用tools/audio_candidates_v2.py与config/audio_director/v2，不能把原audio_design.py的v1重建当新方向。新音色必须在[情境试听](../../../docs/audio_director/listening_v2.md)的真实UI/拾取/战斗中对照；开发fixture/单事件焦点明确标注。用户仍未批准V2，不能自动全游戏推广。

## 当前V3功能与录屏工作流

优先读取brief绑定的[功能风格V3](../../../docs/audio_director/style_bible_v3.md)和[增量事件目录](../../../docs/audio_director/event_catalog_v3.md)，金币是清脆收集、回血有液体、宝箱/长道具获得分开，按真实武器身份，不复制商业原轨。旧v1否决与V2未选保持。V3采用tools/audio_candidates_v3.py和config/audio_director/v3；以brief.next_command为准，顶层旧build/validate保留v1复现意义，不把它当新版生产。

用户只要看着选时，复用tools/capture_audio_reels.py真实MovieMaker原音轨＋tools/audio_reels_lab.py打包；单事件/实际接受结果/正常速度/字幕与MovieWriter帧绑定，不能静图配音。使用新audio_reels_validation.py的稳定局部能量/直接dot后验及同帧双层联合证明，旧4d报告里无效的>1相关值不能作证；新后验不改旧媒体/回执，技术通过不代签听感。网页先fetch缓冲所选小MP4并用Blob URL跳段，兼容不支持Range的私有托管；验证Stop/换片时延迟下载不可迟播/覆盖，保留直接MP4/ZIP下载；手机/Safari另验。仅HTML更新可用--refresh-from复用已指纹验证的音画，不重录不改声音。

[实际录屏交付](../../../docs/evidence/audio_director_03/README.md)保源/工具/发布身份、用户反馈与失败。默认original；用户逐事件选定后再制作所选组合混音并按授权推广，不把整套ABC自动采用。

## 2026-10-28 用户选择

先读取[保留选择原件与归一映射](../../../config/audio_director/selected/selected.json)。金币/回血/宝箱/脉冲枪A，道具/UI三项/主角伤C，命中/敌伤B，手里剑/炸弹原版；炸弹爆炸是复合原版选择推导，不伪造另一条用户明选。13明选仅批准单项偏好；整体混音、正式推广与实体设备另验。`brief`输出user_selection，不再把这些已选项写成全未选。

后续收到JSON使用tools/audio_reel_choices.py按原reels/manifest/WAV指纹验证，原件逐字保留；缺选original并保unknown。`GameAudio.configure_selected_profiles`仅显式配置，`set_audio_profile("selected")`复用原voice池逐事件分派，未选保原消费者。重录可用`python3 tools/capture_selected_audio.py --output build/audio_director_04/FRESH`，录前重算原件映射，10场景original/selected对照，原生音轨与帧锚保留，不代签自然完整关卡。

## 两区环境音

“开发/优化环境音”先运行brief并读取[环境音工作线](../../../docs/audio_director/ambience.md)、两区完整原Bible与ambience sources/recipes/manifest。使用tools/audio_ambience_design.py的fetch/build/validate恢复真实CC0录音，不把V3短事件加工器当环境生产入口。大录音留忽略cache，按URL/SHA可恢复；许可页与原件记录保留。GameAudio拥有的GameAmbience仅显式开发启用，2床/2点声独立预算，原12短SFX池与正式original默认保留；点声只声源真实定位或明确fixture，不能声称完成全地图布点。

用tools/capture_audio_ambience.py原生MovieMaker交两区同Seed/输入original/A/B；tools/audio_ambience_lab.py打包手机章节、原生BGM混音与淡出后环境单听、许可、选择导出。波形/循环接缝/实际播放通过仅签技术，不签自然感、录音污染、疲劳或用户认可。原先13项SFX选择不推导环境音选择；推广到正式仍按明确用户选择与授权。

## 家园与NPC生活音

“家园环境音”先读[家园工作线](../../../docs/audio_director/home_ambience.md)和brief的AUDIO-HOME-01上下文。复用已选quiet-02平原A原字节、单独home manifest，不重建或改签两区选择；tools/audio_home_design.py生产8条获许可生活拟音，HomeAmbienceAudition只绑定实际keeper/home_root，静态NPC无动画动作信号不能假称同步。真实Home原BGM对照由tools/capture_audio_home.py与tools/audio_home_lab.py交付；原工坊/root与previous-v1保留，子页/home/是新候选。
