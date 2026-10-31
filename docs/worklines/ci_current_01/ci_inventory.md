# 当前与历史 CI 的实际边界

只读审计来源：main `bd86237456c7ce12a352b040857b208bdede7f66`。本页是现有 runner/profile/workflow 的导航与优化依据，不增加第二套检查注册表，也不表示全量 CI 通过。

## 26 套 generated-consumers

| 归类 | tests 下的文件 | 处理原则 |
| --- | --- | --- |
| 当前共享功能 | plains_feedback_runner、plains_camera_trace_runner、camera_comfort_runner、floating_touch_runner、plains_refresh_art_runner、home_app_runner、home_ui_tests、menu_settings_lifecycle_runner、player_feedback_runner | 保留自动检查；旧 Boss/旧算法用作夹具或对照不等于整套过时 |
| 仍在使用的实验/共享能力 | plains_terrain_cohesion_runner、generated_latch_trajectory_runner、plains_ground_support_runner、plains_recoil_margin_runner、jump_chain_measurement_runner、plains_spatial_runner、plains_exit_routes_runner | 保留入口覆盖；不能用这些通过代签正式两区 |
| 旧 Boss 内容 | plains_core_access_runner、plains_final_pier_repro、plains_polish_boss_runner、windkeeper_runner | 明确旧 12HP Boss；ModuleLab/GeneratedDemoStage 仍消费，且新 Boss 继承同一基类，不能整体删除 |
| 混合当前与历史断言 | recoil_recovery_runner、branch_library_runner、avatar_presentation_ownership_runner、painterly_skin_runner、meta_notes_save_tests | 先拆断言归属，保留当前地图能力准入、角色唯一身体、默认背景和存档防损坏 |
| 历史调参测量 | jump_height_measurement_runner | 覆写0.15/0.13秒跳跃保持参数；待确认当前默认跳跃测量覆盖后独立调度 |

各文件扩展名为 `.gd`。正式牧风者使用 `windkeeper_storm` 对应的新 Pressure 实现，而四套旧 Boss 测试加载 `scenes/bosses/windkeeper.tscn`。旧场景仍有实验入口；Pressure 和 Bellstrider 均继承 WindkeeperEncounter，调整基类仍需对应覆盖。

当前森林默认注册为 v15；存在 v18 常量不能据此判定 avatar 的 v15 断言过时。branch_library 中包含当前 RunProfile.formal 与两张正式地图的单发准入负例，不能随历史双发夹具一并迁走。

## 真重复与表面重叠

- gameplay154 与 art100 交集88；Harness 在单次联合执行中已去重，实际166。双 lane 互斥，verify-lanes只校验证据，不重跑。
- main 的 environment.yml 联合执行166项，再由 web job执行48项，其中45已在前者；docs.yml另执行33项，全部已在前者。正常完整路径计划为247次检查调用、169项唯一检查；这是计划集合计算，失败中断时实际次数更少。
- PR prepare 的24条Python前置用例用于提前失败，配置明确要求后续父wrapper仍执行，属于有意重复，不能直接删除父检查。
- production.yml直接调用test_cloud_delivery.py，后续profile的cloud-delivery-tests再次运行；environment.yml的test_frozen_assets也与portable-frozen-assets重复。
- floating_touch_runner与core的run_tests.gd均完整调用input_tests.gd.run()。独立触屏runner仍需自足，去重时须保留独立运行的基础覆盖。
- underworld-home-terrace中home_app/home_ui只是OWNED源码指纹登记，并非执行调用，不能算作重复。
- legacy-compat已有16项，与full169没有交集，当前workflow不直接选择它。把更多用例移进去会改变自动覆盖范围，需要同时安排共享代码变更时的触发。

## 优化先后

1. 恢复当前测试契约并保留失败证据。本批只补VisualFixture可空boss字段，原断言不删。
2. 优先消除main跨job/workflow的重复：同一提交、相同准备输入与工具链验证共同检查一次，Web补跑独有检查，并由汇总明确验证完整169集合及对应产物。缺证据或输入不同必须补跑；不能用目标集合缩小冒充full。
3. 拆分混合runner的当前/实验/历史边界，再调整变更影响选择。现有profiles/production_impact仍是权威，不建平行调度系统。
4. 单独诊断森林80路线超时，保预算与路线覆盖。它不能因名称含旧版本就被归档。
5. 最后处理套件内部小规模重复和历史跳高测量；保留可启动实验与共享基类的真实验证。

本轮只完成分类，尚未修改profiles或workflow。247→169是去重目标，不是已经测得的提速结果。
