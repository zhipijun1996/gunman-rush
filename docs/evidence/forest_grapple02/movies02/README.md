# 同源正式路线正常速影片（受控输入）

两部实际GL影片来自当前 `matrix16_final02` 相同的2127项输入库存，记录真实InputRouter/Motor、敌人相位、伤害/资源和区域流程。源码由基线 `6c61faadd511c48a267b975550da897e701fd09f` 加实际库存识别，不能仅凭HEAD代替本轮未提交改动；[检查点04源文本](../checkpoint04/source-custody.json)及[矩阵源引用](../checkpoint05/source-reference.json)保存对应代码/配置身份。

| 影片 | 正常时间轴 | 原采集结果 |
| --- | --- | --- |
| [图2 fast](map2-fast.mp4) | 原AVI与MP4均1769帧、60fps、29.483333秒 | 原生154.930秒，小于原240秒cap；strictPASS、source_stable |
| [图1 growth](map1-growth.mp4) | 原AVI与MP4均2038帧、60fps、33.966667秒 | 原生184.480秒，小于原240秒cap；strictPASS、source_stable |

原AVI逐帧写出耗时不是播放速度。独立ffprobe计数核对AVI/MP4总帧、平均/名义60fps和视频时长相同，未加速/抽帧/补帧改变时间轴。两者各有48kHz双声道音轨（AVI PCM、MP4 AAC）；压缩编码不同，不声称逐像素/逐采样相同。**有音轨不等于已经听音；受控自动输入不等于真人操作。** 本次整理不播放全片，不签声音、全片动作读感、初见手感、趣味或实体设备。

[inventory.json](inventory.json)保存两部AVI/MP4完整SHA、大小、实际ffprobe原输出及所有便携文件SHA。大AVI仍在原build，不复制进Git；MP4是保相同时间轴的有损便携副本。各子目录的 `receipt.json`、`native.log`、`raw-capture.zip` 为原件；ZIP内完整capture与原收据SHA相同，不是删帧摘要。原输入/资源注入与手工Motor步进均为false。两部原生/严格日志通过，不代表完整固定80/600秒、全profile89、最终CI、Web/Windows或公开发布通过。

各子目录 `index.json` 与PNG保留原抽帧来源/帧号/事件字段，**抽帧仅代表样本，不是全片独审**。图1frame171是到接收台前的下降，不能写成稳定crown落地；实际arrival对应presentation193/tick186。图2 `tree_return_view_1078.png` 是W岸视角：可见上方短树皮和部分负空间，下边部分在画外；不拿它单帧证明完整孔框或真实穿孔电影。完整身体穿孔的技术轨迹见检查点04原raw，两者范围不同。像素审查08/09须以审查原件与其实际观察范围另记，本页不代签其报告。

原旧影片及失败仍在[检查点02身份索引](../checkpoint02/movie-index.json)，不冒认这两部同源新片；本次没有覆盖旧媒体、PNG或既有index。影片整理截止时新洞口替代探针尚未完成；后续真实尾部替代与设计决定见[检查点06](../checkpoint06/README.md)，不能据目的影片声称全七段必经或穷尽所有旁路。两部影片与代表16只是当前局部技术/视觉资料，真人、触屏/手柄实机、商业体验仍未验。
