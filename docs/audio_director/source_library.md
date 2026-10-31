# Audio Source Library · AUDIO-DIRECTOR-01

当前新候选见[14事件/42声音与来源](candidates_v3.md)及[逐原件作者/许可/指纹](../../config/audio_director/v3/sources.json)。V3实际选用wobbleboxx获得音、rubberduck液体/材质/刃风及Kenney素材，58原件均CC0；商业作品只作功能参考，不进入素材生产库。旧研究与前轮原件保留。

更新：用户已拒绝v1两套新方向，原起跳/落地正面反馈；[下一轮现成素材研究与边界](../evidence/audio_director_01/feedback-02.md)。下文“尚未听取用户评价”保留第一轮来源快照身份，不再作为当前试听状态。

素材许可事实与音色审美分开。当前候选仅使用 CC0-1.0 原始采样进行剪辑、滤波和分层；不生成或替换任何 BGM。32 个 A/B 候选、64 个短 WAV 是供试听比较的生产草案，主观状态均为 `awaiting-user`。尚未听取用户评价，不能声明商业品质通过。

机器权威为 [sources.json](../../config/audio_director/sources.json)，每条保留作者、页面、许可、商业条件、署名要求、原始文件名、日期、原字节 SHA256。下载自 OpenGameArt 的文件另有精确 ZIP URL、ZIP SHA256 和来源页面 SHA256。实际使用的输入与输出及参数见 [候选 manifest](../../assets/audio/director_candidates/manifest.json)。

| 素材包 | 作者与许可 | 本轮实际处理 | 边界 |
| --- | --- | --- | --- |
| [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney · CC0-1.0；可商用，无强制署名 | 木质瞬态、草地落地、玻璃、轻金属、柔软碰撞层 | 新 ZIP 下载超时；复用仓库 2026-10-11 原件与原许可，2026-10-26 逐字节校核后保存原名副本 |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney · CC0-1.0 | 原确认、拒绝、钟响剪辑作对照层 | 新 ZIP 下载超时；同上保存原始许可与 SHA |
| [Kenney Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | 页面标 CC0-1.0 | 页面研究；ZIP 实际 503，未接入 | 不将页面访问成功写成素材已筛选或试听 |
| [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney · 现有包内 CC0-1.0 许可 | 布料、刀风、机械点击层 | 新页面超时；使用已有来源记录和原许可，不猜测新包内容 |
| [OGA Platformer SFX](https://opengameart.org/content/sound-effects-for-platformer) | Listener · CC0-1.0 | 实际下载 19 声 ZIP；枪声裁成低比例短层；跳跃等原件仅候选库留作后续比较 | 作者请求通过 Twitter 告知是礼貌请求，CC0 不把通知设为许可条件；未对外发消息 |
| [OGA 80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) | rubberduck · CC0-1.0 | 实际下载 80 声 ZIP；选木/锁/链/金属/纸/金币/宝石/魔法/生物层，优先与机械童话材质一致 | 依据来源语义及信号技术检查形成 shortlist，用户听感待评价 |
| [OGA 80 CC0 Creature SFX](https://opengameart.org/content/80-cc0-creature-sfx) | rubberduck · CC0-1.0 | 实际下载 80 声 ZIP；仅低电平短可爱声层进入候选 | 咆哮、重吼、长叫未推广到全部敌人 |
| [Sonniss GDC](https://sonniss.com/gameaudiogdc/) | 专有商业许可；不是 CC0 或开源 | 本轮页面 403，无文件下载，无素材接入 | 用户已明确商业游戏条件、禁止 AI 训练及独立素材再分发；实际包许可证未核验，保持未知和阻塞，不纳入可公开素材库 |

CC0 允许商业使用、剪辑和随游戏分发，无强制署名。本项目仍记录作者用于溯源；CC0 不替第三方商标、隐私等其他权利作保证。本轮未识别此类内容。许可来源是素材作者公开页面及原包许可，不把平台名当作者。

原料分为三层：完整下载 ZIP 与解压包留在本地缓存 `/workspace/scratch/audio-research`，不提交整包；少量选中原件及 shortlist 保存于 `assets/audio/director_candidates/_sources/`，含 `.gdignore`，不随 Godot 资源导出；设计后的短 WAV 与 manifest 才供 Sound Lab 和显式选择的运行时试听加载。旧正式音效和五首用户 BGM 原件均保留。

每次新素材引入都先登记原件与许可，再写 recipe、渲染及验证。非 CC0 素材须逐项人工审阅商业使用与分发条件后建立独立记录；未经审核不能通过改一个 `license` 字段进入本流水线。
