# 六组motion抽帧补审

运行源仍为 `32200d04fe233bda16cf50f678aabee51a9715e5`。实际看过 `motion/{underworld,cavern}_{plains,forest,gear}_sequence.png` 全6张，每张0.0～7.5秒、间隔0.5秒共16帧，总96采样；另用FFmpeg从森林/工城四profile各提3.5、7.5秒1280×720帧并全部实看，共8张原尺寸样本。原尺寸样本临时保存在 `build/style_exploration/review/motion/`，可以按同视频时间重提。

读过实际录制脚本/6个receipt，并用ffprobe逐片核对：6片均H.264、1280×720、60FPS、482视频帧、8.033333秒，只有视频流；Dummy静音轨已移除，不声称听音。每片receipt记录480 driven render frames、479 Motor steps、3次accepted jumps、actor epoch未变，seed均为0。六片SHA与portable_index吻合，见 `motion_viewed_manifest.json`、`motion_inspection.json`。

**ACCEPT（采样观察范围）**：左限位停稳到普通横移的样本中未见原竖条，panorama持续覆盖可见区。不同地区的开阔、围合和工业纵向构造在横移后仍保留；远景与根植装饰的相对位移可见，不是只平移整张截图。Underworld森林3.5秒靠树根的角色/脚边最暗，但脸和浅边尚可辨；7.5秒木桥和接收岸仍可分，Cavern同时间浅岩边的读图余量更大。工城主路经过gantry脚与齿轮，角色在前未被整块装饰遮死；采样里没有证据将初版“假台”的硬失败重新归给该gantry。

**不能宣称的范围**：本代理没有完整正常速度播放全部影片，没有逐帧检查动画/闪烁，也没有听音或实体设备操作。半秒采样无法排除短暂遮挡。六片不覆盖随机seed911动态、上层全路线或真正回程；收据抽样player最大x为1709.59，8秒尾部也未达脚本x>2460的反向条件。脚本存在direction反转分支不证明影片已执行它；`claims_full_route_completion=false`是正确边界，完整往返依然引用实际runtime路线证据。

本补审不改变静态实验交付ACCEPT，不升级商业/玩家/全随机动态/设备认可。最弱Underworld forest seed911仍建议单独动态补样，若根任务追加则属于另一条明确证据，不追改这六片seed0的覆盖。

## 最弱seed911追加

随后独立实看 `underworld_forest_seed911_sequence.png` 全16个半秒采样，并从同mp4抽取1.5、3.5、5.5、7.5秒四张1280×720原尺寸帧全部观看。receipt与画面UI均为seed911；独立ffprobe仍为482视频帧/8.033333秒；480 driven、479 Motor steps、3 accepted jumps、actor epoch未变。证据 `motion_seed911_inspection.json`。

该样本1.5秒角色跃起在深树/左悬台下，浅边与脸仍能区分；3.5秒树根附近角色和地面较暗，5.5秒经过根洞，7.5秒桥与接收岸未被树/光遮死。左拱腹体与背树接近的风险确实存在，但这些实际样本未证实落点消失或角色完全被遮，故不阻断实验交付。小屏/完整速度/所有短暂相位仍未知。

补审合计7张序列112个半秒采样，12个额外原尺寸视频帧；六组主片是seed0，追加仅Underworld forest seed911。**ACCEPT：这些实际采样中的背景覆盖、地域身份与功能边沿；UNVERIFIED：全片正常速度观看/听音、手机、全随机或完整回程。** 不把7片升级为7次完整通关。
