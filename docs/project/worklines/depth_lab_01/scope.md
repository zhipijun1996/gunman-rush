# 房间美术复用实验

本轮执行用户“进行更多实验”：冻结方法，实际检验同批素材在不同几何中的复用、镜头覆盖与共享调整。保持纯2D。结论是技术局部成立，美术未通过，不能据此扩展正式房间或认定新Skill优于旧版。

分支codex/depth-lab；实验基线6094322d1d4bad3d732de71325bf66859ab7e744。前次方法整理35339eb及15300cc、本轮之前的验收说明6094322继续保留，未回滚或继续扩大。地形与实例能力仍依赖开放的PR156（codex/terrain-material-system→main）；本分支能力不等于main／公开游戏已接入。本轮没有合并、游戏发布或Site重试。

## 冻结与写集

AGENTS.md、全部已跟踪仓库Skill和docs/bible共81个文件，实验前记录SHA256，结束逐项核对未变；清单与结果在build/kit-reuse/freeze.json、evidence.json。云端Skill未修改，也未把新实验写成历史认可基准。

新写集仅有assets/kit_reuse的生成源／原生构件／来源清单，config/art/kit_reuse.json，game/presentation/experiments/kit_reuse隔离场景，以及烘焙、捕获和汇总工具；项目管理只更新本交接与任务表本行。正式入口、房间JSON、机关／表现目录、地形母版、角色控制和存档均未修改。

实验JSON是隔离渲染器参数，不是新的正式房间schema。三种几何是压力夹具，不是三个已迁移正式房间，也未验证编辑器配置成本。后续正式接入仍须沿现有WorldRoomDocument、WorldElementCatalog和WorldRoomAssembly。

## 实际进行了什么

| 实验 | 输入与方法 | 观察和判断 |
| --- | --- | --- |
| 固定组画反例 | 加载前次engine_first_2d，关闭水与灯作一致对照；将背景分区单独平移96px，再另测相机平移240／120px | 出现拱洞空缺、重复轮廓和画幅边界。前次互补遮罩只保证原坐标受光分区；不能独立景深或跨机位使用 |
| 完整独立构件 | 先由Godot导出640×640拱廊轮廓，再用该轮廓与前次painting作真实参考，仅生成一次透明完整拱廊；机械裁边、nearest烘焙、硬alpha，另派生半尺寸与直柱中段 | 构件与完整远景底图彼此独立，未从同一整景抠出缺失后方的假背景。但生成未严格遵守轮廓：原生柱约90px而非64px，洞宽约454px而非512px。精确几何生成判失败，仅作背景构件，不改碰撞迁就图片 |
| 三种几何复用 | 横向断渠通道、竖向水闸井、宽阔桥厅，同一路径、同批哈希；真实TerrainComposer、两种既有地形材质、正式44wu角色资源与既有风铃表现；各96帧／12fps镜头巡查 | 只新增一幅源画，派生三张纹理；没有每房新整景、专属补画或遮罩。可引用不等于合屏通过：竖井重复堆叠、竖向接头、宽厅细节重复、平台端头缺少同族接续，旧平台与新拱廊的画法不一致 |
| 共享调整 | A原亮度＋重复中景；B只移除中景；C再切换同一个depth明暗／灯强配置。三种几何都引用同一profile | 去掉竞争的重复拱形让路线更清楚；共享配置无需为三房另画素材。但未解决上述整体缺陷。通道另有一次布局参数修正：桥墩extend由0改1，不能声称所有问题只靠一次公共修改解决 |
| 正式尺度与运动 | 额外加载真实PlayerMotor／PlayerController、UnderworldPlayer及WorldCamera；同源矩形碰撞，左岸走、停、返回；固定12fps捕获96帧，实际478次Motor步进 | 正式镜头1.6倍；96个采样都落地，x约304—824。只验证该岸段运动和显示；不证明断渠跳跃、竖井、机关行为、完整路线或正式入口集成 |
| 灯与覆盖 | 同机位开关真实PointLight2D，图层显隐、正常尺度与1.6倍机位、横纵及返回镜头 | 三夹具灯光变化均未超出配置半径；未测真实阴影遮挡。远景为完整不透明图，固定屏幕覆盖，不会随相机露底；它在竖井仍保留同一水天线，反而暴露场所逻辑失败，不能当作纵向独立景深套件通过 |

完整提示词、实际参考、原始生成、灰盒几何、裁切矩形、尺寸／接点和哈希归assets/kit_reuse/source/generation.json、arch-geometry.json及assets/kit_reuse/manifest.json。新图由image_gen生成，实际输入只有所列项目参考；既有素材沿各自来源，不宣称新绘。

## 美术判断与方法边界

本轮Codex自审为failed，不代签用户反馈。去掉中景后的画面更清楚，但仍是重复结构与异族平台的组合，空间特征不足；竖井尤其明显。一个完整拱廊不是完整区域结构族；这种失败不能推导“所有模块化都无效”，也不能反过来以复用数量签收方法。

本轮支持的结论只有：实际引擎约束和转译检查仍有用；独立资产必须真实完整；共享参数确实能传播；固定画面、完整资产、好看的组合和量产能力是不同证据。当前区域套件候选规则仍未获美术／成本验证，不能推广到44个已写房间或309房规划。

成本记录：一次image_gen调用；每房新增专属生成图0、补画0、遮罩0，布局参数各自维护，共享实验渲染器与配置。未记录独立的逐房人工计时，本轮还包含工具搭建和反例调查，不能宣称每房工时降低。没有通过改规范、换验收标准或新增每房整景来签收。

## 证据与恢复

本地查看入口：build/kit-reuse/comparison.png（三几何A／C，50%缩图）、ablation.png（A／B／C逐步对照）、control-comparison.png（固定组画反例与正式角色机位）、tour-strip.png（沿途机位）。passage／shaft／hall-depth.png为1280×720无标注原始实帧；同名flat、light-off、layers-exposed、zoom1.6及overscan保留。layers-exposed显示独立中景和完整远景，不能据此称完整区域景深库。

passage.mp4、shaft.mp4、hall.mp4各8秒，是脚本镜头覆盖巡查；controller.mp4另8秒，是正式控制器与镜头的岸段运动。共288个巡查帧及96个运动帧；capture.json与controller.json分别记录相机／角色位置。原失败密集中景截图在rejected-dense，原因与参数快照在assets/kit_reuse/source/rejected-dense.json。媒体、日志与证据JSON在忽略的build目录，源、配置与工具跟踪入库。

恢复命令：python3 tools/bake_kit_reuse.py；Godot headless editor import后，在真实显示环境运行tools/capture_kit_control.gd、tools/capture_kit_reuse.gd及tools/capture_kit_controller.gd。两个动态捕获用--fixed-fps 12；主场景单独打开可用1／2／3切几何、Space巡查、F切共享profile、B／M显隐结构／中景、L切灯。python3 tools/summarize_kit_reuse.py从新捕获生成对照、视频与证据，核81文件冻结及灯半径；它不认证审美。

CI四项通过（254项合同、39项保存断言），文档检查通过，实际Godot窗口捕获及正式控制器岸段探测通过。检查不证明整房玩法、编辑器接入、真机性能或美术质量。下一步若继续，先补足同材质的平台／接头与适合竖井的背景，在一个实际房间闭环；不再用同一拱廊堆更多夹具或扩大Skill改动。

## 前次整理与交付边界

前次35339eb整理10项仓库Skill主入口及8份引用，并改AGENTS和8份项目文档；15300cc补方法包来源，6094322明确可证伪验收。本轮不改变它们。当前主入口仍为.agents/skills/godot-room-art/SKILL.md；区域套件是候选生产方法，不是已实现的注册库。已有TerrainComposer、17种材质与现有单层members协议可继续使用，不支持成员继续嵌套或任意跨度自动适配。

前次engine_first_2d的921,600像素原坐标回拼与效果证据在build/engine-first-2d，只支持固定机位原型。更早static_orchard和art_rule_trial实际拼装已被否决，不能作认可画法。本轮复用environment.png只作为待检验的完整远景输入，不恢复此前整体方案的认可。

云端同名Skill未回写，仓库方法包仍为build/art-method-review中的26文件美术包与7文件关卡包，来源35339eb；它们不附完整历史素材，不能叫云端原包的完整等价替换。

原私有观看页https://gunman-depth-review-20261113.zhipijun1996.chatgpt.site仍为旧成功版本，不含本轮实验。此前保存版本appgprj_6af6f10b31a4819197d1e00a834c9436~appgver_122b8cf288808191a33ad3000f4a20d0、部署appgdep_6af72db8e29c8191b675246496dec947返回Failed to publish the built site；缩包仍失败，未定位根因。本轮没有盲目重试或声称线上已更新。
