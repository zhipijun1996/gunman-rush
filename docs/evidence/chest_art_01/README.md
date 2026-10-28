# CHEST-ART-01 · 正式两区接入与实际运行证据

当前蓝／紫／金三档闭开六态已接入正式平原和森林，金箱为紧凑钟箱。通过共享数据与材质读取原`claimed`，奖励成功提交才开启；不修改原箱子分布、奖励或永久音符。修复领奖关闭后下一个W被输入保护吞掉，持续按住的保护逻辑保留。

- [实际原图](sources/source-04.png)与[六态小屏平原对照](live/gallery-plains/six-poses-960x540.png)、[森林对照](live/gallery-forest/six-poses-960x540.png)。对照为明确标注的视觉fixture，非自然六箱分布。
- [三档真实领取与重载影片](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/6d02fe700ee57491b4d58ce6c856a43276d577f7/docs/evidence/chest_art_01/live/main/movie.mp4)：26.066667秒、105断言。原箱原奖励：金币0→8→26→56、3个未装备实例，重载不重复。影片仅站位／镜头fixture，非自然全路线。
- [森林原high箱影片](https://raw.githubusercontent.com/zhipijun1996/gunman-rush/6d02fe700ee57491b4d58ce6c856a43276d577f7/docs/evidence/chest_art_01/live/forest/movie.mp4)：10.1秒、41断言，金币0→18，实际领取后开启与重载保持。
- [完整实际捕获索引](live/index.json)保存原source/trace/receipt/PNG/MP4；两影片源`0f7a5d1c`，平原gallery源`614d7b68`，森林gallery源`5722ca74`。后续只修gallery producer，生产脚本／资源／配置及claim路径原字节不变，保留各来源身份，不把旧片追签新录制。
- [独立实际画面／逐帧审查](final-independent-visual-review.json)：逐张看24PNG，限定V8技术和视觉接受。奖励modal覆盖箱子期间，closed由trace/texture证明，不冒称像素可见。
- 原生210／0（原192完整保留、追加真实两箱W），[导出包隔离](pack/receipt.json)15／0；[最终10项相关Harness](final-validation/summary.json)已全部fresh通过（0复用／0失败，非full165或最新远端CI）。原32＋10与四绑定检查fresh通过，所有原预算／旧断言与失败链保留。

[本轮失败归档](capture-failures/index.json)及[旧商店回归失败](region-shop-repair/failure-01/archive-index.json)保持原件；新版source04是用户采用的V8合同，不改写旧≤1wu及44／58高度失败。六静态姿态，不是开盖动画；实体安卓／手柄、低端性能、听感与完整G5未验。森林960已有教程文字与上左HUD局部重叠，本轮未改该布局。

[公网完整下载校验](public-download-check/receipt.json)：四份媒体实际HTTP200，完整SHA与提交原件相同。媒体固定于`6d02fe70`；[生产／录制／测试身份](source-bindings/delivered-source-identity.json)证明生产原字节相同，后续仅测试producer和文档／收据修订。PR111继续OPEN，不自动合main，最新全量远端CI仍以GitHub实际head结果为准。

[最终验证独审](final-validation/independent-review.json)另核10项原命令／预算、真实marker、Source guard与4份公网完整SHA。补充文档／质量两项fresh通过；仅文档和收据晚于冻结测试源，不改已验证的生产或测试代码。

以下保留此前阶段交接，旧“待执行／待答”只描述当时状态。

---

# CHEST-ART-01 · 用户v8采用与正式两区接入（当前）

用户实际回复“宝箱接入游戏，继续工作”，接受root此前明确告知的source04细微尺寸／姿态差异。当前蓝／紫／金三档闭／开六态已注册production资产，通过[运行配置](../../../config/chest_art.json)及既有平原／森林消费者显示；固定source04原PNG SHA `3258e5cc78e4b0ea9e724a423a0e7ce5a58611471ad3b84cdb28360a8845f5d5`，没有修改像素或生成第5张。[v8采用合同](../../worklines/chest_art_01/spec.md)与[权威收据](../../worklines/chest_art_01/authority.json)保留真实用户授权和完整历史。

这是用户采用后的新合同，不是旧几何规格通过：蓝／紫原始配对宽差约1.5850／1.0841wu、旧≤1wu仍FAIL；金箱旧44／58限制仍FAIL。现图采用的是实际shader观测蓝紫可见配对2wu及金结构闭46／开60wu，source04旧独审拒绝原件不回写。每tier共同等比factor、固定源脚底和完整非零alpha ROI不变，交易／领取账本、Manifest／RNG、原交互与两区支撑脚底、1wu采样和独立8MiB单PNG预算保持；4／4调用用尽。

当前验证：

- 正式原生专项 `build/chest_art_01/native-02.log` 为192检查／0失败，无脚本或原生ERROR；包含平原与森林真实装配，未知tier反例的预期warning如实保留。
- `build/chest_art_01/native-01.log` 首次真实场景未就绪／Nil访问失败完整保留；147／0局部marker不能证明该轮通过。
- production两区当前capture、正式开箱状态切换媒体仍待root执行；当前源最终commit、便携运行回执及公开媒体链接由root最终收口补充，不引用旧录屏冒充。
- 原隔离GL75／0仅属于当时诊断；前两次GL错误及所有源图／gutter／固定grid／native像素请求失败仍归档。实体设备、完整G5与当前正式画面的最终验收未签。

下方为采用前原文，作为历史原件保留。其中“待答／未替换／没有注册”只描述当时阶段，已由上述真实用户授权与production实现覆盖；历史失败未被改签。

---

# CHEST-ART-01 · 宝箱美术候选与真实失败

当前仅为待取舍候选，**未替换默认主游戏宝箱**。三档逻辑及领取账本保持原实现。

- 最新[完整原图](sources/source-04.png)已将金箱改为紧凑厚实形体，蓝／紫／金主体区分保留；第三版长扁金箱已被用户明确拒绝。
- [实际 Godot 六态对照](diagnostic/latest/six-poses-1280x720.png)与[小屏对照](diagnostic/latest/six-poses-960x540.png)只使用合成44wu比例参照，不是正式地图或真实开箱流程。
- [第四源独审](raw/source04-admission-review.json)及[补充交叉核对](raw/source04-cross-review-addendum.json)：蓝紫同箱开闭宽差仍超过1wu，金箱在60±1wu宽下高度超过44／58wu。本轮4次生成预算已用尽；用户对当前差异的取舍尚未收到，不能视作接受。
- [最后一次诊断](diagnostic/captures-04-03/receipt.json)与[原始日志](diagnostic/gl-04-03.log)为75项技术检查、无脚本／原生错误。单一固定相位的1wu实际采样仍呈现蓝紫2wu箱底宽差、金箱46／60wu结构高度，不消除原规格失败，也不代签主游戏、设备或美术验收。

前两次GL诊断分别发生错误API及画布尚未挂接的原生错误，其36／75成功标记无效，均按FAIL保留。最后修复只保证探针能正确测量，不把未完成采样或错误退出当作通过。

[归档索引](archive-index.json)保存4张源PNG、真实调用参数／提示词、版本化G0、独审及失败报告、完整ROI／共同缩放／足点测量，以及待准入的正式接入方案。代码与历史Markdown采用`.source`扩展名保持原字节，均为离线审查材料；没有注册成运行资产，也不进入导出包。批准造型或重定美术规格后，仍须完成正式两区接入、原交易／claimed回归与真实地图验证。
