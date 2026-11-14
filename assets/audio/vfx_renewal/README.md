# 当前攻击、共鸣、入场与金币声音

原创确定性合成，CC0-1.0；无第三方录音、采样或BGM改动。制作源为 `tools/build_vfx_renewal_audio.py`，需要NumPy与SciPy；执行该脚本重建48kHz／16位／单声道WAV及source.json。source.json记录时长、峰值与逐文件SHA256。三组可听音色方向仅输出到被忽略的build/vfx/rework/audio-candidates，正式采用direction-2；这是制作选择，不代表用户认可。

| 素材 | 正式实际消费者／事件 |
| --- | --- |
| shot0／1／2、hit、ice | PlayerWeaponFeelAudioV2的实际pulse／machine／hit／ion_start资源，PlayerWeaponFeelAudio保留同源回退；爆鸣、腔体低音与机械尾音分层，命中是更短的干脆撞击。显式SelectedSfxRuntime消费者也替换shot_pulse／enemy_hit候选，不误以为它是固定世界的实际声音入口 |
| gather、restore | GameAudio.FOCUS_CUES，由WorldFocusHeal接受集气／提交成功调用；集气取消按来源停止，取消及保存失败不发恢复双音 |
| boss_air、boss_land、gate | 正式WindkeeperPressurePresentation安装BossArrivalPresentation，沿Encounter入场钟触发一次入场风声及落地声；gate由真实BossArenaSeal关闭触发，单独事件避免吞掉落地拍点；boss_impact的现有消费者采用同源重击 |
| chest | WorldRoomInteraction.celebrate在存档提交后发chest_reveal；不叠旧item_get／confirm；显式旧SelectedSfx消费者的chest_open采用同源素材 |
| spill、bounce、coin | WorldCoinDrops在新死亡奖励源出现时发loot_scatter，读档初始同步不重播；PlainsStageVisual观察真实首次弹地发coin_bounce；FixedWorldApp成功入账后发coin |

所有声音复用当前世界的GameAudio十二声部池、会话音量、暂停与来源清理；新事件限频并约束同类并发。源峰值约−2dBFS，运行音量仍由宿主及实际声部衰减拥有。旧角色姿态图集保留，旧共鸣声音及其重复合成段已移除。

正常速度原声短片与音色方向位于build/vfx/rework，不把源文件存在或自动检查当作听感通过；交付边界见项目当前交接。
