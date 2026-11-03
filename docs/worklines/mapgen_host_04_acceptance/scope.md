# 0.4宿主工程验收与多端口后续

基线PR129精确46eb3960a592374b5fb99d7df588962a3680f86b，分支feature/mapgen-host-04-acceptance；父PR及0.3/PR128不变。不从main重做，不恢复PR123。

阶段A任务MAPGEN-HOST-04-ACCEPTANCE-01：核父head CI41614301960，分解真实Web执行/墙钟/让帧/加载/工具与离线审图；按SDK和模块SHA复用已验库，独立job输入/RNG/取消/结果；优化宿主自身采样、复制和装配。原SDK18GD、模块1.1.0、随机/90秒算法限额、8ms软让出/原Harness预算不改。原双fresh/总300秒完整Web动作、断言、guards和失败语义保留，截图全部保存后离线审阅，不伪造实时人工批准。代码冻结后执行原完整CI，结果按精确head留证。

阶段B必须等待A工程验收：单独任务/提交处理实际使用端口的净空/落脚/连接准入，保留旧helper来源；完整safe_lesson使用正式ShotLatch/弹体/控制器/生命周期及既有状态权威。按module_id/content_version/role/连接选，不套M号。未支持邻居完整内容前不跨模块声明成功。

不替换普通出发、不升级模块1.1.1、不扩随机危险/敌人/永久存档schema，不合并/部署。原default失败、旧source/PCK/分项证据均保留，不由新结果改写。

责任：root持有文档/质量/提交及单Godot和浏览器租约、装配入口计时；binding_closeout仅job/缓存helper/相应测试；browser_verify仅开发验证工具；ci_audit只读CI；death_event_audit只读独审。独立审查者不修改被审生产实现。

验证顺序：受影响原check和新真实反例→主工具链导出/PCK读回→两冷会话300秒自动动作与完整guards→保存截图离线实看/独审→冻结精确head完整CI。CPU执行计时使用同线程函数elapsed，属于执行墙钟（含调度抖动），不冒称OS线程CPU采样；阶段wall与host执行之差记录为让帧/调度间隙，不全归算法。
