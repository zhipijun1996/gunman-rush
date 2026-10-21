# Docs guard顺序独审

**限定ACCEPT：仅把原PR-onlyqualitydiff步骤提前。** SHA13fadcb8baaf8a9562b14b32143c22ecc096c3686d8d01a1ed47d478d670036d。所有7个stepdict逐字语义集合相同，只有顺序变化；其余YAML完整相同。qualityguard紧接setup-python，早于media/pip/docsprofile。原argv、if、PRbase、默认PRmergecheckout、fetchdepth0、concurrency、权限、上传及预算均保留。

独立实际运行`python3 -B -S tools/check_quality_diff.py --help`成功并检查其本地导入均为stdlib，早期步骤不依赖site/Pillow/media。既有provenance失败会更早暴露而不删除检查。完整PRbase实际通过记录由root提供，本审查未重跑。无engine/Git/remoteCI启动或生产修改，不签森林美术或全量CI成功。
