# RUN-GEAR-R2-03：当前R2测试入口恢复

只修改`tests/demo_ui_01/r2_runner.gd`。当前正式标题Start应进入可操作Home，旧R2仍等待立即进入IN_STAGE，导致后续暂停断言根本未执行。基线`bb4bf46`，修复为原生Start→确认Home→真实Home导航Explore按钮→等待formal→保留全部原暂停断言；导航打开后用原frames(6)等真实布局稳定，保鼠标hover、activation count和viewport守门。

这是UI测试入口fixture，不是自然Home出口路线。自然Home行走和出口另由`bb4bf46`正式游戏影片证明。两次真实失败161／1、167／3保留相应日志和可用原件；第二次不得被包装成通过。最终源`11a4216681a1947ebbff156175581fa025f22323`仅改变这一测试，没有游戏／引擎／资源／录片工具变化。

验收：原R2真实原生输入与严格run_engine退出，保原所有断言与180秒上限；原当前UI contract另跑149／0。最终R2应实际进入formal并执行pause_checks，零失败，独立只读审查本修复。
