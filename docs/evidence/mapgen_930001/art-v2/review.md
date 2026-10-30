# 固定地图 candidate-v2 只读独审

审查日期：2026-10-30。任务 MAPGEN-930001-01；固定 seed 930001、交付包 0.1.0。本报告补充[原接入独审](../review.md)，不覆盖此前失败记录。

审查源 `cce9d74f408f2229d092909f88054a177de2668d`，生产实现提交 `6f1ae4b`，分支 `feature/mapgen-delivery-930001`。实现者为 root agent；审查者为独立 child agent `/root/review`，没有修改生产或测试文件，没有运行 Godot。方法为独立源码反例检查、读取作者实际运行原件、核验字节、打开实际 PNG、在内存解码影片抽样帧。**独立静态／图像审查成立；独立操控重跑 G1/G4 为 UNVERIFIED**。不把作者运行写成审查者运行，不代签用户采用、听感或设备。

## 合同与结论

用户纠正旧版美术后，本轮应接入主游戏现有新版平原地形、背景、玩家和实际交付怪物的正式表现；仍保持交付几何、封口、敌人、奖励、玩家物理和宿主事务。只装固定地图，不扩展生成算法或其他 seed。

**有限结论：本轮表现接入的静态实现和已观察消费者可 ACCEPT；整张地图端到端完成仍 REJECT／BLOCKED。** M24 的原三项真实失败没有解决；全图连续自然路线、所有动态最坏相位和完整 168 项生产计划未验证。不能将 842/845 通过写成整图通过。本报告不包含商业美术、设计趣味、完整声音、实体设备或用户 G5 接受。

## 独立核验的身份

- 当前 HEAD 与上述冻结源相同，读取时已跟踪工作树无改动。最终 acceptance 的 3377 项输入和媒体的 3378 项输入，各自 `source-before == source-after`；逐项重新计算当前文件 SHA-256，均与各自快照一致。媒体多出的 producer 不计为生产功能。
- 原 delivery `manifest.json` SHA-256 仍为 `bef5b567fcd367913be474a02df3bdbb62cf8c8d2902c380861055f272e9cbc0`；独立重新校验其 721 项声明文件，零差异。未改原包、模块、内容或哈希来过关。
- 当前 `plains_presentation.gd` SHA-256 为 `3ecb694cb1dfadd72f29fa44f8ebab825c7f8034e3a0d286b1364341c52a8b24`；`cloud_preview.gd` 为 `c8e73d723a6a5b0c7f8e862b1247a3933b34ac670aaaa3d67e8659230d491585`。最终 runtime 原件 SHA-256 为 `4fd7f1511e3f639feb0337c9b054b381519462a34ec4507aa27b0b63cdf7800d`。
- [最终回执](final-report.json)实际为 **845 checks / 3 failures / exit 1**，842 通过。独立读全案例索引，124 项 `presentation/` 记录全部通过；失败只有 M24 supported_fixture、physical_claim 和要求完整 11 个奖励身份的 instance_isolation。原生日志未发现 SCRIPT/SHADER/原生 ERROR、ObjectDB 泄漏或退出资源占用诊断。此处“clean”仅指诊断，绝不代表验收 exit 0。

## 代码与消费者反例

| 方面 | 独立检查、观察及限定结论 |
| --- | --- |
| 旧地形重复 | fixed_map 在装配前设正式风格 metadata；adapter 在实例上安装正式演员，关闭旧地形绘制，保留原碰撞。UnderworldTerrain 从实际非单向平台并集生成美术，没有新增 CollisionObject2D；移动台使用原 ModuleMovingPlatform 正式绘制。未发现第二份物理地形。 |
| 归一化／镜像 | 本轮不重算交付坐标或镜像；表现读取已经物化的 module.definition 和实例世界位置。原物化装配与镜像专项继续保留，不靠换皮更改几何。 |
| 玩家 | 仅挂正式 PlayerMotionCandidateVisual，隐藏旧 CourierVisual／PlayerFeedback 绘制、禁用旧 PlayerVisualAdapter；旧 CourierVisual 仍保留权威枪口。仍是原 motor/controller、24×36 碰撞和原资源／伤害／钱包／生命周期，无跨实例新玩家。 |
| 敌人 | 正式 EnemyPresentationBinding.replace 替换旧 Presentation，并绑定同一 EnemyActor。交付仍为 13 diver、4 sentry、1 charger；后五只用当前 PlainsRevisionSkin，diver沿正式 EnemyFeedback01 aerial 分支。没有为了展示其余四种新怪而抽取或增怪，没有改 AI、HP、位置或奖励。素材系统“支持七种”不等于本地图应有七种。 |
| 装饰保护 | keepout 含 actual world_dangers（含移动锯包络）、渡台包络、锚点、敌人范围、奖励、M29 原生宝箱、主／第二铃和 access_positions、实际 paired/sequence gate 矩形、所有真实 Port。修改只作用于装饰投放。没有整片 M40 blanket keepout；该可选措施不是原正式 API 的必需合同，也没有实际图证明它导致前遮挡，故不作为已证实缺陷。 |
| Boss 第三阶段 | refresh_geometry 观察已提交的原生平台变化，释放旧视觉地形，重建 scenery；清除旧 light/bloom/occluder 后按新并集重建，未重复修改原生地形。最终实战案例记录 geometry_revision=2，原断桥缺口 `(-4236,-2808)` 不再有旧地形美术或旧阴影。 |
| 暂停／总览 | fine 为 PAUSABLE；foreground 保留原 ALWAYS，使暂停总览仍跟相机，其自身 `_process` 将动画 delta 置零。当前源码遵循正式 foreground API；fine 时钟暂停断言通过。不能仅凭该断言外推所有动画。 |
| 音频宿主 | direct scene 可创建唯一 V2；CloudPreviewBootstrap 的原 base GameAudio 改为同主游戏的 PlayerWeaponFeelAudioV2，canonical attach 不改。V2 继承同一 12-voice pool，没有新增第二服务或临时修改 group 顺序。最终真实 bootstrap 测试确认一个服务、两个 feel.audio 同指 custom_audio、返回菜单旧服务 weakref 释放、新菜单仍 session-only，退出清理通过。 |
| 原生 M29 箱体 | 只隐藏 RegionStage 自绘金矩形，用正式 medium 闭／开 sprite。stage 的 chests、原位置、原输入与 OR 事务仍权威；claimed 改变后才换开盖。原 StageRewardModal 不在被隐藏 stage 下。coin/note 两种原生事务和实际开盖均有最终断言。M29 不支持卸载后重建，现有拒绝策略保留，故 sprite 只依赖稳定的原生 stage。 |

没有找到为表现通过而修改玩家物理、补资源、换奖励／怪物、双地形、双音频服务或放宽 M24 断言的新增实现。原实例隔离、死亡、暂停、生命周期和复杂卸载拒绝测试仍在最终套件中。

## 真正查看的画面与未看范围

已通过图片工具查看最终原尺寸 1280×720 的 [spawn](spawn.png)、[M06 sentry/diver](M06-sentry-diver.png)、[M06 hit](M06-sentry-hit.png)、[M28 charger](M28-charger.png)。与此前已查看的旧 `../spawn.png` 相比，当前为正式 native32 草岩、三层黄蓝天空／风车景、披风玩家、正式哨兵／冲锋怪、金属机关，旧内部 windchime ID 标签变成 contextual SHOOT。图中单个人物与敌人身体、地形接缝、可见落点未见重复绘制；场景空隙和敌人轮廓可读。这是所见像素的有限专业判断，不是用户审美评价或整图画面覆盖。

[影片](plains.mp4)独立 ffprobe 为 H264、1280×720、60fps、860 帧、14.333333 秒，带 AAC。SHA-256 为 `bc07a64d307899cbc9ff660847887248c85c8d84b3c77208670b7753d632f73d`。本次实际解码并查看精确帧 0、120、240、360、480、600、720、840 的联系图，观察出生铃开门、M06 射击后跌入原下方模块、M28 冲锋怪死亡后的原场景。**未正常速度完整播放，未听 AAC，不能签动画全时序或视听同步。** M06/M28 为明确观察位置 fixture，未补资源，不代表自然到达；片段没有偷偷连成全图路线。影片仅为原连续 0–859 帧，不含后续失败的 M29 正中观察初态。

较早的 [M40 phase3](M40-phase3.png)已实际看过：巨钟、岸边和保留高台存在，原桥空出，未见旧桥影。该图属 pre-keepout 源的 GL 9/0，**不重新标成最终源画面**；最终源仅由 845 套件的实际地形／遮光一致性和战斗记录支持。

已实际查看 [M29 右缘闭箱](M29-edge-closed.png)、[原生选择菜单](M29-edge-menu.png)、[领取后开箱](M29-edge-open.png)：玩家在平台右缘；菜单显示金币 +4／音符 +1；领取后 HUD 金币 4，正式蓝箱开盖，原生 toast 存在。对应 [landing](M29-landing.json) 与 [GUI](M29-edge-gui.json) 明示：fixture 从本地 `[270,20]` 原生下落到约 `[270,46]`、grounded=true、距原箱 62<80；真实 W 开菜单，真实鼠标 `(465.5,530)` 选金币，未调用 choice API，claimed/openpose=true。仅接受该侧缘局部落地与 GUI 事务，**不签自然 arrival**。

## 保留的失败与边界

| ID／级别 | 实际反例及最小后续处理 |
| --- | --- |
| R6／整图阻断 | M24 `idea-orbit-choice-001`，Port C Seal_C `[256,0,128,32]` 压住唯一奖励支撑区；24×36 原玩家支持站位落在奖励区域时实际命中 seal。最终 supported_fixture 和领取仍失败，严格 11 奖励身份总覆盖仍失败。归属交付几何与宿主适配合同；记录具体冲突，不能擅自移 seal／奖励、缩角色或造 Route。 |
| AV2-M29／局部不兼容 | Port C seal `[128,0,128,32]` 到单向台 y64 净高仅 32，原身体高 36。真实 intersect_shape：中心 `[208,45.9]` 命中 Seal_C，右缘 `[270,45.9]` 无重叠。两次正中 fixture 不落地／claimed=false 原件均保留。侧缘成功不抹除正中失败，不得写“箱正中安全站立”或自然路线已通。 |
| AV2-PREVIEW／已修测试失败 | preview-02 的 WeakRef 推断触发 warnings-as-errors Parse Error，原件保留。当前显式 WeakRef，后续最终 bootstrap 实跑通过；无过滤错误或删除失败项。 |
| AV2-HARNESS／证据边界 | 四项 related Harness 和两项 host Harness 均确实 fresh、exit0、非复用；其 report.commit 为当时 dirty 基线 `82a228f`，不等于最终冻结 HEAD。fixed_map 字节与当前相同，host-harness 的 cloud_preview 也相同；plains_presentation／新增测试／wrapper 有后续变化。因此这些记录证明正式共用系统的相关回归，不能声称最终 cce 的完整相关 Harness 或 full168 已通过。最终 845／Web 则确实绑定 cce。 |

补录最终六项回归：`build/verification/harness/20261030T140053.921018Z/report.json` 的 commit 确为冻结 cce；`art-art / underworld-terrain / underworld-formal / underworld-mechanisms / cloud-preview-runtime / underworld-player-animation` **六项全部 passed、reused=false、exit0、无 failure_reason**。已独立读取实际 report 和 `build/mapgen_930001/art-v2/related-final-harness-03.log`；报告所列 236 项 working_files 当前逐项 SHA 均相同，验证源冻结守门有效。此为六项 targeted 回归通过，仍非 full168。前两次严格拒绝完整保留：[并写文档漂移](failed-final-harness-drift-report.json)／[日志](failed-final-harness-drift.log.gz)，以及[自动 import 漂移](failed-final-harness-imports-report.json)／[日志](failed-final-harness-imports.log.gz)。第一次含 root 文档更新和本报告并写，第二次为 Godot 自动补生历史 docs 的 148 个 `.import`；两份原报告均为 interrupted，原生日志 marker 不作 Harness PASS。第三次将预热 companion 纳入准备快照、停止文件编辑后从头 fresh 重跑，没有修改预算或 guard。完成本段补录后不再写文件。

未验证：全部自然跨接口路径、所有移动机制最坏相位、连续低资源探索／回退／Boss 到达、完整 168 项、实体设备、完整正常速度动画／声音、平衡／趣味／用户 G5。原测试中的 sweep、fixture 站位、策略战斗和实际 GUI 操作分别按原 kind 解释，不能互相代替。

## Web、生命周期与发布范围

独立打开 [实际 Web 出生](web-spawn.png)和[返回主游戏标题](web-return-menu.png)：新版身体／背景确实在 Chromium 输出，返回图为《失序之钟》开始游戏、继续、设定、新手教程、开发入口，保留 session-only banner。console 也记录 returned to full game menu；当前本地返回 GUI 可接受。指针／移动／M／Esc 证据只支持实际输入和截图，不包含内部位置或自然路线断言；此次 reviewer 未亲自操控浏览器。

独立从本地 ZIP 流式重算 `index.6726edd6c91b.pck`：230181840 字节，SHA-256 `6726edd6c91b0bb32daa3f9472dc3afc25f1ecee21d4ede46d1ae3e74976c6cf`，build-info 的 source_commit 为 cce9d74f。归档 pack-smoke 在无源码 PCK 启动记录 MAPGEN_READY46、spawn `[96,206]`。公开 staging 仍因原 900MiB 守门拒绝，未发布，不应给出公开可玩承诺。

[Web console](web-console.json)没有 Godot SCRIPT/native ERROR 或 uncaught JS，但保留一条 type=error 的 Emscripten 主线程阻塞告警和 ReadPixels stall 警告；不能写所有 console error 为零，也不据此签性能或听感。

本轮没有新增已证实的表现实现阻断项。下一步先处理交付方／宿主合同层的 M24 具体冲突并完成真实全图自然路线，保留已有失败后重新绑定精确源；不以表现接入范围接受开启批量地图扩展。
