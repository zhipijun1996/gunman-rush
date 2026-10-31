# Bellstrider R3旧消费者迁移独立审查01

**限定接受静态迁移范围，实际完整运行尚未通过。** 246项只读核对／0失败，审查者实际纯跑planner22／0、并用其真实lane守门拒绝5项独立内存变异。未运行Godot，未修改生产／测试／预算。作者为bellstrider_combat与root，审查者未参与这三个旧测试的迁移；不纳入自己编写的damage_policy独立验收。

精确源码指纹、实际命令、旧失败与当前02日志SHA见 `/tmp/bellstrider-r3-independent-01.json`。脚本 `/tmp/review_bellstrider_r3_independent_01.py`，执行日志 `/tmp/bellstrider-r3-independent-01-proof.log`，纯测试 `/tmp/bellstrider-r3-independent-01-planner.log`。

## 旧门禁保留与必要变化

baseline目录中的四份旧working/HEAD源均与实际main840108da Git blob逐字相同；原100检查／25失败收据和日志SHA实际核验。此次按用户“唯一上端主铃受伤、铜壳不伤”新合同迁移旧body-accept断言有必要，不能继续用旧body射击当成功指标。

三个原脚本没有移除原方法。component将mini初始16/8改为实际Definition40/20；增加14状态、交替左右真实core命中1及装甲0／恰一次装甲反馈；完整致死由16枪加强为40次真实1伤害命中，并穿插装甲反例。Windkeeper平台／阶段状态分支及原roll_trials逐字保持；暂停、intro/inactive、JSON恢复、接触边界、停止攻击和唯一死亡守门保留。

lifecycle仍是明示的一血／停止AI／控制弹体顺序夹具，不能称自然战斗。仅把Bell射点对准实际core、波来源改为实际Bell _ring_pair并冻结两边；Windkeeper仍调用旧_wave。原两map×两种同帧致死顺序、死亡优先、Gold／biome／mini奖不得生成、旧actor弹体与取消波拒绝全部保留。新增物理币权利不得生成及越过延迟impact后钱包仍不变的反例。

wrapper逐字等旧源：component/lifecycle各180秒、directions120秒、full两map各180秒，最低90／40检查与严格脚本ERROR拒绝均不变。

## 完整App战斗与奖励

原map1旧bot一直瞄车壳，改用已明示的cautious2合法输入观察者合乎新合同；pilot只读取Encounter／弹体／空间，输出真实MouseMotion与Router移动／跳跃／射击，未修改Boss HP、mode、clock、phase、位置或处理开关。只有完整战斗才声明无中途注入；component/lifecycle原有状态与一血夹具没有伪装成自然打法。

原7200战斗帧上限、原60胜后观察帧保留。新增最多300帧仅用于terminal后的真实残骸／金币领取，不给战斗增加血量、无敌或等待Boss停机。原map2平台／攻击pilot段逐字不变，其后原共用逻辑仅加map!=1守门；该路径仍须实际运行确认。

map1新增40实际命中／40实际HP损失，以及死亡完成、[1,1,5,5]四枚全claimed、钱包真实+12。先确认全部物理领取，之后才允许原有UI交易定位夹具reset_at；传送门币增量必须0、重复确认拒绝，原+1治疗权利保留并按真实血量上限钳制。没有把UI定位前的拾币冒称自然，也没有把满血治疗0误写成实际回了1HP。

## 169清单与当前真实失败

原168完整顺序和92／76两lane均保留，唯一尾追加真实七消费者bellstrider-rework-01，当前169＝93／76。planner只改尾项边界，保原144/165等摘要及168期望；5个实际守门反例（删Bell、删旧motion、换旧尾顺序、Bell错入serial、放宽原audio240预算）均被拒。

实际wrapper02先component278／0与directions16／0，然后lifecycle切map2发生生产脚本错误：`Left operand of 'is' is a previously freed instance`，位于WindkeeperHud.bind:52、DemoApp._process:1695。原日志 `build/bellstrider_rework_01/existing-continuous-bosses-02.log` 已核；这是必须修的HUD生命周期问题，不是可迁移掉的旧断言。02未完成lifecycle／full两场，不能称全通过。即使后续修复，也需保存02原失败、绑定新源再运行原wrapper。

本报告只接受守门迁移的设计／源码边界，不签完整原生、full169、冻结GUI、两枪／贪第三枪公平、艺术、听感、设备、用户接受或G1–G5。
