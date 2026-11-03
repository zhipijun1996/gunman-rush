# MAPGEN-HOST-V2-02

继续feature/mapgen-host-v2-01 / PR127，基点9e97b553b7b51cbc64922ed94281061202e3e58b，PR实际base为30e36c9abe223f26e666ceaf796e3fe9cb58e10f。不从main重建，不恢复PR123。

用户顺序：A恢复原受证文档、保留旧CI失败并验证精确新head；B修INPUT/OUTPUT/INOUT协议并区分非法/合法未支持；C先核0.2.0参考包ZIP SHA并逐字节对现有map和三content，开发验证/提取不上游戏；D绑定协议/实现/模块包/实际map与content/选择/宿主bindings身份，旧记录在内容或binding变化时拒绝；E沿原有限导出/入口/bootstrap验证实际Web PCK/浏览器加载移动平台及退出，不发布。

范围仍完整M16/M18/M21受控切片，不扩机制、敌人、奖励或Boss；普通出发/物理/经济/永久存档schema/正式图声不改。map-gen PR2锁0d338c2309d4e17bd8e9b128f745eb93938e99b2，ZIP SHA25f05861b68a99eee1e9d588eb2cab761e30c85b7cc109b0536292fcc98867f6；实际包代码source commit按包原manifest另记，不混为发行提交。

root持有主树生产文件和单Godot/导出租约；ci_audit只读旧CI与绑定，death_render_audit在外部目录核参考包/开发工具候选，browser_verify先只读Web管线，death_event_audit后续非作者独审。各阶段冻结后才执行Harness；不边写文档边跑源码冻结检查。采用project-integration/game-quality-gate，技术阶段与完整内容/设备认可分开。
