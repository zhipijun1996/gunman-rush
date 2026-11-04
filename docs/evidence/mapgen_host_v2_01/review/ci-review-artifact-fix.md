# CI artifact directory修复 非作者窄审

**接受两处精确修复，无阻断发现。** 本附件保留前版 `ci-review.md/json` 原样，不给旧归档配置追签成功。当前两个文件SHA见ci-review-artifact-fix.json；无Godot、测试执行或源码写入。

相对前版已审candidate，独立逐字比较仅两次字符串替换：

- `tools/harness/profiles.json` 新runtime-map-v2-host的artifact_paths：`build/mapgen_host_v2_01/native.json` → `build/mapgen_host_v2_01`。
- `tests/test_production_plan.py` 新方法里对应assertEqual期望同样改目录，原断言没有删、放宽或绕过。

除此之外两文件字节完全相同；config/production_impact.json及tools/production_plan.py仍精确为前版冻结候选。原219检查、180秒新检查预算、171/156前缀、172=92+80、新7fixture精确routing、原planner历史投影/断言均不因此变化。

原因已直接追到未改的原Harness：`tools/harness.py:449` verification_outputs逐base执行`:461` base.rglob('*')，单文件base本身不进入枚举，所以旧配置不能观察native.json；目录base会递归发现它，并在run前后按SHA/mtime_ns/size观察。`:687`将新写入（含同字节重新写但mtime变动）交collect_artifacts，`:355`按原规则复制小文件/无损归档大JSON。该路径在build内部、不是Harness自身排除的control/cache目录。`input_digest:234`把整个check对象纳入payload，因此这次artifact_paths变化也生成新cache key，不会认可旧“只有check.log”的cache为新配置结果。

前版静审确认了artifact声明但遗漏了collector的单文件/目录语义，这里明确更正。root报告旧五项PASS只归档check.log，native原件另存未丢；不将旧结果描述成已含native归档。根本修复局限于新check声明，未改共享Harness或归档实现。

后续root将fresh执行原Harness专项、planner/harness-tests和web-contract，核实际artifact目录包含对应native.json并匹配原件SHA。本审只接受源码修复和原断言保留，不预签这些尚未执行/未读取的新通过或完整172/Web/设备结果。
