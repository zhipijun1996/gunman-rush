# B 方向：两个最小制作范例

先读 [style_master](../../../resources/visual_development/style_master.json)，并实际看 [B1 母版](../../../assets/visual_development/master/b1_master.png) 与 [B 方向板](../../../assets/visual_development/proposals/b_board.png)。以后只按任务补读对应 record；不需要全部 PR 历史。母版四格是教学示意，不能列作真实编辑步骤。以下为真实素材生产经过，均尚未获得正式整屏艺术准入。

## 1. 大明暗体块 → 真正的材质编辑

第一次调用产出 [value_block.png](../../../assets/visual_development/props/value_block.png)，保留[原始 prompt](../../../assets/visual_development/props/props_block_prompt.txt)：先确定低重心、不对称大体积、开口及三档明暗，要求透明 3×2 六格。第二次调用以该原图为输入，依 B1 母版执行[材质编辑 prompt](../../../assets/visual_development/props/props_final_prompt.txt)，得到 [material_pass.png](../../../assets/visual_development/props/material_pass.png)。这两张是实际先后产物，不是把最终图拼成“过程”。工具未暴露的模型与两次精确时钟仍未知。原图 SHA 与可定位的源文件见[来源索引](../../../assets/visual_development/provenance_index.json)。

实证失败也要传递：两次 atlas 都未满足严格等格与净空，不能按固定格线直接切图。[family.json](../../../assets/visual_development/props/family.json) 标记了失败与实际区域。不能因为材质漂亮就把打包、alpha、轮廓、游戏尺寸可读性当作已通过。

## 2. 格线失败 → 有界单物件生成

停止第三次赌多物格线。保留失败源，以 B1 母版和 material_pass 为参考，分别真实生成 [tree](../../../assets/visual_development/props/tree.png) 与 [shelter](../../../assets/visual_development/props/shelter.png)，不是程序裁切或滤镜重绘。具体[树 prompt](../../../assets/visual_development/props/tree_prompt.txt)、[棚 prompt](../../../assets/visual_development/props/shelter_prompt.txt) 及相邻 record 保留参考、原图与 SHA。

测量使用原图实际区域：tree 1254×1254，脚底 pivot (627,1183)；shelter 1455×1081，pivot (727.5,942)。这是摆放依据，不是游戏内比例和碰撞已验证。下一步只在真实镜头、实际角色尺寸、前后景遮挡与原生动态中检查；不通过就返工或隔离，不以“已有消费者”强制保留。

同样规则用于角色：读自己的 atlas 元数据，保留姿态高度差与脚底，不逐格拉伸成等高；Hero 跑步与 RootBell alpha 仍有记录中的缺陷。环境连接图未形成合格等格，所谓 underside 实际仍像草顶边，不能旋转改名假称成功。不要把候选贴图、静态动作格或迁移概念图签成原生动画/整区完成。
