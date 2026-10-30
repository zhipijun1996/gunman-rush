# PLAINS-MONSTER-REVISION-01 · R4 根铃接触局部复审

**限定ACCEPT：PRV-R3-01真实铃体下缘仍悬空的问题已修复。** 独立审查者 `/root/revision_r3_review`，只读，未运行Godot。此结论不追签R3失败，不签七怪完整动作、碰撞、听感、设备或用户G5。

实际新片 `build/plains_revision_01/review-04/review.mp4` 来自 clean `49176c04589c9b156b6a9e34543ff25eb01d2022`，报告source_stable=true；实际7case基础覆盖0gaps，但本次独审只新增查看Root的24个原MP4解码画面（20张致死前→稳定落位后，加4状态样本），不是重新观看其他6只。解码保持真实像素，不缩放不改色，出处／movie n／trace行／裁区见 `/tmp/plains-review-r4-root/extraction.json`；MP4和引擎写入起点一帧偏差未独立校准。

实际比较R3与R4同时间末态：R3平台顶y≈180，铜铃下端留约10–20屏幕px空隙；R4的同体铜铃下端／铃舌清楚下降到平台顶附近，原空隙消失，末段73.67–74.00s的所抽画面保持稳定。先前已有改善的折茎和叶冠枯垂保留，没有整体压成薄片或重新换母图。R4末态原240×200图 `/tmp/plains-review-r4-root/plains_root_bell/death-19.png` 可直接核地面接触。

代码修正恰在失败层：死亡专用bell mask覆盖源图实际下缘／铃舌，而不是沿旧活体区域在uv.y .46→.61把其变形权重衰减掉。父茎和叶链不因此重写。Root新增的真实源opaque像素(394,218)接触断言在**原真实旧mask**先跑325项／2失败，命中underworld与root专用两个消费者；修后325／0。独审实际读了这两份原始日志，修后完整日志无script/shader/ObjectDB/resource/RID失败。没有人为污染生产造坏例，没有改小阈值救旧失败。

这条源像素断言只保护选定下缘的≤1wu接触，不代替整个铃体／叶子的视觉审美；本次ACCEPT由新真实画面与局部原生反例共同支持。未听新低铃声，progress=.72和非零音轨不能签听感或完整音画同步。R3三处死亡有实质改善、Root触地局部继续返工后又有实质改善，故不属于连续两轮毫无进步。

整体仍按R3报告保留完整攻击节奏、动态主身体碰撞、全部中断、设备与用户认可未验；后续新碰撞源需要其自身实际检查与最终影片，不继承本局部片为新源证明。

```json
{
  "/workspace/gunman-rush/build/plains_revision_01/review-04/report.json": "c395eec68e198e3ce6abb16aa62844a2c395324b0ad3f109ee87f7cf50cec165",
  "/workspace/gunman-rush/build/plains_revision_01/review-04/trace.json": "78c68e3074b67d50a4746ba82df10b4b2b69a7c3769cd0f31c98a25ef132daf9",
  "/workspace/gunman-rush/build/plains_revision_01/review-04/review.mp4": "c220fa140df04317e588f0427e7911b6e87622770e747562aa684ad1c5f28776",
  "/tmp/plains-review-r4-root/extraction.json": "786f98182a562e6b0ed87b9620e6912fb5afdeae4268ba51f0e962be14d740ca",
  "/tmp/plains-review-r4-root/plains_root_bell-death-sequence.png": "6d7421ff90765183de2703d0d2e4a1bf72b5a559186ab92e18736c7a0c0f2f9d",
  "/tmp/plains-review-r4-root/plains_root_bell/death-19.png": "543e029f55f5650a5ef3aba8ff922e02398100dc5b3a353e52645e0c0be3863d",
  "/workspace/gunman-rush/scripts/enemies/plains_revision_flora.gd": "3f865ec28d18cd93ae025bba0987e6377b893222e26c07ea67ce1f81c4029dc8",
  "/workspace/gunman-rush/tests/plains_revision_01_runner.gd": "d75e535994a135e7f72a3100580c318bcd4d9d50868991c407b57015a17c7414",
  "/workspace/gunman-rush/build/plains-revision-rim-regression-01.log": "9f4e547dbc0974f9945ba438e3f91389be89a2280f66610953f728f6233bc4e5",
  "/workspace/gunman-rush/build/plains-revision-rim-regression-02.log": "9c996b17606d6d013ddcc90aa6986b8cb0c68b4249c6d5a9f8b9ba7668434822"
}
```
