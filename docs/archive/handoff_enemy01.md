# 会话交接

2026-10-09 UTC。当前分支**feature/enemy01-patrol**，基于origin/feature/actor-resources-framework最新524c97433573402bfc2a3f34b03b9d6238efc23b；fetch最新main仍64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226。开始工作区干净、PR #16未合并，本轮PR以其分支为base，不自动合并/强推。实现1bf2f05及Motor定位边界补强a41c170已推送；[本轮PR #17](https://github.com/zhipijun1996/gunman-rush/pull/17)已创建且open，最终HEAD以git log -1为准。历史资源轮事实见[旧交接](handoff_health01.md)。

## 本轮完成

**ENEMY-01**：一个可配置悬浮巡逻敌人、EnemyActor/PatrolAI/Intent/独立Motor/Health/表现，独立场景与Definition；固定Practice可见，可由现有有体积弹体击败。AI不引用玩家输入/控制，Motor一次move_and_collide，PlayerMotor仍唯一move_and_slide入口。新敌人HealthState是唯一HP状态，Damageable兼容桥验证目标ID/epoch、友伤/自身/非法/重复再提交资源请求。死亡只发一次败亡，停AI/速度/碰撞，无奖励/Run胜负逻辑。

3HP、90速度、±100范围、28×32体积是单一tres灰盒fixture，D038工程候选不锁定正式敌人平衡。实际移动/跳跃/射击反冲/精力政策未改；玩家受伤批次/怪物无敌、环境段回退/零血Home仍未接入。旧灰盒整关Retry重置敌人，仅历史测试；正式段回退须保留其生命/AI，不调用reset全世界。说明见[敌人契约](../enemies_and_bosses.md)、[本轮报告](../enemy01_report.md)。

## 验证

Godot4.7.2 Standard。python3 tools/run_tests.py实际416断言/0失败、退出0，含import（旧374保留+新42）；故意失败入口1。新42涵盖真实运动/巡逻范围/大步墙阻挡、配置启停、两实例/Health独立、真实扫掠弹体命中、友伤/自身/非法/重复/错目标/旧epoch、死亡唯一/清碰撞与重启旧请求拒绝、SceneTree暂停/慢时四分之一速度。check_docs27文档/33任务依赖与链接/契约、diff-check0。

Web/Windows独立实际导出0；Web构建e5415f5135bb在Chromium151触屏模拟真实渲染移动敌人，HUD/慢时黄边/中心透明/退出恢复通过、无脚本/Shader/页面错误；Windows PCK同版本Linux启动0仅数据包加载。最终打包无build验证产物入包。干净检出/远端结果在补证后记录。未发新APK/Pages，公开网页仍旧版。

## 下一任务与边界

**DAMAGE-01 ready**：统一类型化DamageRequest、确定性帧批次、怪物受伤无敌与环境保护分离、去重/持续接触，先按D028暂定策略。然后SEGMENT-01选择性段回退、DEATH-01真正RunEnd/Home；不在本轮临时让敌人直接调用PlayerController.die或扣玩家Health绕过统一规则。

A20仅第一种独立AI/共享受击/败亡自动部分有证据；第二AI/主动攻击尚未实现，A33玩家怪物受伤仍planned。Android/iPhone真机触控/手感/性能/GPU、Windows实机/实体手柄、Cloud界面设置发布仍待；不能以渲染模拟或导出推断实机。Boss/二选一/商店/Run/Meta/Save未实现，GEN仍依赖LEVEL-02新固定挑战手机验收。D027–D031暂定、Q001–Q013待定不变，正式精力用途未定，无默认动作精力消费。

```sh
git fetch origin main feature/actor-resources-framework feature/enemy01-patrol
git status -sb
git log -1 --oneline
python3 tools/check_docs.py
python3 tools/run_tests.py
python3 tools/build.py web
```

使用tools/godot.sh固定4.7.2；网络/API命令有限超时，import90s、suite180s。提交时检查全部场景/资源已纳入Git，干净检出验证；结束保存交接/证据，提交推送PR，不承诺后台无限迭代。

## 干净检出与远端补证

独立无缓存检出1bf2f05实际416断言/0失败、退出0。随后将重启定位委托EnemyMotor.reset_at，确保EnemyActor也不直接改位置；最终a41c170无缓存检出实际416断言/0失败、退出0，含首次import；[Documentation CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/37969792575)与[Godot CI](https://github.com/zhipijun1996/gunman-rush/actions/runs/37969792647)均实际success，core（完整测试/Windows/上传）和web（导出/上传）通过，Android/Pages按条件skip。最终本地Web e5415f5135bb、Windows重导出0，Chromium敌人中心696.5→764.0及HUD/慢时通过；PCK再启动0，无脚本错误。
