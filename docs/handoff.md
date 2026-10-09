# 会话交接

2026-10-09 UTC。当前分支**feature/actor-resources-framework**，基于最新远端设计分支c104d247214d98413cf7d2e3c69869c117d74dbe（PR #15）；fetch最新main仍64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226。开始工作区干净。实现提交50aa3c779ba435c7f4acdb02debd2462d424e94b、场景绑定修复1bbfd6eea8155fac192f80e783990d7f594e9c7a已推送；[本轮PR #16](https://github.com/zhipijun1996/gunman-rush/pull/16)已创建且open，交接补证后的最终HEAD以git log -1为准；本PR base是docs/roguelike-run-contracts，不自动合并/强推。上一轮设计分支CI已实际success，证据留[设计轮历史交接](archive/handoff_design_integration.md)。

## 本轮交付

按用户新要求先完成FRAME-01框架分类与实际资源接入，再完成HEALTH-01。代码导航见[模块分类](module_map.md)，实现与验证见[资源报告](health01_report.md)。新增Definition/State/类型化请求结果、ActorResources、玩家动作资源只读适配与订阅HUD；无万能全局总线/全套空服务。Health与Stamina独立，Health零血终态、不隐式回血；现有慢时使用共享Stamina并保留显式原型政策。玩家动作默认仍无精力消费，正式用途Q002待定。

Health默认5/5仅固定灰盒fixture单一tres来源；Stamina容量从player_tuning映射。原跳跃/射击次数计数器不迁移、N配置不锁死，InputRouter与唯一Motor保持原契约。HP/精力条不遮挡按钮，状态文字移到按钮下。旧Saw/WorldContext即死全reset尚未迁移，Health归零→RunEnd/Home也未实现。

实际Godot4.7.2 Standard；完整374断言/0失败、退出0（旧326+新48，含import），故意失败1。check_docs27文档/33任务依赖、链接/配置/设计契约与diff-check0。Web构建IDf1d93e48426f、Windows分别实际导出0，Chromium触屏模拟HUD/慢时通过；PCK同版本Linux启动0，仅验证数据包加载，Windows EXE实机仍未验；详见资源报告。不代表真机。本轮不发APK、不部署Pages，公开网页仍是旧原型。

## 下一任务与未验证

**ENEMY-01 ready**：先一个敌人Actor/独立AI/攻击消费者，不做Boss或全部两类伤害。按任务后续DAMAGE→SEGMENT→DEATH，才迁移怪物受击无敌/环境回退/零血Home；P3补给/Modifier/二选一/商店，P4开发3关/Boss/最小Home，P5正式10/Boss10及随机，P6Meta/Save内容。

A32/A47当前原型自动部分通过；正式profile消费政策待后续配置阶段。A49底层两效分离已有测试但Effect尚未实现，其余A33–A46不误记passed。GEN仍需LEVEL-02新固定挑战真机验收。Android/iPhone真实触控/性能/GPU、Windows实机/实体手柄、Cloud设置界面发布仍待用户/awaiting-device；无正式美术音乐/Steam集成。

D027–D031继续暂定（第9双Boss出口、伤害批次与回退策略、同帧双死玩家失败、Boss固定核心、候选去重保底）。Q001–Q013仍待定：总大关/终局、精力用途、枪支触发、血量奖励、击退、商店、道具平衡、永久币/带回、金奖领取、续局/成功结算、战斗平衡、永久升级剧情、关卡完成与跳奖条件。见[决策](decisions.md)。

```sh
git fetch origin main docs/roguelike-run-contracts feature/actor-resources-framework
git status -sb
git log -1 --oneline
python3 tools/check_docs.py
python3 tools/run_tests.py
python3 tools/build.py web
```

新环境用cloud_setup/cloud_start与tools/godot.sh固定4.7.2，不使用系统旧版。网络/API命令有限超时，import90s、suite180s。结束保存证据与交接，提交推送PR，不承诺后台无限迭代。

## 远端验证与修复记录

50aa3c7首次Cloud CI失败（[run](https://github.com/zhipijun1996/gunman-rush/actions/runs/37929393763)）：Player初始化发现资源定义无效。原因是提交遗漏scenes/player/player.tscn的新ActorResources节点/绑定，不能把本地工作区通过当成该提交通过。1bbfd6e已补提交场景，随后用无缓存独立检出1bbfd6e完整验证，实际374断言/0失败、退出0，包含首次import；日志无脚本错误。

[修复提交Documentation CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/37929633190)实际success；[修复提交Godot CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/37929633194)实际success：core（完整测试/Windows导出/上传）和web（Web导出/上传）成功；Android按需skip、deploy_web因当前非发布分支skip。没有发布新Pages，也不以CI导出代替实机。最终工作区状态需干净，不能再遗漏未提交运行文件。
