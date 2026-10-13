# 当前交接：单向木桥返工与覆盖纠正（2026-10-13）

基线 main db1a27ef2778405908c91a54f9c02699684884e9；分支 fix/one-way-platform-boundaries；任务 PLAINS-TERRAIN-03（review）；冻结实现 62a7ef8。[PR61](https://github.com/zhipijun1996/gunman-rush/pull/61) 记录本次修复；此前石灰岩正式接入 PR60 的交接保留于 [历史](archive/handoff_terrain_production.md)。

用户正式截图（包指纹 f6134e79）暴露单向木桥端头。根因是正式路径循环整张带端头图，而旧测试检查未被该路径使用的 helper；此前石台样板/入口截图的覆盖被错误外推。保留单向语义不代表旧表现免检。原石灰岩认可不撤回，但“全部空中平台已完成”的概括撤回。

修复：PlatformingModule 为单向面使用 PlainsWoodPlatformArt，两端唯一、中部无端帽采样及透明颜色正确混合。碰撞、PlayerMotor、随机生成、奖励及原图未改。Skills 和质量检查要求运行消费者 inventory 与输出证据逐项对应，漏项/helper/错场景/旧版反例会被拒绝；静态校验仍不能证明画面漂亮或 inventory 完备。

冻结运行：实际两图枚举61/83单向实例；同一正式模块的尺寸/平移及GPU边界检查1054断言通过，旧实际绘制隔离负例7失败、退出1符合预期。7项覆盖规则反例通过。原始日志、代表合屏和失败图见 [证据目录](evidence/one_way_platforms)，[规格及限制](quality/one_way_platform_rework.md)，质量记录 docs/quality/records/PLAINS-TERRAIN-03.json。正式合屏是审查镜头取景，未传送玩家或声称路线通关；正常入口GUI和完整harness结果由命令记录补充。

状态：最终木桥视觉认可、独立审查、手机和性能仍未验证；实现者自检不签独立PASS。极窄8/24压力样本缩小且长条仍有重复节奏，不签美术完美。未重新验收其余材质、装饰、Boss、全Seed和回退消费者，不借本次关闭历史问题。

继续命令：python3 tools/harness.py --profile gameplay --profile art；DISPLAY=:98 python3 tools/run_wood_platform_tests.py --capture（需要可用X服务器）；python3 tools/verify_terrain_production_browser.py URL；python3 tools/check_quality_diff.py --base origin/main。正常GPU测试不能换成headless来签像素通过。

CI 补充：Godot core 工作流在原harness之后运行 xvfb-run 下的实际GPU像素检查，并上传图片/inventory；无GPU环境不能静默替换成headless签通过。冻结游戏/测试实现仍为62a7ef8，后续提交补充CI接线和交付证据。
