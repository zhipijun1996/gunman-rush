# CI lanes C 独立基础设施审查

**REVISE：一个真实proof路径边界漏收须修正。** 绑定commit `5e61afa6233018125ef0fb1d23129d7bc9522f9c`，三个Git blob／实际文件SHA、作者两份真实unit日志SHA及本次执行分列于AUDIT.json。未修改待审源码／tests／workflow；未native/browser/fullprofile/网络动作。不是整区内容或实际GitHubCI接受。

## 已成立的范围

- gameplay+art稳定去重85＝67 parallel＋18 serial，每项归属唯一；各lane检查顺序来自原resolve顺序，合并恢复原85顺序。原manifest/caps/argv未变，release fresh、非targeted、jobs1、partial标记、固定profile列表均需精确匹配。
- 两partial不独自给予whole批准，merge需两不同lane、当前Git完整metadata、当前全部prepared源SHA及afterSHA、相同工具链、当前manifest和每check依赖摘要。prepared resources/foundry在Git源库存，不能仅靠同GitSHA替换该资源。merge以真实stdout SHA、原marker和原strict错误条件复核，拒missing/extra/reorder/reuse/failed。机器间仅合法Python绝对路径身份可不同，其余expanded argv按token逐项精确，未提供任意命令豁免。
- 原run_check／execute_checks AST逐字语法树一致，保原过程超时、清理、strict与源变更拒绝；旧HarnessTests和ProductionTimingTests AST一致。新增8项不是覆盖旧25项。本次C真实执行33 tests/7.042秒/exit0，外cap60、四文件before/after一致；详unit.log与unit-receipt.json，不冒作作者先前日志原生重跑。
- 原5extras仅加serial条件，命令、env、marker等全等；其余所有workflow job结构与父提交完全一致。lane toolchain cache／diagnostics／proof名区分，fail-fast=false但不豁免失败。prepare/任一lane/collector失败使core gate失败；缺artifact/merge失败亦不放行，原deploy依赖core链保持。publisher接口未改。
- 主merge验证后复制各log并重核副本SHA、再重核报告SHA，最终再比当前source/Git，能抓读取后换内容／源变化；这部分不是仅信报告布尔。

## 实际拒绝缺口：proof目录祖先symlink被接受

`verify_lane_reports`先path.read_bytes，只对每个log叶调用is_symlink，未拒报告本身或祖先目录链接。独立真实tiny Python phases完成后，把parallel proof目录移到同ignored build另一目录，以symlink接回原目录；源码／metadata完全不变，verify仍接受。结果见negative-probe.json（不是native或合成自报passed）。初探移到非ignored源目录时被metadata拒，调整为ignored proof路径后真实漏收，未用该首次拒绝冒称路径守门已成立。

workflow collector同样只查source叶，且source.resolve相对已经解析后的report.parent.resolve检查，会接受整个report目录指向别处；报告自身也未强制regular非链接。本次合同特别要求log目录边界与TOCTOU，不能据33绿声称所有linked proof拒绝。

所需有界修正：对phase report及log、collector原report根至叶逐祖先拒symlink；绑定明确的proof根和regular路径，保留已有读取／复制后SHA复核。增真实ignored-build祖先目录替换与report叶symlink反例，不能只测log叶。不要为修此问题增加cap、删检查、放松metadata或改生产。修后另绑定新immutable源复核；当前C保持本REVISE，不覆写原件。

未发现覆盖、其它job、5extras或默认运行语义降标；仍不保证两lane各60分钟必过或所有CI完整执行成功。合并证据保证的是输入/记录一致性，不构成对恶意伪造整套报告+日志的密码认证；真实CI运行上下文仍由GitHub执行与artifact来源提供。
