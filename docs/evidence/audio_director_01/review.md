# AUDIO-DIRECTOR-01 独立审查

审查者：`/root/independent_review`，独立子代理；未编写所审生产或测试代码。仅写本报告。基线 `26e7f2a4459623f35613a857da8a75e89daa3e62`；本轮审查对象为该基线上的工作区候选，最终精确交付SHA由主线收据绑定。阅读 AGENTS、gameplay-reviewer、GameAudio全链、钩索/敌伤调用、Lab、来源/配方/manifest、加工器与HTML。

## 初审：REVISE（工程缺口）

### AD-R1 · 配方/来源/加工器漂移不被validate拒绝

位置：`tools/audio_design.py:validate` 和 `build(--event)`。

事实：manifest保存三项SHA，但validate只核嵌入的sources与输出文件；不比较当前recipes.json、sources.json和加工脚本。部分重建也可把未重建事件保留并把顶层指纹更新成新配方，造成整个版本均来自新配方的假象。

实际只读反例：导入该模块，在临时文件把shot.target_rms_dbfs改为−55，令模块RECIPES指向临时JSON，再执行validate。实际退出0，输出 `AUDIO_DESIGN_OK events=16 rendered_files=64`。生产文件未变。当前冻结产物的三项SHA恰好均与当前源一致，因此这不是声称当前64文件已经漂移；它是未来迭代会漏检的可复现守门问题。

最小返工：validate核当前三指纹；部分重建在其他事件配方/来源/加工器漂移时拒绝，或按事件存逐项可证指纹。要保留真正的单事件快速迭代，不需要强迫所有事件每次全量重建。新增反例必须证明旧失败被拒绝。

### AD-R2 · 下载包保留五曲选择但不包含曲目

位置：`tools/audio_director.py:lab` ZIP构建。

事实：ZIP排除整个music目录，却包含带5个音乐URL的lab.json与同一试听HTML。按README解压并启动HTTP后，选择BGM会404；README没有明确离线包不含音乐。

最小返工：ZIP包含授权内原MP3，或在ZIP专用lab.json将music置空并解释在线版可听五曲。此项不要求改任何音乐字节。

### AD-R3 · 手机Godot工具栏触达风险（未证实失败）

位置：`scripts/dev/audio_director_lab.gd:_make_lab_ui/_layout_lab_ui`。四个最小100px按钮位于HBox，另有长单行状态Label。窄viewport可能被最小宽度撑开。须以实际Godot Web尺寸/截图和点击核验；静态尺寸仅为待核候选，不能当已发生溢出。HTML布局与Godot布局分别验证。

## 独立执行与已证范围

以下命令均由审查代理实际执行，退出0：

- `python3 tools/audio_design.py validate`：16事件、64输出，当前文件指纹与峰值/非静音检查通过。
- 纯Python逐字节对照 `git show 26e7f2a:<five-mp3>` 与工作区：5/5完全相同。
- 纯Python枚举manifest：32候选ID唯一，64输出SHA唯一，每方向两变体；runtime配置16事件集合与manifest一致。

静态已确认：同一个12voice池；original为默认；A/B仅显式选择；候选随机使用局部RNG；EnemyActor只改已接受受伤后的表现调用；钩索只订阅原action_changed；死亡/离树/phase清理不写玩法状态。未发现伤害/物理/资源/操作规则修改。Bus新建0dB路由保留原MusicGain与五MP3。

作者/其他代理的引擎证据已阅读但不冒称审查者独立执行：`runtime-final` 41/0、`original-lifecycle-first` 37/0、`lab-smoke-third` 25/0。首次导入及Lab缺元数据失败保留。受主线引擎独占要求，本审查没有启动Godot。

## 未验与不能签署的内容

没有聆听音轨，不签“悦耳”“风格已统一”或商业品质。没有实体设备，不签手机扬声器、耳机、触屏手感、延迟或性能。尚无本审查独立实际自然战斗/完整钩索动作/全流程奖励证据；静态accepted调用和Home专项不能替代它们。公开URL、完整PCK与最终浏览器交互由主线按实际发布收据另列。

来源事实：新候选选用CC0，并保作者/原件/SHA/URL/日期/许可；Sonniss403未入库且明确专有条款。原版Freedoom为BSD-3-Clause，不称CC0。审计固定main快照，历史三轨未知信息显式保留；未误把新候选数量当原库审计数量。

## 复审

待作者针对 AD-R1/AD-R2 修复后，审新文件与反例。初审发现保留，不能将原先validate误通过改写成拒绝。


### 复审一 · 工程范围 ACCEPT，听感/真机 UNVERIFIED

审新版本后实际执行：`python3 -m unittest discover -s tests -p '*audio_design*' -v`，6项全部通过；`python3 tools/audio_design.py validate` 仍为16事件/64输出。再次执行同一临时−55配方反例，现在明确拒绝：`Manifest recipe_sha256 changed; run a full build before validating or retaining other events`。新增测试同时验证原件变更、来源snapshot篡改、加工器变更、partial drift在写入前拒绝，以及未漂移单事件重建逐字节一致。**AD-R1关闭**；原误通过事实保留。

审查代理独立读取 `build/audio_director/listen-local-third/audio-comparison.zip`，逐个解析其中lab.json：五个音乐路径全部存在且与记录SHA256一致，16事件所有非空候选/原版路径存在。现在ZIP包含五原曲，**AD-R2关闭**。

补充未映射关键声音范围：最初静态发现A/B满池时原版warning/death仍会丢弃。作者已将仅A/B中的death/warning/boss_impact接入严格较低优先级抢占，original保留原策略。已阅读作者 `runtime-critical-review` 的exit0与60断言/0失败，并静态检查新增分支无新播放器/玩法写入；本审查未启动Godot，不把该日志改称独立执行。

AD-R3源码已改HFlowContainer与状态自动换行；原静态风险不等于实际发生失败。最终Godot Web尺寸/点击由主线真实浏览器证据记录，在本报告中仍为GUI待核，不虚签实体触屏。

结论范围：已实际独立验证的加工指纹/原件/输出、下载包路径、BGM原字节与当前静态表现接口可接受。审计与候选系统可以进入用户试听；这不等于候选审美已通过、所有正式消费动作均独立跑过、完整Integration/Release完成或商业品质。音画同步听感、自然战斗与真实钩索、公开部署和设备仍按实际收据分别验收。

复审时关键文件SHA256（绑定本次范围，最终提交SHA见主线收据）：

- `scripts/audio/game_audio.gd`: `e280cca56f33bfd67ee16e3deb7e363928cf8d588ba9186e84eb0af4e6f5db04`
- `scripts/audio/game_music.gd`: `6fe57ccecc3c68b5a9551f140bba5f50705a7276efd776453ff3c7b42499f3ed`
- `scripts/art/player_feedback.gd`: `9d03e2cc1e54b93e74a84fa24c83610b7046ae4cbca4ab55047714d4d85654bf`
- `scripts/enemies/enemy_actor.gd`: `fd53659f38f6d52a75cb5b27986bb12cb090e43d75f23327a61e087a9c06eb6d`
- `scripts/dev/player_presentation_01/motion_audio.gd`: `433e31a412cee8de576eefb68ca7db2e68d07455b204b3f41558e06560eac7f3`
- `scripts/dev/player_presentation_01/weapon_audio.gd`: `bcab201f586fb57ba5cdaef847bc9053d4b8fab88318a5bebc343e4714dd4d11`
- `tools/audio_design.py`: `1eba26f41f7ef0d7db55a15611586b10864a52d3cb44354679c6084abb3dcd08`
- `tests/test_audio_design.py`: `cc293b25617f56ae4f948deaffdd67e10bf94442c335c28b8106561e69f0c1ac`
- `assets/audio/director_candidates/manifest.json`: `353a041977814db5f70d13f00af7546ade187326e49de051bf91311e3108eacd`
- `config/audio_director/runtime.json`: `7d6c0a54260dff759bc6734eccc48320705cde1d6dcf6c5b648f7cec6f4e1db9`
- `tools/audio_director.py`: `2ac7a6dd2c1852987ee0ed45e3e52d4515db9d8fa69da14a21ed520f300d2c9c`
- `tools/sound_lab/index.html`: `580033e4e6b3620c6e533c6ce18a69e8c336dc65deb4f50a7e5b561030276fa1`
- `scripts/dev/audio_director_lab.gd`: `2a407b5f244dcece58d8031e55d2376238d3a25c1b123fc0c2f76677f5166e7c`
