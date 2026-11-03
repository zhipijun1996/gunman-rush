# 0.4 官方样例的选片规划（只读）

这是对官方 `samples/success` 的静态候选规划，**不是本宿主 4.7.2 的生成或装载结果**。未修改仓库、未运行引擎、未换 seed。完整原 instance/content/ports/routes/seals 和来源 SHA 见同名 JSON。

来源为 map-gen PR5 release head `6bf07ab5a655ea056461b935ae4354e15ef83482`；manifest 实际源 `b21c889077ec97eb11a210d0ceab4fbddd862e48`，候选 ZIP SHA `7aa3f0e573675c3bb41e2a2a5b23254c4005bb8eaef9756535e3a6480988d778`。模块包仍为 1.1.0 / `5ad5a787…`。样例 seed930001，implementation=`mapgen/gdscript-candidate-0.4.0`、algorithm=`stable-v3-reward-space`，46 instances / 58 connections / 12 reward_sites。`result.json` 的 PASS map/store 与两个独立样例文件逐字段一致；这些均只是上游文件事实。

## 可选的真实连通切片

按身份与拓扑查询，而不是沿用旧 M 编号：

1. 找唯一 `idea-spec02-s11-001`、content_version=`sha256:afa52a8edc28fa26655f38815c277a21e68c56224c74c2bf125cfa580bd727ae`、role=`traversal`。
2. 沿它真实 `R` 端连接，找 `game-route-junction` 的 `entry_left`。
3. 沿这座 junction 的 `entry_right` 找下一座同模板 junction 的 `entry_left`，并核第二条 upper 连接。两座 junction 的完整版本均为 `sha256:fbb52222ffe928c803c5cfd3107028e3ca86e8d2e44ae3aba1ea0ba987e12d40`，role均traversal。
4. 不按数组顺序随意选其他同版本 junction；任何身份/拓扑歧义都应拒绝。重新生成后必须重新执行此解析。

本次样例解析出的标签恰好为 **M16、M18、M21**，但这是上述查询的结果，不是预置条件。

| 解析结果 | 模板 | origin_blocks → world pixels | 已物化镜像 | 源平台 / 原封口 / 动平台 |
|---|---|---|---|---|
| M16 | idea-spec02-s11-001 | [-3,6] → [-384,768] | true | 4 / 1 / 1 ellipse |
| M18 | game-route-junction | [-9,5] → [-1152,640] | true | 7 / 1 / 0 |
| M21 | game-route-junction | [-15,5] → [-1920,640] | true | 7 / 0 / 0 |

完整18个源平台、2个原封口保留；装配为20个既有平台定义。唯一one-way为ellipse模块原index3。三模块的 hazards、saws、hooks、thorns、latches、enemies、reward_sites、wall indices 均为空，没有为过门删内容。只有ellipse原一个 `P`：start[480,256]、finish[160,256]、size[112,16]、center[320,256]、radii[160,144]、period/travel8、dwell0、phase0、x_sign=-1。完整字段在JSON，不重做镜像或source_affine。

内部实际连接如下，不能继续使用0.3的旧连接编号：

| edge | 端点 | world position | surface |
|---|---|---|---|
| C026 | ellipse.R ↔ first-junction.entry_left | [-384,832] | ROCK |
| C028 | first-junction.entry_right ↔ second-junction.entry_left | [-1152,832] | ROCK |
| C029 | first-junction.exit_upper_right ↔ second-junction.exit_upper_left | [-1152,704] | ROCK |

两端实际 face 互为 LEFT/RIGHT，permission 全 INOUT，原connected_port_ids均包含对应端口。切片外连接为 C021（ellipse.L↔M13.B）、C035/C036（第二junction↔下一junction），保留原开放状态，不生成额外封墙或假邻居。

原封口：ellipse.B `[128,480,128,32]`、first-junction.exit_upper_left `[736,0,32,128]`；second-junction无封口。完整原routes与其 partial能力/原向有限证明一并保留，不能提升为当前镜像或跨缝连续通关认证。

## 当前 Provider 与原 Resource 的拒绝边界

**当前生产 generated 入口仍只接受0.3/stable-v2，直接传0.4一定被版本门拒绝。** 此报告所说“兼容”仅指完整内容类型和几何转换可复用；必须在独立升级批次明确安装/承认0.4，不能仅改source标签假装0.3数据。

原 `PlatformingModuleDefinition.is_valid()` 不只是查字段：authored body helper ports须站在真实平台上、不与任何静态实体相交，身体grow8须避完整危险/运动包络。此处 helper ports 是玩家身体中心，与v2跨界几何port不同。

- ellipse helper entry[616,334]/exit[24,78]，junction两座均entry[744,206]/exit[24,206]。
- 按当前24×36身体与原Rect相交/脚底支持条件做了Python子集检查：六个helper点都在源平台上，未与原封口/实体/ellipse全包络相交；ellipse包络 `[104,104,432,304]` 完整在owned bounds内。
- 这不是调用Godot `Resource.is_valid()`，也没有SceneTree/physics支持登记、速度携带或Motor证据；类型、资源复制和完整门禁仍待原生重跑。
- **不能顺势扩为四座模块**：下一座junction（本样例解析为M29）原LEFT entry_right封口 `[0,128,32,128]` 与其 authored exit身体 `[12,188,24,36]` 相交。虽然平台4提供脚底支持，原 is_valid 的静态实体相交条件仍应拒绝。不能删封口、挪helper或把该问题记成路线已通。

## 由当前几何推导的出生候选

优先在本次实际ellipse原platform0 `[528,352,112,160]`，取中心x、top减18：

- local body center=`[584,334]`；由本次origin[-384,768]相加得到 **world `[200,1102]`**。
- 身体local `[572,316,24,36]`；grow8=`[564,308,40,52]`。
- 完整脚底位于原platform0，未碰其他源平台/封口；grow8在ellipse全包络右侧，不以当前单一相位冒充全相位安全。
- 原platform1 `[0,96,80,416]` 同规则得到local[40,78]、world[-344,846]，也是静态候选。
- 原platform2的中心候选处于ellipse完整包络内，已标失败；不能挑有利相位绕过原安全检查。

这些世界坐标均是从0.4样例当前几何重新计算，不复制0.3的global spawn。只有4.7实际重新生成后再次解析、通过原Resource、真实body shape与脚底支持查询，才能写成新版host bindings并激活角色。任何失败应拒绝入场，不移平台/清危险/临时造支撑。新绑定、版本和实际生成身份必须进入新的host load identity，不沿用0.3恢复hash。

## game-plains-ferry-gears 单独查询结果

**官方0.4默认成功样例中，该 module_id 的 instance数=0，content_store stable_id匹配数=0。** 因而不存在可报告的本次instance/version/role/neighborhood；JSON显式记null/空集合，而不是借用旧记录。

当前标签 **M35 已是 `b31-n06-fourport-two-low-ingress`**，版本=`sha256:5aebe7b7a122a26eabb4f25a4a4324244b336552d1d450b41c1659a01b6c8c0f`，role=traversal，origin[39,1]→[4992,128]，mirror=false。完整内容含1个 `wing-pair` latch 和1个 `plains_diver` 敌人，无原ferry-gears的危险带/锯轮/线性渡台。当前Provider应继续拒绝该latch/enemy内容，不能删数组后当旧M35。

它的真实邻接是 C030→M19、C053→M36、C054→M45、C055→M40；完整端点/坐标及source row见JSON。这些是“当前标签M35”的邻接，**不是ferry-gears邻接**。

若后续还要在0.4生成图里验证ferry-gears，须另行确定真实请求/seed并实际生成，按模板与版本重新找实例；本轮没有扫seed、强塞模板或修改求解器。0.3原M35证据只能继续保留为显式0.3历史覆盖，不能转签0.4。

## 下一步最小验证

在独立0.4工作树由root使用固定4.7引擎、原930001输入真实运行原addon；核实际implementation/algorithm/包及结果身份，重新解析上述模板与拓扑。先验证未删改的完整content、原Definition.is_valid、原封口和出生的真实物理支持，再验同一既有Stage/Runtime中的ellipse、缝连接与退出。若生成结果不同或角色/版本/拓扑不唯一，停止采用本样例坐标。新本地主机/浏览器、设备和完整地图可玩性均未验证。
