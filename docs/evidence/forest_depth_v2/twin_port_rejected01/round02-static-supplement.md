# Twin02 单次因果修：静态边界补审

尚无02实际终态结论，未engine／未改source。01 head133命中、body329撞middle的FAIL保留；不是钩头miss或已证空间不可达。只审build/twin-port-02-patch精确差异。

新prepare从484出发，同一决策当x535.5..544.5、body≤220且上升、已满足原minhold时jump_release→紧接H，不await额外帧；reader要求真实Router batch内jump_release先于grapple，不仅用户意图同tick。它处理01等待下降173后身体撞middle的具体时序，不改Player/range/洞型。不代表新轨迹一定成功。

## touching不等于穿入

原actual_world_overlaps==0会把物理shapequery边界touch也算FAIL。新读者保全部原候选rects的AABB .01穿入拒绝，另记录实际命中的每个CollisionShape2D矩形／world basis／bounds，数量必须和query一致且小于16，unsupported／非axis-aligned／非finite／非positive尺寸拒。对每实际形状也按相同 .01侵入判断。因而允许恰好接触，不能容许1px深入；不等于删掉实际碰撞证据。新native raw仍须复核这些字段与实际body路径，不能仅看已通过布尔。

## ‘另一腔无射线’已被静态反例否定

S(450,342)→Q(930,110)：中干x600处y269.5、x700处221.167，全经上洞；按所有实际solid矩形各膨胀radius3的保守射线路径也无阻挡。跨腔H后打到一弹，不证明原S不能打。

S(450,342)→Q(740,510)：虽中干段y428.897..486.828过下洞，但完整路径先撞自身S central_rib顶角，不当作合法完整射线。S全脚右边缘中心(488,342)→同Q，中干y416.667..483.333，膨胀全部矩形后无阻。它是合法站位的几何强反例，不是已实际发射／命中证明；仍需真实枪口／弹丸启动扫掠、未来目标预测及九点射角。精确数学结果见S-ray-counterexamples.json。

因此强普通左腔等射、站位微调或普通jump/R必须保留，不能靠缩洞／堵射角保H。02若出返PASS，只签两个far-ring身体通行、一弹真实伤害及返回12全脚；新增进攻窗口／整战压力／三阶段价值须另判断，原整区REVISE不随其关闭。
