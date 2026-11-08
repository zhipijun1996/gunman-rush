# 平原怪物重绘

目标：按当前正式平原材质重绘七类普通怪、鸣铃巡游机及主动追压版牧风者。用户已明确本轮包含两位Boss。

- 基线：main@d04912228d6f53f61bd6dde84b22876a5d444487；工作分支art/plains-enemy-redraw。
- 写集：assets/plains_redraw_02、直接消费的敌人/Boss表现、相关对象规范、素材打包与预览工具。
- 素材采用image_gen生成原图，再确定性裁切、最近邻烘焙和alpha清边；源图、提示词与哈希随资产保留。

## 交付

- 七类普通怪：巡逻体、冲锋体、跃击体、单发哨兵、扇射哨兵、根铃、俯冲体。六类继续消费现行动作网格；俯冲体替换八帧图集、锚点及死亡残骸调色开关。
- 鸣铃巡游机：车身、顶棚、车轮与主钟；牧风者：躯壳、头部、腿段、风帆、钟芯与蹄掌。独立部件接入现行关节与动作状态，未修改AI、伤害、碰撞或弱点配置。
- 原图与提示词见 `assets/plains_redraw_02/source/`；确定性烘焙脚本为 `tools/bake_plains_redraw_02.py`。`manifest.json` 记录基线、参考与源图哈希、裁切框、原生尺寸及工具来源。画面使用冷灰阴影、苔绿与低饱和旧铜，按实际世界单位最近邻烘焙。
- 可编辑陈列场景：`experiments/art/plains_redraw_02.tscn`，使用生产地形、背景、怪物绘制器和Boss关节。12秒循环覆盖运动、蓄力、部分攻击和死亡姿态；显式陈列采样，不是实战录像。
- 证据目录：`build/plains_redraw_02/`。最终同屏 `final-gallery.png`、动作预览 `motion.mp4`；正式 FixedWorldApp 的 P-R03、P-R06、P-R14 截图分别为 `fixed-world-patrol.png`、`fixed-world-charger.png`、`fixed-world-windkeeper.png`。正式截图使用原镜头、真实AI，初始房间与玩家位置由捕获脚本设置。

## 实际检查

- 仓库锁定 Godot 4.7.2-gunman-sd1；import、project、smoke、contracts 四项均通过。最终日志为 `final-import.log` 与 `final-ci.log`；smoke 12项，contracts 239项、存档39项。
- `enemy-structure-native` 与 `windkeeper-pressure-01` 通过；后者六个原生消费者。记录在 `build/verification/harness/20261108T073010.276692Z/report.json`。其后牧风者仅补齐钟芯、蹄掌材质及躯壳覆盖，最终导入、日常CI及实机截图已复验。
- 七怪真实AI/Router/伤害流程：7例、4551帧，0失败、0覆盖缺口，详见 `ordinary-combat.json`。该记录使用既有受控初始条件，不等同自然玩家完整通关。
- 巡游机专项前七个消费者通过；整套运行的最后一个 `contact_edges.gd` 达到既有90秒时限，因此不宣称完整 harness 通过。使用原测试、`--fixed-fps 60` 单独复验：246项、0失败，正常退出且无脚本错误/泄漏，见 `contact-final.log`。
- 已实际查看最终同屏、动态四时点及三张正式房间截图；本轮专业判断为材质和像素密度与正式平原协调。尚无用户视觉认可或目标设备观察。
- `python tools/check_docs.py`、`git diff --check` 通过。

## 恢复与复现

1. 检出 `art/plains-enemy-redraw`，通过 `python tools/setup_environment.py --engine-only` 准备项目锁定引擎。
2. 原图重新烘焙：`python tools/bake_plains_redraw_02.py`（Pillow、NumPy、SciPy）；随后 `python tools/ci.py`。
3. 在Godot打开上述陈列场景，或运行 `bash tools/godot.sh --path . experiments/art/plains_redraw_02.tscn`。
4. 录屏：`bash tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --write-movie build/plains_redraw_02/review.avi --fixed-fps 30 --quit-after 360 experiments/art/plains_redraw_02.tscn`。
5. 正式场景截图：有图形显示的环境运行 `bash tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script tools/capture_plains_redraw_02.gd`。

无技术阻塞。后续根据九怪同屏和真实房间反馈微调，保留现行战斗轮廓与动作接口。交付包包含当前修改及证据；本轮未进行主分支合并或试玩部署。
