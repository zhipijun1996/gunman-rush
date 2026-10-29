# PLAINS-MONSTER-REVISION-01 · R3 视觉复审

**结论：REVISE，仅剩本次明确复现的根铃铃体触地缺陷必须继续局部修正。** Hopper与Sentry的R2死亡支撑问题有实质改善，Root叶冠枯垂也有实质改善；不能把这轮误说为“全无进步”或整怪全部ACCEPT。独立审查者 `/root/revision_r3_review`，只读，未修改生产、测试或任务文档，未运行Godot。独审代码／守门限定ACCEPT另见 `/tmp/plains_revision_code_review_r3.md`，不覆盖本报告。

## 实际输入与观看范围

- 真实新片 `build/plains_revision_01/review-03/review.mp4`，76.13秒、7个真实AI/输入/弹体消费者；报告 source=`71ccc385ee181fb055c1c6970ce5fa12132869f5`、clean、source_stable=true，基础coverage0gaps和严格退出通过。此为明示初始实验场，不能称自然平原完整游玩。
- 独立从原MP4实际解码164个不重复画面：7只各20张致死前→落位后连续时间样本，另6只的idle/telegraph/attack/recovery共24张原全帧。只跟随实际身体裁切，未缩放或改色；每张精确选取的movie n、trace行、裁区在 `/tmp/plains-review-r3-c/extraction.json`。时间选取使用 `movie_process_frame_after_draw`，MP4零基帧与引擎写入起点的一帧差未独立校准，故不伪称亚帧同步。两次过长FFmpeg select表达式失败只发生在离线提取，保留原目录；最终平衡表达式成功，不改游戏源／媒体。
- 实际看了7组20样本死亡连续图，并看6组原像素状态裁区；Root/Sentry/Hopper另外查看独立末态原尺寸crop。Diver idle及Root recovery样本恰逢真实受击闪白，不能靠其白影判断身体细节。巡逻的状态命名不是idle，本工具未另抽其全部移动／转向，不签完整步态。
- 实际看了正式原地形同屏片 `comparison-02` 六页的中段原1280×720整帧，显示玩家／原俯冲／每个新怪，同seed、原camera zoom1.60，300帧／页。六图及原trace映射在 `/tmp/plains-comparison-r3/extraction.json`。这是 held staged scale comparison，不是战斗或自然移动证据。
- 未实时完整播放76秒、未听音轨，未在实体设备执行。正常速度节奏、全部中断／转向和听感仍未验。

## R2三项的真实变化

| 项 | 实际R3观察 | 本轮限定判定 |
| --- | --- | --- |
| Hopper腹部落位 | 40.78–41.63s，后腿向后伸展释放承重，腹体整体落低，最终麦黄腹下缘接近原平台，头随后垂到低位。比R2仍站在四脚上的低伏明显不同，圆腹厚度保留。长后腿外伸较显眼，但不再是承重蹲姿。 | 接受R2“腹未落地／仍可发力”缺陷已有实质修复；正常速度一次抽动和全部空中致死不由此签完。 |
| Sentry空壳前倒 | 51.80–52.32s，种囊落低，支撑腿不再架起躯干，喷口与叶整体落到前侧，R2高竖杆消失。末态保留可认的淡色空囊，叶／铜口成为贴近地面的低轮廓。 | 接受R2“尸体仍直立／竖杆”缺陷已有实质修复；不追认R2，也不把已缩囊当所有吐籽节奏通过。 |
| Root叶冠与折茎 | 73.23–73.67s，冠与主茎明显降低，右侧大叶确实枯垂到地面附近，上部不再是R2展开伞冠。 | 叶冠部分有实质改善；铃体触地仍失败，见下。 |

## PRV-R3-01 · 根铃铃口／铃舌仍高于支撑，高优先级

原末态crop `/tmp/plains-review-r3-c/plains_root_bell/death-19.png`（选帧n4440/60=74.000s）宽240高200；地面实际顶约y180，左侧铜铃口／下端仍在约y157–169，可见约10–20屏幕px的空气。20样本中落位后持续存在，不是仅一帧跳接。Root叶已经降低，根也有实体厚度，但这仍不满足“铃铛垂落碰地，再短低铃”。因此本轮不能签该接触，也不能用代码的progress=.72、Remains.settled或存在音轨代签。

代码的旧bell权重在源uv.y .46→.61衰减；实际铃舌下缘接近uv.y .58，末端只很少跟随已降低的hanger。应只校正该器官的真实alpha区域及传递后的挂点，使下缘实际抵达原支撑；保留本轮已改善的stem和枯垂leaf，不重生素材、不整体压扁。Root已收到问题并计划用真实opaque源像素回归捕获旧mask失败，修后另录、保留本片REVISE，不由公式宣布成功。

## 其余四种死亡局部

巡逻在7.33–8.18s折腿、侧倒、头落低，末态保有厚躯干，未回到R1薄片。冲锋在18.20–18.80s前腿／角先后降低、壳有厚度，抽样终态稳定。俯冲在29.52–30.28s失力收翼、侧卧落地，蓝灰翼膜和铜腹身份一致，末态稳定；微小回弹／翼尖滞后没有足够正常速度观察签完。扇射在62.07–63.50s先后失力后坠地，终态翼松散摊开、腹暗，未见末态循环摆动。上述均仅是这些实际局部样本，不是所有移动、蓄势、出手、收招、受伤分支的整怪ACCEPT。

状态裁区中，Sentry种囊的蓄势变大／出手回缩和实际籽弹、Fan开扇／发射／收扇、Hopper离地与落回、Diver翼角不同可以看出。Charger负重姿态变化较小，Root状态取样又有受伤遮蔽；完整攻击可读性仍需正常速度观看。样本中普通HP／未来路径线未见；真实弹体、命中星火和地面实体不按辅助线删去。

## 正式平原同屏：像素粒度、尺度和碰撞边界

六页真实同屏1.60视角里，怪物轮廓与玩家、未改俯冲、前景草地的细像素台阶接近，未见怪物独立放大成粗棋盘像素或线性模糊，铜／灰绿／米色材料也与现有画面融接。可限定接受这些实际六页的静态整体像素粒度一致性，不以shader=1wu文字替代画面，也不签缩放、全动作或设备。

当前六只与44wu玩家及40wu可见俯冲相比是适度的小／中体型：巡逻低于玩家且头身腿可分，冲锋宽矮且象牙角醒目，Hopper后腿可认，Sentry浅囊／铜口分离，Fan横向双翼与细长Diver不同，Root高约60wu而铃为焦点。本片没有旧六怪同屏，故不据此精确签每个器官的+5/10/15%倍率。

真实碰撞盒分别为patrol/charger/hopper/sentry/fan的28×32、Root40×48；真实neutral可见体分别41.4×39.33、40.5×30.375、41.4×33.12、41.4×42.46、41.4×30、49.5×60。Charger/Fan碰撞高度略超全部可见体；Fan核心腹更窄，Box包含部分翼根／肢根。此处既没有实际投射物逐部位擦边，也没有动画轮廓与碰撞的完整合屏验证，**主身体动态碰撞吻合保持UNVERIFIED**。不能把alpha总bbox与UV映射当美术／物理已精准匹配。现有shape仍有明确旧消费者/机制依据，不擅自凭一张图重定义全体碰撞；若继续调整应独立明示其玩法影响与反例。

## 后继

只重做Root真实铃下缘的接触与对应低铃时点，冻结新源后用同真实消费者复验，保留此轮与R2失败。R3对另外三处确有改善，因此有依据继续这一局部返工，不能虚构“两轮毫无改善”。其余当前局部成果可进入工坊具体动作／版本复审；整体任务仍review，用户／完整G5／设备／听感不代签。

## 原件与解码收据SHA256

```json
{
  "/workspace/gunman-rush/build/plains_revision_01/review-03/report.json": "cb1d92fb096ff3d7ca977ab38c71f2c3a69234275d45e22ae87b9ae92178126a",
  "/workspace/gunman-rush/build/plains_revision_01/review-03/trace.json": "78c68e3074b67d50a4746ba82df10b4b2b69a7c3769cd0f31c98a25ef132daf9",
  "/workspace/gunman-rush/build/plains_revision_01/review-03/review.mp4": "31e7389112ed30bad122d65b6996c68c9279b577242b9260512f2975c46f10f9",
  "/workspace/gunman-rush/build/plains_revision_01/comparison-02/report.json": "a5cea27559fec1aa47eefb9db445fc90454e4bf91ed31b04063ad6a60021eddf",
  "/workspace/gunman-rush/build/plains_revision_01/comparison-02/trace.json": "9bca6b8d6b0808d2a1f1160be66cb1b65bf96a9d76a21d2ed19a7f08d4c067b8",
  "/workspace/gunman-rush/build/plains_revision_01/comparison-02/review.mp4": "4956488e5a56b58c456fa919291c8b6f57950fc1f3c9c10c1480f3d2e5347ea4",
  "/tmp/plains-review-r3-c/extraction.json": "0d98f9f93a247747b6e2aa418b8ea17b4ac3acfe6cd64d41f015607e7021f8c5",
  "/tmp/plains-comparison-r3/extraction.json": "84abd04183c172a2d92c6aef9ae11503700500ced416885dc170f7fb5852deb2",
  "/tmp/plains-review-r3-c/patrol_drone-death-sequence.png": "d7ad84b97d3de4fb642b4e3f2b8fc9a203e9a46353c9b8bde883cd030a1a908f",
  "/tmp/plains-review-r3-c/plains_charger-death-sequence.png": "f5bd1e8408c6b9b0f6ca4c4ad812969fda5ee703b46f0622a7eb280ea1bddb7e",
  "/tmp/plains-review-r3-c/plains_diver-death-sequence.png": "2ae8df0a384bcc23709b82998b1963672ff1ef674ff1146280fe4605ed7b864d",
  "/tmp/plains-review-r3-c/plains_fan_sentry-death-sequence.png": "7e7cce93fd6d5265e0b70c475863367950d399660595e62037cff1d196d88989",
  "/tmp/plains-review-r3-c/plains_hopper-death-sequence.png": "198caca65f70f56b1cd8b34d8f06b81a3a4bfab0ea73032ae9df650707e06250",
  "/tmp/plains-review-r3-c/plains_root_bell-death-sequence.png": "175b18aefdb94d41cbb5e784920e75a9a7d0068cfbf73abf004177a6cab04ef7",
  "/tmp/plains-review-r3-c/plains_sentry-death-sequence.png": "542915e0f39f205af834fb80fe30cb0f6fbae5b1599c5330231d9a9543f58cfc",
  "/tmp/plains-comparison-r3/charger.png": "c0eb5b80c20f3366fd293292756ca60f56aa06c55e5f23646140c40534cd71bf",
  "/tmp/plains-comparison-r3/fan_sentry.png": "2cae79fd926d22dd863b1892e92bd0d4525ee0c48b8e5a90a09bf9253370ae32",
  "/tmp/plains-comparison-r3/hopper.png": "9f0c77dd00523a4fa34878ee9e9e33566ea3cfb4fe058555f31c80ac8e588326",
  "/tmp/plains-comparison-r3/patrol.png": "572efcddf63ac7a7546170ecbcdd3448d5fd64cbb47da31bdffa87d0bb69c887",
  "/tmp/plains-comparison-r3/root_bell.png": "31fb00f8bbb4ccec0689b0c89718914b039e464c0a8d30fbbe0c0c1fc4ea8aaa",
  "/tmp/plains-comparison-r3/sentry.png": "6d1e01e7a6c8c8d7607a96da70ceaed955116477d594a18cc42e91eb05d613d6"
}
```
