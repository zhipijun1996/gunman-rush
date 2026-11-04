# 0.4.1浏览器验收工具独立审阅

结论：限定接受当前冻结工具实施，允许进入真实Web验证。不是实际Web或截图验收通过。

审阅者`/root/browser_041_tools_review`与作者`/root/web_041_driver_upgrade`不同。未启动浏览器、服务、Godot，未stage/commit或修改生产代码。

## 独立证据

37项独立原件/SHA/字节与AST逆变换/无浏览器JS状态注入/300秒watchdog检查通过。实际历史default与gears原件逐字节一致；默认仅SDK两处字面及人工ACK等待改为明确自动动作/离线真审图，并保持原70个非ACK断言，两fresh、d180ms/a180ms、取消、6张截图、原全部source/PCK/producer/HTTP守门。gears仅SDK两字面改，原79断言、一fresh、10秒源时钟及墙钟、7张截图保留。

独立执行23项pure测试15.183秒/0失败，原始日志`independent-pure.log`。这些明确fake browser/source/PCK，不能称真实截图或Web通过。`test_prepare`会把确定性生成器文件原地重写为相同字节；实跑后全部25项冻结成员长度/SHA复核0变化，未有被审源码字节修改。

新风铃driver按实际native输出提取身份/单实例/风铃和门/出口接岸，不硬编码M号。只被动接console；真实鼠标射击通过已有adapter/Router，真实键盘Motor行走，第二fresh真实generate取消及ESC返回；不evaluate/init-script/teleport/补资源。9图全部必需。出生站稳、未开/开门/重复计数、最终落脚、上下文释放以及退出前清理顺序都有自动拒绝路径，外层与内部共同保300秒。

## 继续验收边界

prepare从native日志提取实际值并绑定提供的source，日志自己并无完整源码向量，因此复用原WIP native结果须另有真实生产源码身份/树等价收据；不能仅因parser接受新HEAD称fresh。实际PCK、来源/服务HTTP前后值/完整守门、全部raw错误及自动结果由root真跑。随后不同审阅者必须真正打开6/7/9张新PNG，单列离线审图耗时，严格合流才能接受。此报告没有看过真实新图，不签浏览器/真机/性能/整图/邻居或普通出发。
