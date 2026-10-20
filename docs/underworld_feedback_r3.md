# Underworld第三轮：战斗反馈与场景交互

任务UNDERWORLD-FEEDBACK-03，状态review。实现基线0fab13f，准确运行源P `9402bf92fa9be16b10d401db5e02b5c63124ff3c`、[试玩build74431d31fbfd](https://zhipijun1996.github.io/gunman-rush/?v=74431d31fbfd)。[十一项结果、六段影片与已知失败](evidence/underworld_feedback_03/README.md)、[用户原话与澄清](evidence/underworld_feedback_03/user_feedback.txt)、[可证伪范围](evidence/underworld_feedback_03/spec.md)。Q只改录制驾驶器，1885项运行树与P相同，媒体保留各自原源标签。17项新鲜专项通过，不代表完整85项/完整CI全绿或用户体验认可。

## 已定位的问题与生产规则

| 实际观察 | 修正与可复用规则 | 验证边界 |
| --- | --- | --- |
| Damageable桥只提交HP，丢失方向/已接受事件；旧反馈节点隐藏后绘制不可见 | 伤害表现从实际提交HP的事件派生；音频、身体、碎光和唯一Motor击退分别有owner，拒绝/无敌/旧epoch不播第二次受击 | 正反例覆盖真实弹丸、墙、暂停、重复、同帧死亡；最终GPU/听音另验 |
| 旧局部pit sensor和荆棘同走static_dangers，跨层合法下落被误伤 | 保留原数组/顺序，添加surface/fall_plane来源语义；只有无实体附着的坠落面检查真实下方可落地支持，表面危险保持真实伤害 | 同一ferry几何旧HP4/新HP5，移除下层仍HP4；不能泛化为“下面有地面就免所有环境伤害” |
| 环境伤害的HP提交与回安全点同tick，容易只在出生点出伤花 | 原受伤点保留有限无碰撞残影，安全点淡入；动画进出不延迟扣血/回退，不新增存档API | 用户已明确“导入导出”指进入/退出动画过渡 |
| DemoApp给主角弹追加PixelPlainsProjectile覆盖，单改弹体自身_draw没有效果 | 盘点实际绘制链；原真实发射点、历史轨迹驱动muzzle/trail，接触火花与HP命中分开；取消/到期不假爆 | 原15武器断言在实际Underworld分支继承验证；特殊风刃/桥落伤害代理仍由对应Boss攻击演出表达 |
| 上侧单向捷径不是普通ShotLatch，而是W→assembler.open_shortcut另一条路径 | 删除原W旁路，真实上侧弹驱动专用actuator；原assembler仍唯一持有门碰撞和opened账本 | 保留90wu/上侧资格、遮挡、敌弹、旧token、重载与幂等反例 |
| 领取后宝箱只调alpha；首批实机截图玩家遮住箱体 | 已接受原奖励事务驱动真开箱姿态，脚底/宽高比保持，重载读原ledger；验画面必须主体无遮挡 | 原遮挡图拒绝保留；定向重采玩家仍在原80wu交互范围内，未改奖励 |
| 原裁切元数据只有threshold8，audit把>误当>=，三个alpha8尾缘像素造成分歧 | 记录比较符与实际原builder，保留原图、原crop、阈值和派生像素；逐字节重建，不改阈值追签旧失败 | 实际是alpha>8；不宣称alpha>=8裁切曾通过 |
| 家园平铺与只看X的交互不适合多层 | 地面+96/192wu平台，角色基本单跳实际到十二站，二维邻近且落地才交互；slot_world_foot是锚点唯一查询 | 原四业务/Meta与八预留无授予分别验；原坐标驾驶器迁移，业务断言保留，旧源可重建 |
| 两Boss主体拒伤、core_open/方向锁限制输出；旧长过渡可无风险站桩 | 正式连续战斗Definition使存活活动战斗可伤；用可学前摇、行动、收招和有界过渡提供贪刀风险 | legacy窗口合同显式资源保留；两完整正式App战斗仅初始房间定位，非自然全地图通关 |
| Boss图形、受击范围和硬编码接触框不一致；扩大整图接触导致跳不过 | 受击体覆盖可打躯干，接触体只覆盖承载实体；同源Definition+真实世界shape；真实不躲受伤/正确跳躲过对照 | Bell全140×144接触失败被拒，128×110底盘接触通过；不是16区通用尺寸 |
| 新弹体叶节点间接依赖整套Actors，正式场景单独加载出现循环解析失败 | VFX样式查询局部沿祖先meta读取，解除Actor/场景反向依赖；编辑器导出通过不能替代独立消费者加载 | 原K失败和导入后同失败保留；原20张地图40374条检查修复后通过 |
| Boss弹命中回调漏传实际飞行方向 | 所有伤害入口保留真实碰撞步方向，最后由已接受HP事件驱动Motor | 真实左右弹体原16检查4失败，修复后16/0，不直接伪造hit信号 |
| 新普通受伤物理反馈抢占grapple及既有skill的运动所有者 | 真实producer传skill_attack，grapple按原damage_type分流；已接受hurt音画共用，技能力与stagger仍由原技能定义执行 | 原action-budget12条moving-hook失败保留；新增317专项真实两类skill/移动hook，原7305另作完整验证 |
| 地面敌人无重力，被普通受伤击退出平台后悬空 | 仅地面受伤力检查实际下一leading-foot支撑；宽地面仍有力，空中敌人与旧技能保持原行为 | 原297检查2失败，修复后297/0；普通AI、攻击和吸引不被改写 |
| 新Home专项计数较多仍漏旧适用检查 | 独立逐条比对旧guard而非比较总数；恢复单身体、muzzle、预留世界标签、完整Meta、源/回执守门及故意坏例 | 原HomeUI退出泄漏另留失败，不能用新专项退出干净冲销 |

## 风格与扩展

本轮仅新增一套真实生成开箱姿态；门/机关铜牌复用同族材质，弹体光效明确为程序VFX，不冒充新原画。装饰只增已有草花的小型有根簇，独立seed和whole-object keepout不改。家园东侧道路与开口钟拱表达出村；重复W说明交给近身HUD。16区复用伤害/动画/实体接口及画法，各区材料、色域、生态另有来源，不把本轮苔石铜色定成所有区域的固定配色。

## 检查入口

原underworld-home迁移到当前多层实际消费者，旧97及源原件保留在[精确R2 fixture](../tests/fixtures/underworld_home_r2/README.md)。新增underworld-damage-feedback、underworld-projectile-vfx、underworld-world-objects、underworld-continuous-bosses检查，分别覆盖真实伤害/跨层、15武器与远程、攻击开门/实际领取重载、连续Boss及真实同帧死亡/唯一奖励。source/assembly审计保留原107用例并增加Home/开箱反例，原Semantic arms故障注入改按ID定位以适配合法布局顺序。

最终独审必须实际看当前源连续像素和正式合屏；组件数值、定位图、完整Boss战、自然整图路线、听音、设备与用户审美是不同范围，不互相代签。

实机复审追加：Encounter的objective更新不会自动更新独立WindkeeperHud。连续合同须同步检查护甲状态行、命中词、阶段大字与方向箭头，legacy窗口提示只留在legacy分支。本轮N原片保留旧提示REJECT，后续仅HUD修正另绑定源。录制脚本必须等待真实异步Stage ready/assembly，而不能以start_plains返回值当同步就绪。

## 连续录制与最终守门经验

远程测试的初始站位必须同时满足真实激活净空、实际LOS和平台脚底。旧180wu定位在当前activation180−20条件外，不能以单独发弹或暂停敌人救证据。Q改为合法120wu间距；三发真实主角弹击杀实际哨兵，对方弹也实际扣主角1HP。反冲补偿用真实A/D，输入在物理边界交给原适配器，原100ms请求TTL不改；慢宿主曾真实过期的日志保留。真正Input、Router驱动、初始定位及自然整图路线须分别声明。

使用单一固定回执路径的工具应串行执行，避免并发写者造成看似正确的SHA。P家园影片与17项专项曾时间重叠，按写入时间和唯一结束写者独审确认：headless回执先写，影片后写，间隔188.341秒，复制所得对应影片；相同确定性内容的SHA单独不能证明来源。后续录制按case隔离路径、整段前后核对全部运行源与六个producer，保留原MovieMaker、trace和音频日志，raw AVI不入库。

正常退出也是原验收条件。断言0失败但ObjectDB/resource泄漏，或根本没等到完成标记的超时，都保持失败；单次隔离通过和后来新鲜通过不能追签原失败。P完整CI的generated-consumers严格泄漏与level-design-contracts超时独立于本轮17专项，尚未修复。软件录制时间和固定60fps媒体不是目标设备性能测试；有声轨不等于听音验收。

公开浏览器同样要读原始console。P9原42操作谓词通过、http_failures为空，console却仍有一条未知URL的generic404。报告应同时保留这两个事实，列定Godot错误为0不能扩写成所有资源错误为0；不猜favicon，不通过改过滤器或重跑擦除原记录。
