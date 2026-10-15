# V3-ASSET-WOODLAND-01：真实单图生产，原规格失败保留

作者 `/root/v3_art_director`。真实ROOT controller session35058，稳定source `f18f4bade9254031b3e0aa15ef915841ecfa0866`；implement nonce `0709669f4589493fbe9de89bd8d7261a`、hash `75a77955574394e1248e911a3162eeb91157300e553bd3ad9cd957f1ffe69e3e`、source_hash `0497ec6176ab239fe1dd0bc7e02774d0221e22d1d4be402a5499ded2611c6cf7`。父宿主clearsource后正式派发；完整真实prompt/Skills已读取，三份reference先view_image(original)，再真实唯一image_gen.imagegen，53.624秒。预算1/1已用，没有第二图，无抠图、移动像素、去背景、拉伸或代码重绘。

完整原PNG1774×887 RGBA，SHA `5727c0e36f9f4e28998d4da8c72d40d1a09c085ec1f0136c7c4751ae3a510d56`；逐字节等于工具原路径。已view_image(original)实际看过。工具只暴露image_url与output_hint，model/license/cost均not_exposed；精确request、referenceSHA及原字节参考、工具输出位置/耗时保留，JSON不重复巨大inline dataURI。

## 原规格对照：没有事后放宽

| 项 | 生成前原约束 | 实际结果 |
|---|---|---|
| 两条独立横向cutout/各自完整根坡 | 同源分区，各带完整自然基础，无天空山瀑/矩形背景 | 源确画两条树脊，各有自身低坡、树根与自然末端；像素独立采样数据可测，但不等于合同准入 |
| 完全透明条间隙 | 至少80px | alpha>=2上体到y385，下体始y406，中间21px；alpha>=128为33px；alpha>=1尾部占据整个间隔，没有严格全0整行。**80px失败** |
| 上far宽高/角色 | worldW1300/H200..240，低频退远，depth.28 | alpha128bbox[13,96,1749,282]，等比1300×209.605489，数值范围符合；颜色/景深仅源观察，不代实景 |
| 下middle-far宽高/角色 | worldW950/H280..310，约3.2比，depth.12 | alpha128bbox[13,411,1748,435]，比4.018，等比950×236.413043，**目标高度/轮廓失败**，不拉高救规格 |

整族原规格状态failed，G0原约束预检failed，G2未验；原图保存为失败候选，不准批量推广，不让树林失败阻塞正确地形下一包。能辨认两条树林不是“已经完成两层真实视差”的证据。

## 实测分区（只供复现，不授予采样准入）

用真实alpha2 body bands之间385..406的间隔中心选y395；不是直接对半裁图。上region[0,0,1774,395]，根锚region-local[887,368]，ground_line368。下region[0,395,1774,492]，根锚region-local[887,442]（global837），ground_line442。family.json layers[]保存source-global与region-local alpha1/2/128/250、每层比例/等比尺寸/深度及失败状态，filter_clip只作技术候选。若未来获不同准入范围，也须保留原80px失败并明确新任务，不能修改此原合同。

最初临时midpoint443探针混入下条树冠，且打印lower bbox时漏加全局y偏移，已废弃；中间一次测量脚本空格拼写SyntaxError未写成功，已修正。最终数据明确以395分区、全部global/local坐标一致；原row occupancy保留。没有把测量脚本失败算成图生失败或偷偷再出图。

作者源观察：上条较柔、下条树干与石坡较清楚，材质沿水粉苔草/石灰岩；下条大冠偏浓、树脊上下留白不足，原图彩色细尾明显，实际滤波会否露光边未验。根坡有较长横边，若在真实主路空隙中露出可能像悬浮岛，仍需后续真实镜头，不能补不透明底带/贴屏/纵向循环掩盖。alpha0隐藏RGB不是已证游戏灰底；本次失败来自原80px/尺寸目标未达，不是虚构GPU测试。

## 产物、验证与退出

source.png/family.json冻结，原工具/测量在自身production/；共享spaces manifest、旧CLOCK/旧失败卡、游戏脚本/碰撞/相机/资源/RNG未改。正式consumer未接入。本任务没有新增独立Sprite、没有相对运动或全路线/设备/用户证据。根当前parent累计图生5/18（前4+本1），账本由根维护，本代理不改共享budget。

原字节/SHA/RGBA/alpha行及分区测量实际运行exit0；它证明失败事实与来源真实性，不证明资产通过。现有全局art静态校验exit0同样不覆盖这张尚未晋级新源。质量卡保持review，G0/design failed（原规格），technical仅完整性/记录检查passed，其他全部unverified。真实ready_for_review交不同审查者决定接受限定生产事实或拒绝原资产；原controller不得冒称原G0/G2或完整内容complete。停止本包图生，下一独立terrain包等待根新租约。
