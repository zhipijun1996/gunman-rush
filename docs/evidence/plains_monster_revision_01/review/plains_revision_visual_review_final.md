# PLAINS-MONSTER-REVISION-01 · 最终有限复审（R5）

**限定ACCEPT：发现的死亡落位缺陷已在实际新片改善／修复；真实平原静态同屏像素粒度一致性可进入用户复审。整套所有动作、听感、动态完整碰撞、实体设备与用户G5仍UNVERIFIED，主任务保持review。** 独立审查者 `/root/revision_r3_review`，未写生产／测试／任务文档，未运行Godot。没有把技术marker／基础0gaps换成商业品质结论。

## 本次真实来源

最终production源：clean `7edda9f5f2a20c5406391ff3f7edebbeb2322047`。独审实际读取两份完整原始capture.log、report与trace关键原件：

| 证据 | 实际结果与边界 |
| --- | --- |
| `build/plains_revision_01/review-05` | 原Godot60fps/1280×720，76.166667秒，7个实际输入／AI／弹体消费者，basis0gaps，source_stable=true，clean source。明示初始实验场，不是自然平原路线。 |
| `build/plains_revision_01/comparison-03` | 原DemoApp正式生成平原、同seed、原camera1.60，30.266667秒，6页各300帧、manifest未改、source_stable=true，clean source。玩家／原俯冲／新怪同屏；sample AI与玩家输入held，标签明确NOT COMBAT。 |

两份原生日志均无script/shader/ObjectDB/resource/RID失败；保留实际VSync warning及软件llvmpipe条件。MovieMaker用fixed60fps，原录制墙钟较慢，不把它当实体性能／正常交互帧率证明。视频含原引擎音轨，独审未听音，不能签声音或混音。

## 实际看过的像素

独立从最终原MP4实际解码164个不重复画面：7怪各20张致死前→稳定落位后的时间连续样本，另6只各4个状态原全帧已提取。本轮真正逐组查看了全部7组死亡20样本板，另加Charger首次攻击6张原片与原全帧前后；此前R3已看6组状态裁区，本轮不重复声称已完整观看新片的每个状态。正式comparison03六页各取中段一张原1280×720完整帧，6张均实际看过。

死亡裁区不缩放／不改色，来自实际身体位置和camera映射。`/tmp/plains-review-r5/extraction.json`记录MP4 n、trace行和裁区；MovieMaker引擎序号与MP4零基起点的一帧差未独立校准，不伪称亚帧精确。全片未实时连续播放，不能由20张采样签所有节奏／中断。

## 局部修复在最终源保留

| 物种／问题 | 最终实际像素观察 | 限定结论 |
| --- | --- | --- |
| 巡逻薄尸R1 | 折腿、头最后落低，末态仍有褐色躯干厚度，不再是数条薄纹。 | 旧薄片缺陷没有回归；完整转向／步态未签。 |
| Hopper R2仍承重低伏 | 后腿向后释放成低伸展，圆腹降到平台附近、头再垂落；不像R2架在四脚上准备再跳。 | 已有实质改善；整套空中致死及抽动正常速度未签。 |
| Sentry R2竖杆／直立囊 | 落成低位空囊／叶／铜口轮廓，R2高竖杆消失，腿不再架起直立躯干。 | 已有实质改善；所有吐籽／瞄准相位未签完。 |
| Root R2展开冠、R3铃浮空 | 枯垂冠和折茎保留，真实铜铃／铃舌下端落到平台顶附近，原R3约10–20屏幕px空隙不再出现。 | PRV-R3-01真实接触修复保留；低铃听感／完整AVsync未听不得签。 |
| Charger | 折前腿／角下降后有厚壳终态，样本末段稳定；新碰撞源未使尸体悬空。 | 所看死亡局部成立，侧翻重量完整节奏仍待用户。 |
| Diver | 保原蓝灰翼膜／铜腹，失力收翼转为落地侧卧，样本末段稳定。 | 没有换身体身份；细微回弹／翼尖滞后未以代码代签。 |
| Fan | 空中失同步、坠落后双扇松摊，铜腹暗，末态稳定；缩小核心碰撞后仍能落位。 | 所看死亡局部保留，悬停／全部开扇节奏未签完。 |

实际Charger首次attack的trace行697→719，x712.5→580.5，23帧位移-132wu；独立解码6张该窗口的原画面和首尾完整帧，清楚看到身体真实冲向玩家，并非仅AI state marker。`/tmp/plains-review-r5/charger-first-charge/receipt.json`记录真实位置与画面。此支持sole探针修复后该实际战斗消费者可移动，不把一次冲出升级成所有转向／刹停品质通过。

全部所看样本未见普通HP或纯未来路径／瞄准线；真实弹体、命中星火、身体关节与实际地面实体不因该要求被当作辅助线删掉。这仍不是所有森林／Boss表现分支的独立图像覆盖。

## 用户追加的像素粒度

最终comparison03原camera1.60的六张完整合屏，玩家、未改俯冲、新怪与草地／风车背景保持同一细像素尺度。新怪轮廓台阶没有独立变成粗棋盘块，也未见线性模糊边；铜／灰绿／麦黄的大材料块可认，原背景不被新怪高亮特效盖住。**限定接受这六个实际静态同屏的粒度与场景融合，足以供用户在工坊继续审核。** shader=1wu、PNG分辨率或贴图hash不是这个结论的代替依据。

六只仍是与玩家／Diver适度的小中体型，Root较高但铃口是焦点，Fan宽扇与细长蓝灰Diver可区分。没有旧六怪并排，所以不签每个器官的精确+5/10/15%倍率。用户审美与缩小后可读性仍由用户／实际设备分别确认。

## 碰撞边界与代码／反例分开

同源comparison03真实trace确认Charger28×28、Fan22×18，Root40×48，其余28×32；没有靠换visual scale制造比例。Fan box按约14wu腹与约3.3wu镜向偏移包住核心／翼根，外翼不是整个solid box。Charger顶缘回到新壳内。有限代码／物理审查在 `/tmp/plains_revision_collision_review.md`：原339/2支撑失败保留，sole-2→+8真实10wu探针后340/0，左右core实际radius3 sweep命中、旧过大顶框越过、真实支持move_attack和无支撑拒绝。

这些有效地修复了已找到的明确尺寸／支撑缺陷。**并未逐像素签全部动态身体碰撞**：未完成所有翼尖、腿、头、角、横纵来弹／玩家接触的自然战斗矩阵，不能将neutral alpha bbox／UV映射或本片held展示当精确动态命中审美通过。没有发现需要继续扩大本轮返工的新严重画面缺陷；其余未验如实留在具体动作卡，而不是涂绿或无限补造检查。

## 总体状态与失败链

本轮局部可交工坊，版本标review，保R1/R2/R3失败、R4局部触地接受及R5当前源证据。主怪物任务不能因窄测试守门process的独审ACCEPT变成完整内容ACCEPT。全部动作／中断节奏、听感、平衡、设备和用户G5仍未验；当前适用完整Harness由root集中执行，不由本报告预签。

```json
{
  "/workspace/gunman-rush/build/plains_revision_01/review-05/report.json": "1c54871be7e349bf535ac2d378128692270c8307300db01b58c6a04eaee1c269",
  "/workspace/gunman-rush/build/plains_revision_01/review-05/trace.json": "fedfd3ab9086991d2db7b8cea9e81659f6e74daf8e133123342162e17bf88da8",
  "/workspace/gunman-rush/build/plains_revision_01/review-05/review.mp4": "5596f4d050299e6a0dc10b8d4f56cc0b46ede1b2b31c87f466ead856e95711c4",
  "/workspace/gunman-rush/build/plains_revision_01/review-05/capture.log": "5d812845c559b6b9ee1a8458f282fd9257b3267c5e5dafe83069189e57dc4b95",
  "/workspace/gunman-rush/build/plains_revision_01/comparison-03/report.json": "41b4ac256e9dd08bdd41487a35e320fbc696f2c61b885d89bf57075ed6c6b7a0",
  "/workspace/gunman-rush/build/plains_revision_01/comparison-03/trace.json": "7f9adf56177cc6319a63795830da0431e415080c2aa93c939b5f44cea2de6732",
  "/workspace/gunman-rush/build/plains_revision_01/comparison-03/review.mp4": "4956488e5a56b58c456fa919291c8b6f57950fc1f3c9c10c1480f3d2e5347ea4",
  "/workspace/gunman-rush/build/plains_revision_01/comparison-03/capture.log": "07ad89b4dfb77628f38cb22e7552e96079d42db23ace524e633953fe678b0ddb",
  "/tmp/plains-review-r5/extraction.json": "04b6142c2510a315d89b7c4ffa2de876a001e72b61573b04dd4fea52584a030b",
  "/tmp/plains-review-r5/charger-first-charge/receipt.json": "2d3f74fa44254f52f35afb92784c0888e2cac817284f7da63a78d5aef38a11a6",
  "/tmp/plains-review-r5/charger-first-charge/body-sequence.png": "1f04aa359e866b7b806bc33b747415cd15a59c631aa06dd3c3e6c59f3fc5c93b",
  "/tmp/plains-comparison-r5/extraction.json": "7770f75c1c15aa7888a0b6910488dcf4056f0b2f9ec154bd9ca8e532e0d889c1",
  "/tmp/plains-review-r5/patrol_drone-death-sequence.png": "d7ad84b97d3de4fb642b4e3f2b8fc9a203e9a46353c9b8bde883cd030a1a908f",
  "/tmp/plains-review-r5/plains_charger-death-sequence.png": "069ee6cbaf38f0da403f374dc74ff7b5ca21743696f2785a83d2e1e8fbfbdae4",
  "/tmp/plains-review-r5/plains_diver-death-sequence.png": "ef65e0ad6033b981083cb22119ea04ac0a45c2a4d2a8f749236de4f8957f16c2",
  "/tmp/plains-review-r5/plains_fan_sentry-death-sequence.png": "84807b9eee7c62f3919b0dc0828cfddff47832ea83ff76ab0d64ee27973ae5e0",
  "/tmp/plains-review-r5/plains_hopper-death-sequence.png": "dec031c3f51338d258b34b7feb68ba1936145341ebbc91504232e48d916d4d89",
  "/tmp/plains-review-r5/plains_root_bell-death-sequence.png": "b9cad94023c9b28a55e7a6a469597548b7ad66cabc5ac3bf8922833b5cd1bc28",
  "/tmp/plains-review-r5/plains_sentry-death-sequence.png": "ef112455f9dba6f56300ab16cce6a576109b468c4d7ed7428c6643ceb70f4a81",
  "/tmp/plains-comparison-r5/charger.png": "c0eb5b80c20f3366fd293292756ca60f56aa06c55e5f23646140c40534cd71bf",
  "/tmp/plains-comparison-r5/fan_sentry.png": "2cae79fd926d22dd863b1892e92bd0d4525ee0c48b8e5a90a09bf9253370ae32",
  "/tmp/plains-comparison-r5/hopper.png": "9f0c77dd00523a4fa34878ee9e9e33566ea3cfb4fe058555f31c80ac8e588326",
  "/tmp/plains-comparison-r5/patrol.png": "572efcddf63ac7a7546170ecbcdd3448d5fd64cbb47da31bdffa87d0bb69c887",
  "/tmp/plains-comparison-r5/root_bell.png": "31fb00f8bbb4ccec0689b0c89718914b039e464c0a8d30fbbe0c0c1fc4ea8aaa",
  "/tmp/plains-comparison-r5/sentry.png": "6d1e01e7a6c8c8d7607a96da70ceaed955116477d594a18cc42e91eb05d613d6"
}
```
