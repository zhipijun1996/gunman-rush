# 风铃平原精绘背景 v2

三件原始 AI PNG 已生成并视觉检查，作为固定黄金样板分层候选。不是 SVG，不覆盖旧运行资产，不改变物理或布局。世界锚点为 docs/world_and_story.md，品质锚点为 docs/art_quality_target.md。

| 文件 | 内容 | 尺寸 | 建议视差 x/y |
| --- | --- | --- | --- |
| sky.png | 完全不透明、蓝天与暖白体积云 | 1672×941 | 0.02/0.02 |
| hills.png | 透明远山、蓝灰大气透视 | 1672×941 | 0.10/0.04 |
| meadow.png | 透明草甸、远景风车、维修小屋与遗迹 | 1672×941 | 0.22/0.08 |

按天空→远山→草甸排序，以完整画布相同中心锚点和等比缩放组合。视差只是接入起点，实际相机边界必须另行验证。不要把背景轮廓生成碰撞体，不使用小屋或风车作为玩法对象。

## 实测透明度

hills alpha≥128 的内容边界为 (0,589,1672,941)，meadow 为 (0,545,1672,941)。两件的上半部 alpha 最大值为 1，存在极低透明度零散残留；绝大多数上部为空。可见主体 alpha 大约250–253，透明轮廓预览能见少量青色细边，需深浅背景及目标手机合屏验收。未宣称透明边缘最终通过。所有原图完整保留、原样复制，没有额外后处理。

## 随机地图限制

当前不是无缝循环纹理；横向左右轮廓及云量不同，不直接 repeat。使用同一世界级背景锚点，禁止每个玩法模块重新起一套地平线。长距离与高落差覆盖仍需世界相机规则、同母版背景扩展或另行生成循环版本。不要垂直重复草甸或地平线。任何随机变化不得影响玩法随机流或实时重抽地图。

## 生成来源与提示记录

工具：image_gen.imagegen，2026-10-10；三次都引用同一合屏母版 `exec-b229b4a0-ec16-4180-905b-14954d71d657.png`。源文件、哈希、尺寸与透明实测见 manifest.json。没有命名主角身份、新增区域机制或最终剧情。

天空：actual 16:9 sky game texture; refined original handpainted watercolor/gouache fairy tale Windchime Plains; luminous blue late spring sky, warm ivory sculptural cumulus, atmospheric painterly details; sky and clouds only; opaque blue every pixel; large cumulus lower third, delicate wisps above, spacious blue middle-upper; soft warm upper-left sunlight; no earth/mountains/trees/architecture/character/UI/text/platforms/mechanics; polished painterly, not photorealistic or flat vector; transparent_background=false.

远山：actual transparent isolated distant mountain/hill parallax layer; wide 16:9; top two thirds empty alpha; bottom third continuous pale blue-grey rolling hills and rounded mountain peaks, slate/lavender ridges, muted green suggestions; tallest peak below bottom 40%; extends left/right/bottom; gentle warm upper-left light; no sky/clouds/white background/opaque rectangular backdrop/foreground rocks/cliffs/platforms/trees/buildings/character/UI/text/symbols; low-contrast distant atmosphere; transparent_background=true.

草甸：actual transparent isolated mid-distance meadow strip; wide 16:9; top two thirds empty alpha; bottom gentle rolling pale sage/olive meadows, meadow tree clusters, warm golden light, blue-grey shadows; one tiny old windmill left-center, timber maintenance cottage right, sparse worn stone remnants; tiny eave windchime and no readable text; far landmarks never playable-looking; no cliff/flat ledges/foreground/black outline/sky/clouds/white or opaque backdrop/character/UI/gameplay props/text; upper-left light; transparent_background=true.

这三段为提示内容记录；原始模型调用没有返回 seed 或模型版本，无法声明确定性再生成。状态：visual_review / device_pending；合屏精美程度由用户验收。

## 透明轮廓追加精修

2026-10-10 第二轮使用 image_gen 编辑，禁止脚本改图。原始山/草甸和第一轮编辑保存于 candidates/。草甸二次编辑明显减少了原始电青色轮廓，因此替换 meadow.png；源文件为 exec-eca04173-704f-4788-8925-4b990f57917a.png。编辑提示要求以相邻灰蓝/橄榄色重绘约5像素轮廓、清除电蓝青边、保留构图材质和真实透明。仍有极细浅色轮廓及个别蓝色残留，没有宣称边缘最终通过。

山体两次编辑仍产生较明显电蓝边，判断没有可靠改善，未替换 hills.png；失败候选为 candidates/hills_edge_edit_1.png 与 hills_edge_edit_2.png，原图为 hills_initial.png。需要进一步 AI 精修或明确授权的透明边处理策略，当前保持 visual_review。草甸的新透明边界实测以 manifest.json 为准。
