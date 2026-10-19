# 采证工具失败原件

- golden1：正常活世界连续定位使probe死亡退出1，只有部分图，不是正式游戏通关失败的证据。
- golden2：冻结父CollisionObject的process_mode将其移出物理space，但ALWAYS子Actor仍step，body->get_space错误；拒绝此采证。生产代码未使用该冻结机制。
- golden3：递归停止physics callback后相机也停，未snap到新位置，多个point其实仍拍spawn；拒绝此镜头覆盖，不能按数量当不同场景。
- tools/capture_underworld_formal.gd已改为callbacks冻结+正式CameraRig.snap_to_target/force_update_scroll，只作标明positioned_fixture的静态图。真实路线与动作影片另证，不用这些失败图片签覆盖。
