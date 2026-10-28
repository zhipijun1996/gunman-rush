# Sound Design Pipeline · AUDIO-DIRECTOR-01

此流水线将已登记许可的采样加工成可比较的候选。它验证可重建性和文件完整性，不评判悦耳、世界观匹配或商业品质。

```sh
python3 tools/audio_design.py list
python3 tools/audio_design.py build
python3 tools/audio_design.py build --event hook_release
python3 tools/audio_design.py validate
```

输入权威是 [sources.json](../../config/audio_director/sources.json) 与 [recipes.json](../../config/audio_director/recipes.json)。原文件名、许可、作者、来源、获取时间、SHA 保留；选用原件由 `_sources/.gdignore` 隔离，不向运行时导出整包素材。机器输出是 `assets/audio/director_candidates/manifest.json` 与同目录短 WAV。

每层按顺序执行：44.1kHz/mono 转换、只去前导静音（−55dB 门限）、按明确时长裁剪、可选反转、重采样音高、独立 `tempo`、高低通与 2.8kHz 轻削、3ms 淡入/25ms 淡出、相对电平和毫秒偏移。多个原始采样以明确比例合成，经过轻动态压缩；混合暂存为 PCM32，预留线性 headroom，避免 PCM16 中间削波；最后按事件家族 RMS 目标与 −4dBFS sample-peak 上限求有界增益，导出 44.1kHz mono PCM16 WAV，尾部淡出35ms。无随机噪声或纯正弦波生成器。

音高和时长可以独立调整：`pitch` 改重采样速率，`tempo` 使用 FFmpeg `atempo`；当前 recipe 只采用 0.7–1.5 倍短层音高，默认 tempo=1。剪辑、音高和尾音都由采样决定，不能把只加响度当声音设计。

本轮 16 事件，每事件两方向，每方向两变体：A 以布料、木芯和细小钟簧为主；B 以轻金属、玻璃与稀疏亮点为主。第二变体优先替换真实不同原始 take，并采用有界2.5%音高微差；没有相邻原 take 时只微调，manifest 明确每层实际原件。方向名称是设计意图，听感尚待用户选择，不是已接受风格。射击包含短爆发与锁芯回弹层；独立 recoil 只供分拆比较，不能默认叠加双响。hook_pull 是0.52秒可取消纹理，带淡出，不宣称无缝循环。

清晰的动作瞬态先于装饰尾音。起跳/落地、命中/受伤/死亡、金币/回血/普通奖励分别有 recipe；不能以同一全局 cue 代替成功受伤与物理接触。当前没有扩展全区域环境、敌人种类或武器，避免在方向未试听前批量推广。

每个输出登记：recipe/source/tool SHA256、FFmpeg 版本、所有输入 SHA、实际滤镜串、每层参数与最终增益、输出 SHA、时长、峰值、RMS、采样率与格式。`validate` 将 manifest 内 recipe/source/tool SHA 与当前源逐项核对，同时核验原料注册表快照；拒绝指纹变化、超峰值、静音/过短输出、无许可或原料漂移。`--event` 只允许在同一冻结输入和 FFmpeg 版本上重建单事件；任何配置或工具漂移都在写出前拒绝，要求完整重建，避免未重建事件被冠以新指纹。渲染期间输入指纹发生变化也会拒绝写新 manifest。响度衡量为整个短 cue 的 RMS，不冒充 EBU R128 integrated LUFS；短音的RMS/频谱和峰值只用于技术筛选，仍需在实际 BGM 与动作节奏中比较。

短瞬态选 PCM16 WAV，降低 Web/Godot 解码与短音首帧成本；本轮所有样本均小于0.7秒。不触碰现有五首 MP3。未来长环境纹理应另选 Vorbis 导出与真实无缝循环点，并验证 Web 延迟；不能把短淡出候选直接设 loop。

离线重建只需仓库保存的少量原件与 FFmpeg。相同 FFmpeg 版本下 PCM 输出应逐字节一致；跨版本重采样/滤镜差异须写新输出版本，不以旧 SHA 强行追认。构建不自动替换正式默认映射，候选只有在 Sound Lab 或显式配置选择时进入试听链。用户的选择记录包含候选 ID 与 version；新渲染应升级版本并重新试听。
