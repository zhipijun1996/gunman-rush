# 会话交接

2026-10-09 UTC。当前分支**docs/roguelike-run-contracts**；基于origin/feature/snappy-shot-burst最新77b10ec92e97aa89eddd92d83c409154f5d732b5；最新fetch main仍64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226。开始工作区干净、未覆盖任何用户改动。提交/本轮PR在推送后补充，最终HEAD以git log -1为准。#12/#13/#14仍未合并，本PR base是feature/snappy-shot-burst，不自动合并或强推。

## 当前交付

用户新增正式动作肉鸽设计已整合，权威来源与AGENTS已更新：整体定位、正式10小关/第10Boss、主题/类型分离/两出口、奖励二选一与交易、Health/Stamina/动作资源分离、两类伤害/段回退/零血Home、Run/Meta/存档、独立随机流与完整Manifest。旧game_design/MVP/架构/战斗/世界/敌人/关卡/路线图/任务中的冲突直接修正，没有只追加互相矛盾的文档。

[整合报告](design_integration_report.md)记录冲突映射/来源与实际验证；[决策](decisions.md)分用户确认、工程方案、D027–D031暂定与Q001–Q013待定。正式精力用途未定，既有AirFocus耗精力与遮罩保留原型实验，不增加移动/跳跃/射击消费。当前运行灰盒尚有旧即时死亡/整关reset，P2须明确Legacy测试隔离并迁移，不能说新死亡/回退已实现。

DOC-02与BASE-01完成；A32–A49只是新增planned验收。Godot4.7.2 Standard；python3 tools/run_tests.py实际326断言/0失败、退出0（含import），故意失败自检1。check_docs实际26文档/32任务依赖/链接/参数/设计契约通过，py_compile与diff-check0。临时副本文档负向自检：正式3关、暂定冒充确认、缺A39、循环任务依赖均实际退出1；正常副本退出0，未修改真实仓库来制造失败。本轮未改运行脚本/场景/物理参数/旧断言，未构建APK或发布新网页。

## 下一项与阶段门槛

下一实现任务**HEALTH-01（ready）**：固定灰盒最小Health/Stamina Definition+独立实例/API/HUD与资源测试；保持现有动作链、ActionResources和输入，不实现完整敌人/Boss/商店/家园。然后依tasks逐项ENEMY→DAMAGE→SEGMENT→DEATH（最小RunLifetime与Home占位）。P3才奖励/最小Modifier/商店，P4固定3关链/Boss/最小Home，P5正式10关/随机，P6Meta/Save与内容。

GEN-01依赖RUN-TEN-01与LEVEL-02新伤害固定挑战的手机验收；旧即死A14/LEVEL-01证据不能代替。3关只development_only，正式规则10关。二选一/Shop/Boss/Run/Save均无当前实现或运行证据；不得误标passed。

## 暂定与待决定

暂定D027第9双Boss出口、D028环境优先批次/怪物无敌不挡环境/回退满动作次数保留精力冷却与世界账本、D029双方同帧死玩家失败无金奖、D030Boss固定核心随机适配外围、D031候选去重与验证保底。

待决定：大关总数/终局、正式精力用途、枪支其他发射方式、血量关两效选择、击退、商店价格内容刷新、道具叠加互斥权重、永久货币/局内币带回兑换、Boss金奖领取方式、续局保存/成功结算、具体战斗平衡、永久升级与剧情、各StageRule完成/奖励跳过条件。不得擅自当用户已确认；不影响已确定10/Boss/松手射击。

Android/iPhone真实触控/配色/性能、Windows实机/实体手柄、A27矩阵与新固定挑战仍awaiting-device；Cloud界面发布按environment待用户。未制作正式美术/音乐、未做Steam SDK/商店发布。现有[网页原型](https://zhipijun1996.github.io/gunman-rush/)是旧运动/慢时测试；仅feature/snappy-shot-burst push部署，当前设计分支不发网页。[历史交接](archive/handoff_before_roguelike.md)保留当时版本/构建/公开链接事实。

```sh
git fetch origin main feature/snappy-shot-burst docs/roguelike-run-contracts
git status -sb
git log -1 --oneline
python3 tools/check_docs.py
python3 tools/run_tests.py
```

新环境按environment运行cloud_setup/cloud_start，必须用tools/godot.sh的4.7.2而非系统旧版；所有网络/进程有超时。结束更新本交接/任务/实际证据，提交推送并PR，不后台无限迭代、不自动合并。
