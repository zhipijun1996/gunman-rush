# LEVEL FOUNDRY 黄金技术切片

任务 LEVEL-HARNESS-V2-01。使用现有 `level-module-creator` 与同一 G0–G5；本页没有授予正式模块池准入或用户认可。现有 Foundry 的 `build/sources/next` 行为保留；新增 `experience` 是离线证据消费者，不修改 PlayerMotor、资源、随机流或两张正式平原。

## 可执行入口

在仓库根目录，先安装项目规定的 Godot 4.7.2 并完成项目 import，再执行：

```bash
python3 tools/foundry.py experience --output build/level_design_v2/golden
python3 -m unittest discover -s tests -p test_level_design_golden.py -v
```

默认 `--count 24`：当前六种已有模板、两个变体、请求相位 0/1，共 24 个短语，再运行六条连续三短语 itinerary。生成器原有每请求最多四次相位尝试保持不变；报告按实际成功相位记录，不能把请求相位当覆盖证据。`--count 6/12/48` 可缩小或扩展候选覆盖，失败仍停止，不能无限重抽。

每次执行分配新的 `build/level_design_v2/golden/<time>-<id>/`，不会复用旧 batch 获得通过。复用仓库 `run_tests.run_engine` 的脚本错误快速中止、超时和进程组清理；输出实时写入日志，异常也保留。运行前后对比共享 `level_design.source_files()` 的源码快照，新文件、内容变化、文件删除都会否决 fresh 并记录 `source_changes`。目录包含 `batch.json`、30 份独立输入记录（默认数量）、Godot 原始 `run.log`、结构化 `report.json`。输出根的 `report.json` 指向最新尝试；旧成功及失败目录保留。记录包含源提交、消费者文件校验、引擎、Foundry basis、执行命令、退出码、耗时、Seed、Manifest hash、实际模块/相位、输入帧数与动作计数、资源观察及文件 SHA256。没有画面时截图与录像数组为空，视觉审核保持 unverified。

## 三类设计卡与实际消费者

完整设计意图在 [golden_challenges.json](../../tests/fixtures/level_design_v2/golden_challenges.json)。设计卡由统一 `validate_design` 检查，再读取校验 SHA256 的本次真实 batch，逐个核对实际 Manifest 的 kind、template_id 和 phrase_count。当前适配器只接收 template 的 1 个短语及 mixed itinerary 的 3 个短语；这不是游戏全局动作链上限。卡片字段不能代替运行证据。绑定输出 `binding_status=passed` 与 `motor_replay_status=passed` 仅指这部分证据；`challenge_contract_status=unverified` 明确保留动作顺序/替代解法、入口位置速度范围、出口状态范围、能量冷却、时序窗口、恢复意图与镜头可读性，不能把 ID 对应当完整设计卡技术验收。

| 设计卡 | 实际技术底座 | 验证范围与边界 |
| --- | --- | --- |
| ordinary | `height_then_precision` | 反冲升高 → 支撑/恢复 → 低顶与精确落点；短动作组合意图，普通难度仍需试玩校准 |
| advanced | `resource_then_rhythm` | 真实反冲资源接力 → 调整轨迹 → 读取齿轮相位；不人为补充弹药/能量 |
| master | 现有三种不同短语的 itinerary | 真实九模块连续输入，从唯一初始出生点到整路线出口；具体短语由 Seed/Manifest 决定。这是大师设计流程的技术底座，**不是已完成的大师挑战** |

调用链：`foundry.py experience → level_design_golden.run → tools/foundry_validate.gd → FoundryCatalog / FoundryWorld → PlayerController / PlayerMotor`。原有 driver 提交真实输入；只在创建场景时设定初始出生位置。每帧经过实际资源、碰撞和全角色扫掠。短语先 trace，再内存 replay，再磁盘 round-trip replay；完整 itinerary 独立连续 trace/replay，不能把三个单模块成功相加当整路线成功。

新消费者只使用 `base`，无调参 overrides，同一时刻使用 ShootAbility 的当前默认 pulse gun。不是全部合法武器覆盖；真实快照和其他武器路线证据由 V2 capability/traversal 专项补充。现有 Foundry replay 暴露位置、输入、shot charges，没有完整逐帧能量/冷却、设备动作来源，因此这些字段不能冒充已量化通过。headless 输入策略也不能代替键鼠、手柄、手机真机操作。

## 可证伪门槛

`inspect_batch` 要求 schema/profile、非空 basis、引擎、正数 assertion、requested/accepted 数量、零 failures 和精确完成日志一致。六条连接 proof 必须全部存在且通过；每条 proof 的 phrase IDs、节点数、真实接受的完整短语 Manifest 必须一致。

逐项验证 Manifest 自身 canonical checksum、basis/engine、ID 与模板/相位/Seed、scope、真实记录文件名与 capability；replay 必须非空、有动作、坐标有限、axis 合法、shot charges 非负。trace ticks 与 replay 全部 frames 相等，最大重放位置偏差不超过原验证器的 0.05；缺失输入、截断 replay、错 basis/hash、失败 proof、缺完成标记都失败。不会重新解释或降低现有 Motor 标准。

32 个 Python 用例包含正常证据和上述故意坏证据，也包括进程失败/早期脚本错误/超时保留原日志、旧成功报告不能替代新 batch、设计卡没有真实对应证据时否决，以及运行中源码发生变化时否决 fresh。独立 R4 反例覆盖 phrase_count=99/2/bool/float、错误 mixed 模板、记录元数据与实际 Manifest 不符、绑定前 batch 被修改，并检查完整挑战合同保持 unverified。它们是解析器的可证伪测试，合成输入本身不算 Motor 验证。运行 Motor 的证据只来自实际 `experience` 子进程及其原始 artifacts。

## 返工和准入

失败先查看最新报告 `failure`、`run.log` 与 batch `rejected`，以实际 Seed、节点、相位、原输入轨迹定位；保留原件后修改设计或模块，重新运行同一入口，比较原/新证据，不能改 Motor 或阈值救样板。

G0 使用设计卡定义进入/退出状态、能力、动作、观察、相位、资源、镜头与失败恢复；G1/G4 由该真实技术入口提供部分证据。G2 的构图、美术、动画、合屏及 G5 的学习、公平、乐趣、手感、实体设备需继续人工验收。G3 的正式集成未执行，`production_pool=false` 保持。未经完整相关门槛和独立审查不得将切片升级为正式黄金关卡。
