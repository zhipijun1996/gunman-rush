# 0.4.1接入的阶段结果

本页记录可复核的阶段事实，不是最终候选的验收签字。精确SDK升级远端提交为 `a0089f1cf061bb8397bbae151dfbca6026576525`，tree `f30e9dc23ff8f762f1d831c7c5172ee01de9bdae`；其父提交为本轮范围提交 `5440f36b31063fa5f38b679579b75c2702b46f2f`。SDK升级的本地提交 `a800649390644e84ab70656f1445fb221931763b` 与该远端提交 tree 相同，Git Data API提交元数据不同。下列原生、适配和CI工具验证发生在共享WIP，必须按各自记录中的source/SHA判断覆盖，不能代签后续完整head。

## 固定输入与真实调用

采用SDK交付 `c35871446cc0a3939e1a38171435f42cdc64a359` 的原版0.4.1包，archive SHA256为 `f5c84e5e51dff01d16429783b957c0d5214056b9d2fea47a830baac12ecedb4e`。manifest实际算法源码为 `8eefdbd140ce10defe1570ab8eefb6729382f8b3`，不把交付提交混称源码提交。模块仍为1.1.0/SHA `5ad5a7871941b2c1ffa759b18f7b1e80f2fe7e571b72f95d1e0ef26031f08723`，公共协议仍为runtime-map/v2。

先显式核验原0.4.0安装的23叶/18GD，再核升级后24叶/19GD。新 `derived_library.gd` 和其余18个运行GD均为锁定SDK原件；主仓没有修改供应商求解器。原moduleZIP、两个请求和config保持字节相同。安装纯测试保留31项并新增5项，36/0。[原升级收据](../../evidence/mapgen_041_windchime/sdk-upgrade/upgrade-040-to-041.json)与[安装测试](../../evidence/mapgen_041_windchime/sdk-upgrade/installer-tests-attempt01.log)保留原件。

主游戏锁定引擎 `4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf`、binary SHA `eeaec2b65dc3234168be1e1cbcc89731514bbb78dfb2c1b502920c50830a0638` 实际执行原包 `tests/verify_bundle.gd`，使用原锁定moduleZIP，success、gears-930007和failure的完整结果对照均true，整体PASS。[原日志](../../evidence/mapgen_041_windchime/native-preliminary/sdk-verify-bundle-01.log)。该验证在原包project执行，不冒称主游戏Stage或浏览器验收。

## 已有实际宿主验证

| 消费者 | 实际结果 | 覆盖与边界 |
| --- | --- | --- |
| v2风铃Provider | 35/0 | 真实930001生成、按语义选完整起点；封闭未用helper可以合法入场；实际usedPort/body/bank/connection负例仍拒绝。不是真实射击路线 |
| 完整风铃Stage夹具 | 100/0 | 从真实1.1.0ZIP读取完整模块，原SDK物化正向/镜像；真实Router弹丸、门阻挡、开门幂等、Motor走到本模块岸、永久状态恢复、取消/actor失效拒迟到弹丸、退出音频清理。明确是fixture，不是生成入口或跨邻模块 |
| gears生成入口 | 初次69/0，恢复负例后73/0 | 真实0.4.1/930007生成并经同Provider→Plan→Stage装配，保危险带、锯齿和两台线性渡台；伤害、运动、共享时钟、生命周期；新增真实旧0.4身份恢复拒绝。单模块范围 |
| 森林音频原wrapper | 93/0、source_stable=true、released=true | 只修测试局部饱和夹具；原生产GameAudio、音频文件、池上限及原90s/210s预算不变 |
| CI选定输入工件 | 初版41/0；磁盘诊断后45/0 | 有限真实Git/Python夹具，非实际4.43GB工件传输。独审41/4/54通过的SHA范围见原报告；后续4项磁盘测试不冒称已独审 |

原日志和capture均见[证据索引](../../evidence/mapgen_041_windchime/README.md)。首次import的font错误、首次Provider body-path错误保留，随后分别修正/复验；不把失败记录改成通过。实际generated风铃入口、0.4.1 Web两fresh与最终完整CI另行记录，当前表不预签。

0.4.1 gears930007生成的 `content_store`、`instances`、`connections` 与保留的同请求0.4.0原件逐值相等；实现指纹与装载身份确实变化。新输入指纹 `84d94b05e86a00a507ef0de8cac9f407a6dbd9dd7662a505ac182402c8ead918`，地图内容身份 `273410cebf375c38f52783ea8edc281003ed6b2dfb19b40bd85d1a9542bd5eee`，宿主装载身份 `4ccac1be1cf8a29a04427209cd639bca3bd3067d0c842d4df761d4d9d3318bfb`。[逐项身份收据](../../evidence/mapgen_041_windchime/native-gears/initial-69/receipt.json)。该结论限同一请求；不把单例对照说成40张宿主地图物理可玩。

## 原PR130 CI必须保持失败身份

原精确head `9ba7d4b64b939f80168a3d7d1ef08fd32a5b6be8` 的 [run41679005631](https://github.com/zhipijun1996/gunman-rush/actions/runs/41679005631) 已实际结束FAILURE。原178项中观察到126PASS、1FAIL、1在途无最终结果、50未开始。

serial实际37PASS/1FAIL/47未开始；`forest-bible-ambience` 在9.781秒/210秒内断言失败，原生73项/1失败，清理released=true，不能称输入超时。parallel原日志89项PASS，90th `bellstrider-rework-01` 在途；job在90分27秒边界被cancelled，没有最终phase-proof和source-after，不能把在途check称timeout/PASS。输入恢复分别45分16秒和49分42秒，这是CI准备耗时，不是算法生成耗时。[原收据](../../evidence/mapgen_041_windchime/original-ci-41679005631/final-run-receipt.json)与原日志保持未改。

最小CI修复让prepare产同run/精确HEAD/完整plan与原收据绑定的输入工件，后续lane/affected校验复用；完整保留path/mode/Gitblob/SHA/source及no-overwrite、原preflight。原178检查顺序、参数、预算及Harness原件保持；最终可增加本轮真实新消费者检查。磁盘记录按真实volume/free/所需额外字节给出下界，确定不足就明确失败，不宣称标准runner已足够。实际4.43GB上传/下载/恢复及最终精确head两通道合流仍必须以最终真实CI结果为准。

## 当前完成声明限制

普通出发未切换，模块未升1.1.1，玩家物理/经济/资源/奖励/RNG和永久保存schema未改。当前不声称完整地图、邻模块跨缝、全部敌人奖励Boss、真机或用户认可。最终main合入须在本轮全部代码/证据冻结、实际完整Web与精确head完整CI/独审通过后普通merge；merge message使用 `[skip-playtest]` 保检查而跳本轮Pages部署，不使用skip ci。

## 后续实际原生消费者（本轮WIP源，非最终CI）

原始日志与capture见新证据native-current：生成身份81/0、任务1005/0、三模块58/0；完整起点真实controller请求生成、Router射击、走岸、连续两次restore/旧job拒绝、ESC真实菜单与两种取消60/0。新聚合保独立ports35/0及原完整机制fixture100/0，均实际执行。第一次generated runner类型推断失败、第二次固定帧先于真实audio drain导致菜单等待失败原件保留；第三次按既有drain真实墙钟5秒上限等结果通过，未改生产退出或音频。
