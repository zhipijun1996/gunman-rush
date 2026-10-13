# 本轮 AI 素材来源与候选状态

工具为 image_gen.imagegen，模型标识未向调用者公开；不伪造许可证已核实或用户画风认可。所有 PNG 原始字节直接复制，无脚本图像修改。Godot区域采样和绘制属于游戏接入，不能据此宣称图像已无缝验收。

- modular_terrain：参考 assets/plains_v6/cohesion_atlas.png，提示生成童话手绘苔木单向平台、根系石灰岩实体平台，两行分别左端/直中/右端，透明背景。返工提示为移除全部背景、保留六物体及位置。原始输出 exec-b2bf02f4-02f3-4873-89ad-5f1f23af2843，返工 exec-80a4e7ea-7dc8-424f-b5f8-b65e82a702d2。透明像素必须实际分析 alpha，预览背景颜色本身不是不透明证据。
- terrain_borders_candidate：以 modular_terrain 参考生成 4×4八方向边界、四内角、内部填充及变体，要求固定连接高度、像素密度、边界轮廓、草只朝上、透明外部。首稿 exec-b8a23d47-6076-46a8-94c7-01c67327d525 存在黑色分隔线和非严格格网，退回；用 imagegen 编辑“仅移除所有黑分隔线，补连续材质，保持位置和外轮廓”，输出 exec-4cd36c5f-411f-4d47-8ab1-8a6c46be66f7。按实际分区记录归一化采样，不假称生成器遵守256方格。镜像中段使连接条共享采样；边角连接的视觉质量仍需合屏审查，纹理技术连续不等于自然。
- enemies/guard_moth：新创作 1536×1024、6列2行透明母版；第一行右向苔石护盾甲虫的待机/举盾预警/前突/疲劳/受伤/蜷伏，第二行柳籽蛾的翼上/翼下/预警/射籽/恢复/坠落。软水粉童话材质、苔绿/琥珀/乳白、左上暖光、每姿势身份一致。输出 exec-806ed7ee-8772-45d6-85c6-068ccb5efdb8。运行时用短过渡拼接真实行为；不声称六静态姿势本身已证明动画完整自然。

每件素材的 SHA、消费者与未验状态见 asset_records/；实际截图和正常速度录像才用于 G2审查。

## 2026-10-13 material master / candidate-v2

Previous modular caps and boundary atlas were REJECTED by the user and independent review; their formal renderers were withdrawn. They remain source evidence, not approved reusable art.

Tool: image_gen.imagegen; model not exposed. Source output: exec-e95d876e-5ad5-4690-9bc5-9de5f9de8607.png. Copied unchanged to assets/plains_v7/meadow_tile_material.png. Prompt: 1536×1024 opaque edge-to-edge orthographic cutaway meadow material; top 80px continuous sage/olive grass aligned to top edge, next 60px dark root transition, remaining calm warm desaturated umber soil, broad soft limestone and few roots. No background, endcaps, ornamental braids or grid. Horizontal continuity for all bands, vertical continuity for earth. Refined gouache, muted, no neon grass.

This generates a shared material source, not 47 independent finished tiles. The actual Godot composer resolves 47 neighbourhood masks, applies directional boundaries and samples common coordinates for 1×1/1×2/2×1/2×2 blocks. Numerical topology and GPU partition tests cannot approve the aesthetic. Candidate palette, surface edge treatment and formal integration remain under review.
