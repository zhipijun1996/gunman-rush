# PLAINS-MONSTER-REVISION-01 · 视觉 R2

**结论：REVISE。** 当前4ff影片的 basic0gaps／技术退出通过不能签动作与死亡品质。独立审查者 `/root/plains_revision_review`，不是实现者；未写生产／测试／任务卡，未运行Godot。先前R1视觉REVISE、代码R2限定ACCEPT和本报告分别保留，互不替代。

## 实际来源与观看范围

- 录片报告源：`4ff79069628776ac489e3344cd3e49d390a4db56`；`source_stable=True`，原MP476.13秒、7个真实Underworld渲染链、原引擎音轨。目录 `build/plains_revision_01/review-02/`，完整报告和原trace保留。审查不把固定初始实验场说成自然平原场景。
- 真正看完7组live/death共14张原尺寸截图（`inspection/`），再从原MP4分别解码7只各20张致死前→落位后连续样本，共140张。每种的局部序列在 `/tmp/plains-review-r2/<id>-death-sequence.png`；`extraction.json`记录精确视频时间、所选trace行及裁区。裁区未缩放或改色，保持原片屏幕像素；只跟随实际身体位置方便看关节，不伪称原相机运动。
- 未完整实时播放76秒、未听音轨，不能签声音／正常速度全动作节奏／真机。活体截图大多在recovery/attack，未覆盖每种全部蓄势、出手、收招窗口。
- Raw drive-frame与MovieWriter frame有逐case装配偏移：死亡时间以真实解码画面和trace的movie_process_frame为准，不能简单把events.frame/60当MP4绝对时间。此处的具体秒数都是实际解码视频时间。
- 正式同seed平原比较当前未取得可用画面，本报告不签比例／主身体碰撞范围，也不拿实验场技术背景代替美术合屏。

## 首要三项真实失败及返工层

### PRV-R2-01 · 草籽哨兵尸体仍直立，泄气与前倒不成立（高）

实际52.40–52.67s稳定末段，浅色种囊仍像一颗站立饱满的球，喷口／颈叶组合形成竖杆般结构，身体主要像坐下或蹲低，没有“种囊泄气→喷口垂→支撑腿折→躯干前倒→叶最后塌”的清楚受力关系。51.40–52.31s连续样本可见确在变化，故不是漏播死亡；问题在落位目标与关节层级。

先返工骨骼／几何：为囊和躯干确定前倒后的实体接触位，解除腿部承重；喷口、颈和叶的挂点跟随已倒下的父体，再各自下垂。保住空壳厚度，不把所有点挤到地面。当前中性图可先继续用，不据此要求批量生成新图；只有需暴露原图未绘腹侧或改变遮挡次序而无法成立时，才补一个严格同体死亡关键姿态。

### PRV-R2-02 · 跳跃怪腹部没有落地，终态像仍能发力的低伏（高）

实际41.63–41.98s已稳定，腹仍被腿架在地面以上，主要轮廓像保持可起跳的蹲伏；未读到后腿失力摊开、腹先落地和头最后垂下。40.76–41.54s确有后腿与头部变化，说明这不是状态没进，而是最终质量／支撑关系错。

先返工髋—踝与腹部父体落位：把腹的最终下缘置于真实支撑附近，圆腹质量整体落下，后腿向侧后方释放承重，头再滞后垂落。不要回到R1整体乘y的薄片方案；保体积后改变重心高度及支撑。当前体图不需要先重生。

### PRV-R2-03 · 根铃叶冠仍撑起展开，枯垂不够（中高）

实际73.73–74.02s，铃已落低、茎也有弯曲，但叶冠仍抬起并大幅展开，茎／根组合像仍承重的高拱，缺少逐节失力与叶尖顺重力枯垂的末态。72.68–73.63s的连续折落过程存在；“有动作”不能抵消最后仍像活体支撑的轮廓。

修关节父子链与传递后的pivot：每一上节茎／铃／叶使用下节弯折后真正移动的挂点，叶尖再沿重力垂下。不是要求整株都压到地面，更不能把拱形一刀裁平；保枯根和暗铃的实体厚度。只有单层中性纹理无法形成必需遮挡关系时才考虑单个同体死亡关键帧。

**共同事实：Remains.settled只证明共享脚锚找到真实支撑；它不证明种囊、腹、铃、叶等特定器官已经按美术目标落位。** 自动技术门槛不能替代这些实际像素失败。返工后新提交另录，原4ff失败原件不得覆盖。

## 其余四种本次有限观察

| 物种 | 真正看到的内容 | 本轮范围结论 |
| --- | --- | --- |
| 巡逻 | 7.02–8.53s序列中，折腿后头部下落，8.21–8.53s躯干比R1明显厚，头／胸与躯干不再完全合成2–3条细纹；普通头顶HP与路径线未见。 | R1薄片缺陷有实质改善，这个末态无需与上面三只一起扩大返工；整体行走／转向品质和用户认可仍未签。 |
| 冲锋 | 17.58–19.15s序列有前腿折下、角／壳下落、最终仍保甲壳厚度，末态所抽样本未见循环抖动。 | 未见前三项同等严重的落位失败；具体侧翻重量、刹停和所有攻击转换仍待正常速度及正式比例复审，不把尸体静止升整怪ACCEPT。 |
| 俯冲 | 29.25–30.30s序列清楚失力、收翼、转为侧卧并落到地面，最后蓝灰翼膜／铜体仍清楚。 | 原身体身份与留尸成立于此局部样本；微小回弹与翼尖滞后不能仅按代码参数确认，全动作与用户认可未签。 |
| 扇射 | 61.60–63.85s序列可见空中双翼失力不完全同步，随后地面翼松摊、腹变暗，落位后所抽样本稳定。 | 末态比sentry/hopper/root清楚，当前不要求新图；悬停展扇／真正发射节奏、躯干5–10%与翼宽15%须正式比较证据，不由总bbox代签。 |

这7个实验场样本的普通怪与玩家像素阶梯接近，未看到明显的粗像素放大；仍需正式场景与未改俯冲同屏，才能判断整体美术粒度和相对体型。不能以“shader=1wu”文字直接签视觉一致。

## 后继复审条件

最小返工限定上述3种死亡关节／接触目标，不重开全体美术、不因模型预算扩大生成。冻结新源后先录3个从实际致死到稳定末态的连续小样；再核未改四种的技术消费者及真实平原比例／碰撞。原3技术green、R1/R2失败、用户旧拒绝和各自源绑定全部保留。当前总任务保持review，用户与实体设备仍unverified。

## 原始媒体与截图 SHA256

```json
{
  "review.mp4": "acf7f76b6dfb32df8868162d24190fd1119eb52ca5255eb50b0fe8a53994d720",
  "report.json": "68068227a87e539677652ad81a4748db3e7dbd5804849cd5245e16b53d36460e",
  "trace.json": "92184fafe84f3bb36a01df2c19a0f41e6acf3442b6a750e292037905db4b3842",
  "inspection.json": "cc4e48322841792dbf8799b9b1f1b322a3e9511e0615378d686aed4747afd199",
  "inspection/patrol_drone-death.png": "c497ff5548458bd29d720da93f9e541ba224f37293c8d4dd89f596e45f70a11c",
  "inspection/patrol_drone-live.png": "70b34e5ccfbe742306fa736f6fdc3200fa25d60fe390b557db5e1b573edac083",
  "inspection/plains_charger-death.png": "0177216da8fce863bffcde97e9828416e3b60b5a161bdabee5e8960653440cd2",
  "inspection/plains_charger-live.png": "1afa3adb8425d437f3f99000c7a6ed833ab8daeb3b359a99ca49f3bf4b966db0",
  "inspection/plains_diver-death.png": "85ec0e6526321e37faf2e6f586bd3fb1e0c75756a536f88cc3d702b06842bccf",
  "inspection/plains_diver-live.png": "8efed66c3428019d792d592584d75d067399ae5f3590cf3219fd33d10e4d7754",
  "inspection/plains_fan_sentry-death.png": "94059edcbf4b3732c8de2971174afcfe4a9d002a65cff3e898add2d19fb7c92b",
  "inspection/plains_fan_sentry-live.png": "6c1b9bf97d4bfa17a9bac4d8dce5066d9fc886db70a059bc41f6d4fbbe030ebd",
  "inspection/plains_hopper-death.png": "da7a08a3f3e70a19abb71b5ce7473699136107e1ce7bbfe7d0bb358fc8d1de8b",
  "inspection/plains_hopper-live.png": "32d1ea3af6998fc3b69cd9740dde55aa117669dd6c011c1239eeb50717adbc33",
  "inspection/plains_root_bell-death.png": "45f401b1eab6033d92b4f5c52fb81cd5c22204ed3b7615c5fcdcdcdb8af1f781",
  "inspection/plains_root_bell-live.png": "2dfb054859185a694c137f70e2fc062f14636512002a8425359e33e2fdc1cafa",
  "inspection/plains_sentry-death.png": "98098c3dda01d07a3986a7799820187ad5c969a1da94d793c25c883e51cbbbe8",
  "inspection/plains_sentry-live.png": "f96bc220b25ec698586e2b15ea7ff2e88de4a50a98ca56aac4b451fa8ce33144"
}
```

## 独立实际解码序列 SHA256

```json
{
  "patrol_drone-death-sequence.png": "87e9604a0a1d64399983be776d8f3add362bffa86cc825a9a168a7a314107732",
  "plains_charger-death-sequence.png": "dbbc4f0ac8da751b497f78b2e64b40e89c0ba1ef33d5062a7595eaf47f640d28",
  "plains_diver-death-sequence.png": "1e0560594e5de94789350d7a0ac547a51f91de7b0747e510a6cdd04e76910489",
  "plains_fan_sentry-death-sequence.png": "22a21d75a6984ec6a57c9dab43bd34a0c51f537d2658d5550a72aec32cddac5c",
  "plains_hopper-death-sequence.png": "5bcd5bb810d099b4f31c3cbfb44ea9747338d36b8248bdceffb3d6c7bcf1a567",
  "plains_root_bell-death-sequence.png": "36b6d00a2ed4090308cb21b6c091439327f817d3cf3cb41ca9a04cb1e6a7ac05",
  "plains_sentry-death-sequence.png": "2f7a6ab80e52dedd32b5440ae1f8ef3837f440ebc54d564ca112d8e4b6ebd28e"
}
```
