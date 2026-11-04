# Mapgen v3：同源八项专项独立核验

限定接受源 `5b0b58accf56259928870d2428e8f343dbf211af` 的原 Harness `--release --jobs 1` 八项结果：8 fresh、0 reuse、0失败，实际合计109.82秒。不是完整176项CI，也不签正在执行的Web。

|检查|实际计数 / 失败|耗时 / 原预算秒|
|---|---:|---:|
|runtime-map-generated-identity|44 / 0|21.751 / 180|
|runtime-map-generation-job|883 / 0|35.59 / 240|
|runtime-map-generated-slice|55 / 0|28.922 / 240|
|runtime-map-v2-host|199 / 0|4.885 / 180|
|cloud-preview-runtime|45 / 0|6.844 / 120|
|web-resource-contract-tests|66 / 0|1.18 / 60|
|mapgen-candidate-installation|14 / 0|1.176 / 60|
|cloud-production-planner-tests|52 / 0|0.323 / 60|

已独立读取八份原log及cloud-preview token对应归档原生log；markers、原argv/预算、exit0、无脚本错误/原生ERROR/泄漏均相符。两个mapgen JSON原件已归档。原report、日志及小artifact逐SHA保存在 `/tmp/mapgen-v3-runtime-head-native-proof-raw`。

源守门边界：report记录精确5b0提交、clean Git与空working_files；原Harness在每项前后和最终重新比较全源digest，全部未拒绝。但targeted模式没有序列化source_files/source_files_after，不能声称已独立比较两份原inventory。当前HEAD、manifest及守门代码均与受验Git blob一致；Web后续收据不能倒签native。

保留三个import的Android build-tools目录提示；本次不包含Android验收。job实际advance_max_ms=241.156也不构成16ms或设备帧率通过。

JSON证明SHA：`4864dd920f021fdd744aede6a3b064afae204f78aec2e92e42c9bd1c3b87afb2`。
