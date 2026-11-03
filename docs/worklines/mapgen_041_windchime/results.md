# 0.4.1宿主接入验收进度

当前受验运行源 `a0a90061816516bb4ac15ea56b3d644b5c8b477d`，PCK SHA256 `e49853f58481a79a4fe50b696a257209a26b86742038b9857756d4da3d098ec9`（220414276字节）。原生结果按[源码兼容收据](../../evidence/mapgen_041_windchime/coverage/native-source-custody.json)复用原执行，不改成新head fresh；实际新Web在该精确head/PCK中运行。

本轮完整风铃Web已实际自动与九图独审严格通过；最终完整CI及main合入仍待执行。普通出发未替换，不部署网站。

## 来源与真实路径

SDK交付 `c35871446cc0a3939e1a38171435f42cdc64a359` 的0.4.1原包 SHA256 `f5c84e5e51dff01d16429783b957c0d5214056b9d2fea47a830baac12ecedb4e`；manifest实际算法源码 `8eefdbd140ce10defe1570ab8eefb6729382f8b3`。模块1.1.0/SHA `5ad5a7871941b2c1ffa759b18f7b1e80f2fe7e571b72f95d1e0ef26031f08723`，runtime-map/v2不变。先实核0.4.0再升级24叶/19GD；原版SDK源码不改，Python不进游戏。

主游戏锁定Godot4.7.2实际原SDK验证，开发入口调用实际算法内存结果，经同Provider→Plan→Stage→Runtime装配。SDK已物化镜像/偏移，宿主仅加placement。已有唯一Player/Controller、钱包/伤害/奖励及lifetime继续复用；公共装配不抽地图随机数。

## 实际原生结果

| 消费者/检查 | 结果 | 限定覆盖 |
| --- | --- | --- |
| SDK原包verify_bundle | PASS | 主游戏锁定工具链执行原成功/gears/失败完整结果对照；不是Stage |
| 生成身份/Job | 81/0、1005/0 | 内存来源、三种身份、旧恢复拒绝、真实算法/缓存、取消/重复/退出 |
| 冻结三模块/实际生成三模块 | 199/0、58/0 | 各自真实入口与既有玩家/服务，保完整所选内容；不是整图 |
| gears Provider/Runtime | 80/0、73/0 | 原危险带/saw/两linear、伤害/共享时钟/生命周期、旧0.4恢复拒绝 |
| 风铃Provider/真实内容夹具 | 35/0、100/0 | usedPort准入/反例；全原内容正反镜像、实际弹丸/开门/恢复。fixture不充当入口 |
| 风铃实际生成完整起点入口 | 60/0 | controller请求、站稳、Router真实射击/幂等、Motor到本侧岸、两恢复、ESC真实菜单、取消拒迟到 |
| 音频原wrapper | 94/0 | 原生产音频不改；真实50.005ms饱和保持、原41表达式/6case保留 |
| CI输入/计划/工作流 | 45/0、57/0、4/0 | 纯Git/工具反例；非实际4.43GB工件或完整179验收 |

## 实际Web与独立审图

| 用例 | 自动执行（原300秒） | 离线真实审图 | 当前结论 |
| --- | --- | --- | --- |
| 默认双fresh | 150.177737秒 | 六图逐张，77.638572秒 | 严格合流PASS；生成/有限移动/取消/菜单返回 |
| gears | 108.986178秒 | 七图逐张，93.501018秒 | 严格合流PASS；运动与退出。第二渡台最多裁切细条，不签双渡台全可视覆盖；原生负责完整危险伤害 |
| 风铃第一次 | FAILED，90.378572秒 | 三失败图保留 | 实际生成/出生/关门阻挡后，测试工具用了不存在的Mouse.click(timeout)参数，开火前TypeError；不是算法超时/游戏成功 |
| 风铃v2完整双fresh | 149.985604秒 | 九图逐张，152.835561秒 | 严格合流PASS；真实mouse miss/hit/repeat、正常Motor到本侧岸、ESC与取消；Web未测reload，原生恢复独立 |

实际源、producer、HTTP/PCK前后守门和browser闭合见各自原report/acceptance。原favicon404、Emscripten主线程阻塞告警保留，脚本/页面错误按实际报告；不把软件SwiftShader称手机FPS、硬帧预算、音频听感或整图验收。

## 边界与下一批

实际controller生成45个实例；其起点按module/version/start角色选择，连接C001至 `idea-spec02-s12-001`，不是早期conformance的 `idea-interface-s12-001`。[真实邻居原字段](../../evidence/mapgen_041_windchime/coverage/actual-controller-start-peer.json)包含完整4platform/2oneway、P/Q两linear的designState:FROZEN_EXAMPLE，以及group_motion bell/access/targets资格数据；当前宿主未支持，未装邻居，不宣称跨缝。

新三份离线覆盖库存分别绑定默认conformance46、gears43、controller起点45个实际实例及各自result SHA/请求/配置/连接。它们不是运行注册表或40图验证，不沿用0.3覆盖表/M编号。

## 保留的失败与CI要求

PR130/head9ba7的run41679005631实际126PASS/1FAIL/1在途未证/50未开始，保原身份。serial音频断言失败与parallel输入45:16/serial49:42占用job时限分开记录，不能称全部测试通过或算法慢。

CI现prepare同run精确HEAD/plan/原receipt绑定工件，后续lane/affected核path/mode/Gitblob/SHA/来源与安全恢复后复用；45纯测试、独审接受不等于4.43GB真实跑通。原178顺序/argv/marker/单项预算保留，m35仅追加实际旧恢复fixture输入，新增1个总240秒风铃聚合，full179=parallel93+serial86。旧54计划断言在显式历史tail适配后保留并加3项，57/0；原失败保留。

全部代码与必要证据冻结后才启动最终精确head完整CI/合流。通过后普通受保护merge保历史，合并消息含 `[skip-playtest]`，只跳网站部署，不skip CI、不绕保护。

## 本批工程收口与已知限制

三实际Web自动/独审严格合流均通过，共22次真实截图审阅；风铃[实际最终合流](../../evidence/mapgen_041_windchime/web/windchime-attempt02/acceptance.json)保自动149.985604/300与独审152.835561秒。完整起点只是自身模块到本侧岸，未装邻模块；恢复由原生真实消费者独立证明，未宣称Web测试reload。

DEV-BANNER-BELL-PROMPT-01：现有开发横幅轻微遮部分风铃小提示；风铃实体、门、角色和真实射击目标/通路未遮，实际操作通过。这是开发提示UX限制，另批处理，当前不改冻结源/几何/物理、不签精制教程或玩家认可。v1工具失败90.378572秒保原FAILED；v2只修Mouse API兼容，保动作/断言/原300预算及所有guards。

质量G4/technical/formal_integration只指明确四开发消费者工程范围；workflow仍review、G5/普通出发/邻居/整图/设备保持未验。最终冻结候选179+affected及4.43GB工件真实CI是独立必过的合入门禁，尚无结果，不借上述局部PASS代签。
