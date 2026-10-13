# 当前交接：人物动作设计与harness规划（2026-10-13）

任务 ACTION-DESIGN-01（process/review）；基线 main 37c2153d9378e3e774fa9191c02318305af47ca5；分支 docs/player-action-harness-plan。本轮用户授权收录三附件、记录单武器限制并规划动作harness/skills；没有运行实现或合并授权。

设计入口 docs/design/player_actions/README.md；原始附件 sources/*.md.txt逐字节保留与SHA256；整理版修复旧链接/V0.7指令引用，保留LOCKED/PROPOSED与历史基线。最新单武器规则覆盖全局：只有一个当前武器Runtime，不等于只一弹体；H/W/D独立；局中切换未定。新W与核心能力独立奖励覆盖旧未来缓降/金道具描述。

规划 docs/quality/player_action_plan.md 与 docs/templates/player_action_coverage.md 包括八类待实现专项、动作阶段/转换、输入回放扩展、正常速度带音轨证据、设备/用户分开以及任务依赖。现有六个相关skills已增加入口和职责。新增专项均planned，未注册空runner；不改变scripts/scenes/resources/config/assets、世界连边或正式参数。

后续先 ACTION-INVENTORY-01 盘点正式角色，再输入/Runtime最小切片，Courier三连+W黄金样板及共鸣最小切片，逐条六分支/H/D，三级候选定稿后实现，再地区锁与设备。按规划给新内容独立质量记录。主角样板不能外推所有人物。

验证和交付结果见本页后续记录与 docs/quality/records/ACTION-DESIGN-01.json。本轮不声明新动画、独立审查、实际生产循环或真机通过。继续命令：python3 tools/harness.py --profile docs；python3 tools/check_quality_diff.py --base origin/main。

本轮验证：冻结内容提交 f7f88ce628d42f9adb3253f56d0af29fe0e5f438，docs harness 10项全部通过，报告 [docs/report](evidence/player_action_plan/docs/report.json)。首次检查因新任务索引review与初始化记录planned不一致失败，修复记录后复跑；[首次结果](evidence/player_action_plan/initial/report.json)保留。三附件来源逐字节及哈希核对通过，见 [来源检查](evidence/player_action_plan/provenance.json)。独立审查/新运行专项不在本轮验证范围。

---

# 当前交接：单向木桥返工与覆盖纠正（2026-10-13）

基线 main db1a27ef2778405908c91a54f9c02699684884e9；分支 fix/one-way-platform-boundaries；任务 PLAINS-TERRAIN-03（review）；冻结实现 62a7ef8。[PR61](https://github.com/zhipijun1996/gunman-rush/pull/61) 记录本次修复；此前石灰岩正式接入 PR60 的交接保留于 [历史](archive/handoff_terrain_production.md)。

用户正式截图（包指纹 f6134e79）暴露单向木桥端头。根因是正式路径循环整张带端头图，而旧测试检查未被该路径使用的 helper；此前石台样板/入口截图的覆盖被错误外推。保留单向语义不代表旧表现免检。原石灰岩认可不撤回，但“全部空中平台已完成”的概括撤回。

修复：PlatformingModule 为单向面使用 PlainsWoodPlatformArt，两端唯一、中部无端帽采样及透明颜色正确混合。碰撞、PlayerMotor、随机生成、奖励及原图未改。Skills 和质量检查要求运行消费者 inventory 与输出证据逐项对应，漏项/helper/错场景/旧版反例会被拒绝；静态校验仍不能证明画面漂亮或 inventory 完备。

冻结运行：实际两图枚举61/83单向实例；同一正式模块的尺寸/平移及GPU边界检查1054断言通过，旧实际绘制隔离负例7失败、退出1符合预期。7项覆盖规则反例通过。原始日志、代表合屏和失败图见 [证据目录](evidence/one_way_platforms)，[规格及限制](quality/one_way_platform_rework.md)，质量记录 docs/quality/records/PLAINS-TERRAIN-03.json。正式合屏是审查镜头取景，未传送玩家或声称路线通关；正常入口GUI和完整harness结果由命令记录补充。

状态：最终木桥视觉认可、独立审查、手机和性能仍未验证；实现者自检不签独立PASS。极窄8/24压力样本缩小且长条仍有重复节奏，不签美术完美。未重新验收其余材质、装饰、Boss、全Seed和回退消费者，不借本次关闭历史问题。

继续命令：python3 tools/harness.py --profile gameplay --profile art；DISPLAY=:98 python3 tools/run_wood_platform_tests.py --capture（需要可用X服务器）；python3 tools/verify_terrain_production_browser.py URL；python3 tools/check_quality_diff.py --base origin/main。正常GPU测试不能换成headless来签像素通过。

CI 补充：Godot core 工作流在原harness之后运行 xvfb-run 下的实际GPU像素检查，并上传图片/inventory；无GPU环境不能静默替换成headless签通过。冻结游戏/测试实现仍为62a7ef8，后续提交补充CI接线和交付证据。

最终本地回归：首次 gameplay+art 在新增 headless 退出资源 guard 处失败，未签全量通过；Core5942、legacy43、region15及其前序检查通过。诊断保留后仅将新测试host改为真实时间 max-fps=60，保留ERROR拒绝；连续3次各1041断言通过，art全profile复验通过。合并两次运行的25项检查无缺项，见 regression-summary.json；不是一次无中断full PASS。冻结Web13项、正常入口GUI及Web木桥可见性通过，浏览器包3b23691de8fc。游戏/着色器代码仍与62a7ef8相同。既有套件的退出资源警告保留，性能维度未签通过。

2026-10-13 用户明确指令“合入到main。”，授权 PR61 普通合并。合并前 dfe9627 的 push/PR 两套 docs、core（含新增 Xvfb GPU 检查）和 web 均 SUCCESS，见 [CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/38353756518)。本次仅更新交接文字后合并，游戏与测试实现不变；实际合并提交和部署结果以 PR61 与 main 工作流为准。Git 合并授权不代替最终木桥美术、独立审查和设备验收，质量任务继续 review。


实验室合并与增强进行中，旧工坊交接见[归档](archive/handoff_foundry_before_main.md)。

## 实验室持续测试与main整合

用户授权本轮验证后合并到main。基线7f0e433（PR61），整合8712fdd，反馈/敌人及键盘源提交0e4891250c41d2e300b1bd798977d59b75501445。保留主线harness/软件GPU平台不变量、平台边界和正式两张地图。新schema2意见导出兼容旧数组，包含manifest/basis、位置、能力及敌人计划；AI任务保留原文和整段关联。敌人开关为最多3个既有巡逻敌人手动预览，真实射击/接触伤害，无强制全清和永久奖励；不声称带敌人路线已验证。

Native反馈11/0、回放34/0、触屏438/0；完整gameplay+art harness通过，Web harness通过；独立触屏中文输入/下载、死亡反馈、模态拦截、弹体击伤与实例清理通过。死亡不能反馈、HUD叠层、虚拟键盘重点击不能输入的反例及修复留在[审查](evidence/foundry_main/review.md)。有Native退出资源诊断；实际Android/iOS键盘、手感/趣味与正常速度录像待验。FOUNDRY-MAIN-01保持awaiting-device。合并/公开构建验证后补充结果。

最终已按用户授权合并[PR62](https://github.com/zhipijun1996/gunman-rush/pull/62)至main **a165fbdda462d890b7c1cdf8ffd468ddf43c89b5**。[main CI38371668137](https://github.com/zhipijun1996/gunman-rush/actions/runs/38371668137)Core/Web/deploy全部成功，保留原harness和软件GPU平台检查。公开版 **[2765b0e93bb8](https://zhipijun1996.github.io/gunman-rush/?v=2765b0e93bb8)** source_commit准确匹配main；[构建](evidence/foundry_main/public_build_info.json)。公开844×390触屏实测：重新点击输入框后中文输入、保存、下载schema2含原始Manifest、敌人开关与模态屏蔽通过；[线上结果](evidence/foundry_main/public-touch-result.json)。真实手机系统键盘/手感/趣味仍awaiting-device，后续增加模块遵循foundry_agent_workflow；新增敌人模式仅手动预览，不能冒充敌人路线完整验证。
