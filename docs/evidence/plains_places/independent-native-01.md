# PLAINS-PLACES 首三原型整屏独审：整体REWORK，局部候选保留

审查者 `/root/environment_art_review`；独立于实现，只读生产，不图生、不运行Godot。采用既有gameplay-reviewer、visual-director、art-director、scene-composer适用要求，没有另建质量框架。

**结论：三原型整体REWORK，不准含lee_court的Seed组合扩展。wind_meadow/postal_valley在已看静态及离散运动窗口可ACCEPT_SCOPED作为独立艺术候选保留，不签完整G2/随机黄金。** P1用户偏好不等于最终风格认可。

## 原版本与实际观看清单

源 `ac5419a742723574e2ba3aa053eb857bfffc9231`；原receipt `build/plains_places/full_02/visual_capture.json`，原native `capture.json`，真实电影 `gameplay.mp4`；Manifest `f0a53a9db99aacf8a30004fb41d39dfa5369120eca5b5f2cb08419491648b181`。本次actual full02是首三原型全链，目录full02不等于第二次艺术返工；旧失败启动不当完整视觉轮。

已实际打开whole_bank、真实简化后的enclosing_ridge功能源，读places_v1.json三composition。已重新打开PR82原master及round03 entry/receiver/bridge/shelter/lookback作为失败对照。

本轮实际view_image原1280×720帧如下，均位于 `build/plains_places/full_02/video_frames/video_frame_NNNNNN.png`。时间为视频frame/60，不冒精确物理tick：

| 视频帧 | 视频时间 | 原PNG SHA256 |
| --- | --- | --- |
| 120 | 2s | `6cb8d357a6b57d80ebef2927544adb4f508cb7f41f888b3dc984e34e768e0317` |
| 240 | 4s | `235160d552f7d4c647e91fadbcd435221fce0e978c6883e80133f41a18e8ec80` |
| 360 | 6s | `be181bf9422867d2d878477d2f197b3d5db95c9876b0c6e56318a5152b436b13` |
| 480 | 8s | `1c1da5931347a7cedf4ac1db12981b041189e2e8b03c37f4a7c975be31d9633d` |
| 600 | 10s | `e3046ab7e4e7376c474c3a10e0592650d51804a2d92bf20462f68ac202952a44` |
| 720 | 12s | `746a2228b953f41af691c1bb6dbb839b64741e038983d9756b6eb45699a3ac6a` |
| 840 | 14s | `5ef72904373438161166d377bb0b84fc6e1d36feaef3343eb3fd774ab4b24ddd` |
| 960 | 16s | `1f3fa24e95e44525692e5f700e4a600b0d267566b22651d941632759400a972c` |
| 1080 | 18s | `8bc77037ab5a2ae4d4e8e6691fa5ee8f17bf6124961793940d109d2be582554b` |
| 1200 | 20s | `dae7eb9683da65fda619717d2da3171164088d6744a06594a16a1d5b58e4ebe3` |
| 1800 | 30s | `e6d48a6150949813d653a740b38814df177e59b780e4b392b8ea4502eac6daf5` |
| 2160 | 36s | `09b2086cced02ec86365347ef910c63e0c971cd5432b0b10b0575df9c53194e3` |

120/240/360观察court进入、上升、出发；360/480第一连接；480/600 meadow；600/720/840第二连接；840/960/1080/1200 postal、桥踏面/真锯、远端；1800/2160返程及court回落。采集者另给review_windows.json映射原时间与案例物理tick，未假设两者严格等同。

未完整播放39.4167秒影片，未亲听音轨，无实体设备实测，未本人操控路线。35点/2360tick/HP5/6shot/零恢复为采集者技术记录，不冒本人独立操作。没有因原strict captured把艺术自动判passed。

## 整体专业判断

**连续体积有实质改善。** 新完整岸体由顶草、垂根、明暗侧岩到圆端同源绘制，旧PR82草肩方切/alpha擦淡不再是画面主问题。meadow600、postal840/1200轮廓完整，脚下与外侧不再像草布覆盖另一个石体。可保留完整功能源、真实测站面与受约束等比接入的方向，不回到独立带面修补。

**景层有实质改善。** 冷灰树坡不再与近岸同细节；120/240有大树后坡围住棚、600由低频塔坡托住前树与跑道、720谷的近中远重叠成立。暖近冷远、木石铜同语言、少女跳跃轮廓与桥锯可辨，确有世界吸引力。未以层数或hash判层深；动态相对位移/所有状态未完整验证。

**中尺度关系改善但court不成立。** meadow是一段开阔风树恢复岸，postal是两岸/真空谷/桥拱铜钟的横向地标；这两者有可辨身份，不是只换ID。court引入上下站面、棚与活体遭遇确实改变轮廓和动作，但两层岸没有共同受力的整体形体。

## 唯一主返工：PLACE-ART-01，court组合与资产用途

在120/240/360与2160帧，较小上岸保留了完整倒三角岛底、右侧多层台阶及同向斜裂纹；它压在同形下岸前，底尖/台阶与下岸梯台穿插。AI艺术判断：读成两个浮饼并置，难读成背风院共同阶地。上岸的大白岩三角还比棚/RootBell更抢焦点，削弱“避风、观察敌人、攀到高处”的场所观看顺序。这是母体形状与中尺度组合的主要问题，不是无伤通过可以豁免的小接缝。

责任scene-composer + art-director，最关键替代实验仅作用court：做一件上下层共同受力的完整院岸/高台母体，低台棚脚、上站面、连接岩脊在同一功能源共同绘制，再测实际两层站面并按原操作真实验证。保留中景、桥、树与meadow/postal已成立内容；不加装饰、不全局覆画，不再把完整孤岛任意叠成同一自然岸。该实验是建议，尚未实际制作，不能写完成。

## 扩展边界

同一whole_bank的右梯台/斜纹已在三处反复出现，当前限定用途尚能看懂，但不足以证明批量重复后的视觉丰富度；不可用首三段技术成功签随机地区。可保存meadow/postal已看窗口的限定接受与工程证据；court失败不应让作者毁掉已成立家族，但含court的首三原型共同黄金未过，因此当前不开展其batch Seed扩展。

本轮并非无实质进步。这里拒绝的是court依赖的组合，不拒绝完整源体积和冷中景方向；不列装饰清单，也不以缺陷清零冒称商业吸引力。用户/设备/完整运动音频/多Seed/正式池均未验，整体艺术仍REWORK。
