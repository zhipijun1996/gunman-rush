# WINDCHIME-FIVE-STYLE-01 独立审查

审查者 `/root/independent_review`，非实现作者；只读生产代码，只写独审证据和build临时验证。采用 gameplay-reviewer、art-director、scene-composer；未查看历史美术图作创意输入。基线 `2f25083da11da11604a3535a2feae20d119ac001`；最终实际审查运行源 **`32200d04fe233bda16cf50f678aabee51a9715e5`**，脚本/scene/shader逐文件SHA与该提交吻合。

## 结论与范围

**ACCEPT：技术与静态风格实验交付范围。** 五锚点可运行、同布局真实TileMapLayer拼接、每风格固定0及随机101/307/911、真实Motor往返证据、来源/许可记录与可再生派生接口均具备。新增Underworld/Cavern × 平原/森林/齿轮工城六组能够比较跨地区颜色、构造、景深与光源，不再把Cavern绑定为全游戏紫色。本代理逐张实际打开全部最终45张1280×720原图：36场景（9表现环境×4seed）和9个实际调色profile图集目录；不是只读文件名/Hash/metadata。范围与每图SHA/收据在 [final_viewed_manifest.json](final_viewed_manifest.json)。

**UNVERIFIED：商业品质定稿、用户审美/最终风格、实体设备/小屏/目标性能、完整连续动态与音轨、正式森林/工城玩法、全16区生产。** 静态收口后已完成六组seed0加最弱seed911共7段motion的112采样和12个原尺寸帧补审，见 [motion_addendum.md](motion_addendum.md)；只签采样范围，不追认完整播放/听音。可玩实验ACCEPT不晋级正式战役，不代用户选择，也不签整区商业品质。

**REJECT的仍是两类扩大声明**：47配置等于47张原创独特tile、9profile等于9套新材料图集；以及同prompt可零审图自动产生互换成品。原版三类假交互和相机裁边被拒记录保留，修后指定像素已通过。

## 独立执行与实际消费者

- `python3 tools/build_style_anchor_atlases.py --check`，退出0，见 [atlas_recheck.log](atlas_recheck.log)。五原生源/逐象限配方/输出PNG重建一致。
- `python3 tools/run_style_exploration_tests.py --skip-import --output docs/evidence/style_exploration/independent_review/runtime_recheck`，Godot 4.7.2，退出0，**17215 checks / 0 failures / 20主路往返 / 80上层模块往返**；含删除新增桥后真实160px跳跃失败负例。见 [runtime日志](runtime_recheck/runtime.log)、[报告](runtime_recheck/runtime_report.json)。没有搬角色替代这些路线；端点重置的独立one-way fixture不计入路线证明。
- `python3 tools/run_style_exploration_tests.py --skip-import --biomes-only --output docs/evidence/style_exploration/independent_review/biomes_recheck`，退出0，**1706 checks / 0 failures / 16新增表现消费者、3 CLI**，含实际暂停B键和鼠标选择。它证明regions切换保持cells、TileSet、碰撞、玩家/相机/资源/Motor身份，不虚构新增森林/工城通关；旧实际路线依据未变物理复用。该独立运行早于最终catalog调色小改，最终catalog另按真实GPU和源审查通过；根任务后续冻结harness不是本代理冒称执行的命令。
- 最终45文件SHA、style/biome/seed与原始receipt逐项核对，全部匹配，receipt明确`traversal_claim=false`。9个目录已实看实际palette应用；36场景均看过。另实看6combo×x640/1800共12张、相机限位修复前后4张。只移相机的x1800图玩家仍在实际出生点，不能当路线证据。

真实链路为 `StyleLab → StyleTerrain.build → TileMapLayer.set_cell → TileSetAtlasSource`。永久`.tres`指向本库对应`terrain.png`；实体碰撞由相同cells的Blob47Terrain并集独立创建，one-way用独立StaticBody2D。不是整幅概念图伪装成地形，图片和碰撞无需互相改形凑通过。

## 资产接口与随机覆盖边界

所有style同seed复用80×23格、32世界单位布局，地面、悬崖、实体厚台/拱/凹槽与单向木桥均有实际消费者。三个随机seed只是四种既定20格模块重排，证明该有限组合库的接缝与可达性；不外推任意宽高、薄柱、洞口、无限随机或正式两图。

47atlas配置的不同像素数量：**Retro16、Basic16、Scribble1、Underworld47、Cavern16**。Underworld原生支持凹角；其余连续地形是方形凹角适配，Basic右边来自左侧镜像。Scribble每格完整白砖是积木语法，不是无缝岩土。Cavern从已拼示例裁取边界，短台下齿不是伤害尖刺。9个调色profile不增加拓扑和材料形状，原始紫色源文件保留。

当前景深为一幅大panorama与两组稀疏props剪影视差，并非三张完整独立风景母版；灯为跟随实际bell/源灯锚点的additive Sprite2D glow（每屏最多2个）和少量motes，不冒称Light2D投影。树/草摆动不控制物理。

## 发现、返工与最终像素

| ID | 初版事实与证据 | 最终结论 |
|---|---|---|
| IR-01 | Scribble初屏x335/y596、x913/y563非碰撞白圆与白砖同权，易误读角色/圆台；保留`initial_pixels/` | 最终四seed白圆已移除，改为可辨花草；指定消费者ACCEPT |
| IR-02 | Basic绿团像敌；Cavern竖立暗块像地形却无碰撞 | 最终对应四seed已移除，不以新调色掩盖；ACCEPT |
| IR-03 | camera.position与限位后的真实view center分离。独审先推导算术反例，随后before_300 GPU右端约65px竖条证实 | 改用get_screen_center_position；after_left/middle/right三视野与最终45图无条边；指定像素ACCEPT。端点reset_at是fixture，不计路线 |
| IR-04 | 初版只有每style一张props/背景，无同规格重复生成证据 | 已补每style n=3，见下文；接受有限实验，不接受零审图量产推论 |
| IR-05 | 原catalog可能显示调色前紫源，与活跃region不一致 | 最终源码给TextureRect应用同palette、region变化刷新目录；已实际看9目录：暖灰/冷绿/铁蓝铜分别生效，ACCEPT |

最终随机场景中没有发现需要再次阻断交付的错缝、缺贴图、明显裁边或唯一落点遮挡。最弱视觉样本是 **Underworld forest seed911**（已另补动态抽帧，详见motion addendum）：左上悬台与深色巨树叠加，实体腹体融近背景，浅边仍可追踪；Cavern同seed浅岩边更快读清。它是动态/小屏反例的优先样本，不以静帧签手机可读。

工城无碰撞gantry上梁仍有可站联想；但细棕金铆接框/齿轮/支脚与统一浅边大暗实心terrain已有区分，不能凭AABB或源图将它强判为已证假台。正式关卡需要玩家实际跳向上梁、经过背景桥的动态语义验证。本轮不要求给装饰增加碰撞来救画面。

## 风格与16区发展建议

最终更值得继续的是 **Cavern材质/层次路线 + Underworld暗体/局部光路线**。新暖色Cavern平原及两对比地区GPU改变了初审只看紫色平原时的Underworld+Basic推荐；理由是新画面中的扩展性和落点边界，不是把用户偏好本身当PASS。

Cavern可在明亮平原、冷绿森林、铁蓝铜工城间保留形体边缘和景深，更适合作为下一轮统一世界画法的主候选；安静的近单色腹体本身不是不合格理由，仍须完成材料内角/薄结构和大轮廓设计。Underworld以暗体衬局部暖铃最有气氛，接口原生完整，但森林深色环境下读图余量更小，需严格控制背树明度与安全边。

其他锚点仍有比较价值：Retro独特的线框与低信息密度明确，但新云/树连续轮廓明显比原生繁密；Basic明快易读，新增景物比原生小包更丰富，容易走向通用卡通；Scribble纸绘气氛清楚，但白砖没有承接连续自然材料。它们不是因用户偏好而被判技术失败。

六组的地区差别**已经超出纯换色**：平原横向空气与缓坡，森林巨干/冠层围合/根洞，工城高塔/硬桁架/人工光。两style的新增森林、工城景物却趋同，差异主要仍在地形暗剪影与浅岩边。不能把6环境宣传成6种画法，也不能据此证明Underworld复杂资产更省工。

共享应为像素密度/线粗或色阶、受光方向、交互/危险功能色、景层对比规则和拓扑接口。16地区至少同时改变主体材料、轮廓、空间/光源、主题构件；不能复制本轮树/风车/钟塔再换16套palette。现有shader只调源明度，不会产生森林树皮/枝台、工城金属板/铆边、冰面透明/玄武岩裂边等新拼接语义。

下一阶段：选1～2套原创黄金 → 固定实际像素/色阶与角色母版 → 一套主材料完整四边/凸凹角/填充/薄台 → 先做树皮或金属这种强反差第二材料 → 三seed、孔洞、一格柱、岛底与双向路线真实GPU/动态准入 → 再逐材料扩区。保留每次原图、工具/提示/参考SHA、失败与修补耗时；AI提供画法与景观候选，边界拓扑和碰撞由确定性管线约束。

## AI重复与许可

实际看过5张n=3 contact、Cavern replicate2/3原件、5组新region的10张props/background原件；源SHA与记录吻合。15/15有四个alpha分隔主体，**0/15符合严格四等分槽位**；Underworld #2 hood变绿、Retro线粗/人物头身、Basic色阶、Scribble纸白块/笔触、Cavern材质密度/扇叶形/人物比例均漂移。独立审查在三张Cavern都数到4片风车叶，未复述为数量失败。结论是可生成同家族候选，需要提取和审图；不是可互换成品/动画帧/原生47 AI生成稳定。详见 [ai_repeatability.md](ai_repeatability.md) 与 [源独立重查](generated_source_recheck.json)。

Retro/Scribble/Cavern有原包CC0条文；Basic包内LICENSE为0字节，CC0/可商用依据是保留的作者页面，不伪造包条款。Underworld只有作者自定义宽泛使用语句，无标准独立LICENSE，不能标CC0；正式商业资产宜取明确可改编/分发条款，或原创同语言家族。本报告是证据核对，不冒充法律意见或最终商用资产审核。

## 尚未观看或未验证

7片motion只做明确抽帧补审，没有完整正常速度播放、没有听完整音轨；没有实体设备操作或玩家反馈；没有验证正式战役全部敌人/机关/状态，也没有开放其余地区。完整商业美术/手感/用户认可仍需这些范围自己的证据。后续发布与浏览器验证由根任务提供，不在本代理已执行事实中。

交付工具另有只读工程抽审：[delivery_review.md](delivery_review.md)。它不替代最终公开浏览器或完整发布验收。
