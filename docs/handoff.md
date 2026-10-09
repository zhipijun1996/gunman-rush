# 会话交接

2026-10-09 UTC。当前分支 **feature/playable-demo-loop**，基于最新origin/feature/enemy01-patrol的b2eb137；已fetch最新main=64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226，PR #17仍OPEN，未自动合并或强推。开始工作区干净。用户明确授权持续完成多个任务至可玩demo，按P2→P3→P4逐步验证。旧敌人轮事实见[存档交接](archive/handoff_enemy01.md)。

## 本轮完成

DAMAGE-01/SEGMENT-01/DEATH-01：类型化帧伤害、稳定优先级与重复过滤、独立怪物无敌/回退保护；安全段起点与选择性回退；零血终局取消并回家园，不全场reset。bda8303为伤害阶段提交，实际440/0。

SUPPLY-01/BUILD-01/REWARD-01/SHOP-01：一次补给、独立回血/最大HP效果、可撤销来源Modifier、蓝紫金定义、二选一、RunCoin/报价/库存/原子单件购买与收据。未确定正式经济数值或精力用途。

RUN-01/BOSS-01/HOME-01：默认入口scenes/demo/demo.tscn。固定开发三关可玩：家园开局→射弹击败巡逻敌人→两个实体出口选择Shop或Items→购买/二选一→两个Boss出口→两阶段Boss与真实敌弹→保证金道具领取→胜利回家园；死亡也回家园。下一局清本局状态，Meta仅独立内存摘要，无自动转币/存档。完成条件独立资源、六类型注册、四种实际房间，地图固定；版本化Manifest记录配置SHA、实际布局/能力/路线/奖励/库存与收据，独立随机流。

正式仍每大关10小关/第10 Boss；development_only三关隔离。RUN-TEN-01的正式内容、GEN-01生成器、完整永久成长/剧情/Save尚未实现；不以三关冒充正式验收。LEVEL-02待真机，GEN门槛保留。D027–D031暂定、Q001–Q013仍待决策；本轮HP/敌人/Boss/商店/道具均开发fixture，不把候选当已确认平衡。旧graybox/WorldContext全reset已显式Legacy，与默认demo分开。

## 验证

Godot4.7.2 Standard。集成python3 tools/run_tests.py实际620 assertions/0 failures、退出0，含import（旧416保留）；随后补充死亡清最大HP Modifier来源的两项独立回归，economy独立55/0。最终干净检出结果与提交/PR/部署将在补证段记录。故意失败入口实际1。check_docs27文档/33任务依赖/链接/契约，diff-check0。

实际Web构建ff8c81d32b01，Chromium手机触屏模拟：HOME开始、真实左右杆/跳跃/松手射击击败敌人/10金币/解锁两出口、空中慢时金边/透明中心、暂停取消与返回家园，无脚本/Shader/页面错误。实际检查修复HUD提示遮住血条，触屏HOME含义与重复Pause按钮；不声称手机Safari已通过。

Windows Desktop、Web、Android debug APK分别导出0，APK签名校验通过。Windows PCK同版本Linux实际startup0及启动第一关配置hash验证0；这仅包加载，不是Windows EXE实机通过。Android设备未连接，adb daemon连接提示不影响export；Godot使用已安装build-tools35.0.1的fallback提示如实保留。SDK22已提示CLI将弃用，实际命令仍退出0。安装检查Linux x86_64 / Git2.52.0 / Python3.12.14 / Godot4.7.2官方二进制 / 同版模板 / JDK17.0.20.1 / API35 / build-tools35.0.1 / NDK28.1 / CMake3.10.2均实测可用，无missing。

## 未验证与下一任务

**LEVEL-02 awaiting-device**：请在Android浏览器与iPhone Safari分别横屏试玩，检查双杆/跳跃多指、短长跳、向下开枪反冲、慢时/遮罩、两条完整路线各实际通关和性能。Windows实机、实体手柄、APK真机触控/性能也单独待验。美术只有原创灰盒表现，没有新生成音乐或正式素材，不伪造完整美术。

复现：python3 tools/check_docs.py；python3 tools/run_tests.py；python3 tools/build.py web/windows/android分别运行；bash tools/godot.sh --path .默认进入demo。具体操作见[试玩说明](demo_playtest.md)。网络命令有限超时，import90s、完整suite180s、单次export180s；不承诺后台无限运行。build产物忽略、不提交SDK/引擎/密钥或机器绝对路径。

公开网页部署采用本分支push后tests→Web→Pages流水线，尚待本轮实际部署补证，不能把旧页面说成已更新。PR以feature/enemy01-patrol为base、叠加未合并原型，不自动合并。
