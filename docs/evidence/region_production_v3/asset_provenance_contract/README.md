# 资产来源合同：真实离线记录与运行消费者分离

真实 CI run `38816884186` 的 docs profile 已通过20项，但 PR 差异门槛拒绝大量未逐文件绑定的资产和未精确记录的修改；原始失败见 `original_ci_failed.log`。本修复不把失败冲成通过，也不放宽任务 `affected_paths` 的精确匹配。父任务和独立资产记录作者另行补充真实记录。

既有 `validate_asset` 新增可选明确 disposition：

- `rejected_evidence_only`、`production_record_only`：必须 `runtime_paths=[]`、非空 `non_runtime_reason`，且 `visual_status` 不可为 passed。用于诚实保存被拒原图或离线生产合同。
- `runtime_candidate`、`limited_preview`、`legacy_fixture_only`：仍须非空且存在的真实 runtime_paths，没有非运行例外。
- 未声明 disposition 的旧合同保持原规则；空 runtime_paths 仍拒绝。未知 disposition 拒绝。

可选 `associated_files` 是逐项 `{path, sha256, role}`；role 仅 generation_record/reference/processing_record/source_contract/documentation。必须精确仓库内实际文件、64位小写 SHA256，并逐字节匹配；目录、通配符、外部路径/外链、遗漏、坏哈希、未知角色均不获得覆盖。整份资产记录通过既有及新增校验后，差异门槛才允许明确列出的关联文件作为来源覆盖；实际消费者继续由 runtime_paths 表达。没有跳过任何 assets 路径。

原26项测试及全部原函数 AST、28处断言调用保留。原入口实际执行37项全部通过；新增反例涵盖缺理由、假视觉PASS、非运行却声称消费者、未知 disposition/role、坏 SHA、目录/外部/缺失路径、重复/畸形条目、真实 Git 差异遗漏资产，以及一条关联记录失效使整份来源覆盖撤销。所有测试是隔离合成合同/临时 Git 样本，不是正式美术验收。

修改仅涉及 quality.py、check_quality_diff.py、test_quality.py；policy、G0–G5、十一维和原断言未降低。原源码/新源码/完整diff/真实执行日志与冻结SHA均保留。未运行 Godot，没有修改资产、资产记录或其他生产代码，尚待不同代理独立审查与新的实际CI。
