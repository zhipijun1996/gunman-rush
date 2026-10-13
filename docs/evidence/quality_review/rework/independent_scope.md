# 最后范围独立审查

审查者 `/root/independent_gameplay_audit`；独立读码与反例，不参与实现，不修改生产代码/文档/仓库测试。应用 gameplay-reviewer、art-director。2026-10-13 HEAD `89ca510cad97b8940389d25423ab7869313734eb`，dirty（审查时 44 条状态），不是冻结交付；逐文件 SHA256 在 `build/verification/independent-final-source-hashes.json`。以下结论只绑定该清单。父代理继续修改需重新核对。

## 范围结论

- Skills/mission 的职责与证据区分：本次静态范围成立；没有把 fake-worker 单测伪装成真实模型成功。
- production_loop 成功调度真实模型：**UNVERIFIED**。已真实调用失败，不是未尝试；不得写真实生产循环通过。
- tile 候选通用组合完备性：**REJECT**，有下述预算反例和 shader 可移植性缺陷。局部拓扑/覆盖 Python 测试通过不抵消它们。
- gallery 仅开发消费者；正式地图接入、美术认可、设备/性能、完整游戏：**UNVERIFIED/不在通过范围**。原整份 REJECT 保留。

## 已执行与证据身份

独立运行 `python3 -m unittest discover -s tests -p 'test_terrain_tiles.py' -v`，5 tests / OK；以及 `test_production_loop.py`，8 tests / OK，shell exit0。日志分别为 `independent-final-terrain-tests.log`、`independent-final-loop-tests.log`。未重跑重型 harness、未导出、未启动新的浏览器或真实 Codex 会话。

实际查看已有 `terrain-tile-gallery/shapes-macro.png` 与 `all-47.png`：可见单行、多行、L、台阶、环洞、T、孤岛和 47 页；洞仍为空，未见旧整平台草帽分块重复。但这是实施者采集的 build `6633514eb1f0`，报告 bbox=null/art_acceptance=unverified；本审查只独立看图和读采集脚本，不冒称亲自操控或看过完整录像。最新 world-space shader 后改，旧截图不能验证新版本。图片中较直硬轮廓、材质重复/尺度、与角色/背景协调仍需真正黄金合屏和用户判断，像素分块完全一致不证明漂亮。

## F1：P2，大块×密集孔洞越过边界预算，确定源码缺陷

`PlainsTileComposer.build`，`scripts/art/plains_tile_composer.gd:24–25,47–56`：允许每宏块最多 16 格；对 rect.grow(48) 内所有边界逐段收集，超过 64 只 assert，并没有按契约自动拆块。release 若禁用 assert，face_count 仍大于64，而数组resize(64)和shader循环64会截去部分边界；debug 则断言。

可复现形状（8×6；中心 4×2 实块；周围棋盘孔洞）：

```
#.#.#.#.
.#.#.#.#
#.#####.
.#####.#
#.#.#.#.
.#.#.#.#
```

中心宏块(2,2)尺寸4×2合法，按源码同一几何相交规则计得局部 **66 段**；4×4 类似反例80段。独立 Python 几何计数原数据 `independent-final-edge-budget.json`（未运行Godot/GPU断言，明确是几何枚举+源码证明）。小块1×1同类只有40段，可退回细分。地图内容增多不是单纯全局边数问题，局部复杂邻接足以触发；当前gallery仅几个稀疏例子未覆盖。

修复验证：对当前绘制计划实际执行预算检查，超预算递归拆块；在Godot端加此组合及平移、旋转、镜像、负坐标、不同宏尺寸，记录每块实际face_count<=64，并跑1×1/宏块GPU对照。Python pack的覆盖证明不能替代Godot计划预算。

## F2：P2，圆角 smoothstep 参数逆序，确定代码可移植性问题

`shaders/plains_tile_material.gdshader:57–60` 使用 `smoothstep(radius+0.4,radius-0.4,d)`。GLSL smoothstep 的 edge0>=edge1 结果未定义；当前 SwiftShader 给出预期结果不能证明其他 GPU/设备成立。可见影响可能是圆角alpha不一致、边缘缺失/突变；本次**没有复现具体设备坏画面**，不把可能影响写成已观察现象。

建议使用 `1.0-smoothstep(radius-0.4,radius+0.4,d)`；验证有效顺序并对边界像素、实际浏览器和目标设备复核。

## 元数据与运行消费者的真实边界

`catalog()`确实读取JSON，并以mask建表（composer:10–14）；`build`检查目录有mask，传入cell_masks给shader，外凸圆角实际使用N/E/S/W位（:64–68；shader:51–60）。不是完全无消费者的文件。

但 `grid_world_units`、`material_pixel_density`、`quadrants`、`macro_sizes`、join_contract 不驱动渲染；CELL=32、纹理尺度、宏尺寸由代码独立硬编码，shader没有读取catalog象限材质。47条是合法邻接目录，不是47张独立绘制资产或47种视觉差异。凹边的实际几何来自 PlainsTerrainBorders 并集边界，不能把元数据quadrants存在当实际凹角艺术处理已完成。

catalog join_contract写“partial cells clipped at actual authored boundary”，但API只有整数格Dictionary，不接受任意实际边界；当前只有整格gallery。`terrain_tile_contract.md`已明确非整格/极薄正式适配未证明，应以此限制为准并修正catalog措辞。正式中小于32、非整格、单向平台、移动/旋转参照系等仍未实现或未验，不能为候选改碰撞对齐格子。

`tests/test_terrain_tiles.py`覆盖256→47、307小形状及两个洞的Python pack，支持其离散覆盖性质。`test_seams_use_same_material_coordinates`只是整数恒等式，不执行shader；注释如实说明是placement proof。Godot pack仅尝试指定macro再退1×1，Python尝试多级尺寸，两者不是同一实现；今后需要运行时对照以免Python过而绘制失败。现有GUI包含多行但仅高4格，无大实块深层材质、密孔预算、4×2实际draw覆盖或移动参照系GPU证据。

## production_loop、Skills、mission

`tools/production_loop.py:70–104`真正构造 `codex exec --json --output-schema ...`，审查用read-only新调用，写prompt/events/实际invocation；非零退出或缺result就抛错。`:148–155,197–203`先消费调用预算再调用，异常blocked并保留状态。只读变更、越界修改、质量记录task绑定/当前production_snapshot都有检查；但路径检查是事后检测，不是安全隔离，文档明确限制。

`tests/test_production_loop.py:1,16–25`明确 fake worker，mock snapshot/harness，结果summary为SIMULATED worker。8项只证明控制器状态机；不证明Codex读Skill、独立判断或真实修改能力。

`skill-routing-smoke/LOOP-ROUTING/1/implement/invocation.json`为actual_codex_exec，exit_code=1，耗时约4.727s；events.jsonl含401和“access token could not be refreshed…sign in again”，没有result。state.json status=blocked/calls=1，任务pending/rounds1，history空，没有review会话完成。真实成功执行必须保持UNVERIFIED。未输出或读取任何认证秘密。

F3（P3，证据完整性）：`:92–98`超时分支kill/wait后立即raise，跳过invocation.json保存。部分events/state保留，但缺该次退出码、耗时、kind，与说明“全部保存”有差距。此为静态反例，本次未触发真正超时；可在finally记录timed_out和实际returncode，然后保留失败状态，添加明确mock进程测试但不能当真实模型验收。

三项creator Skill明确真实输入链、唯一Motor、正式授予/装备、完整动作、生命周期、G5人和设备未验边界；各自专用设计要求分别覆盖角色、武器新判断与反冲、能力解锁/输入优先级。没有把文档存在等同能力实现或用户认可。forest.example明确EXAMPLE ONLY/重大设计proposed；当前每项allowed_paths仅docs/、checks仅docs/quality，所以只是依赖拆分模板，不能直接拿去执行完整游戏制作，需先填写真实授权文件范围及相应gameplay/art等检查。

## 可重复审查方法

从接口契约构造空间×状态×时间×消费者矩阵：格数/密度/洞数/边界长/宏尺寸分别变化；同一几何做平移、镜像、旋转、重分块变形测试；直接检查实际GPU/运行计划而非另写一套算法自证。预算、空域、材质相位、alpha、端点连续性分别作为不变量。控制器用故障注入检查各个保存边界（启动失败、超时、缺结果、只读改动、harness失败、review拒绝、质量记录过期、恢复中断），并将mock、实际进程失败、真实模型成功三种证据严格分开。视觉始终需要真实合屏/连续动作/用户与设备证据，不能自动从像素等价推导。

## 收到修复后的独立复核（后续结论，不覆盖原失败证据）

本段针对同HEAD dirty后续修复，版本绑定 `independent-final-recheck-hashes.json`。已重新读实际代码与新增测试；**F1/F2/F3 的代码契约修复限定 ACCEPT**。前述失效源码的REJECT、反例与原哈希保留，不把这个局部通过扩大为tile通用美术/正式接入/真实模型成功。

- F1：composer现在对超64的宏块退1×1，同时重算size、rect和nearby_edges，后续擦除剩余格、mask数组、polygon几何均使用新size。不会只缩数组而遗漏地形。对固定32网格，单格grow(48)局部能相交的网格边段有界；棋盘组合实际40，不会再次触发64上限。原4×2/4×4反例已被此分支覆盖。
- 新 `tests/quality_review_runner.gd:159–179`直接调用实际PlainsTileComposer.build，枚举6个宏尺寸×2棋盘相位，读每个ShaderMaterial的face_count，逐格验证无重复/不填洞/覆盖全部。核对真实测试不是只镜像Python算法。实施者`quality-review-budget.log`记录952 assertions/0fail及完成标记；**本审查未独立重跑该Godot套件**。日志含Android目录/重复导入UID警告，不能称环境零告警。当前仅headless计划，未证明新GPU输出。
- F2：四处圆角均改为1.0-smoothstep(radius-0.4,radius+0.4,d)，关闭逆序未定义算式。实际设备输出仍未验证。
- F3：invoke在finally写退出码/耗时/timed_out/launch_error；超时kill/wait后保留元数据再抛错，启动失败也保留attempt记录。独立再次运行`python3 -m unittest discover -s tests -p 'test_production_loop.py' -v`，**10 tests/OK、shell exit0**，日志 `independent-final-loop-recheck.log`。新两项清楚mock Popen/killpg，不冒充成功模型调用。原真实401失败及UNVERIFIED状态保持。

仍待验证：新版world采样+圆角+fallback的GPU截图/分块一致性、正式非整格/极薄结构适配、性能、黄金合屏、用户与设备认可。catalog“partial cells clipped”的过度措辞已反馈实现者；实际API目前只整格，应明确候选边界。没有整体PASS。
