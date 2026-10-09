# FRAME-01 / HEALTH-01报告

2026-10-09 UTC。基于设计PR #15的c104d247214d98413cf7d2e3c69869c117d74dbe创建feature/actor-resources-framework；再次fetch最新main仍64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226。起始工作区干净，未覆盖用户改动。用户要求先搭框架/分类再下一任务，本轮依次完成FRAME-01、HEALTH-01，不继续一次实现整套伤害/敌人/Boss/商店/家园。

## 实际改动

- scripts/resources/{definitions,state,contracts}分离可共享Health/Stamina定义、每实例数值状态、请求/快照/结果；scripts/actors/ActorResources局部组合，不依赖玩家输入/Jump/AI。PlayerActionResourceView单独适配原计数器，HUD实际消费快照。
- Health支持damage/heal/set_max、钳制与零血终态；set_max不隐式回血。Stamina支持消费/恢复/不足拒绝，不主动再生、不定义正式用途、不默认动作消费。
- 带ID的事务去重、异payload拒绝、实例+epoch验证、结果/收据/快照副本隔离。实时慢时脉冲不累计每帧收据，旧epoch拒绝。
- 玩家场景持有资源组件，AirFocus使用共享StaminaState保留原型消耗/地面恢复/取消和金黄遮罩；原物理、输入配置与动作规则未改。HP5/5只来自prototype_health.tres固定fixture，Stamina容量只从player_tuning映射，未复制基础数值。
- 固定灰盒新增HP条，资源HUD局部订阅/解绑；状态说明移到按钮下方，避免遮挡。旧危险仍是待迁移历史即死/整关reset，不把Health零血接口当成已实现RunEnd。

## 自动验证

| 命令/检查 | 实际结果 | 能证明的范围 |
| --- | --- | --- |
| bash tools/godot.sh --version | 4.7.2.stable.official.ed1daf0bf Standard，0 | 固定实际引擎，未用系统旧版 |
| python3 tools/run_tests.py | 374 assertions / 0 failures，0；含headless editor import | 原326全部保留+新48资源/集成断言，脚本错误与提前退出由wrapper拒绝 |
| bash tools/godot.sh --headless --path . --script tests/run_tests.gd -- --verify-failure-exit | 故意失败1 | 失败退出码仍可用于CI |
| python3 tools/check_docs.py | 27必需文档/33任务依赖、链接、配置与设计契约，0 | 文档与DAG；不是正式新玩法验收 |
| git diff --check | 0 | 格式检查 |

新48断言覆盖Health/Stamina独立实例、定义更改不影响活跃状态、重复/冲突/跨实例/过期请求、不可变快照/收据、非法值/不足原子拒绝、当前HP与最大HP分离、零HP不可heal/set_max复活、精力为零不算死亡。固定真实物理中零精力仍移动/跳跃/松手射击弹体/反冲，补射击与补精力不串资源；HUD订阅/解绑与历史重启更新通过。

A32与A47当前原型自动部分有证据；正式精力政策仍Q002待定。A49只底层HP接口通过，补给/奖励Effect仍planned。A33–A46整体系统、RunEnd/Home和正式伤害规则没有运行证据。

## 构建、渲染与限制

不提交build产物或工具二进制。Android/iPhone实际触控/手感/颜色/GPU/性能、Windows实机/实体手柄保持未验证。没有新APK、未发布Pages、未实现Steamworks。

下一任务ENEMY-01：一个独立敌人Actor/AI与玩家弹体攻击消费者；不实现Boss或全部伤害/段回退。随后DAMAGE→SEGMENT→DEATH。新暂定策略D027–D031和Q001–Q013未擅自升级为用户确认。

最终Web导出命令python3 tools/build.py web退出0；构建ID **f1d93e48426f**。Chromium151手机触屏模拟实际加载对应PCK，HP红条y78–86、精力黄条y95–103、按钮y110起；状态说明已移到y168，截图复查无文字遮挡。慢时边缘RGB从(14,19,27)→(90,72,31)→原色，中心保持原色，无脚本/Shader/页面错误，退出与释放仍正常。截图及浏览器报告只保存于忽略的build/verification/health，不提交模拟产物。

Windows独立命令python3 tools/build.py windows退出0；PCK 114944 bytes，SHA256 f1d93e48426f24ef00329db645c55b7ebc7e2e4ceb731f54866fe6015ff33aa7。在Linux固定同版本Godot中使用--headless --main-pack build/windows/gunman-rush.pck --quit-after 5实际启动退出0，无脚本加载错误；这只验证跨平台数据包加载，不声称Windows EXE已在Windows执行。

打包检查发现旧all_resources会收集本地build截图/报告；三个export preset已统一排除build/*。最终Web/Windows导出日志都无res://build/文件入包；Android预设改动但本轮未构建APK。
