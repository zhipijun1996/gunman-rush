# 第二批网格性能与扩展架构

本轮运行实现提交 `ca505102f2bcd429a8a4c62eabd4f3a73a040ee8`；任务表修正为119f4a7e，必要技术绑定及最终局部验证来源为 `4ed961113a65068e3d488c0370cb573154a2bd14`。分支 `refactor/game-architecture-02`，没有合main或发布新Web。

## 实际改变

- 原 `PlainsRevisionPose.prepare` 每姿态计算33个64位波形标量及两个原有quiet表达式。Ground／Flora的真实625顶点消费者复用结果；raw/clamped政策和各偏移正弦分别保留，未用三角恒等式或Float32容器替换。
- Ground三个内部live函数接同一prepared pose，省去逐顶点的拆包／重传。Sentry／Fan只在实际零UV权重的叶子调用点跳过无效变形；共享枢轴helper保持原样，没有第二套渲染器或跨帧姿态缓存。
- 原变形回归保留全部旧断言，追加PI/TAU附近、长clock/stride、live/dead及signed-zero真实消费者反例。最终7101断言、371801个顶点比较均通过，包括实际draw准备一次、旧静止尸体缓存和可变bounds／texture／kind。
- 当前图声、网格密度、绘制频率、UV、碰撞、伤害、资源、奖励、RNG与保存格式保持。

## 测到的效果与代价

以下为同一云端原生引擎进程内交替运行原基线与候选，六物种、三姿态、三轮，每轮暖机3帧后60样本；计入prepare＋625顶点核，UV权重缓存条件相同。数值是三轮均值的平均，毫秒；不含mesh上传、GPU、AI、自然战斗或浏览器。

| 物种 | 移动：原→当前 | 受伤攻击：原→当前 | 死亡：原→当前 |
| --- | --- | --- | --- |
| patrol | 3.887→3.647 | 3.867→3.563 | 5.603→5.377 |
| charger | 4.007→3.768 | 4.068→3.719 | 5.645→5.403 |
| hopper | 4.036→3.799 | 3.982→3.790 | 6.639→6.456 |
| sentry | 3.092→2.704 | 3.081→2.670 | 3.091→2.952 |
| fan_sentry | 2.927→2.039 | 2.974→2.109 | 7.410→5.398 |
| root_bell | 3.722→3.658 | 3.688→3.600 | **4.336→4.464** |

地面三种活体核约快5%–9%，哨兵约13%，扇翼怪约29%–30%。**根铃死亡核三轮均回退2.08%／2.56%／4.17%，合计约+2.95%**，单列为本候选代价，尚待继续优化；这不是settled尸体draw-cache成本。该代价没有隐藏在整体平均值里。

54组checksum全部精确一致，原frozen oracle位级回归通过。此前候选把零权重判断放入共享helper，出现根铃回退；最终改为叶子调用点。所有早期结果及六版24份源码均按原receipt SHA核验后保留。基线四类只作测试内词法改名，原公式与循环完全保留，经独审确认。完整数字与归因见[比较](../../evidence/mobile_combat_mesh_02/comparison.json)。

这些是CPU核测量，不能当荣耀手机FPS、整帧P95/P99或已解决卡顿的证据，也不能与上一批微秒级表现管线的改善比例相加。

## 实际验证与两次失败

1. ca505首次Development：本轮新任务表少了依赖列，原quality拒绝；docs／structure通过，其后未运行。119f只修表格列位，没有修改检查器。
2. 119f第二次Development：原核心、怪物及森林相关检查通过后，原Bible拒绝三份源码SHA漂移；不能将该次称14项通过。
3. 原机制后继style31／creative34仅更新206引用中的三GD指纹，其余203、全部角色／路径／顺序／86非GD引用和原Bible图声不变。旧style30和九份旧输入按Git字节保留；有限history链复用，当前live validator不从历史回退。原82／27方法保持，当前46、手动history40、creative28在原30／30／60秒预算通过；219注册／full171、全部命令与预算不变，两既有check仅追加实际输入。
4. 干净4ed最终显式局部集合 **32项全部fresh通过，403.276秒**，包含正式Actor／受伤／尸体／恢复、森林消费者、原核心、7101位级回归、绑定及Harness／选择器守门。源码、版本重绑与测量分别获非作者只读独审。

[原始收据与失败](../../evidence/mobile_combat_mesh_02/receipt.json)、[源码／测量独审](../../evidence/mobile_combat_mesh_02/kernel-review.json)、[绑定独审](../../evidence/mobile_combat_mesh_02/binding-review.json)及同目录原件ZIP保留完整日志／命令／预算／源码与版本。性能测量发生在8df HEAD＋已记录候选工作树字节，四源码SHA与保存的ca505／4ed一致；不是当时干净4ed测量。最终32项则确实在干净4ed执行。

本轮改动到原profiles输入和历史工具，**原最终Integration计划仍升级full171，未执行**。32项是显式局部技术证据，不替代该计划、远端CI或Release。当前公开仍ab263ea6／build2e1274f62210，不能用旧包展示本批效果；手机、当前候选Web及GPU帧耗时未验。

## 后续与回退

- 性能下一步先完成累计full171与同源Web验证，再在真正交战中分开测空场、移动、落空射击、命中和批量死亡；复用现RAF／LongTask观察器，物理手机单列。根铃几何／IK常量及未settle阶段属于后续针对性优化，不宣称本批已处理。
- 后续业务扩展见[功能接入方案](../../architecture_extensions.md)。教程／剧情不是已实现模块；map-gen是已核的Python静态原型，正式模块及运行时部署合同仍需打通。应用模态流程、多区域准入及永久升级UI仍有明确收口任务。
- 本轮也暴露了维护成本：普通表现内部优化需要技术绑定版本和有限历史消费者迁移。后续可独立审视这层职责耦合；本轮遵守原保护机制，未借性能优化削弱准入。

回退基点为 `8dfaf7f325907e4b60853d6e49965fd359e869d4`。**必须成对撤回运行／测试与技术绑定**，不能只退三源码而留下新SHA。本批22路径逆补丁已通过 `git apply --check`，未应用；未来接入方案、质量卡和证据不在撤回集内。路径与SHA见[回退收据](../../evidence/mobile_combat_mesh_02/rollback.json)，补丁在原件ZIP中。干净回退分支先检查：

```sh
unzip -p docs/evidence/mobile_combat_mesh_02/original-receipts.zip experiments/rollback.patch > /tmp/mobile-combat-mesh-02-rollback.patch
git apply --check /tmp/mobile-combat-mesh-02-rollback.patch
git apply /tmp/mobile-combat-mesh-02-rollback.patch
```

仅逆向本批声明路径；后续若修改相关文件，先解决差异，不强制覆盖。回退后记录实际当前状态，原失败及测量保留。
