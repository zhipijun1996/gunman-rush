# Blob47 新地基：独立审查

日期：2026-10-19。任务 `ART-BLOB47-FOUNDATION-01`；审查者为独立只读代理 `/root/foundation_review`，实现者为 root 与模块作者。审查者未改生产代码、测试或权威规范；自行编写隔离探针，发现问题后由实现者修复再复测。

**结论：ACCEPT（仅限下面已列明的新地基技术范围与独立候选低层路线）。完整合屏黄金、正式地图重制、用户审美、设备和完整回归均 UNVERIFIED。** 不以本结论晋级全区或恢复任何旧美术风格。

依据是本轮新权威 `docs/art_foundation_v1.md` 与 gameplay-reviewer 的拓扑、语义、生命周期、反例要求。旧素材/旧截图没有作为创意或质量比较基线。审查源基于 `e8ee34446aa82b4e64f5cdc414a22f5b6e2a6ca7`，最终冻结源码为 `222ee12fa002710de104d31f660ee275c1e6d2f6`，Web build_id `45c1a10f8767`。逐文件 SHA256 清单在 `build/blob47-independent/reviewed-source.json`，清单摘要 `b0e4581f9e890c6ec14b4110e67e80cd67189f468a5ec87f1d3f16e8997dd87e`；包含新地基与 DemoApp/Menu 实际入口。冻结前后生产代码逐字节复核，唯一构建器差异为新增固定64px/8列断言，重跑 `--check` 退出0，实际资产字节不变。

## 实际覆盖

| 范围 | 实际观察与判据 | 状态 |
| --- | --- | --- |
| 256→47、实际图集 | 独立读取导入后的 SVG texture 像素：141 个 mask/variant crop 均不同；每个正交连接边像素依 mask 改变；透明 gutter；runtime 选择存在的 atlas coordinate | passed |
| 跨模块并集 | 20 个独审 seed 重建正序/逆序模块并集；x19/39/59 的两侧均含正确 E/W 邻居，无模块内端头遗留 | passed |
| 物理语义 | 原生 PlayerMotor 的 solid/one-way/moving 分离；实际站上 one-way 后下穿；作者新增移动平台携带测试经独立重跑 | passed（列明样本） |
| 候选路线 | `independent-route-00` 到 `09`，10 seed × 双向，20/20；全部 6 种模板 bag 顺序；move/jump 请求驱动原 Motor，路线中无 position 写入；无重启或受伤重置伪装到达 | passed（低层路线） |
| 装饰/灯光 | 10 seed 的全 prop bounds keepout、间距、bucket 上限、灯间距；整场 keepout 负例确为空；不消耗 global RNG、不修改玩法 Manifest | passed（当前 profile） |
| 模块卡 | 缺 family/tile size/halo/density/background/visual role/exceptions 的独立反例均被拒绝；实际 Manifest 记录对应字段 | passed |
| catalog/暂停/重启/换 seed | 实际实例开 catalog 后 Restart/Next seed 会先关 panel 再恢复；输入取消由 UI router clear 接入；退出清理无本专项泄漏日志 | passed（此状态序列） |
| 正式消费者 | 源码追踪 DemoApp HOME → 新入口 → Blob47Lab → Home；候选独立于正式地图，未改 PlayerMotor 参数或正式生成池 | passed（静态接入范围）；最终 GUI 另记 |
| 视觉 | 真正打开最终 `final/01-playable.png`、`02-catalog.png`、`04-new-seed.png`、`05-decoration-off.png`、`06-depth-off.png`、`07-light-off.png`、`08-moving-camera.png` 全7张1280×720 GPU原件。47目录各角形态可辨，换seed实际改变拱/台地组合；关闭装饰与景层后实体边缘和危险仍清楚；相机移后背景塔/山与地形位移不同，未见屏边露空。此前首版也已看，不混淆版本 | passed（这些候选静态像素）；连续动态未签 |

本次光照是局部透明光晕，没有动态阴影。12 prop/2 灯是40×23格世界 bucket 上限，当前横向视口跨两 bucket 的保守上界24/4；不是任意移动屏幕严格12/2。灯间距160大于两光晕半径之和100，当前 profile 无双灯局部叠加。该实现限制已写入新规范。

## 发现与返工链

- **B47-R1，G3，catalog 生命周期，中等：** 原 `restart()` 无条件恢复 simulation，但未隐藏可见 catalog；Restart/Next seed 可让目录遮挡游戏时继续运行。静态发现后交作者修复。作者现先隐藏 catalog；独立实际探针分别开目录后 Restart、开目录后 Next seed，确认目录关闭且暂停解除。未伪造修前运行证据。
- **B47-R2，G1，one-way 下穿，中等：** 原平台创建的 shape 名为 `@CollisionShape2D@234`，Motor 约定查找 `CollisionShape2D`，故真实落地成功但下穿请求失败。保留 `probes-initial.log` 的3失败：shape 合同缺失、drop=false、35帧后未到下方；实际角色(192,429.9987)，平台(160,448)。作者补 shape.name 后，同探针 `probes-fixed.log` 全通过，下穿请求为 true 且角色到达平台下方。没有改 Motor 或碰撞语义救测试。
- **B47-R3，模块卡与预算声明缺口：** 初版模块未完整登记新卡字段、装饰无显式预算。作者补可拒绝的模块字段、Rules profile 和实际 bucket 计数；独审 missing-field/预算/keepout/RNG 反例通过。bucket 与任意视口区别已明确，未据此签纵向镜头。

作者先前低路失败与低 one-way/狭缝返工日志保留为历史失败，不以旧失败签当前通过；本独审的10 seed双向路线在修复后另行实际运行。

## 独立执行原件

以下均实际执行，完成日志未见 script error、ObjectDB/resources 退出泄漏。独立探针使用 Godot 4.7.2 Standard；headless 检查不当作 GPU/实体设备验证。

| 命令 | 结果与日志 |
| --- | --- |
| `python3 tools/run_blob47_tests.py` | 退出0；当前 layout 20356/0、foundation 958/0；`build/blob47-independent/final-foundation.log` |
| `bash tools/godot.sh --headless --path . --script build/blob47-independent/topology.gd` | 退出0；1466/0；`topology.log` |
| `bash tools/godot.sh --headless --fixed-fps 60 --path . --script build/blob47-independent/probes.gd` | 修前退出1，修后退出0；`probes-initial.log`、`probes-fixed.log` |
| `bash tools/godot.sh --headless --fixed-fps 60 --path . --script build/blob47-independent/routes.gd` | 退出0；20方向完成、0失败、0重启；`routes.log` |
| `bash tools/godot.sh --headless --path . --script build/blob47-independent/decoration.gd` | 退出0；3489/0；`decoration.log` |

## 未验边界

最终冻结版本7张GPU原件已实际看过，含完整47目录与移动后的相机画面；未观看连续影片，未完整听音轨；未进行实体手机/手柄/目标设备性能测试。敌人合屏、纵向镜头、所有可选上路、正式地图迁移、完整战役回归、公网部署身份/GUI、用户对画风和趣味的认可均未签。本审查不要求恢复历史4GB原件来证明这个独立地基，但也不覆盖仓库全 profile 失败或历史正式内容问题。

后续如源文件或最终 GPU 包与摘要不符，须更新身份与受影响复测；不能将此报告自动绑定任意后续版本。

补充视觉判断（AI专业观察，不是用户认可）：新候选形状与色彩词汇一致，暖色实体对冷色景层区分清楚，装饰数量克制；大面积地面纹样仍有明显周期，背景地标偏示意性，画面尚不能签精美最终稿。当前低层路线主要用于地基地形验证，不能把20条同策略成功轨迹解释为正式关卡乐趣已完成。
