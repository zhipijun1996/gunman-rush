# 2026-10-31 第二次暂停：可恢复节点

用户要求在当前节点暂停。本节点仅保存已审代码、原始失败和恢复计划；没有执行新平台策略，没有启动新完整CI、导出、合并main或发布游戏。

## 已保存的实现

- 消费者与CI元数据收口：dce431120e1ad7c0cb69ff1d189490bf9fa47b8e；18个既有消费者，原命令/预算/profile前缀保留。资产总清单仅三条SHA修正，两条既有record另做来源技术重绑，原资源版本/生成事实保留。
- 独立原缺陷修复：61c4fac9e3f5674787cecc963a8ac1d9b675480d；只在RootBell恢复时复用既有粒子epoch清理。回退基点为前一提交dce43112。hit393/0、lifecycle112/0及原RootBell/deform检查通过。
- 内容基线main仍为2ce4ffa64ef65dd5fba892776eea019c9e2841d4，包含PR122/124/125/107；PR123关闭且排除。原dirty工作树/workspace/gunman-rush不改。
- 结构性重构已实施：1124文件按功能迁移、491 UID保留；Session/Composition、地图Provider/Plan/Runtime、库存/钱包/装备/奖励、敌人/Boss状态、音频和入口辅助均有真实消费者。新地图库和新算法没有实现，当前仍通过旧Provider/Manifest适配。
- 固定上游修复版Godot4.7.2及同源模板已经真实构建、发布和按锁安装，不能重复构建或混官方模板。

## 验证边界

原剩余157项预检为151通过/6失败，源前后不变。后继原spatial、production-loop115、scheduler27、forest-bible-reader58、Harness91以及audio四case通过；独立motion708/0、hit393/0、lifecycle112/0只代表相应消费者。暂停前原docs与quality检查均通过，原qualitydiff也通过；结构检查通过不代表完整185通过。

R3仍阻断：完整wrapper278/1；精确main运行子集5637文件上的原/精确callback两次roll-only均8/1。两组296行物理轨迹与重构源逐字段相同，仅全局tick差6759，说明这条旧轨迹失败已存在于main。一次warning转roll事件起跳仍8/2，未采用其时序。现有cautious2正式App战斗记录1608帧/3失败、Boss26HP、player0及fatal/run_ended；无脚本错误或泄漏，严格失败退出。它不证明所有合法策略不可行，不能拿旧漏主铃接触的影片证明当前成功。

未注册directional的旧捕获验证仍23/4，与精确main同失败；单列历史捕获合同问题，不改payload/容量规则，也不新增到185冒充覆盖。

最后公开核验源55b07609ea756c6faee771aaa84f080b249917fe，不是本重构。完整185、最终同源Windows/Web/Android、实际PCK/浏览器/连续影片及设备/用户认可仍未完成。本节点不跳红灯、不自动合并或发布。

## 恢复后第一个任务：仅一次平台策略诊断

平台候选只有静态双独审许可，没有编译或原生结果，主树未应用。candidate.json的UNREVIEWED是生成时原件状态，现状以两份独审和本index为准。

1. 读现有continuation_guide、current_state和本index，核Git干净、实际HEAD、唯一Godot租约与磁盘。不能reset原dirty工作树。
2. 对照index中两文件before_sha256，核原件不变；把两个当前源另存普通文件备份。核platform-counterplay.patch的SHA为4715b69e51932d74f163b3f2b598509a40821fd8d4fcdb83265a6843cbd72665，再检查/应用补丁。不要直接把.source快照放进运行路径。
3. 只用原真实App/map1 capture，多加显式--platform-counterplay。通过tools/run_tests.py的原run_engine执行以下参数，原180秒与7200帧不变：

       --headless --fixed-fps 60 --audio-driver Dummy --path .
       --script tests/underworld_plains/capture_underworld_r3_boss_fight.gd
       -- --map=1 --platform-counterplay

4. 候选必须通过真实InputRouter登既存130wu低台并落地，读取实际Module/shape/slide支撑，待实际incoming rig前缘进入支撑跨度后基础垂直跳。无H、最大跳数1、原HP/弹药/两枪预算；不设途中位置/速度，不改Boss/玩家/资源/RNG，不读取离线推导坐标作为运行机制。
5. 必须分别核实际登台、起跳、无伤完整首组（含完成tick后的伤害结算）、换边/落地及两请求两命中；标签不能代替物理证据。原25条胜利条件仍生效，试验失败/未完成必须真实失败。首组成立但后续死亡仍不是完整战斗通过，更不能直接改旧CI断言。
6. 归档实际候选SHA、命令、完整trace/log、退出码、源前后指纹和反例；没有新证据不扫帧、不加能力、不放预算。若失败，将假说拒绝并单列内容/测试契约问题；若成功，再独立审查正式消费者迁移及旧R3保证的版本边界，不擅自删除或expected-fail原检查。
7. 试验结束后仅在当前两文件仍匹配候选SHA时，恢复保存的两原件。若出现未知改动则停下保现场，不全仓reset/clean。

## 其余收口顺序

1. 先解决R3真实阻断，保留已核main原失败，不能把输入策略失败换成通过。
2. 运行当前源原受影响检查；再以同一干净提交执行正式full185=95parallel+90serial，不能拼接不同源的selected结果。
3. 更新三份审计索引。当前file_inventory/runtime_inventory/dependency_graph仍明确标acb快照；本包index-generator保留05生成器及三个原helper与两个原JSON的无损压缩。只运行05包装器，不能直接执行会写冗余输出的旧helper。参数包括实际expected-head、technical-closeout、consumer-closeout=dce43112及root-bell-paused-fix=61c4fac9；先核祖先/干净源与生成器内路径。
4. 正式CI成功后，按既有final-delivery-readiness计划核API digest绑定的实际Web ZIP/PCK，运行三个真实浏览器消费者；同包空目录核v11旧定义原始SHA，另录原生连续正常速度原声影片。再核公开metadata与完整PCK；不能用旧站替代。
5. PR仍未创建，main未合并。现有PR草稿说明只能据实际新CI/交付结果重写，不把pending字段改成虚构通过。新地图库/算法是后续功能工作，不把接口完成说成新地图已实现。

## 环境与历史保留

当前工具链只用原tools/godot.sh严格身份入口；不要用GODOT_BIN绕锁。真实编辑器版本为4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf，SHA eeaec2b65dc3234168be1e1cbcc89731514bbb78dfb2c1b502920c50830a0638。Xvfb已按Debian官方签名/包SHA装在/workspace/toolchains/xvfb/usr/bin/Xvfb，不必重装。

该仓库是partial clone。git archive曾隐式拉无关promisor包至磁盘满，原失败和精确tmp_pack清理收据保留；没有删除已索引Git对象。恢复旧源必须先git --no-lazy-fetch检查所需blob闭包，逐已存在blob物化，不重复大archive。冷字体导入4个ERROR和暖导入7.256秒clean均保留，不能混作一次clean导入。

旧inactive forest的81个大型JSON已无损gzip，原SHA逐件核过，恢复脚本/workspace/refactor-evidence/restore-retired-forest-large-json-01.py；所有原失败字节仍保留。两份重复引擎ZIP仅在核有相同toolchains/downloads副本后移除。完整大临时运行集仍在外部，仓库保留精选证据和可恢复源；不清理原件以制造绿色。
