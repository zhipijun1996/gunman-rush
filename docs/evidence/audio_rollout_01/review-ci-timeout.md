# CI串行corpus80超时 · 独立补充审查

针对run40820328364/job123274596047原完整stdout的只读分析，不修改已冻结装配review、不运行引擎。

**允许一次同head、原配置的失败serial job完整重跑；不能据现证据断言纯调度偶发。** 原600秒超时仍FAIL，保持正在执行的parallel和原始失败日志。重跑须原80例、默认4工人、原600秒、原assert/success marker/源守门；之后仍让原同源完整lane verifier及下游门禁核验。不以局部本地通过或旧73+新7拼成CI成功。

独立去重失败尾部5条重复stdout，实际只有0..72共73例，全部passed；73..79尚未证明完成。已完成例每例23.969–50.047秒，均值30.954秒，累计重叠wall时间2259.633秒。按同均值粗投影80例/4工人理想619.077秒，尚未加import/调度，说明既有600秒边界紧；这不是新时限建议，也不能从单一运行分离CPU调度、Python验证、I/O及原生执行成本。

独立逐字核对wrapper、runner、trace/策略、profile六文件与main45e98完全相同。实际trace通过DemoApp脚本new创建宿主，未实例化改动的demo.tscn，因而不挂新SelectedAmbienceRuntime；没有新选音循环导致此corpus成本增长的直接证据。导入/全局类缓存成本仍不能仅凭源码排除，运行器零diff也不能自动证明所有性能成本零变化。

原workflow支持失败serial proof覆盖更新，同时按run_attempt保独立lane日志，原失败不能删除；同head重跑后的原verify-lanes仍验证源码、完整检查集合、argv、时限、无reuse及日志，不绕过parallel/affected。若同类超时再次发生，应比较宿主资源与同80基线/分段成本，保失败后修真正瓶颈；不能提高预算、删case、换工人数或降低门槛以迁就红灯。

统计、原日志SHA及六文件SHA见[独立分析](review-ci-timeout-analysis.json)。本补充不签完整CI或允许红灯合main。
