# 环境音原料与加工 · AUDIO-AMBIENCE-01

候选版本 `audio-ambience-v1`。两区各 A/B，四段 24 秒双声道 Vorbis 床声；另有两种短铃、树干轻响、近叶轻拂。均为可淘汰的试听候选，正式默认 `original`。没有改写五首用户 BGM 或原跳跃／落地。

## 实际取得的原件

[来源机器记录](../../config/audio_director/ambience/sources.json)逐文件保留作者、URL、下载日期、原始文件名、完整 SHA256、字节数、商业条件及许可页 SHA。所有下载日期为 2026-10-28。

| 原件 | 作者／来源 | 本轮用途 | 许可 |
| --- | --- | --- | --- |
| `park_ambience_wind.wav` | Thimras，[Park ambiences](https://opengameart.org/content/park-ambiences) | 平原风床、森林 B 的低层风 | CC0-1.0 |
| `park_ambience_birds.wav` | 同上 | 森林 A/B 的不同树冠录音段 | CC0-1.0 |
| `birds-isaiah658_0.ogg`（页面原名 `birds-isaiah658.ogg`） | isaiah658，[Ambient Bird Sounds](https://opengameart.org/content/ambient-bird-sounds) | 平原 B 稀薄远鸟层 | CC0-1.0 |
| `bell_ding1.wav`／`bell_ding2.wav` | PWL，[Bell dings/chimes](https://opengameart.org/content/bell-dingschimes) | 平原地标短铃 A/B | CC0-1.0 |
| `tree_creak.flac` | Department64；AntumDeluge 清理，[Tree Creaking](https://opengameart.org/content/tree-creaking) | 森林真实树体点声 | CC0-1.0 |
| `moving leaves stereo.ogg` | HaelDB，[Random Sounds Samples](https://opengameart.org/content/random-sounds-samples) | 森林近叶点声 | 页面双许可中选择 CC0-1.0 |

CC0 允许商业游戏、剪辑和再分发，不要求署名。本项目仍保留作者／来源。短铃页面没有说明录制方式，不将它冒称实地录音；主要床声来自作者明确描述的实地录音。

完整原件约 161.6 MB，保留于忽略的 `build/audio_ambience_01/source-cache/`，不把数分钟未使用录音装入游戏或提交 Git。原下载 URL 与完整 SHA 可恢复同一原件；`fetch` 对缺件下载，不覆盖已有损坏原件或接受漂移。许可页面原 HTML 与既有 CC0 全文保留在 `assets/audio/ambience_v1/_sources/`（`.gdignore` 防进入运行导入）。本次 CC 官方 `legalcode.txt` 请求返回 403，全文复用仓库既有 CC0 原件并保其 SHA；新素材的 CC0 授权依据为实际取得的新作者页面，不把失败请求写成功。

## 原料取舍

实际检索并取得页面的其他来源：

| 来源 | 结论 |
| --- | --- |
| Luke.RUST 的 `wind1` | 页面明确 PureData 合成；不作为本轮主要原料 |
| Sharm 的 `Breeze` | CC-BY／OGA-BY 许可；本轮先用已取得的 CC0 实录，未接入 |
| JC Sounds Nature Ambient Pack | CC-BY 4.0；未下载／未接入，不能称 CC0 |
| Gregor Quendel Free General Ambience | CC-BY-SA 4.0；本轮未接入 |
| sinny Dry bushes | CC-BY-SA 3.0；本轮未接入 |
| Yo Frankie mountain/forest bundle | CC-BY 3.0；本轮未接入 |
| Pauliuw Forest bird sounds | 页面 CC0；未下载／未接入，避免无必要扩库 |

没有使用 Sonniss，亦未将专有许可或 CC-BY 素材误登记为 CC0。

## 可复现加工

[配方](../../config/audio_director/ambience/recipes.json)与[生产工具](../../tools/audio_ambience_design.py)记录原件截取时间、滤波、每层参考 RMS、相对增益、目标电平、采样率、交叠时长和导出编码。无纯正弦／随机噪声生产。A/B 使用不同录音段与稀薄鸟层／风层配比，区别不只在总响度。

- 从 26 秒实录得到 24 秒床声：输出开头 2 秒将原尾部与原头部作线性交叠，其余为原中段，环接不插入静音淡出。Vorbis 解码后的环接跳变量另测；工程阈值不是“听不出接缝”的保证。
- 床声目标约 −31 dBFS whole-file RMS，样本峰值上限 −9 dBFS；每层先参考归一，再施加配方相对增益，避免原件不同录音电平令鸟声无意压过风。短点声按全片 RMS 与峰值上限处理，长尾／高瞬态可能受峰值限制而低于目标 RMS。
- 短点声 PCM16 WAV／48 kHz，床声 stereo Vorbis quality 5／48 kHz；使用 bitexact 标记避免无关编码序号漂移。暂不加工 BGM。
- manifest 保 source/recipe/pipeline 指纹、每次导出文件 SHA／字节／RMS／峰值／DC／环接跳变。开始和写 manifest 前实际校验完整录音 SHA，拒绝渲染途中原件漂移。
- `regions.*.profiles.*` 是唯一运行混音参数；`events/candidates` 是工坊展示索引，验证器检查二者引用同一实际产物。点声只供真实可定位地标触发，没有源坐标时不凭空响。

```sh
python3 tools/audio_ambience_design.py fetch
python3 tools/audio_ambience_design.py build
python3 tools/audio_ambience_design.py validate
python3 -m unittest discover -s tests -p test_audio_ambience_design.py
```

输出为 `assets/audio/ambience_v1/manifest.json`。普通验证无需下载完整大录音；若本机存在原件会校验它，重建则必须取得所有原件。不同版本 ffmpeg 的编码结果可能不同，必须重建并记录新实际指纹，不能继承旧通过。

## 已证与待听

作者页面、许可、完整下载指纹和工程波形可由工具核验。模型没有进行人耳听音，不宣称已经排除公共公园远处人声／交通、鸟鸣过近、尖锐、循环疲劳或 BGM 遮盖。所选段的频谱、电平与接缝检查仅防明显技术故障；真实 Godot 情境、用户试听与实体手机扬声器分别验收。若任何段听到现代城市背景，应淘汰或更换录音，不能靠加响／加层掩盖。
