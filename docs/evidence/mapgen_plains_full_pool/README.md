# 平原全模块适配验证

[公开试玩](https://zhipijun1996.github.io/gunman-rush/?build=d02bb003d9eb)版本 `d02bb003d9eb`，源码 `269f3d0c3f9e205d1e2faf43dc52da3ebc51ca4b`。线上完整PCK与本地导出长度及SHA256一致，见 [部署凭据](playtest_deployment.json)。

模块包1.1.0的106个平原模块全部有正式消费者，原先37个宿主排除项已清空；另外9个森林模块不属于平原池。SDK0.4.1与原始模块ZIP保持原件，内容清单和资格条件见 [模块池](pool.json)。机器参数只维护在 [正式配置](../../../config/plains_mapgen.json)。

出发角色仍使用真实能力和动作容量。基础一跳／一发空中弹药时，`game-challenge-long-gap`、`game-plains-recoil-chasm`因原资格配置要求额外动作容量而被保守筛除，给SDK的候选ID为104个；SDK还按实际能力筛选路线。拥有相应容量时两者可参与生成。原资格配置不授予资源，也不等于最低必要能力的物理证明。

## 已绑定行为

成对门互补切换并检查关闭区的真实角色；返程铃使用原侧向条件。平台启停、组运动、挂载铃、泊位、单向载台、闭合折线轨迹和载敌使用现有平台与Motor。炮台只由有效玩家命中产生授权中继弹，取消时清除未提交弹体。伸缩齿轮／尖刺使用现有伤害策略，奖励联动只消费已提交领取记录；释放板的实际碰撞、正式地形和地图同步消失。伏击区域触发一次原生敌人，重装保留已触发状态和结算身份。墙体使用原攀墙碰撞分组，角色能力由既有授予流程决定。

## 验证范围

- [全库目录](catalog.json)：106个模块的原版／SDK镜像，共212份内容、几何和声明Port落点。
- [绑定与恢复](runner.json)：212个原生装配夹具，保存与重装机关事务和平台相位，保留原玩家与基础资源。
- [实际交互](mechanisms_runner.json)：54个隔离夹具，使用Router和真实子弹、炮台中继、载台接触、伏击触发及既有奖励提交边界；检查组运动、挂载偏移、泊位和单向碰撞。奖励检查先完成原生资源授予再提交Stage领取，不冒充实际走近宝箱UI。
- [防夹](guard_runner.json)：18个隔离夹具，真实子弹和CharacterBody2D检查成对门拒绝夹住角色。

复现：`bash tools/godot.sh --headless --audio-driver Dummy --fixed-fps 60 --path . --script tests/mapgen_full_pool_runner.gd`；同目录交互检查为 `mapgen_full_pool_mechanisms_runner.gd`，防夹为 `mapgen_full_pool_guard_runner.gd`。

正式流程71项通过，覆盖标题／家园出发、实际射击与邻接移动、敌人和奖励事务、两张完整地图、既有Boss结算及H／森林后续流程。Boss结算及奖励事务中的明确位置／伤害夹具，不代表自然战斗通关。原有连续行走专项在新地图的工坊攀爬和移动载台路线未通过；当前证据不能证明任意模块组合连续通关，失败观察见 [路线限制](route_limitations.json)。不删除这些模块或降低三主路／六奖励来掩盖问题。

## 固定样本

同组六种子、两图，比较已发布69池与106池；基础脉冲枪，无额外能力。第二图由显式测量入口加载。完整观测见 [统计](corpus_report.json)、[第一图对照](map_1_comparison.png)、[第二图对照](map_2_comparison.png)。图绘制实际平台／封口，为整图比较而不加探索迷雾；不是游戏运行时额外暴露地图。

12张均达到三主路、六奖励，共抽到61种模块，其中21种来自本轮适配；其余未抽中的模块由全库原版／镜像夹具覆盖，见 [抽样覆盖](corpus_coverage.json)。连接模块占比29.3%→18.6%，平均不同模块24.25→22.67，总重复率56.4%→58.6%；扩大内容池未自动解决重复分布。原生等待中位数8.15→19.62秒，最大36.97秒，失败尝试6→14；完整扩池增加了搜索成本。以上为同环境原生无帧率限制执行；Web实际等待独立记录，不把预载或失败重试藏掉。

## 公开网页

桌面Chromium从标题、家园菜单正常进入 `ci-smoke`，非调试入口，地图哈希与原生一致；鼠标实际命中教学铃，键盘通过教学门。见 [正式画面](public_plains.png)、[过门画面](public_start_crossed.png)、[实际地图](public_map.png)及 [浏览器报告](public_report.json)。未发现页面或Godot脚本错误；这不代替整图连续通关或实体设备验证。

点击出发到进入地图38.264秒；场景计时37.821秒，其中剩余预载2.049秒、求解33.880秒（失败重试13.589秒）、验证0.300秒、绑定／装配1.414秒。标题／家园预载完整观测15.214秒，包含与出发后剩余预载重叠的部分，不能相加。初始网页／PCK下载不计入点击后的生成等待。后台求解已生效，当前主要成本仍是SDK搜索和重试。

另一个全新浏览器会话在后台求解开始后取消，恢复结算／家园界面，无旧地图迟到提交和页面／Godot脚本错误，见 [取消报告](public_cancel_report.json)与 [取消画面](public_cancel.png)。

## 上游缺口

[原SDK可复现请求](upstream_repro.json)包含实际基础能力、104个候选ID、三主路／六奖励、原配置和失败诊断。命令：`bash tools/godot.sh --headless --audio-driver Dummy --path . --script tools/mapgen_plains_review.gd -- --output=res://build/mapgen_full_pool/repro --repro=res://docs/evidence/mapgen_plains_full_pool/upstream_repro.json`。

[map-gen #7](https://github.com/zhipijun1996/map-gen/issues/7)跟踪闭环、Boss／奖励预留搜索成本；扩池后的分布和失败请求也由此追溯。仍需上游提供基于真实动作容量、机关相位和跨模块连续状态的路线资格；当前结构路线和原局部夹具资格不能替代连续Motor验证。
