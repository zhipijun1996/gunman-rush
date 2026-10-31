# AUDIO-HOME-01 · 平静家园与稀疏生活声

新任务消费用户家园平静/NPC生活音要求，复用已经选择的quiet-02 plains_a原字节，在home另−2dB，不改原BGM、MusicGain.16或玩法。8个CC0真实录音点声，四实际keeper位置的布料、木件、工具、纸页；静态NPC无动作帧，不伪称同步。原9文件finite闭包/17反例不改，新helper8路径是真正消费的白名单，新home9件由原scanner识别。

## 保留的失败和纠正

- 第一次加工布料段crest太高，实际RMS过低；替换同一CC0原件更平稳的不同实录段，不提高原床/BGM。首8WAV/manifest保在build/audio_home_01/design-first-render。
- 独审发现同帧input_blocked+pause先return会留下尾音；修为先清点声再暂停，并用实际voice/关闭后不恢复反例验证。发现重绑新audio服务遗留旧audio床/点声；修为成功新配置后清旧owned服务，失败保原态，两真实service/旧Home存活专项验证。
- runtime01两个snapshot动态字段推断失败（未执行checks）；显式int/float修。runtime02真实60项/1失败，错误把无stream闲bed槽的paused=false当未暂停；修成先证明真实床非空/在播，再全部真实床保留且paused=true，原前后真实snapshot保留，不放过任何有效床。runtime03真实60/0，实际controller.die入口/面板/重配/退出及有界teardown通过。
- scene-smoke01运行分支typedArray ternary类型错误，root有界停止仅自有native进程，保原日志/raw/report与清理；修明确typed初始+clear/append。smoke02真实960×540、217帧/33.997秒/source稳定，根实际看PNG无新增字幕遮动作。
- actions01真实3×1560帧/exit0，但headless默认物理window64导致后验FAIL，原trace/report未改签。deferred run显式1280动作窗口、Movie仍严格960，源与原90秒动作预检/900秒原生预算未提高；后续fresh复核另列。

新家园原音轨、手机GUI/公开部署和独立后验待最终收据；历史失败不冲销。用户听感、实体设备、完整CI和正式推广均未签；不是新完整Godot Web导出。

Fresh actions02在deferred显式1280×720下3×1560帧同路通过，27.329秒、源稳定；实际正常生活事件home_cloth_1在clock17.583秒/真实NPC距50.667wu出现。无排程强触，不冒称8素材都在短片出现；8独立素材另供试听。窄smoke实际960画面已看，最终原生全片仍需当前源验证。

## 新完整原生片

producer`a4b2113aa786193a1d653080365f6067dd020880`，3×26秒/4969帧/60FPS，原生录制4分42秒、全包络325.023秒；7,900,638B，SHA `d56076d5610af5f50b7f835046e28b51f8b6286c6d195b299b164bd86cf843a4`。3838源before/after稳定，自有override清理，真实world/HP/位置/镜头/输入逐帧一致。床/音乐实际runtime增益与原native PCM差分验证通过，home_cloth_1一次正常近处事件在17.583秒。原BGM全程保留，片中不强触其它7素材。

首版Home HTML被独审发现内容版本/mix/manifestSHA一致守门不足，未发布。仅新HTML修复、fresh lab02与GUI反例另列；原片和音效不变，不重录。

## 手机交付

[家园/home/](https://clock-ambience-lab.zhipijun1996.chatgpt.site/home/)已部署Site v3；source1bfc4d6...，只新增home，旧54文件/hosting原字节保留（独审直接核旧/新TAR）。nativeproducer a4b；UI/后验包装745分记，没重录/重标旧捕获。实际390px GUI3章/9单听、正常播放/循环/取消/导出与11个身份/manifest原字节反例全过；修前lab01/positive历史保留、只发布修后同字节lab-final。

远端/home全7,900,638B MP4 SHA实核、manifest原字节校验、真实life指针/AAC decoded45827字节/960×540/Stop通过；旧root及previous-v1/manifest HTTP200且SHA仍匹配。参见remote-browser-01、deployment.json、site-source.json、site-preserved.json与独立review-site-archive.json。仍不是实体手机或人耳听感验收。

最终限定工程独审[review-final.md](review-final.md)已冻结，SHA7e4f5621dbb66d0d1d0b11644c6b4703704cb59f1b396a0f290b1e5df4c1b7d7。任务保持review；用户新家园听感/素材选择、实体设备、完整CI和正式推广未签，不自动合main。
