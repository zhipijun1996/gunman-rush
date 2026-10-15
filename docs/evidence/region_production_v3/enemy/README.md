# V3-ENEMY-01 技术阶段候选

当前正式晋级关闭：`PlainsRootBellPlacement.PRODUCTION_ADMITTED=false`。新敌芦铃播种者以固定地印、延迟短芽、真实HP减伤打断制造站位判断。G0/G1已真实实施和自检，提交不同代理审查；G2–G5及完整正式遭遇未验。

- [最终G1报告](g1_report.json)：当前唯一输出新源165断言/0失败、5个证据删除拒绝、4个输出策略拒绝；[实际轨迹](g1_capture.json)、[原生输出](g1_runtime.log)、[命令收据](command_receipt.json)。
- [重复实际CLI](repeat_cli_rejection.json)：同一个成功目录再次执行在启动引擎前exit1，旧成功所有字节未变；[原始拒绝输出](repeat_cli_rejected.log)。
- [宽度校准](width_calibration.json)：400/440/560各双向6个独立真实Motor fixture，活敌/实际pulse、基础单跳、零伤害/零射击；最小体接触包络垂直余量93.36px。不是连续往返或种子成功率，560正式门槛未改。20实际正式Manifest原1/20合格候选保留。
- [623帧连续影片](movie_showcase.mp4)：10.383秒、1280×720、60fps、48k立体声，单场不重置、跳芽/走出/3真枪/2打断/1死/走过尸体。不是正式区域路线。[时间轴](movie_trace_v1.json)、[原收据](movie_receipt.json)、[合屏](movie_contact_sheet.png)、[完整尺寸警告帧](movie_warning_frame_60.png)。
- [影片原源归档](movie_source_v1.zip)及[重建说明](movie_source_v1.json)：14份原SHA全匹配，旧Python明确为精确逆补丁的verified reconstruction，其余为未改原字节。新wrapper观察产物修复另有[实际差异](producer_output_policy.patch)和[适用范围](producer_scope_bridge.json)，不把旧片说成新wrapper fresh。
- [原图技术度量](art_measurement.json)：仅证明实际透明图/六不同姿态；[原资产与来源](../../../../assets/region_production_v3/enemies/root_bell/README.md)保留真实单次图生原PNG/请求/参考SHA，未用第2call。
- [历史限制](limitations.json)：早期两次失败完整帧曾被固定路径覆盖，无原载体不能恢复；原失败日志保留earlier_logs。共享引擎锁等待被按协调要求取消，[记录](lock_wait_cancelled.json)是not_executed，不是玩法失败。

未签独立ACCEPT、主观画面/声音/动画连续性、趣味、用户或真机。音轨非静音及事件数不等于已实听；软件GPU录制时间不等于目标设备性能。Boss核心、Motor/资源/保存/RNG服务均未改。
