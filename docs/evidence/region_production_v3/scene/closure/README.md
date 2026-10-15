# 冻结静态pilot证据与源码增量闭包

原controller终态 `awaiting_acceptance` 原字节保存在 `raw/build/verification/v3-scene/state.json`。其唯一record error是缺当前`production_snapshot/task`绑定；真实review已接受有限G0/G1，G2仍未验证。这个归档不改写原状态，也不把补绑定写成原controller曾经complete。

`portable_closure.json`列出冻结growth电影964份代码/配置/位图SHA：945件精确来自Git `ebcf348312b2e128e51b8c5b684e402b3a565de0`，13件来自两家族实际素材提交`fafec0ff4bde30ffa183ecd736e71ae9b5229b96`，其余6件渲染/测试源码原字节在`runtime_delta/`。另有工具/UID/import控制文件的精确增量。这些数字是逐文件Git blob与已匹配冻结SHA256的实际字节比较，不是版本名推测。

恢复时在独立checkout定位ebcf348，按每个source_files记录从指定commit读取该path，或复制runtime_delta对应文件，逐SHA256验证964件，再恢复raw/build证据。不要覆盖现有工作区。原JSON/审查保持原引用字节；`external/gunman-rush`保留审查用旧baseline两帧。Godot4.7.2工具链不打包，不为恢复证据重跑native。本地完整155733219字节源码fallback只留ignored `build/region_production_v3/scene/frozen_movie_source_closure.tar.gz`，未提交五份全项目分片。

raw包括原真实实施/review宿主请求响应、命令日志、等待状态、完整正常MP4、实际抽帧、实测raw/observation与不同作者审查。原growth为3952 physics ticks、3956 video frames、33实际观测sample、source_before=source_after；视频帧号不是物理tick。独审没有完整正常速度播放/听完整音轨或真机，不扩写其证据范围。

补绑定后的只读`production_loop.check_task_quality`结果保存于ignored build，原等待state保持不变。绑定是本独立工作树的当前整体文件快照；ROOT普通复制后整体快照不同，应由协调者以原工具为集成树重绑，不把本工作树binding或旧电影冒充新敌人/新家族整合源已经过同一电影验证。
