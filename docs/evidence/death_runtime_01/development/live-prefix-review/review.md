# Live-prefix 非作者静审

对象：`live-prefix-candidate` README/receipt、Skin `360228b65702ef218cad9a22d0decf25cef6b835670025446deca288536e2805`、Ground `d871a81f16371fb9cf9666074c027d3e86380218907e1b8fb8e9020bf9e8a4d2`、两个新增/兼容测试。Ground基点为Hopper-only `a265e233…`，没有重新引入Patrol/Charger整组death geometry。

**未发现当前正式消费者内的阻断问题，限定接受非作者Skin/live-prefix、GroundHopper、Pose两字段与测试结构。** 采用仍应由root实际draw的live/death配对及A/A基准决定。本审不运行引擎/Chrome、不写生产。不自审签本人Flora a408，也不自审签本人shared-loot及其App四断言；它们需要另一非作者。

- 键正确性：Skin :110–121/:138–150 包含原始pose除dead/death/death_clock/landing外全部字段；四个删除字段均不进入Ground live/vitality前缀，air/vertical/raw load/strike与clock等仍保留。kind/bounds/texture、独立复制的point/UV内容及只读weights数组identity均参与匹配。没有依赖可变字典identity。原始pose缺键与显式默认值会保守miss，不产生错误hit。live画出的真实625个结果可直接作为下次相同捕获状态的前缀；miss仅调用同一Ground live路径得到相同Vector2值。
- 算序：Ground :69–85仅在dead且传入Vector2时绕过live+vitality，默认调用与非dead仍执行原分支。三个live函数/vitality不读取dead/death/death_clock/landing，因此prepared.live与原dead pose的前缀相同。Ground从`if not pose.dead`起至文件结尾相对Hopper-only基点逐字未变；target、death<=0早退、lerp、floor及Skin最后landing保持。未把Vector2乘加改成矩阵或改变f32写回边界。对d=0/负值，仍返回同live前缀再执行Skin原landing；对d>=1仍保留原target计算与既有静尸缓存。
- Hopper-only：复核缓存只依赖size/death，类型cast失败重建，缓存仅Hopper分支使用。IK旧骨点、Vector2 body_shift、足目标lerp、原_hopper_knee与3个angle_to输入/运算顺序保持；标量float字段接收原返回值，未主动降精度；per-point segment距离、权重及最后blend不提升。旧五参_hopper_dead调用通过末尾optional geometry=null兼容。此前完整Ground静审中的Hopper结论适用于这个收窄版。
- 存续/失效：PackedVector2Array源快照显式duplicate，避免持有被编辑源的同一别名；缓存vertices没有再作为目标数组写入。世界transform、Canvas材质/颜色不在局部顶点键里，原每次draw的material刷新与draw_mesh都仍执行。字段仅值数组/pose值字典/纹理/只读anatomy引用，没有Canvas/Actor/Stage回边或全局实例缓存；rig释放时自然释放。原静尸缓存已有的源point/weights原地修改边界没有被扩大保证。
- 正式边界：实际Ground宿主只有原Skin，已有两个观察性subclass为ObservedSkin/CacheSkin，均接受新增第五可选参数并原样forward；其他四参public/prepared调用保持兼容。将来若subclass会改变super返回坐标，不能直接假定缓存其最终live输出后再次套同一变换仍正确；目前已查两者只记录不改值。当前actual pose只含标量/值输入；不给任意附带Actor/Object的扩展pose字典作无宿主引用保证。
- canonical anatomy合同：`Array.make_read_only()`冻结数组，不冻结其中Weights对象字段。这个候选按现有工厂提供的canonical masks不变合同工作；不支持同一Weights对象mask原地变动。源码当前没有该类生产修改消费者。只读数组换binding会miss，任意同对象mask mutation不在本次认可范围，不因此新增缓存框架。
- Pose依赖：实读`/tmp/gunman-first-use-web-source`的Pose，唯一差异为字段尾部两RefCounted及说明，无算法变动；Geometry不反持Pose。Flora依赖SHA确为a408；这里只核依赖身份，**不签其作者自评**。

测试核验：四候选/原件SHA均与receipt一致。原Oracle runner（已含cache-invalidation）的14处_check源行、motion的42处_check源行均原序逐字保留；motion改动确实只有override签名/super两行。新增reused prepared测试覆盖两pass、kind轮换、A/B/A尺寸、death完成→未完成、Fan clock与UV分支邻点，使用原2ce4ffa6 Oracle。新增真实DrawCanvas序列逐顶点字节比对，含3 Ground种类、live→dead、air往返、d=0/.14/.16/.999/1/.1、landing及clock/bounds/kind/point变更，未用重算当前实现替代冻结Oracle。没有删预算或弱化原断言。

一个非阻断的证据措辞边界：新增`supplied_live_points==625`证明每点经过前缀参数，不单独证明miss发生；texture更换与同值weights-array重绑本就不改变数值，byte Oracle也不证明这两项分支确实重算。因此测试标签“supplies recomputed live points”不应被报告成所有失效分支的独立计数证据。实际失效实现由源码键核对；影响数值的clock/size/kind/point变更由原Oracle验证。没有要求为了分支计数再添加实现镜像测试。

root在本审过程中报告：原180秒冻结Oracle 7899/0、442442 vertices、退出0且无ERROR/leaks；原motion wrapper603/0。本审未自行执行或读取这些新原始日志，故作为root提供的结果记录，不伪称独立运行。真正draw性能仍待；live每draw新增键deepcopy/源比较与缓存保留，会有成本，需看live/death全组而非仅孤立dead内核。额外固定数据约3份625×Vector2（约15KB/已画Ground rig）及小字典/引用，不签手机帧率。
