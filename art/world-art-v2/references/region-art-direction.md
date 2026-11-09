# 16区域美术计划与来源边界

正式身份来自 7d73389feab22224d0f8bd7c09325420a7605980 的 `docs/bible/world_regions.json`。只有平原、森林有选中区域Bible；其余14区 `current_bible:null`。用户认可的上一轮5区试片（平原、森林、蕈灯地穴、齿轮工城、熔火腹地）保留既有像素源，其余11区具体材质、候选色板、构件、光线和层次为本轮扩展。新素材和正式游戏内容不能继承旧样片验收。

原生32px/32wu、1源像素/世界单位、nearest。细节集中于表面和连接处，暗体积保持安静。平台附着前景与平台同速；独立前景稀疏放在屏边。9-slice试片和正式47邻接图集分别标记。亮尘有可见亮核与短尾，灯光须影响附近材质。完整层次和复用规范见 `region-plan.json`。

## 16区材料与主光

| Code | ID / 地区 | 材料 | 主形 | 光线 |
| --- | --- | --- | --- | --- |
| P | `windchime_plains` 风铃平原 | 草顶石灰岩；细窄橄榄金草沿、灰蓝岩芯、局部风化旧桥石。 | 低而宽的层状断岩与不对称旧石拱；歪斜铜铃提供单一记忆点，保留开阔天空。 | 左上暖天光，冷灰天幕作填光；局部铜铃只反光，不整件自发光。 |
| F | `thorn_forest` 荆棘森林 | 厚实苔根地基、层叠树皮、浅芯断枝和暗土；苔沿窄而破碎。 | 粗壮根盘和空心树腹；大根拱带一处钩形末端，分叉大枝交代内外回路。 | 林冠开口的冷灰斜光，少量种荚/铜灯暖光；透叶淡金限定在焦点，避免统一荧绿泛光。 |
| M | `mushroom_caverns` 蕈灯地穴 | 紫灰湿岩、薄菌毯、细菌丝与暗梅色岩芯；大蘑菇使用柔曲面像素块。 | 低顶不对称双菌盖与宽窄交替洞穴；菌褶形成向下扇形节奏。 | 青绿菌褶局部生物光，低紫灰环境；亮度照入邻近台面与菌柄，远景自发光受限。 |
| S | `firefly_marsh` 萤雾沼泽 | 深橄榄泥炭、潮湿黏土断面、缠根泥岸与腐朽窄木栈道；少量旧排液陶管。 | 矮平泥岸、倾斜苇秆与低垂柳枝；一座半没水中的旧闸框形成偏低的横向地标。 | 阴天冷青灰填光，低位萤黄绿小光团与孤立旧灯；水面反光只出现在实际可见水面。 |
| Y | `windswept_canyon` 风蚀峡谷 | 横向风蚀砂岩、夹层暗赭岩芯、薄浅黄沉积边；锈蚀输送管和断测量柱作少量人工材。 | 宽窄不均的横层崖壁、偏斜石桥和竖向被蚀柱；长负空间强化风的通道。 | 暖色低角度侧上光、紫灰侧壁阴影；迎风棱边有细断光，背风洞口保持冷暗。 |
| I | `frostmirror_glacier` 霜镜冰川 | 蓝灰冷基岩、乳白层冰、深蓝裂隙；透明感用少量清楚色块与断反光表达。 | 竖向裂冰镜面与倾斜冻住的细构件；水平薄冰台面和向下冰挂形成方向差。 | 冷色漫射天光为主，极少量不流动的暖灯对照；冰亮边沿实际入光面，勿每条裂纹自发光。 |
| C | `moonshadow_cemetery` 月影墓园 | 风化骨灰石灰岩墓台、深灰旧砌石、少量锻铁与薄地衣；色块偏干燥粉质。 | 低而不齐的墓碑群、细长柏影与一处破损圆月门；整体视线低，保留安静留白。 | 偏冷月光擦石，少数暖祭烛照亮邻近碑基；整体不靠发光墓碑。 |
| K | `moon_crown_castle` 月冠古堡 | 规整暗石砌块、蓝黑页岩顶、少量磨旧铜件与酒红破帷幕；窄磨损边。 | 厚重竖向扶壁与细长尖拱；窗格和破帷幕制造一处明确偏置焦点。 | 高窗斜入的冷月光与局部暖烛灯；墙内暖区和窗下冷区有清楚空间边界，避免全室蓝滤镜。 |
| G | `gear_city` 齿轮工城 | 木炭色砌砖、铆接深铁、磨损薄钢沿、管道槽口；反光面稀疏。 | 竖向工业廊架、偏置破齿轮门与悬链；砖墙有重复尺度，机械有承重结构。 | 琥珀炉火/油灯局部照亮铁边，冷窗光界定上层结构；阴影压住砖芯。 |
| N | `echo_mines` 回声矿井 | 干燥深灰层矿岩、少量暗金矿脉、粗木支护与窄铁轨；岩石为主体，金属为工事。 | 向深处收束的斜木架与竖井卷扬架；绳索、断轨和局部矿脉形成方向线。 | 煤油暖灯塑造木梁与岩边，冷竖井漏光给深度；矿石只微弱反光，主体不整块自发光。 |
| E | `ember_depths` 熔火腹地 | 冷却玄武岩柱、角形破层、深靛黑岩壳；只有裂缝下缘暴露少量熔流。 | 大块不均玄武岩肋拱与低位熔沟；轮廓硬、断口多但内体量安静。 | 低处橙红裂隙上照，冷灰天空/洞腔填光保护可站台面；热光不染平所有暗体。 |
| T | `root_sanctuary` 根脉圣殿 | 多孔浅石雕、青灰旧地砖和大根脉；木质根纤维温润，石刻保持平静大块面。 | 被根脉抱住的厚石柱与偏置祭厅拱；根与建筑互相承托，中央留高而安静的空间。 | 顶部根隙暖天光形成一处主焦点，青灰环境填光；局部石龛微暖反光，避免全根脉发绿。 |
| R | `sunken_ruins` 沉水遗迹 | 被水磨钝的旧石砖、薄贝壳钙化边、深蓝湿岩芯与青灰水藻；水位痕迹连续。 | 被水切断的水渠拱与半没入水中的台阶；横向水线和斜断柱形成区域特征。 | 上方/侧口青蓝反射光，局部气室暖灯；水波反光低幅度且不覆盖所有表面。 |
| A | `shattered_isles` 破碎浮岛 | 浅色断裂岩、薄浮土草皮、悬根和少量脱落旧桥金属；岛底层次必须可见。 | 不对称悬石桥与楔形岛底；岛间大面积透天空负空间，局部结构向上断开。 | 大天空冷填光+暖日侧上边，岛下也有少量天幕反照；不把岛底压成纯黑墙。 |
| V | `starbridge_gate` 星桥天门 | 深蓝玻化石、薄星银嵌线与少量暗紫晶面；大多数表面哑光，亮纹稀少。 | 瘦长桥门、偏置断弧和狭窄桥脊；尺度宏大但组件细长，节点有明确承接关系。 | 低饱和靛蓝环境和少量冰白星光，银嵌线为微光焦点；局部暖遗物作为对照。 |
| Z | `world_clockheart` 世界钟心 | 深暗精砌基石、磨旧黄铜大件、陶白绝缘件与少量蓝钢轴；材质交接准确。 | 偏置巨钟轴、被损坏的同心环架和承重肋；主体轴线清楚，以不对称损伤避免徽章式整屏贴图。 | 一个主要琥珀核心光照亮近轴材质，冷蓝填光分开外圈；能量脉冲影响局部而非闪烁全屏。 |

## 区域区分

- 平原 / 浮岛：平原连续地貌；浮岛浅岩楔底、广阔透空与上拔断口。
- 森林 / 圣殿：森林暗土树皮迷宫；圣殿浅石柱拱、根石互托、暖光井。
- 沼泽 / 遗迹：沼泽泥苇低闸；遗迹石构、水位、半沉拱渠。
- 墓园 / 古堡：墓园低矮粉质石与留白；古堡垂直厚砌石、窗月光/烛灯分区、破帷幕。
- 矿井 / 工城：矿井裸岩木支护；工城砖铁工业建筑。
- 天门 / 钟心：天门玻化石、细银线、瘦长断弧与空域；钟心巨大主轴、黄铜/陶白机构、核心集中光。

## 来源与未覆盖范围

- [docs/bible/world_regions.json](https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/bible/world_regions.json)：16区名称、稳定ID、Code、旧key与剧情锚点。
- [docs/bible/regions.md](https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/bible/regions.md)：区域身份映射、逆时钟塔退出、回声矿井为新身份。
- [docs/bible/visual_bible.md](https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/bible/visual_bible.md)：正式细粒度像素、材质、光照、边界、可读性与第二空间复用要求。
- [docs/data/creative_direction/bibles/registry.json](https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/data/creative_direction/bibles/registry.json)：当前区域Bible状态与共享风格入口。
- [docs/data/creative_direction/bibles/style-continuity-20261102-v34-death-runtime.json](https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/data/creative_direction/bibles/style-continuity-20261102-v34-death-runtime.json)：仅提取 shared_dimensions/source/validation；不把历史运行绑定当新素材视觉认可。
- [docs/bible/regions/windchime_plains.md](https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/bible/regions/windchime_plains.md)：平原已定材料、空间、层次与动态方向。
- [docs/bible/regions/thorn_forest.md](https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/bible/regions/thorn_forest.md)：森林已定材料、形体、色域、层次与危险语言。
- [docs/data/story/regions.md](https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/data/story/regions.md)：已改为叙事制作入口；没有16区材料/色板表。
- [docs/data/world/README.md](https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/data/world/README.md)：固定世界来源与按房读取原则；世界地图坐标不能等比当碰撞坐标。

大世界JSON未加载；样例构图不改正式房间连接/碰撞。`references/repository-authority.json` 保留来源摘录，`references/repository-world-regions.json` 保留身份源索引。`region-plan.json` 的时间可视化为局部叙事建议，不是新增全局机关。

