# Root Bell G1路由：纯Python阶段独审

当前CLI SHA a3812dcdeeb4070ee1c8054f34c92d6cfc4a2adb82ba64ef83a744d80bd9b1c5 的收据验证器通过本阶段。原实际native audit03 JSON正例通过；同一旧60与追加79反例不改断言重跑，共139项删除/重复/false/类型/loader矛盾均被拒绝。R1五漏洞及R2两个map_index类型漏洞原件保留，不能称首轮无问题。全部是实际导入Python verifier运行，不是新增native或mock worker。

只读代码确认G1先执行原run_root_bell_tests.py，之后调用真实root_bell_formal_runner.gd；新audit绑定command、exit、日志/JSON SHA并检查source before/after，最终自有成功marker仅在全部完成后打印。原root-bell-tests ID/360秒/inputs等字段保持，改argv/marker将新准入检查接入既有门槛。旧wrapper/tests/runner working==HEAD，原SOURCES/历史收据协议未改。

实际G1原生执行尚待父代理引擎窗口；本阶段不签已经完成调度闭环。实际退出资源/ObjectDB诊断必须保留，不能借这些Python测试称生命周期clean、地图完整可玩、商业或设备验收。
