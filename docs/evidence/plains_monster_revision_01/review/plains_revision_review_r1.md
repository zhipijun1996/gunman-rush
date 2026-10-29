# PLAINS-MONSTER-REVISION-01 · 独立审查 R1

**结论：REVISE／旧样本不可作为本轮制作完成。** 审查者 `/root/plains_revision_review`，实现者 `/root` 及其有明确写集的制作子代理；审查者未修改生产、测试、任务卡，也未运行 Godot。报告为 R1 留档，不能因后继修复而回写为通过。

## 实际审查对象与身份

- 基线 commit：`0d33ab56cb06d5bb37b30bd82387415ae5c7725e`。影片使用当时尚未提交的工作树，不声称基线 commit 就是完整录制源。
- 原采证目录：`build/plains_revision_01/dev-patrol-01/`。原生报告 `report.json` 保存完整 working_files、git diff、untracked 及 source_stable=true。实际执行 exit0／22.541s，10.65s MP4，1 个 patrol underworld case，basic coverage_gap_count=0。
- 电影 SHA256：`afec7b90e6d7eb4a150f39dfd953502ade0cf4c7f63897f6521906e0fd13c6a2`。
- 真实最终 renderer：`UnderworldEnemy`；实际 Definition 为 `graybox_patrol_drone`，不是名字相近的伪造 ID。
- 实际观看：`live.png`（2.0s）、`death.png`（8.0s）；另从同一原 MP4 解码观看 7.00–8.52s、每0.08s的20张局部连续样本（MP4 frame约420–511），保存在 `/tmp/plains-review-r1/patrol-death-sequence.png`，原解码单帧同目录。未完整实时播放整段、未听原音轨；不得签听感。
- 以上仅为初始实验场、原 AI／Router／弹体／伤害条件的 patrol 局部证据，不是真实平原同屏黄金，不覆盖其他6只、Boss、森林或实体设备。
- root 的 native 314／0 是实现者运行证据，本审查没有冒称独立执行。

## R1 发现

### PRV-R1-01 · 巡逻终态压扁，侧卧厚度与头身层次失败（高，实际像素）

7.00s 活体仍能区分头胸、躯干和腿；7.40–7.72s可见分段折腿。但8.12s及后续8.20–8.52s，落位后的主体被压成约2–3条水平纹理层，头／胸／躯干轮廓合并，呈摊平薄片而非保有体积的侧卧身体。不是只取8.0s中途一帧的误判；终态连续样本均出现。旧 ground 实现把全点 y 乘0.43，再下压头，并在最终顶点钳到地面，侧卧体积没有被独立保住。

最小返工：先保躯干实心体积与侧面厚度，腿独立折收，头独立最后落地；不要只延后淡出或提高透明度。复验须同体、原比例、正常速度从致死前到稳定末态，以及真实平原与玩家／俯冲对照。

### PRV-R1-02 · Flora 死亡首帧未延续 live joints（高，代码反例）

R1 的 `PlainsRevisionFlora` 在 sentry／fan_sentry／root_bell 的 dead 分支从 neutral point 开始，而 d=0 时不经过捕获 live pose。与 ground 的 live→target 桥接不同，蓄势、出手或受伤时致死会立即把当前器官形变复位。fan还在air+d≈0强制另一组翼角。此为时序／姿态反例，尚未用这3只的实际电影确认幅度。

最小返工：death=0严格等于捕获 live joints，再从该姿态分器官失力；死亡优先级不能等同于瞬间回中性。补攻击中／受伤中致死的真实连续首帧对照。

### PRV-R1-03 · 巡逻转向仍先整图翻转（中，代码反例）

R1 Visual.refresh检测brain.direction变化时立刻改_face，随后scale.x翻整个身体；turn_age=0仅在已翻身后驱头部。与“先探头，再带动身体”的时序相反。最小返工为渲染侧头部领先、躯干滞后，不能改AI判定朝向以配动画；左右与连续转向须实拍。

### PRV-R1-04 · 喷口未消费真实锁定瞄准方向（中，代码反例）

R1 pose没有aim字段，sentry喷口关节仅依赖load／strike／turn／hurt的固定角度，无法在斜上／斜下目标间表达真实锁定方向。需从只读表现状态提供既有locked_direction，不改弹体方向和时钟，再用喷口关节对齐。复验至少水平、斜上、斜下。

### PRV-R1-05 · 新身体绘制缺少已存在的纯绘制屏外早裁剪（中，性能回归候选）

R1 draw_pose无旧body_mesh_visible早退，625个顶点每次绘制都重新计算并上传；host持续queue_redraw。正式多怪场景可能重现此前CPU回归。没有独立设备数据，不虚报实际降速数值。应恢复保守可见边界的纯绘制早裁剪，动作／epoch／反馈时钟仍需继续推进，不能靠停Actor避开。

### PRV-R1-06 · 局部死亡材质目标未完整表达（中，待GPU确认）

R1 fan仅有通用轻去饱和，未有腹部暗下分区；root的plant_body处理主要依赖绿色mask，铜铃大部分不受暗化。用户要求的腹部暗下／暗铃不能由“死亡后淡出”替代。需按器官加有限暗化，再看原尺寸实际像素，不能只读uniform名就签通过。

## 已观察到的正面事实与未验范围

巡逻活体在这份实验场影片中，头／身／腿可区分，与同屏玩家的像素粒度接近，普通头顶HP与辅助路径线未见。此为本样本的有限专业观察，不是全体风格或真实平原比例通过。实际伤害／一次致死／原攻击取消／无碰撞尸体的代码所有权沿原Actor与Remains，未见本轮表现反向结算伤害；最终仍需原回归。

全7怪动作、实际攻击意图可读性、正式场景与主要身体碰撞范围、声音、真机性能和用户审美均未通过本报告。用户旧品质拒绝保持有效。

## 后继修复交接（不追签 R1）

root 已消息报告拟修flora bridge、只读aim、渲染朝向延后、纯body early cull、分区暗化和ground末态厚度。这些属于后继工作树，未以本R1旧影片重签。待新冻结源与实际7怪／平原比例媒体后作R2。

## R1 关键源码 SHA256（来自原电影 report.source.working_files）

```json
{
  "scripts/enemies/plains_revision_flora.gd": "e2ec4734e1b49da3b89b38144a172e7b6f5030e67ab0df42fba70ab02df87392",
  "scripts/enemies/plains_revision_ground.gd": "f8366b9486844b18954c6dfea7791d0a6df7a81d4fecd49aea703a24a4278074",
  "scripts/enemies/plains_revision_remains.gd": "f086059c4b40fbabccfc9059907e93d5dae753ed861499501012c7282bfb5262",
  "scripts/enemies/plains_revision_skin.gd": "1bb5d544b9b612cea3c7368ba590f03871cfca9cf60ca3fb7df7ad5fa2fe1977",
  "scripts/enemies/plains_revision_skin.gdshader": "8b90794ef53d3b3e92b2a57113664fa63c618d73f5128a5402e77e34491d6f6f",
  "scripts/enemies/plains_revision_visual.gd": "8965aec1852fb8ded5b96ca0424ecf95a9db6e21883bcb83252d900fa15d99d3"
}
```
