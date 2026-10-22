# FOREST-VARIETY-04：第一轮探索场所

基线 `e594d3ff54daaf9d8f5e30f3190890737ce39a1e`，开发分支 `feature/region-bible-v2-forest`。运行源为基线Git字节加各轮保存的完整changed source；测试发生于未提交开发树，不能称最终HEAD全量CI。用户8–12／15–20分钟是初步每图目标，没有从帧数换算达标。

## 可恢复的原件

- `iterations-01.zip`：round01–09、两轮局部轮廓、首轮实际App静图、协调脚本与原独审。
- `iterations-02.zip`：round10／11、实际App第二轮、首次primary20项完整native及外层ENOSPC失败。native exit0／249.136秒不抵销外层失败。
- `iterations-04.zip`：原33项超时、完整App04／倒木05、fresh library16／受影响正式主路线05、全部绑定源码／日志／独审与协调脚本（606成员完整读回验证）。
- `iterations-03.zip`：新库local01–03、round12真实世界失败、材质03、被拒木纹覆盖和AI素材的原件／派生失败、独审与离线汇总器反例。

各ZIP旁的`*-index.json`保完整成员长度／SHA及整包SHA。每个成员写入后都读回逐字节长度与SHA核对，未删除临时原件。解压后各native轮的`source-before/after.json`、`source-closure.json`与`changed-source.zip`给出完整运行源；primary轮的`source-bytes-before.json`指向完整`source-snapshot-before`。未改路径从基线Git blobs恢复。Godot仅4.7.2 Standard，root单引擎租约，固定60，不改核心动作／资源／能力／RNG／保存。

App第二轮的3699路径inventory与首次primary运行逐项完全一致，静图仅为明确摆位合屏，不作路线或动态证据。精确清单在各原件，不按文件数量推导丰富度。

## 已成立与原失败

七型从悬根后的龛内领奖、近侧低口返旧营地、远侧接新场所；双窗上下去向分开。Z外路下落，内路反向越断口／覆生刺，奖励再经另一侧继续；倒木上下两路；背枝使用固定果H后反向射击，安全外路不耗空中枪。它们不是六个完成区域，也没有把固定果冒称活果。

local01的24项有20项通过，倒木返跳离刺不足与背枝恢复支撑实际失败；修正真实站位／重复覆盖块后，local02仍揭出恢复路线被实体根挡住。local03两变体的真正外侧恢复和东侧穿口均通过。round12的185结构断言／union通过，但七条App路线均失败：整支持面被树干隔断，以及Z内跳净空不足。保留原失败；之后真正开侧窗、添加不同岸侧出口，并把观察袋及下部内环下移，未删守卫或调整物理。

首个33项primary矩阵原600秒超时：29项已完成通过，第30项因剩余26.98秒超时，最后三项未跑。两图正式出生点分别完成80／108段，Z实际取得6金币。内层未完成和外层timeout原件不能补写绿色；另存的外部观察仅证明终止后运行源仍与before一致。为适应地图规模，后续选择core20或library16，各自重新运行且保相同上限。

## 独审与未验

[原生round11独审](native-review11.md)只签四条C初始fixture路径，未签正式出生点；[实际App轮廓独审](app-review02.md)只接受有限静态轮廓继续做不同样板；[覆盖材质独审](material-review03.md)明确REJECT。新汇总器先被纯Python假engine反例揭出身份／空列表／fixture／领奖漏检，随后收紧；假engine不是游戏回归结果。作者单元测试不能自签独立验收。

整区美术、正常速度观看、充分网状拓扑、更多模块、活果渡口、8–12／15–20分钟人类计时、设备性能及用户认可继续未完成。生成的树皮study未保原布局，派生失败，未接入运行或改签素材许可；原工具结果、提示和失败完整保留。BGM未更改。

## 最新限定结果

新library16 fresh inner及outer exit0／334.075秒／源稳定，见[原生回执](library16-receipt.json)与[外层harness](library16-harness-report.json)。新倒木18.3之后只补两图受影响的正式出生点主路线，[journey05](journey05-receipt.json) exit0／135.791秒／源稳定，不冒称重新跑过完整core20或原33。

[App04独审](app-review04.md)拒绝倒木巨L，也指出Z与背枝局部几何；[App05](app-fallen05-review.md)实际看八图确认真实曲根／凹窝有改善，只准继续玩法验证，仍ART_REWORK。没有连续动作录像或全区艺术通过。新浏览器显式候选选项有[源码反例独审](browser-option-review.md)及[直接API防漏独审](browser-api-review.md)；未跑浏览器前不记GUI通过。

[最新原生独审](native-review05.md)独立恢复两个run各3708路径：53份changed bytes与3655份基线blob，库存完全一致。新库五条App共10098帧235段，两正式出生点共11815帧188段，完整路径、单Motor、真实24×36和每终点12帧全脚均核对；不为独审者本人编写的wrapper自签，不签整体FUN／美术／时长。

文档／流程profile29项fresh通过，见[原harness report](docs-profile05-report.json)，完整logs／fingerprint在`docs-profile05.zip`和每成员索引；原80/fullCI未跑。首次质量差异检查发现新脚本只登记目录而非具体路径，已补齐真实affected_paths并在实际PR base上重验，不修改生产或放宽守卫。

## Web依赖的真实失败与修复

[首次Web构建](web-failed05-receipt.json) exit1／源稳定：旧Foundry库因保守绑定所有generation文件而失配，未生成新包、旧包不冒充。用原 `foundry.py build --count24 --promote` 实际完成36短语／18连续路线及重放，随后原stamp通过；[回执](foundry-refresh05-receipt.json)明确只56个resources/foundry开发JSON改变，其他运行源逐字节不变。不是只换basis，也未修改guard／物理。完整旧池、原失败、新报告／回放、前后3708源与新JSON在`dependency05.zip`，成员索引保完整SHA／读回核对。森林原生输入证明仍只属于原始冻结源，可限定复用不变的森林／动作消费者，不追签整个新库存fresh。

[Foundry只读独审](foundry-review05.md)独立重算225项basis、核对旧ZIP和54份56113帧：实际回放payload全与旧版一致，只身份头改变。仅支持不变森林输入消费者的限定复用，不签新Web或整区。

## 浏览器真实失败后的小范围提速

Web06实际导出和完整PCK检查通过，但实际点击后截图30秒超时，[原browser FAIL](browser-failed06-report.json)保留。未改超时。perf07定位1155实体的原外边界计算11.94秒／App延迟组装27.23秒；perf08同场景为1.09／5.527秒。perf06最初探针没等待deferred组装，明确不足作时间证明，不补签。

闭AABB邻居粗筛保留原所有cuts、顺序、重复和精确one-sided占用，异常矩形保守全扫描。[native08](border08-receipt.json)3000断言含两完整世界逐项ordered faces/corners/edges/pieces等价；首native07两失败是fixture缺合法H条件，原失败保留。新增小矩阵接现有underworld-terrain入口，原120+新20在原150外层上限内，未增CI预算。

[实际GPU09](gpu-border09-receipt.json)两正式平原、四森林荆棘App静图和五原矩阵，11对逐RGBA及PNG全同；[数学独审](border08-independent.md)和[实际像素独审](gpu-border09-independent.md)只接受该等价提速。原style v3实际先拒绝漂移，完整新证据后才版本化重绑v4，不修改旧文档／原Bible／素材。原生／GPU／错误探针／源闭包和失败在performance06.zip（155成员完整读回）；失败包核心保存在本地build/region_bible_v2/preserved-web06，没有把它交作已过GUI的包。
