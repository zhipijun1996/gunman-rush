# 固定上游工具链：产物激活前独审

审查源码 `184970c7fff5baa6842efb8f34339ce87fff5bfd`，构建 run `41180438395`。安装器以已独审 `62eceec4` 为准；本轮没有重复其单测，没有发布、修改 main 或运行引擎。

截至读取 API 的快照，plan 成功，4 个 compile 运行、6 个排队，0 个 artifact；目标 Release 标签返回404。故当前只能确认接入流程，不能接受尚不存在的实际产物。精确状态见 `engine-184-activation-remote-snapshot.json`。

## 实际平台与产物

“十项”是四个平台家族的10个构建 lane，不是十种平台。既有 recipe 合计19个输出，其中编辑器ZIP为4成员，模板TPZ为18成员。完整名字取 `config/godot_build.json`，外部 JSON 报告仅记录本次审查，不能成为第二注册表。

| 家族 | 实际消费者与必要产物 |
| --- | --- |
| Linux editor | 原生/import/capture/所有导出，共用精确 `godot-linux-x86_64` |
| Web | 正式线程 debug；线程 release及非线程debug/release能力保留，4个ZIP |
| Windows x86_64 | 原强制CI debug导出；debug/release各exe+console，原D3D12两DLL名与上游导出器匹配 |
| Linux templates | debug/release两文件，原environment完整模板守门保留；当前没有Linux应用导出preset |
| Android ARM64 | 原可手动CI及正式签名non-Gradle preset；debug/release APK和source ZIP都保留 |
| 公共资源 | ICU数据在templates，与上游模板管理器一致；LICENSE/COPYRIGHT在编辑器ZIP |

引擎构建的API36/NDK29不意味着可以改应用原API35/NDK28。既有Android应用preset须实际导出验收，不得因新包失败删选项或改规则。

## root 后续可执行顺序

1. 等**同一** run 的10个 compile及package成功，确认head仍是上述184提交。旧390 run的成功lane不能拼入。保存API job/artifact id、SHA digest、expiry与精确run/head；Actions压缩包digest与其内部Release资产SHA是两层不同证据。
2. 下载同run的全部 `engine-built-*` 与 `engine-distribution-candidate` 到新的外部目录，保失败日志。不要用临时Actions下载链接作为toolchain安装URL。
3. 用已核与184逐字相同的10文件builder小快照重放既有打包器（不会编译或运行Godot）。以下路径为具体已审核快照；输入/输出目录由root新建，输出必须为空：

```sh
python3 /workspace/refactor-evidence/engine-63af-on390-b63fzj6k/tools/engine/package.py \
  --inputs /workspace/refactor-evidence/engine-184-download/lanes \
  --output /workspace/refactor-evidence/engine-184-repack \
  --release-base-url https://github.com/zhipijun1996/gunman-rush/releases/download/toolchain-godot-4.7.2-gunman-sd1/ \
  --recipe-commit 184970c7fff5baa6842efb8f34339ce87fff5bfd \
  --workflow-run 41180438395
```

既有package会重核10lane的commit/run、recipe/patch/source、容器、原编译argv/cwd/exit、日志真实SHA、输出集合/大小/SHA，以及VM中的完整custom/source身份。对重打包和远端candidate的8个文件逐字SHA比较；对ZIP/TPZ再核4/18成员、每成员SHA及版本/identity，不能只看文件名或成功日志。`SHA256SUMS.json`列其余7文件，不包含自身，应单独记录它自己的SHA。

4. 审核完成后才由root创建固定目标184的唯一Release标签并上传这8个已核原件：editor ZIP、templates TPZ、provenance JSON、build-logs ZIP、engine-identity JSON、version.txt、godot-lock-candidate.json、SHA256SUMS.json。若标签/资产已存在，先比对；不覆盖不同字节。发布后通过candidate中的最终公开URL重新完整下载editor/templates/provenance并核SHA，其他证据资产也核对。公开成功不等于游戏验证通过。
5. 将已核candidate作为 `config/toolchain.json` 的**godot对象**，保其余git/python/Android/Windows字段原字节语义。与已审recipe、两个patch、安装器、identity、现有真实消费者及缓存改动原子接入；不能仅放lock或仅放新wrapper。安装目录采用新build_id，保留原官方控制安装；若环境变量指向官方目录，新守门必须拒绝。
6. 在完整最终源码上先跑原Harness91与既有相关纯Python检查，再使用原182、Windows/Android/Web/PCK/实际浏览器等既有门槛和预算完成验收。不能把本报告、builder成功、旧网页或此前native结果代签这些结果。

## 有限剩余风险与保留边界

- 原schema搜索没有发现安装器候选之外的新官方版本阻断；当前tree没有 `tools/check_contracts.py` / `tools/check_data.py`，实际structure/world/data专项不读取toolchain schema。旧official日志字符串主要是历史合成receipt正反例，62共享解析器保留它们。
- `make_variants.py`、`prepare_threaded_diagnostic.py`、`build_formal_audio_ab.py`仍是固定旧官方素材/包/源码的历史移动端诊断，未在full182中。不得把它们的成功当新版正式导出，也不应刷新旧SHA让其假装验证新引擎。
- 新recipe/build_id沿用sd1，但不同run产物可能不同；只有本次实际锁定字节允许安装。跨lane严格同run校验继续有效。Release标签一旦占用不同字节不能覆盖。
- 安装/完整模板哈希的真实耗时、新Android模板与旧应用SDK组合、所有真实导出/平台执行仍待实测。原预算不得放宽。

精确源SHA、19输出/18模板清单及边界见 `engine-184-activation-review.json`。本次没有新增仓库工具或测试注册机制。
