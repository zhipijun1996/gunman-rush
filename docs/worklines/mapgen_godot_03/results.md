# MAPGEN-GODOT-03 阶段记录

保留PR127 exact e7d；run41569062806 prepare/serial/parallel/affected全成功，172fresh。后续分支feature/mapgen-godot-runtime-03从e7d派生，321549f1只装锁定原包，5b0b58ac实现真实生成来源，231049be独立修复初始定位。普通出发地图、原物理/经济/永久存档格式未改，不合并、不发布。

当前真实依赖：冻结文件入口→原字节SHA核验；生成入口→实际controller能力快照或明确conformance930001→RuntimeMapGenerationJob宿主信封→原addons/mapgen ModuleArchive/GenerationJob→真实GenerationResult。两来源最终调用RuntimeMapV2Provider同一个_build_level，再由共用Stage→LevelRuntime→原模块及碰撞/伤害服务装配。无第二RunSession/钱包/伤害或奖励权威；公共装配不抽随机数。Python仅开发安装/验证，不进入运行包。

内存来源不伪造map.json/files原字节证明。原算法fingerprint不重写；生成输入指纹、完整生成map/content数据身份、所选范围+实际host binding+能力的装载身份分别记录。原结果原样保留；上游点赋值产生的StringName文本键仅在内存边界复制为String，整数、浮点及其他scalar不做JSON往返，旧Frozen身份函数原字节保留。

5b0干净源的原Harness实际8项fresh通过：44身份、883job、55入口、199旧Frozen、45bootstrap、66Web contract、14离线安装、52planner。原源摘要守门通过；targeted报告没有序列化双inventory，未编造独立比对。原始证据见[evidence](../../evidence/mapgen_godot_03/native-5b0/independent-proof.md)。

5b0 PCK build9e57e8df54aa，218875268B，SHA9e57e8df54aaa8c9eb9f93443bd2a0190d0b00ad7f0a5267df03e82f172fc4f0。真实浏览器205.8s/300：930001实际46实例/55连接/46content，原fingerprint9a5c671e…与host7a54b2f5…精确匹配；D/A、平台运动、ESC清理返回标题及另一fresh generate中ESC取消通过。35335源文件前后原向量相等，完整PCK/19依赖+旧7JSON读回，console的favicon404/Emscripten Blocking/autoplay warning保留。完整原报告与六图在[原归档](../../evidence/mapgen_godot_03/web-5b0/actual-01-raw-evidence.tar.gz)。

**随后发现该版本真实出生点未被测试覆盖**：actor仍[0,0]，不能把上述PASS签成正确进场。原结果保留；[初始定位独立修复](initial_spawn.md)后需新native/Web定位断言通过。M35另批仅保留真实危险带+锯轮+两linear ferry，不替代完整地图。此文目前是阶段记录，最终M35/新源Web/CI/交接尚待收口。
