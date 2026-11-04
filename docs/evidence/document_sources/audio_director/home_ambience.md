# 家园声音 · audio-home-v1 / home-quiet-01

## 用户选择 · 2026-10-29

用户在三模式家园试听后明确“底音+生活音”，选择当前home-quiet-01的life整体混音。保留平原A借用床额外−2dB与12–22秒／全局6秒／至多1生活声的正常稀疏节奏。[精确选择](../../config/audio_director/home/user-selected.json)保存原话、manifest／全部音频SHA与真实录屏源。后续brief自动读取；不套用到重加工新版本，不把整体选择说成8素材各自排名或真机验收。


[手机实际场景试听](https://clock-ambience-lab.zhipijun1996.chatgpt.site/home/) · [MP4](https://clock-ambience-lab.zhipijun1996.chatgpt.site/home/home.mp4) · [对比包](https://clock-ambience-lab.zhipijun1996.chatgpt.site/home/home-comparison.zip)（拥有者账号）。


用户希望家园有平原的平静和NPC生活声。沿已选quiet-02 plains_a原OGG字节，家园运行额外−2dB；五原BGM与MusicGain0.16完全保持。[实际事件与代码](home_event_catalog.json)／[来源](home_sources.md)／[运行](home_runtime.md)／[范围与真实权威](../worklines/audio_home_01/scope.md)。该家园life整体方案已有独立明确的用户选择，不由先前两区A/A推导。

声音分为静听的柔风草叶，以及靠近真实居民所在地才出现的稀疏生活拟音：织时匠整理布料、维修工坊木件收放、武器工坊收放小工具、档案员整理册页，各两变体。当前NPC是静态精灵，没有挥锤或翻页动作帧；声音归于NPC所在工作处内部日常，不宣称动作同步。未开放且无NPC的预留建筑无生活声。

原有GameAudio→GameAmbience负责播放，适配层只读实际keeper.home_root作定位；8条路径是实际运行白名单，不放开旧finite9闭包或另造声池。只用1条持续床声和至多1条生活点声，保原2床2点预算；正常每NPC12–22秒、全局至少6秒，远处/忙时丢弃而不补队列，两变体成功后轮换。

对照为原版／仅平静底声／底声加生活，真实DemoApp创建原HomeScene，经同一Router地面路线到织时匠、穿过上层工坊下方；不能把地面路过当成已经上楼互动。原家园BGM全程保留，差分只用于后验核对，不替换录音原音轨。短片不强触全部素材，8声另供独立试听。

加工入口：`python3 tools/audio_home_design.py build` / `validate`，包括新CC0布料实录与已审查木/工具/纸原件的裁切、EQ、轻淡入淡出、低响与峰值控制；新manifest借用床单独bed_reference，不伪造新床render，原A/A元数据/字节锁定。

运行入口：`res://scenes/dev/audio_home_lab.tscn`，明确开发试听、Meta不落盘。后续简短“优化家园环境音”由Audio Director brief读取新风格/许可/参数和原选择，不自动重做两区或改BGM。

自动检查只签来源、波形、电平、正常节奏/生命周期与真实路由。自然感、是否过响/过密、当前life整体选择已记录；真实手机、未来重加工新版本和素材单独排名仍需各自依据。
