# 家园生活声原料 · AUDIO-HOME-01

本轮为 `audio-home-v1`／`home-quiet-01` 开发试听候选。运行 schema 继续 `audio-ambience-v1`，复用现有 GameAmbience；没有改写两区已选 A、旧配方、旧 manifest、逐事件选音和五首原 BGM。

家园底声直接引用用户已选 quiet-02 的 `plains_a.ogg` 原字节，另施加运行增益 −2 dB；不再次减去已烘入该文件的 −14 dB。底声不是本轮新加工资产，manifest 用 `bed_reference` 记录旧选音／旧 manifest／原文件 SHA，只有八个新短 WAV 进入本轮 `renders`。

## 三份实际原料来源

[逐文件记录](../../config/audio_director/home/sources.json)保留原始文件名、作者、来源与下载 URL、CC0 商业条件、署名要求、下载／复核日期、原文件／原包／许可页 SHA。旧原件直接引用现有 Git 路径，不重复下载或伪造新下载日期。

| 用途 | 原件与作者 | 授权依据 |
| --- | --- | --- |
| 织时匠附近布料轻拂 | Iochi Glaucus，`rustling.ogg`，[Fabric Rustling](https://opengameart.org/content/fabric-rustling) | 2026-10-29 实际取原 OGG 与页面；作者明确 AT2020／Audacity 录制腿套布料，压缩与降噪，长文件含多次 rustle；页面 CC0 |
| 维修工坊木件收放 | rubberduck，`wood_misc_01.ogg`、`wood_misc_02.ogg`，[100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | 复用 V3 已取原件／原页面／原包指纹 |
| 武器工坊手工具轻响 | rubberduck，同包 `keys_02.ogg`、`keys_03.ogg` | 原声文件身份是钥匙短响；本轮作为小型金属物件收放的候选，未声称原件记录了枪械维修 |
| 档案员附近册页翻动 | rubberduck，`book_03.ogg`、`book_04.ogg`，[80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) | 复用 V2 已取原件／原页面／原包指纹 |

上述均选择 CC0-1.0，可商业使用、修改与游戏分发，无强制署名；本项目仍保留来源。新布料完整原件 337,262 字节、26.853878 秒，SHA256 `897c0937041afdf3581427b80a7546f99d219d0008e12ff5500c2afdfa4b7a1e`，与许可页保存在 `assets/audio/ambience_v1/home/_sources/`，由 `.gdignore` 排除引擎导入。缓存副本位于忽略的 `build/audio_home_01/source-cache/`，同样设置 `.gdignore`。

布料两变体来自同一长原件的 **2.5–3.5 秒**、**4.0–5.0 秒**不同时间窗，不是两次独立录制的声明；木件、钥匙和册页各复用两个不同原 take。本轮未使用人声、人群 loop 或持续锤击。

## 实际研究与取舍

- Kenney 官方 RPG Audio 页面已实际读取，但 `download-link` 端点返回 HTTP 403；没有取得 `cloth2.ogg`，没有把它登记为下载成功。
- 随后实际取得 CC0 的 Fabric Rustling 替代，避免用同一旧 jump 布料素材简单变调充当生活声。
- OGA `Cloth swing sounds` 页面是 CC-BY 3.0，未接入。
- 研究时重新取得 rubberduck 80 RPG 原 ZIP，1,845,114 字节，SHA `1c2f06ff4e8563b5b8b745b23cf213c1474142a69bb82bd8f5e10d9b3f7a7bbd`，与既有登记一致。包内没有 cloth 类文件；未将整包提交／装入运行时。

## 加工与复现

[Home 配方](../../config/audio_director/home/recipes.json)记录每段起止、滤波、淡入淡出与目标电平；[Home 加工器](../../tools/audio_home_design.py)复用现有 `audio_ambience_design.py` 的解码／电平／编码函数，并在 manifest 锁定该共享加工器 SHA。

八个短点声使用双声道 PCM16 WAV／48 kHz，目标全片 RMS −43 dBFS，峰值不超过 −27 dBFS。高 crest 原件受峰值限制时，实际 RMS 会低于目标；精确实际值存各 `renders.metrics`，不以目标值冒称测量值。点声不循环，起尾微淡化；不生成波形／噪声主材，不叠加奖励音或音乐。

`regions.home.profiles.A` 是运行参数唯一来源：`home_a` 引用原床，gain −2；八个 detail 独立 ID、gain 0、最短间隔 10 秒、最大距离 240。实际播放还需场景提供对应位置、互斥／稀疏调度和生命周期管理；加工器不修改 NPC／交易／控制规则。工坊内部短声不代表静态 NPC 正在挥锤，情境字幕应说明这是附近内部生活声。

```sh
python3 tools/audio_home_design.py build
python3 tools/audio_home_design.py validate
python3 -m unittest discover -s tests -p test_audio_home_design.py
```

生产前后核对真实原件、许可页、旧登记、两份选音、两区 A、旧 manifest／配方与五首 BGM 的字节 SHA。渲染先在临时目录完成，若原件或锁定输入在途中变动，拒绝并保留既有正式候选与 manifest。输出携带输入／配方／加工器／共享库指纹和八文件完整 SHA；反例检查独立覆盖伪造候选 ID、点声身份、错床增益、改输入／输出／许可及渲染途中漂移。

## 试听范围

技术检查只验证来源、字节、电平和引用。模型没有进行人耳听音，不宣称已通过悦耳、布料真实感、金属声是否近似拾取、稀疏节奏或原家园 BGM 下可辨识度。用户需在家园近处／远处、BGM 同播和暂停／返回中判断；实体手机扬声器另验。若点声仍像动作提示或太突兀，应换片段／来源，不靠加层和增响解决。
