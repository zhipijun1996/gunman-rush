# 完整随机区域：实际入口与已证伪方法

任务 PLAINS-REGIONAL-01，基线 PR85 `148d9251`。先看[实际独审](independent-native-02.md)，不默认加载此前所有PR。P1是用户偏好，尚非最终风格批准；本轮两个方法艺术均失败，不扩正式池。

正式调用链是 `DemoApp → PlainsRegionStage → PlainsRegionGenerator → PlainsExplorationTopology/PlainsRouteRecipes → PlainsRegionAssembler`。PR85场所链仍可复现局部实验，不能代表完整区域。新入口只在显式 `plains_regional_art_candidate_requested` 生效。

- `plains_region_art_plan.gd`调用真正整区生成、校验及组装，保留探索图、分支、环路、奖励、商店、敌人、双深层挑战与Boss入口。`regional_art_profile=continuous_plains_v1`在世界嵌入前分配额外路线空间；最多4个候选，无未验证回退。
- 同一Manifest派生实际碰撞支撑、联合轮廓、站面、机关/路线保护空腔、局部语义、全局景层与有根附件；`plains_regional_composer.gd`消费计划，不自写布局或碰撞。X绘画相位属于世界空间，不按场所重置；Y仍依赖各渲染体筛选的顶面及局部回退，跨体连续性未成立，不能用元数据标签证明。
- 第二方法将实际岩体向区域底部延伸，再二维扣除完整下层空间、机关与回程；原跳跃缺口/竖井一直保留到原实心接收面或区域底部。真实碰撞由原ground_supports消费者安装，原模块平台不改。默认无profile的6个完整Manifest与原PR85逐字节相同。

```sh
python3 tools/harness.py --profile regional-art-feedback
bash tools/godot.sh --path . --script res://tools/plains_regional_art_preview.gd -- --seed=regional-art-01
python3 tools/visual_director.py capture --seed regional-art-01 --strategy deep --encounter-policy kill_from_bank_v2 --capture-script tools/plains_regional_art_capture.gd --max-ticks 36000 --timeout 3600 --frame-stride 600 --output build/plains_regional_art/NEW_CAPTURE
```

手动入口使用原控制，可选择角色，不写Meta；电影是实际Motor与输入路由自动驾驶，不是真人试玩。`plains_regional_art_overview.gd`另存正常相机和明确标注的缩放全图；演员不搬移。`plains_regional_art_map.py RECEIPT OUTPUT.svg`绘制真实计划地貌、拓扑、景层与附件诊断，不能冒充实机美术。

预登记Seed为`regional-art-01`至`06`。精确无标签图同构比较排除名称/坐标/机关相位/模块名，实际有5种连通类；01/02非同构。真实路线按所有普通区域的落地访问核对，Boss前庭到达不等于Boss战或全边遍历。

**已证伪的生产假设**：第一种碰撞矩形合并＋统一绘画仍是悬空货架；第二种深岩体减空腔改善实体与背景，却把同一行列布局挤成规则立柱和矩形井。世界UV不能替代形体设计，核心纹理镜像会重复。停止局部圆角/纹理周期/装饰修补。下一项不同实验应先联合求解可行地貌场与探索路线，再嵌入挑战；图的探索关系可以复用，原行列坐标不应被冻结为艺术权威。该方法尚未实现，不能由本轮技术通过推导成功。

短任务`python3 tools/level_design.py route --request '制作风铃平原美术' --output build/NEXT.json`现在绑定完整区域候选、实际失败和相应检查；明确“局部/场所”的任务仍走原局部入口。route只生成现有production_loop任务，不会自行执行，也不授予改碰撞的额外权限。当前没有成熟自动艺术生产能力。

当前运行冻结`46c3c0993b2ea69293f60161a1c2a95cc6677942`，计划`plains-regional-art-v2`。修复原v1漏接的完整棚屋脚距守门：实际源图尺度推导可行区间，安装后以真实节点和真实SOLID碰撞复核。52项实际节点变异反例与193项六Seed合同通过；修复前后完整Seed02 Manifest逐字节相等。此为工程回归修复，不是第三种艺术方案。旧首片e450保留艺术失败及缺失此守门的边界；中止的5cb第二片原件不能作为完整录像。
