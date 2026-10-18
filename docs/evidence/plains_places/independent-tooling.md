# PLAINS-PLACES-01 independent tooling review

审查基线：PR82 `4a4b3fd7`；当前冻结提交 `ef6a8b4f1d06406b6b5f0a3db658902c15c1084e`。
审查者 creative_loop；未编写本次被审工具/测试。此前本人修改的 Skills 明确排除，不自审。

**结论：限定 ACCEPT（实现/范围与旧门槛保持）；两项 P2 证据/缓存局限待修，不签艺术、实机路线、Seed验收、正式CI、设备或商业认可。**

## 实现与范围

- 新 route 实际绑定 `plains_place_composer.gd`、`plains_place_plan.gd`、`places_v1.json`、`plains_places_capture.gd` / preview、当前recipe/质量卡及文件SHA；不是只改方法文案。仍明确候选、无新碰撞授权；普通美术route写集没有 `scripts/generation/` 或 `resources/generation/`。授权空间实验与普通覆材继续分开。
- 新capture纳入既有显式白名单及ENVIRONMENT_CAPTURES，调用原正式capture生命周期；extension closure递归绑定共享driver/preview/teardown。继续拒绝其他catalog治疗冒用，新增三原型身份、顺序、有限translation、measurement哈希格式及实际waypoint/case绑定。
- 相对基线，既有source before/after、producer origin、核心输入/teleport/resource/enemy禁改、完成marker、ERROR与退出leak判断未降低。`compare_captures`、`load_capture`、`validate_review`、`producer_command_origin`、`formal_source_projection` 的AST与基线相同。继承环境分支仅扩展到显式新capture并增加专用校验。
- 既有Python测试只替换当前候选预期（旧肩/端方法→完整体积），保留原G0/G1、检查名、来源SHA、geometry authority断言；没有删掉物理/错误/泄漏负例。新测试对scope/teleport/source漂移/driver字节/ERROR/leak和缺失访问/伪位置/错实例/错顺序/measurement/NaN均构造拒绝。合成fixture明确不是实机证据。
- `plains-places-contract` 与 `plains-places-capture-tests` 已注册真实Harness argv，route实施任务引用它们。新native runner真实调用Plan.generate/validate_recorded，含重放、重hash篡改、源身份/scale/port/overlap失败与有界尝试；Python wrapper沿用run_engine原退出码、脚本错误与leak拒绝，并追加ERROR/完成标记/运行期间sourceguard。门槛是编译/重放，不假称Motor或美术。

## 两项 P2 与修复建议

1. **缓存输入不闭包。** 新 `plains-places-contract` 设置 `cacheable:true`，inputs虽覆盖运行scripts/resources/assets，却未覆盖实际wrapper依赖 `tools/run_tests.py`、`tools/level_formal.py`、`tools/run_root_bell_ecology.py`、`tools/godot.sh` 等。原 `harness.input_digest` 严格只按inputs过滤；这些工具改变可能复用旧成功。补精确执行依赖或关闭此check缓存；本审查不修改生产配置。
2. **结构签名仍混入命名。** `plains_places_plan_runner.gd` 的shape直接包含solid与connection字典，带id/place_id等字符串；`different_geometries>1`并不单独证明纯几何不同。应另以数值points/translations/连接gap-rise构造签名（对象语义另列）。现代码确实检查order变化，但本审查不把这条断言当随机结构实机证明，也没有断言本轮真实Seed几何相同。

## 本次验证边界与快照

只执行只读git diff、源码阅读、Python AST parse/基线AST对照与SHA计算；未执行Godot、Harness、Python测试、电影或设备任务。运行采证由其他worker负责。本报告不修改源码或测试，不评价首样板艺术。

| 文件 | SHA256 |
| --- | --- |
| `tools/visual_director.py` | `9308ccdd05e07039eb5b2ae8a033bf00b41d883b3f89d62e7eb0da1b6c7420a3` |
| `tools/level_design.py` | `4210208c29b93d4c6e3a25ae391ce0554aa88e86498b5f1338f7db8aaf8281b8` |
| `tools/harness/profiles.json` | `d0635cc805ee3c6486bc05b077152a8dae14062e1eb010f83743db53a15d5ce5` |
| `tools/run_plains_places_tests.py` | `f72a2a2d739089d9809f6b78eadd73c1011b068cd64d190c4c51d9ed902aa25e` |
| `tests/test_visual_director.py` | `b4b7e1b58ddda03ad16d16571fc2a79f6608d9f6c2b128a29fb47eb2d7e1863c` |
| `tests/test_level_design_routing.py` | `c157b7c01eb36234336910b1fc635f7e8dbb8a6f1fee9e0f96b2f990623f3d30` |
| `tests/test_plains_places_capture.py` | `f345c506bffe7a5b621f47e62546d7919555cd16f767fe9ada94c8f3a5fe9090` |
| `tests/plains_places_plan_runner.gd` | `a3068b148ed78d68f3f45b4e9811c99964da63d1e97a508a7938b2c387d16a19` |

## P2 修复复审 addendum（2026-10-18）

只读复核相对 `ef6a8b4f` 的三文件修正；本次只改报告，没有运行Godot、Harness或测试，也不审自己的Skills。**上述两项P2在当前实现范围内已闭合，限定tooling ACCEPT维持。**

- contract缓存inputs从单wrapper扩大到整个 `tools`，原scripts/resources/assets/config/native runner/project输入保留。此前指出的run_engine、源枚举、锁与Godot wrapper等工具依赖现在参与同一个原Harness input_digest；保留cacheable不再遗漏这些源码变更。
- Python wrapper读取本次实际native输出的 `actual.json`，对完整预登记样本投影有限数值translation、连接path/gap/rise，要求至少两个不同结果；不再只凭GD旧签名中的ID或Hash获得结构结论。旧GD断言保留，而新增纯数值验收进一步收紧门槛。
- 新反例明确验证仅改实例/边ID不改变投影、改真实连接坐标改变投影，NaN/bool/string坐标被拒绝；没有降低旧capture/source/ERROR/leak/physics断言。

保留限制：纯数值投影证明有限样本的空间排列差异，不能证明玩法丰富度、完整物理可达、视觉差异或艺术准入；原生采证版本、测试运行结果和包仍需各自实际日志。root报告48项Python 9.098秒、该文件4项1.281秒，本审查未独立重跑，不据此签实机或完整CI。畸形actual.json引发未捕获ValueError/KeyError时进程仍失败，但可能不写完整report.json，属失败归档诊断局限，不构成放行。

当前复审内容SHA（以字节为准，不将旧冻结commit重签为修改后源码）：

| 文件 | SHA256 |
| --- | --- |
| `tools/harness/profiles.json` | `f01edb96e56930c12e2b5fc077416c1a1768214bd15e4bf45e97b36e27f595fc` |
| `tools/run_plains_places_tests.py` | `664bee3ef77f22d43123a389b7a39f5d8b8e720975fb55b44e3f65d38c7500bd` |
| `tests/test_plains_places_capture.py` | `335ddc65a462557511f618d3faf3a3d20ae7cbbcc3df030e58c7d125e858c92c` |

最终归档收口：wrapper已将ValueError/KeyError/TypeError纳入失败归档，并在error保留异常类型；status仍为failed，不放行畸形actual.json。当前wrapper SHA256：`6061938ad05b980ceef8ae0cc692839df7cb2c3ee291fb4b9985ffb0b9d75fc2`。仅只读核对该修正并更新报告，未运行检查。
