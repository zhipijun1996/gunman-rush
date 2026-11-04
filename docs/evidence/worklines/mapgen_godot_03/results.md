# MAPGEN-GODOT-03 阶段记录

保留PR127 exact e7d；run41569062806 prepare/serial/parallel/affected全成功，172fresh。后续分支feature/mapgen-godot-runtime-03从e7d派生，321549f1只装锁定原包，5b0b58ac实现真实生成来源，231049be独立修复初始定位。普通出发地图、原物理/经济/永久存档格式未改，不合并、不发布。

当前真实依赖：冻结文件入口→原字节SHA核验；生成入口→实际controller能力快照或明确conformance930001→RuntimeMapGenerationJob宿主信封→原addons/mapgen ModuleArchive/GenerationJob→真实GenerationResult。两来源最终调用RuntimeMapV2Provider同一个_build_level，再由共用Stage→LevelRuntime→原模块及碰撞/伤害服务装配。无第二RunSession/钱包/伤害或奖励权威；公共装配不抽随机数。Python仅开发安装/验证，不进入运行包。

内存来源不伪造map.json/files原字节证明。原算法fingerprint不重写；生成输入指纹、完整生成map/content数据身份、所选范围+实际host binding+能力的装载身份分别记录。原结果原样保留；上游点赋值产生的StringName文本键仅在内存边界复制为String，整数、浮点及其他scalar不做JSON往返，旧Frozen身份函数原字节保留。

5b0干净源的原Harness实际8项fresh通过：44身份、883job、55入口、199旧Frozen、45bootstrap、66Web contract、14离线安装、52planner。原源摘要守门通过；targeted报告没有序列化双inventory，未编造独立比对。原始证据见[evidence](../../evidence/mapgen_godot_03/native-5b0/independent-proof.md)。

5b0 PCK build9e57e8df54aa，218875268B，SHA9e57e8df54aaa8c9eb9f93443bd2a0190d0b00ad7f0a5267df03e82f172fc4f0。真实浏览器205.8s/300：930001实际46实例/55连接/46content，原fingerprint9a5c671e…与host7a54b2f5…精确匹配；D/A、平台运动、ESC清理返回标题及另一fresh generate中ESC取消通过。35335源文件前后原向量相等，完整PCK/19依赖+旧7JSON读回，console的favicon404/Emscripten Blocking/autoplay warning保留。完整原报告与六图在[原归档](../../evidence/mapgen_godot_03/web-5b0/actual-01-raw-evidence.tar.gz)。

**随后发现该版本真实出生点未被测试覆盖**：actor仍[0,0]，不能把上述PASS签成正确进场。原结果保留；[初始定位独立修复](initial_spawn.md)后需新native/Web定位断言通过。M35另批仅保留真实危险带+锯轮+两linear ferry，不替代完整地图。此文目前是阶段记录，最终M35/新源Web/CI/交接尚待收口。

## 最终0.3技术收口（不升级协议或开放整图）

运行源7f65ab03949bf7a9665033ae58a74847f72e5fbc，12项原Harness release fresh全部通过，0reuse；真实计数48/883/56/199/45/71/14/54/76/67/42/13。源码守门实际执行通过，targeted报告未序列化双inventory。原M35错误HP假定与JSON数组数值比较失败均已保留，修测试oracle而不改HP/坐标/预算。

独立M35完整4平台、1原危险带、1锯轮和2linear ferry保留；Module.clock共同驱动原生运动。真实安全足底检查成功后才提交，unsafe spawn/提交前actor失效均丢弃provisional Stage。自然Router落险/1HP/返回/保服务与clock/最终5→0致死均实际通过；saw仅一次明确的场景内接触重定位证明真实sweep与下一pulse0.7调度，不是初始进场、连续路线或两次实伤间隔证明。

最终PCK 9952803573706414bd003a37e696627df1e55d6feaade3d7a917c0a593539140，218887548B，当前4.7.2锁定模板。两个本地实际Web轮各原300秒：三模块242.14s/两fresh，M35221.31s/一fresh，14图逐张查看。新硬断言首次真实loaded身体[-448,846]/[1626,1742]通过；上游9a5c671e…输入指纹不变，map content身份同为60bb6a119d7a8f7ebbd87f45b4003d40cd0d4e03acb714122b71979551c3d4bb，/2 host身份分别9bc6716d84953e884aa96ab3073a20d08670b60fc5fec2397025f801d2243f32和ae99b20e1b7d5913e4980d22eabc2b1243c295829a0adc615f8849dcf4c07c45。

PCK原字节和全部有限依赖读回、source35394文件前后向量相同；真实D/A、平台/锯齿10.5源秒运动、ESC清理返回标题、generate中取消无commit全部过。M35第二渡台画面裁切，危险带以DEEP DROP提示和实际节点rect证明，不签同时完整可见/美术认可。favicon404、Emscripten Blocking和autoplay警告均原样保留，不说Web诊断为零。独立非作者逐图/两归档原成员/PCK/原生报告已审，限定技术接受。完整证据在[final-web](../../evidence/mapgen_godot_03/final-web/README.md)与[独审](../../evidence/mapgen_godot_03/review/final-acceptance.md)。

原172全部保留，追加6项→full178=93parallel+85serial。两旧不可缓存Web检查显式实际资源闭包，旧命令/预算/断言保留。完整远端178 CI将在元数据交付head启动，以PR精确head checks和最终合流artifact为准；本地12项不升格178。普通出发地图/资产/物理/经济/永久schema不变，不合并不发布。

## 下一版本0.4（独立升级，不重做架构）

用户已要求0.4奖励空间修正版。实际候选为map-gen未合PR5 head6bf07ab5a655ea056461b935ae4354e15ef83482，ZIP7aa3f0e573675c3bb41e2a2a5b23254c4005bb8eaef9756535e3a6480988d778；主游戏0.3源码与输入锁此处固定。0.4仍1.1.0/v2，但40布局全变，默认58连接，不能沿用本节M16/M18/M21/M35编号、出生、装载身份或map-edit旧覆盖表。下一工作树从本0.3收口head派生，先4.7.2原包验证→实际生成→按module_id/content_version/role/ports/连接重选→重算绑定及身份→同Provider/Plan/Stage/Runtime→同原producer重新提取覆盖清单。原0.3表/源码/失败与证据不得改签成0.4。
