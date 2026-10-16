# V3-TERRAIN-FAMILY-01 — 有界原画采样与真实消费者

本阶段只交付原 G0/G1 技术消费者与代表像素，不宣称全域岩岸、美术商业 G2、用户或设备认可。核心物理、Definition、碰撞、生成参数、路线、相机、资源、RNG 与保存未改。当前正式表现只选每图一个实际有地基的连通 union 与至多一个真实 24×110 悬空挡板；`PROMOTE_APPLICABLE=false`，其它形态逐项保留基线。

## 资产与材料职责

两份正确原画的原整件规格仍 FAILED：CLIFF 完整等比 420×152 必要条件不成立；PANEL 完整 24×110/full-contact 条件不成立。源 PNG、family 和 production 记录没有编辑。新的独立采样合同不追认它们的原 G0。

新合同见 [contract_v2.json](../../../assets/region_production_v3/terrain_sampling_v1/contract_v2.json)，SHA `5be47acdcbc1c69f22e8ac88dbdb4d653588a8965a8a5becb99fb5b37cf6b011`；v1 原合同与失败保留。

CLIFF 原图内场 alpha128 虽完整 opaque，但 .15 等比重复产生 45world 绿缝与横向砌砖带。ROOT 实看拒绝该 body。最后组合恢复已验 v8 大块石灰岩 body、原世界相位与原 standing-grass 算法；新 CLIFF 只按真实外露端/底采样手绘 alpha。墙身 RGB 连续取原 v8，不程序画核心美术。内凹上限侧4/底6，普通外扩侧≤3/底≤10；接近其它实际实体或单向落点的底部仅≤min(3,clearance/4)，无假填空洞。薄截面仍走原基线，未用大岸母件压扁替换。

PANEL 用统一1/9比例、core源x379..595、standing y130；上 Atlas 从 y103 开始，只删16源像素苔叶尖，保留27源像素/3world顶饰。831→1242中段删除411源像素，保留石铜端帽；两原始 region、filter_clip=true，完整体高110。11源像素旧提案右侧外扩2.333>2，仍为失败反例。当前实际挡板下方50gap保持，不生地脚或撑柱。

## 实际消费者与反例

`PlainsTerrainStudy.refresh_geometry()` 实际调用 `PlainsTerrainFamilySampler.build()`。先按真实静态 solid 连通并集与实际 ground columns 区分有根体/无根悬体，one-way/moving 独立基线；当前 Manifest 未填旧 floating-version hint 时，不信空 `floating_solid_indices`。按 union 共线外边选择接口，输入分块/顺序不会再各自加帽。

首两图为真实 DemoApp/正式 HUD、PlayerMotor 和机关的静态构图 fixture；测试明确重置 actor 姿态后由原相机跟随，不冒充通关轨迹。/08 map2 原型实际岸体是320×152，PANEL[560,-142,24,110]，不是凭旧草图造出420。最后成对图在 [final_static](../../evidence/region_production_v3/terrain_family_01/final_static/)；正常尺寸原图已实际打开。背景过亮、旧重复藤拱和其它矩形岩岸依然存在。

新检查真实改错活节点的 source texture、union face count、Atlas region/filter、缩放与位置（下移50填 gap）并诊断拒绝，恢复后复查。实际 union 换序/重新分块、平台分类总数、真实地基、one-way 基线、Manifest不变均检查；没有以断言数或源 SHA 评美感。

## 真实失败与最终技术证据

- 首次 native25/0+26/1仅覆盖根岸，因旧floating hint为空漏了PANEL；这是覆盖不足，未当作完整通过。
- `rejected_brick_body`：实际岩墙内场重复退步；原图和小 source delta 保留，不扩产。
- `failed_v2_rgb_and_cleanup`：v2 outside分支错误仍取100%新RGB导致色接缝，且严格退出guard拒绝4resources/8ObjectDB；原件仍 FAILED。修复outside与inside均纯alpha、保持v8RGB连续。
- `failed_corpus_fixture_expectation`：20map396断言2失败，baseline/map1及/04map1只有24×619/429等高板，没有24×110。保持/08代表图强断言，新增按真实form存在精确匹配与“缺型必须fallback”，未拉伸高板凑齐。
- `failed_flaky_cleanup`：下一次20map418/0但故意负例退出又泄漏，整suite仍 FAILED。不同 source环路/释放等待的初步缓解不足，原 verbose 与失败保留；最终 headless显式max-fps60，保留任意ERROR拒绝。
- 最终 [20map报告](../../evidence/region_production_v3/terrain_family_01/final_20map/report.json)：实际418/0、故意46/1，source_before==after，无 Script/Shader/ERROR 或退出资源警告。20 canonical Manifest 哈希逐项同上一阶段，未把 serialized whole-JSON SHA 与 canonical hash 混用。两缺型图保留baseline。

所有引擎显式 `GODOT_BIN=/workspace/gunman-rush/build/region_production_v3/godot_locked.sh LP_NUM_THREADS=1 OMP_NUM_THREADS=1`，单层共享锁，cold import在source-before之前。首静态GPU有ALSA ERROR且旧新guard尚只拒Script/Shader，保留该受限运行；后续静态明确Dummy音频并拒任意ERROR，音频品质未验。

## 正常影片与边界

旧/08map2fast实际3090帧轨迹在两处ground pilot附近始终y≈-700，不能证明新消费者观看。基于旧 `pilot_map2_fast_v1/capture.json` 选择 literal root_seed=`level-design-v2-baseline`，map_index=2，strategy=`fast`；旧真实最近PANEL tick764、岸体tick1429，自然经过。新片只录一次，不改bot、镜头或消费者位置迎合路线；未当严格新旧内容收益对照。

唯一正常电影已真实完成：3063native ticks/3067video frames，route_target_reached，999source before==after；native236.613s/总271.028s。完整MP4、原trace/log/27原抽帧位于 [movie_original](../../evidence/region_production_v3/terrain_family_01/movie_original/)，只录一次。作者实际打开720/840/1320/1440/1560：PANEL进入/经过、1440岛岸自然在角色脚下，actor/HUD/铃/落点可辨；1320工坊整体仍可见，其旧地基没有冒称全数换新。未传composition，明确not_requested。原退出10ObjectDB/4resources ERROR保留，旧pilotfast也有相同计数但原因未证明相同；不称lifecycleclean。原producer成功路径自动删AVI，原AVI SHA留receipt，未改producer伪保留AVI。未观看完整正常速度/未听音轨/无真机一律未验。

[最终 source closure](../../evidence/region_production_v3/terrain_family_01/closure/portable_source_closure.json) 实际封口999电影源：977路径复用已验978源闭包，16原始family输入从ROOT Git `2a585124f2c94ed41f3f8df06642b275f0ac96be`逐SHA验证，6小delta+4UID/检查控制；没有复制整项目或重复PNG。原G0失败、前次movie和host历史原字节不动。独立原host review、整体G2、其它Seed实景、音频、性能、生命周期全矩阵、用户与设备仍待验。

原 `tools/check_quality.py` 全索引检查实际exit1：child未provision旧ACTION/武器等历史证据和2个旧Skill引用，原失败日志保留；没有为过关复制或改写旧任务。当前本任务record schema实际errors[]、verdictUNVERIFIED，ownrow与workflow一致，ROOT完整树整合后须再跑全索引。
