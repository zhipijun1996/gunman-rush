# DEATH-RUNTIME-01 开发证据

原生、逐顶点冻结Oracle、真实App与绘制微基准的证据；结果与限制见[报告](../../../worklines/death_runtime_01/results.md)。不是full171、CI API artifact或手机帧率证明。

`source-packaging.json`列出原始诊断GD到`.gd.txt`的无损打包映射，原字节SHA保持，避免Godot扫描归档时注册重复class_name。重现时先复制整个证据目录到项目之外，按映射恢复原文件名，再运行原脚本；不可直接在生产源码树注册这些诊断副本。原绝对临时路径是实际运行来源，不代表提交后同路径仍存在。

R1/R2、Web未完成采集、未固定time原生及早期微基准失败完整保留；只采用shared-only材质，不采用loot-gpu中用于试验的额外预热版本。
