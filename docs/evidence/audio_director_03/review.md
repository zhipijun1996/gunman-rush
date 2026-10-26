# AUDIO-DIRECTOR-03 独立审查

审查者`/root/v2_review`，与V3候选、场景、公共接口和网页实现作者分开；只写本报告，不修改生产或测试。任务输入630f3c52，实际冻结提交/录制源待主线后续提供。已读当前AGENTS、gameplay-reviewer、AUDIO-DIRECTOR-03 scope、用户feedback03、Style Bible V3，以及候选pipeline/manifest/recipe/rules、四个公共音频接口diff、reels/capture脚本、专项测试与reels HTML/验证器。没有启动Godot，没有完整重渲染42/54音效；场景代理独占引擎，素材登记仍在刷新，不把制作中状态判终态失败。

当前为早期**REVISE**，只针对下列已确定工程缺口；真实正式MP4、逐段原生音轨、审美、真机均待后续实物。Mario/动森/Hollow Knight为用户指定功能参考，不把商业原轨当可商用输入，不把本报告写成用户已接受新ABC。

## V3-R1 · 动作局部帧不能作为MP4时间轴 · REVISE

位置`AudioDirectorReels._physics_process/capture_reel`。当前_reel_clock仅_recording=true时累加，并在capture开始清零；Godot MovieMaker从进程启动连续写帧。boot/open_context中的process_frame、每profile重建以及mix中途重建继续产生影片画面，而局部动作时钟停计。因此segment.start_frame/end_frame不能直接除60当实际影片秒数；初始和转场偏移会累积。

这是静态确定路径，尚未声称已测到具体错位帧。已交场景作者修正：捕捉专属首draw前建立实际MovieWriter连续帧锚，segment及accepted_event记录movie_frame，动作trace独立保留。首次实片需实际抽取各段start前后±2帧核字幕和0/1基偏移，包含开场、第二profile与mix场景切换，再扩其余影片。

## V3-R2 · 捕捉成功守门未核本片目标事件 · REVISE

位置`tools/capture_audio_reels.py`及capture_reel。包装入口当前只核native退出/complete marker、媒体流、整体非静音与源稳定，未读取trace.json；capture_reel没有逐段成功断言，流程结束即返回true。实际MovieMaker中若Router TTL/接触/领取某次未成功，其他profile的声音或mix的BGM仍能令全片非静音并被标passed。

当前专项headless测试确实校目标事件/played，但它不能替本次实际录制的受付证据。要求实际影片入口或打包守门按reel核四profile、目标精确事件列表、正式结果、played_delta、有效时间窗口；weapons核三发射加实际bomb_explode，item/chest核build_count且不可重复领取。需临时删除某段target事件/played并保留有声视频的拒绝反例。此项不声称尚未完成的影片已经失败。

## V3-R3 · 捕捉源快照漏项目设置 · REVISE（独立实际反例）

位置capture.sources。独立在完整隔离的临时git ROOT建scripts/test.gd与project.godot，导入捕捉工具仅将ROOT改指临时目录。sources()实际只列scripts/test.gd。将project.godot音频mix_rate从48000改8000后，before与after仍完全相同，`project.godot_audio_config_drift_detected=False`。

真实生产配置没有被修改；这是source_stable对音频/渲染项目设置的遗漏，不是已录影片造假证据。要求至少把project.godot纳入；实际引擎启动脚本、版本/身份也应与录制来源绑定。临时参数漂移应拒绝，原始采集音轨不能仅凭完整commit字符串而忽略关键工作区文件变化。

## 当前静态边界与后续矩阵

- 新pipeline对path/variants、source IDs、WAV摘要、recipe/tool/source指纹与重渲染派生DSP逐字段比对，比V2最初守门完整；待作者刷新结束再做当前版本的隔离篡改反例，不把V2旧测试升级为V3通过。
- 当前coin源为收集符号/钟亮点；heal有bubble/splash/water主体；chest锁扣/木盖与item长乐句独立。当前item_get非静音尾约1.69–1.76秒，非简单拖静音。仅核材料/时间事实，未听音轨，不签Mario清脆、液体感或动森式获得感是否成立。
- 公共weapon_cue新增末尾可选weapon_id，旧调用默认空身份；精确pulse_gun/shadow_shuriken/recoil_bomb才选择新shot/bomb事件，缺bank沿原路。shot_bomb仅Lab监听真实shot_fired后触发；正式原版bomb launch仍静音，不把场景候选称全游戏默认接入。
- chest/item走正式RewardService实际claim；角色近距Router交互或Area接触后才发声。明确开发固定样板与原版confirm/note通用映射，不称正式所有宝箱已有Chest节点或新声音。
- 影片未交付前，不签正常速度画面、帧同步、原生音频真实性、BGM混音或手机视频循环操作。最终需分别审媒体流/时间锚、实际受付、浏览器seek/loop/stop与用户音色偏好。
