# 0.4 输入 profile 扩展候选（未运行、未获上游接纳）

基点为 map-edit PR78 `812e89050e062c866a5dd7e8c258e47d3897bc4d`；唯一修改文件 `tools/runtime_audit/check_930001.py`。当前 gunman-rush/map-edit 仓库均未写。开发补丁与完整候选见本目录，`freeze.json` 给全部SHA。

原工具没有可直接调用的独立提取函数。候选只把原 run 中100行变为 `extract_inventory(...)` 并迁回原消费者；新 `--actual-profile` 分支调用同一函数。默认分支不触发时，原 CLI、43输入SHA/Gitblob验证、两ZIP、0.3/Python对照、46/55、三个焦点、1.1.1迁移及原输出全部保留。已用整文件逆还原和抽取主体AST检查其完整性，仅Python语法编译；没有执行旧全套，更没有产生0.4覆盖。

新分支不会把旧e7的Provider签署状态套用当前源：所有新行固定 `UNVERIFIED_CURRENT_HOST`，原模块资格报告仍只是模块来源。读取当前Provider/验证收据/源向量的精确字节并列入锁，但不从hash自动推导兼容PASS。需后续独审和实际host验证才能更新限定结论。

## 等待宿主交付的七份真实输入

本目录**没有填充虚构SHA的可执行profile**。等实际产物出现，由root记录它们的相对路径和真实SHA256。profile仅是本次提取输入清单，不是游戏registry，也不是接受记录。

| files角色 | 期待的真实内容 | 来源要求 |
|---|---|---|
| result | 完整原始 generation-result/v1 对象，含status/map/content_store/request_fingerprint | 当前host RuntimeMapGenerationJob.actual_result；不能用包内samples/success或只给选择切片 |
| provenance | 原job.provenance对象，含request/config/algorithm_package/module_archive/expected_request_fingerprint | 与上述ticket同一次运行、generated_memory |
| protocol_payload | 原 GDScript DATA.canonical({request,config,library_sha256,implementation}) 的精确UTF-8字节，**无附加换行** | 同次provenance；原Protocol.fingerprint已使用同表达式。不要用Python重造canonical数值规则 |
| host_bindings | 当前实际装配所用binding对象的原记录 | 本批新布局的真实spawn/选择/topology，不借旧M编号 |
| host_provider | 当前实际运行的runtime_map_v2_provider.gd原字节 | 冻结source向量对应叶，不是e7旧Provider |
| host_source_snapshot | 实际run前后源向量、精确提交及WIP叶差异/一致性收据 | 不伪称WIP已经存在HEAD；提取器只锁字节，不自动签Git归属 |
| validation_evidence | root实际验证报告或明确未验证收据 | 必须保原失败/未测与适用范围；提取器不解释为通过 |

profile顶层字段：`profile="actual-0.4.0"`、`host_commit`（40hex基点；真实WIP见snapshot）、`mapgen_commit`（actual provenance.algorithm_package.release_head）、`generation_package_sha256`（已锁ZIP7aa3…）、`files`。files恰好以上七角色，每项为 `{path: 相对--inputs目录的路径, sha256: 原字节SHA256}`。所有文件先核SHA，路径不能逃出inputs；缺件/错SHA拒绝，不产生表。

还需原模块ZIP1.1.0（SHA5ad5…），从已有包/锁直接复用，不换1.1.1。新profile会核完整result PASS、schema、0.4 implementation/stable-v3-reward-space、模块identity、实际Protocol payload SHA和result/provenance/map三处fingerprint；核实例/连接ID唯一、端点存在，并复用原catalog精确contentVersion/sourceSha256与17机制未知kind拒绝。新输出保存完整实例role/transform/seal/port及连接，供跨版本按module_id+content_version+role+连接邻域定位，不做M编号映射。

## 后续命令（尚不可执行，等待实际输入及独审）

先在锁定的**外部map-edit工作树**核原工具SHA746a20…，应用 `candidate.patch`。这是对上游原producer的开发补丁，不是当前仓库新工具。不要改旧43输入lock。

```bash
# default old replay: original argv remains unchanged
python3 tools/runtime_audit/check_930001.py --inputs "$OLD_INPUTS" --zip110 "$ZIP110" --zip111 "$ZIP111" --out "$OLD_REPLAY_OUTPUT"
# explicit new profile, output must not exist and cannot be the frozen 930001 subtree
python3 tools/runtime_audit/check_930001.py --actual-profile "$ACTUAL_PROFILE" --inputs "$ACTUAL_INPUTS" --zip110 "$ZIP110" --out "$NEW_OUTPUT"
```

这里没有声称这些变量已有产物。新profile禁覆盖任意已存在输出目录及旧frozen目录。先做缺文件/错SHA/旧实施版本/假memory来源/指纹错配/缺content/重复ID/未知机制/输出覆盖反例，再实际提取；旧默认完整重放及原篡改负例仍需执行并证明输出一致。

## 上游接纳边界

必须把patch、真实新清单、原旧重放与新负例结果、host源/验证收据交上游维护者；不能把外部未接纳patch称官方map-edit能力。新覆盖仍是静态清单，不能把0.4上游40报告或当前inventory签成40张宿主可玩。当前只完成补丁准备，未生成覆盖、未Godot、未改任何现有仓库、未外部发评论。


## V2 审查修正与有限反例

V1的实际缺口：只核内容中声明的source_sha256/content_version不能发现删掉机制数组；原抽取的c.get(field, [])会把缺字段当空。V1源码/patch/16早期负例原件保留在 rejected-v1/，未冒称完整性已过。

V2只在新profile先读原ZIP compiled，核content_store keys恰等实例content_ref、根字段=compiled去ports/routes加coordinate_frame/source_affine，列表长度/元素类型、矩形列表长度、机制对象字段。仅原ContentTransform允许的ellipse_x_sign增删例外。该守门是结构完整性，不重实现坐标变换，**不是几何值等价或提交真实性证明**；自行更改数字并重锁SHA仍不能获得任何host通过状态。

16个早期CLI拒绝在最终V2源码上重跑通过。content_integrity_probes.py另有19项：上游实际sample结构正例（不是host actual）、17个缺字段/清空/错类型/缺ref/orphan/缺对象ID或trajectory/坏矩形长度拒绝、一个标准--actual-profile=path调度拒绝。没有运行完整producer生成覆盖。第一次probe发现上游0.4样例hazards确为0，因此无法从该样例挑非空hazard（StopIteration，测试脚本准备问题）；后续hazard负例明确从已锁ZIP的gears compiled添加一个纯结构fixture，仅用于guard，不包装成实际生成结果或写出coverage。

当前还未执行旧43输入完整重放，未填真实0.4七件清单，也未生成任何新覆盖。需独审接受后再在精确外部map-edit工作区应用候选；当前主项目源码正在并行修改，不能据此声称其source snapshot已冻结。


## 后续实际旧消费验证（新增收据，原未验冻结记录保留）

root授权后的完整旧重放已完成，见 `/tmp/mapgen-v4-old-replay/comparison.json`：43原输入逐SHA/Gitblob恢复，原producer与补丁默认分支同argv各exit0，10个输出逐字相同且全部等于PR78提交原件。`negative-replay.json`另证明原/新各缺件与M35篡改均拒（4/4，无输出）。原freeze中未跑字段仍保留其生成时点；不得用新增旧重放通过替代尚未执行的0.4实际profile/host验证。
