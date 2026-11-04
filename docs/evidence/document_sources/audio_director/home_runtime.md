# 家园环境与生活拟音 · AUDIO-HOME-01

家园候选使用同一个 `GameAudio` / `GameAmbience`，不增加播放器，不修改 `HomeScene`、`DemoApp`、共享 loader 或其质量适配器。正式默认仍为原版。已选 quiet-02 `plains_a.ogg` 原字节直接复用，家园独立 manifest 的运行增益为 −2 dB；不重复加工或再次扣除已烘焙的 −14 dB。五首 BGM 及既有选音不变。

```gdscript
var audition := HomeAmbienceAudition.new()
add_child(audition)
audition.configure(actual_home, actual_audio, "life")
audition.set_mode("bed") # 保留家园床声，停止生活点声
audition.set_mode("original") # 清除本候选
var observed := audition.snapshot()
```

`assets/audio/ambience_v1/home/manifest.json` 只配置 `home/A`。适配层在调用共享 loader 前核对唯一 home region / A profile、原床声身份和八个真正使用的 literal WAV 白名单，并验证当前保留用户选择的旧 manifest 与 plains A 文件 SHA。实际增益、细节声 cooldown 与距离以独立 manifest 为唯一运行来源；共享组件继续执行类型、范围和音频资源校验。八声按 cloth、wood、tools、page 四族各两 take 配置，允许逐族淘汰；用户未听选的新生活拟音不自动成为正式资产选择。

真实家园 NPC 是 `UnderworldHomeWorld` 创建的静态 `Sprite2D`。适配层只读取其中的 `home_function` / `home_root`，并确认真实 slot 已 active 且存在 keeper。character→cloth，upgrade→wood，arms→tools，achievements→page；无 NPC 的预留建筑保持静音。坐标来自 NPC 的实际脚底，经真实 world transform 转换；没有硬编码各建筑的 x/y，也没有隐藏建筑内的虚构声源。当前不是 NPC 敲打、走路或翻页动画帧同步；对用户应称为 NPC 所在地的稀疏生活拟音。

每个真实 keeper 的首次及后续间隔均为 12–22 秒，由独立固定 seed 的 presentation RNG 决定，不调用玩法 RNG。全局两次成功生活声之间至少 6 秒。只有当前可见、距离可听、无面板、未暂停且没有其他点声播放时才发出；由共享组件做真实距离衰减。即使共享组件可容纳两条 detail，本适配层也只允许一条生活声。每族在实际成功播放后轮换 1/2，拒绝不推进 take。

远处、离屏、忙碌和 cooldown 拒绝均丢弃当前请求并重定时，不存积压。面板 `input_blocked` 在下一表现帧停止现有点声并禁止新点声，床声继续。树暂停由原组件暂停床声与点声；恢复后重定时，不能补发暂停期间请求。面板关闭同样重定时。独立节点使用现组件 `_stop_details()` 执行“只停点声”；这是对既有 SHA 冻结组合内部接口的明确依赖，没有另加音频引擎。

监听位置采用实际 `HomeScene.player`。该 `PlayerMotor` 没有死亡信号，因此另连接真实 `home.controller.died`，立即停止床和生活声；home 的 `tree_exiting`、隐藏或卸载也停止。旧适配层只清理它仍拥有的 component owner，避免退出旧 home 时清掉后来进入的地区声。`stop()` 断开旧 controller / owner 信号，必须重新显式 configure 才能再启动。

`snapshot()` 包含 mode、presentation clock、各 NPC 脚底/家族/下次时刻/可见性、最多 64 条实际成功音频事件，以及原组件的真实播放快照。事件保留实际 ID/path/slot、声源与玩家位置、距离、volume dB、physics tick 与 voice index。此记录仍需和原生录音核对，不能凭计数宣称已经听到或品质通过。

专项测试入口：

```sh
bash tools/godot.sh --headless --path . --script res://tests/audio_home_runtime.gd
```

测试实例化真实 Home，但位置与调度时钟属于明确测试 fixture；不得称自然探索路线或真实经过 12–22 秒。它覆盖实际 NPC 定位、预留槽拒绝、家族、白名单、近远/并发/变体、面板/暂停/死亡/卸载与原严格 teardown。自然速度真实家园录像、原音轨核验、浏览器 GUI、听感和实体设备分别记录，不以这些 transport 检查代签。
