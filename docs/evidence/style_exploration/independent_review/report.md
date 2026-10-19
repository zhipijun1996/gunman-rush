# WINDCHIME-FIVE-STYLE-01 独立审查（复审等待中）

审查者：独立代理 `/root/independent_review`；非实现作者，只读生产代码。基线 `2f25083da11da11604a3535a2feae20d119ac001`，工作树候选；使用 gameplay-reviewer、art-director、scene-composer。未查看历史美术图作为创意输入。本文当前仅记录初审和已实际执行的独立技术复验，原五风格最终图、Underworld/Cavern × 平原/森林/齿轮工城六组及动态样本尚待复审。用户新增要求不同区域采用不同色系；原紫色Cavern仅作源锚点基线。

## 目前范围结论

- **ACCEPT（技术范围）**：本代理独立执行 `python3 tools/build_style_anchor_atlases.py --check` 退出0；独立执行 `python3 tools/run_style_exploration_tests.py --skip-import --output docs/evidence/style_exploration/independent_review/runtime_recheck` 退出0，Godot 4.7.2，17215 checks / 0 failures / 20主路往返 / 80上层模块往返；含删除新增桥后实际160px跳跃失败的负例。此结论只签真实消费者的这四个布局、这些策略和分离碰撞语义。
- **REJECT（初版语义）**：初屏Basic非碰撞绿团像敌、Scribble非碰撞白圆像角色/可站圆台、Cavern非碰撞直立暗块像地形；开发者已报告修复，须等待新屏证实。初屏保存在 `initial_pixels/`，不追改历史结论。
- **UNVERIFIED**：最终修复画面、连续动态、商业美术定稿、实体设备、用户审美；AI系列稳定性初版仅每style一张props+一张background，重复同规格实验正在补采。16区只有生产设计矩阵，其他15区未实现。

新增独立运行：`python3 tools/run_style_exploration_tests.py --skip-import --biomes-only --output docs/evidence/style_exploration/independent_review/biomes_recheck`，1706 checks / 0 failures / 16新增表现消费者、3个CLI，退出0。此检查只证明region切换与原cells/TileSet/碰撞/Motor身份一致，不能证明相应地区图像已完成。`style_palette.gd` / `region_material.gdshader`为源明度映射，明确不是新绘制森林或工城材质图集。

## 初审已实际看过的图像

五张完整1280×720 `build/{retro,basic,scribble,underworld,cavern}_scenery_final_review.png`（保存副本和SHA见 `initial_viewed_pixels.json`）；五张原生terrain源 `source/{Environment.png,sTileset.png,spritesheet_default.png,TileSet.png,tiles.png}`；五张 `generated/source_props.png`。看过源码、许可原文及生成提示记录，不以metadata代替这些像素观察。补看 `scenery_validation/basic_camera_limit_before_300.png` 与 `basic_follow_after_left/middle/right.png`，并读对应fixture脚本。尚未观看最终录像、没有听完整音轨，也没有实体设备操作。

## 证实的实现边界

`StyleLab → StyleTerrain.build → TileMapLayer.set_cell` 使用实际TileSetAtlasSource，永久 `.tres` 指向对应 `res://assets/style_exploration/<style>/terrain.png`。所有style复用32世界单位网格、合并cells及Blob47Rules；实体碰撞由同一cells的Blob47Terrain并集单独生成，one-way通过独立StaticBody2D；不是整幅概念图伪装可玩地形。风格切换保留位置/相机/碰撞实例并清输入。

47个atlas配置不等于47张不同图。独立检查与源配方一致：Retro16、Basic16、Scribble1、Underworld47、Cavern16个不同像素tile。Underworld有原生凹角支持；Retro/Basic/Cavern使用方形凹角，Basic缺失右边由左边镜像补接口；Scribble是每格完整白砖积木语法，不能称连续无缝岩土。Cavern来自已拼示例，短平台下缘齿尖只负责外形，不是伤害判定。

三个随机seed为101/307/911；实际变化是四种既定20格模块重排，保持共同端口和底路。它证明该有限组合库的稳定性，不证明任意宽高/薄柱/任意洞口或更大随机区域都已通过。黄金布局seed0和三随机布局在五style间相同。

## 初版发现与待复验

| ID | 事实/候选与定位 | 严重度、职责、范围 | 状态 |
|---|---|---|---|
| IR-01 | Scribble初屏x335/y596、x913/y563的白圆使用与白砖同权的白填黑边；源码显示来自无碰撞小物；产生可站/角色误读候选 | 影响跳跃读图；scene-composer；本轮五风格消费者 | 初版REJECT；作者已修，待新像素 |
| IR-02 | Basic小绿团为装饰，但原生源语义和外形像史莱姆；Cavern x336/y598等直立块与地形同色却无碰撞 | 影响交互读图；scene-composer；初版对应style | 初版REJECT；作者已修，待新像素 |
| IR-03 | 初审源码用camera.position计算视差；后续before_300 GPU右端约65px底色竖条，反例成立。改为get_screen_center_position后after_left/middle/right三帧均无条 | 原缺陷已GPU证实；scene-composer；端点reset_at fixture不是通关 | 指定3视野修复ACCEPT；连续动态仍待验 |
| IR-04 | 初版每style仅1张props和1张background，无同规格重复生成/跨区对照 | 不能称AI稳定性已测；art-director | 正在补n=3同提示重复；跨区仍未验 |

## 16区可持续性判断（初屏专业意见，非用户认可）

最值得继续的两个互补候选是 **Underworld** 与 **Basic**。Underworld以暗体/苔缘承接实体与树，少量暖铃易形成焦点；须用明亮平原、湿润菌沼、硬质工城反证，避免16区皆黑洞。Basic最清楚地保留开放明亮童话身份，地形明度层级稳定，但新图生树/人物的色阶和细节显著多于原生16px小包，宽土内部也偏单调；下一步必须先锁统一像素/色阶与原创材料边界，避免通用素材包气质。

Retro识别性强，但目前高细节云/树的连续轮廓明显多于原生稀疏线框语法，地形绿线与金青景层关联不足。Scribble有纸绘故事感，但白砖与彩色大树/天空之间缺一套连续地表材料，尚不能靠这一张白砖扩成16区。Cavern具材料体积和纹理上限，生成树/地形色系接近，却容易把地域差异化简为紫灰换色，短台岩齿也应在安全落点处谨慎使用。

共享应为像素密度、线条/色阶、受光、功能色、景层对比规则及拓扑接口。地区差异至少共同改变主体材料、可读轮廓、空间结构/光源和主题物件，不能共用本轮同一树/风车/钟塔加16套palette。本轮景层为一幅大panorama加复用props的两个稀疏视差深度，实际是可复用技术起点，不能称三幅独立风景内容已完整生产。

四个原包许可有CC0证据。Basic包内LICENSE为0字节，但作者页面明确CC0/可商用，应按该证据归档；Underworld是作者自定义宽泛使用语句，没有独立标准LICENSE，不可标CC0。它适合本轮实验比较；正式商业生产宜使用原创同语言家族，或取得明确可改编和分发的条款。

建议下一阶段只晋级1～2套原创黄金：先做一套完整边界/薄台/内角和不同大轮廓；再以森林树皮或工城金属做强反差第二地区小样，进行相同输入重复图生和修补成本记录；三seed及端头/孔洞/一格柱/岛底真实GPU通过后再逐家族扩区。全16区量产、用户最终美术和设备均不在本报告技术ACCEPT范围。
