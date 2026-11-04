# Production CI Python补丁版本固定

任务MAPGEN-CI-PYTHON-PIN-01，仅CI工程修复；基线PR130精确0167ef34990e9c19a9ad57898f1e07f479ab2a5d。原阶段A宿主/SDK0.4.0/module1.1.0/生成配置及运行资源不变，不阶段B、不合并/部署。

## 实际失败与修复

[原run41659241932](https://github.com/zhipijun1996/gunman-rush/actions/runs/41659241932)两原phase实际178/178通过、0复用。原报告记录parallel Python3.12.16、serial Python3.12.15；各自前后稳定，但跨lane身份不一致。原harness.verify_lane_reports要求完整toolchain一致，不能用178测试通过代替合流成功。affected实际退出1，原错误为`Harness failed: Phase toolchain identities differ`。run最终FAILURE；原merged报告status=interrupted、checks=[]，不能称完整合流通过。最终收据及原mergedZIP、affected日志均保留。

原因：production.yml三处setup-python只选择3.12，check-latest默认false，不同hosted runner可选到各自已安装的不同补丁。只把本workflow三个消费者统一引用同一顶层PRODUCTION_PYTHON_VERSION=3.12.16；该精确版本已在本次parallel真实取得。原比较器、178集合、通道、命令、预算、缓存/来源/产物检查不改，不靠忽略Python身份过关。

## 有界验证

- 原tests/test_production_plan.py：54/0。
- 原tests/test_harness.py HarnessLaneTests：16/0，包含成功合流及工具链漂移拒绝，原负例诊断保留。
- 三处action引用、YAML、恢复旧版本选择后逐字等原workflow的独立检查另存；独立审查另存。
- 修复head重新执行原完整178+affected，结果在PR130 Actions实际核，不预签。只改CI和文档，复用原同运行源Web/native，不重跑默认双fresh或gears，不把新CI的PCK冒作原Web实测包。

## 原件

parallel.zip/serial.zip是原API digest绑定的小phase证明，含完整报告与逐项日志；phase-audit.json只因跨lanetoolchain不一致而阻断。mismatch收据含完整值、原ZIP/API链接和SHA。旧运行结果不覆盖、不删除。它们的源码身份0167与未来修复head严格分开。

本地初次docs/quality因切到相同tree的0167时重施稀疏规则而缺历史输入，真实失败日志以missing-input-attempt01保留。只从当前Git对象恢复缺件并核完整blob，未删旧卡或刷新其SHA。为避免根文件系统ENOSPC，仅将无活跃Godot进程的可重建导入缓存完整移至/tmp保全，源文件、项目UID、PCK、Git对象及证据不删；见cache-space.json。

独审直接读取过的merged-original-report.json按原字节gzip保全为同名.json.gz，解压逐字相同；原JSON同时完整留在merged.zip及持久旧run目录，不重写报告或更改其状态。
