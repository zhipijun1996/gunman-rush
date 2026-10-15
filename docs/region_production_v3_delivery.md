# 风铃平原 V3：实际交付与未完成范围

本文件为交付收口记录，当前仍在执行最终回归和部署；不代表已上线或品质完成。
分支 `feature/plains-production-v3`，[草稿 PR #69](https://github.com/zhipijun1996/gunman-rush/pull/69)，基于 PR68 `ed0623000c61287282f89e6b0463937b0afe0aca`，继承 PR67。未合并 main。

## 结论与完成边界

**全区商业级手绘美术目标没有达到；完整自主地区制作能力也没有完成。**
本轮实际产出是可玩的有限升级、真实敌人遭遇切片，以及经实际执行/失败返工检验的生产链修复。不能用下文的技术结果把目标改称通过。

独立审查实际看过正式画面，接受部分空间资产的限定用途、高地完整风塔的静态预览、挂藤修复及 RootBell 的限定交互；仍拒绝整区商业美术完成。重复矩形岩壁、部分旧细柱/小风车的支撑感、中景资产不足、天空过空、Boss 美术及完整视听仍有缺口。停用不合格树林造成的中景空缺不是画质提升。

## 正式可玩内容

| 内容 | 实际消费者与范围 | 准入边界 |
| --- | --- | --- |
| 维修工坊 | `PlainsRegionScenery → PlainsRegionComposition → PlainsSemanticLandscape`，实测完整330宽结构落在真实支撑上 | 原500宽失败保留；不是任意平台皆能放 |
| 古老钟庭 | 同一正式场景链，完整钟庭资产与实际根基 | 此次 fast 对照路线没有进入钟庭，使用该空间独立实景证据，不能混称本片覆盖 |
| 风车高地 | `windmill_highland_v1` 完整146世界宽塔，默认有限开启 | 240规格、200实景裁屏均失败；20图11可建/9明确省略，不重抽凑数 |
| 溪谷岸端/石灰岩 | 受限的岸肩后景、天然岸端与铜石板采样 | 原整墙/整板母版失败保留；不能称完整岩壁家族已精修 |
| 天空与远山 | 独立天空/石灰岩远脊、横纵相机连续视差 | llvmpipe成本仍高；默认树林已退出，不能再声称整区树冠风动已完成 |
| 挂藤 | 从实际静态/单向平台下沿挂接完整原图 | 20图76处有支撑、66处因无合法挂点或冲突省略；不支持任意碰撞形状/移动支撑 |
| RootBell | `scripts/enemies/root_bell_*`，只在已验证620宽 double_gear 类最多替换1个旧敌人 | 40图仅1处满足条件，0/20入门、1/20进阶；不是全区敌人生态升级完成 |

RootBell 的新判断是避开标记脉冲、起跳越过后返回、射击打断/击杀后经过；不是改血量/速度的换皮。实际使用两张完整图集、GDScript region 绘制和既有 CC0 声音。没有虚构独立裁帧PNG或新原创音效。Boss 尚无充分新机制重做依据，保留原玩法；两次新 Boss 美术失败，未进入运行时。

原 Motor、武器/输入/资源规则、能力成长、RNG 服务、保存规则与 PR67 有效路线没有为本轮画面改动。采集驾驶策略另有显式 opt-in v2 实验，保留原 v1，不能将驾驶变化算作内容或纯美术收益。新敌人生成版本为 `plains-region-v11-root-bell-v2`；旧 v10 恢复与单局模式固定有专门兼容检查。

## 实机截图、录像与前后对照

- [PR68 与 V3 实际路线对照](evidence/region_production_v3/canonical_route_comparison/README.md)：两份可直接播放的原始 MP4、六组画面、原记录/PNG ZIP、完整差异与 SHA。分辨率1280×720，视频60帧/秒，正常时间轴。
- [完整 RootBell 默认正式遭遇录像](evidence/region_production_v3/final_default_movie/README.md)：实际15案例、5145物理帧、5149视频帧、9次脉冲，含0/30/60等待、出返程、两次真实弹体打断/死亡、死后经过及齿轮走廊返回。源码为 `b5b9be2`，早于挂藤修复，不冒称当前源码重录。
- [修复后完整路线独立像素审查](evidence/region_production_v3/final_after_ivy_visual_review/README.md)：真实打开27张原尺寸新帧、6张旧帧，另直接解码3张MP4画面与原PNG逐RGB字节一致；没有完整播放/听音或实体设备验收。
- [挂藤真实失败与修复](evidence/region_production_v3/ivy_attachment/)、[不同作者审查](evidence/region_production_v3/ivy_attachment_independent/README.md)：缺陷来自正式电影实际像素，不是预写失败样板。

相同 literal Seed `level-design-v2-baseline`、map2、fast、`kill_from_bank_v1`、post-draw协议，PR68与当前V3均走完3063物理帧/7段路线，3067视频帧。实际逐tick位置、速度、输入轴、生命与能量精确一致；没有逐tick相机观测，只能确认原记录中的初末相机，不冒称逐像素配准。

严格纯美术比较仍拒绝 PR68→V3：Manifest实际3处叶差异、RunManifest10处差异，以及 `tools/level_design.py` 驱动来源差异均保留。五个实际trace/capture协议SHA相同。只在同v11的挂藤前后，原严格比较通过；没有删字段取得PASS。对照片可见高地、主路岩围合、维修营地、下层溪谷下降/回升，**未覆盖上层钟庭和Boss**。

## 自主生产体系实际改变

沿用原 `harness.py → production_loop.py`、G0–G5、十一维和既有专业 Skills，没有新增第二套质量体系。

| 实际缺陷 | 修复与可证伪证据 |
| --- | --- |
| 中断/撤销租约与响应同拍可被误接收 | 现有循环在解析/发布前后复核撤销与到期，保留实际R1拒绝、重试状态与原调用预算；完成阶段有绑定检查点 |
| 稀疏工作树缺基础/历史依赖却先消耗worker | 调用前核对所选真实argv、tracked文件/目录成员、权限和外链；原81测试保留，目录扩展后84及额外独立真实Git反例通过 |
| 慢速录制吞掉过期输入 | 可见模式在实际post-draw之后生成下一条新输入；保留100ms TTL，绝不重盖旧时间戳；真实130ms反例仍拒绝。不能追认旧无时间戳失败的根因 |
| Hash或metadata冒充美术通过 | 原像素、影片和来源绑定；独立审查实际看图；`limited_preview`不升级商业/用户认可，失败 Boss/树林不进入正式包 |
| 动态素材只在源码存在、Web遗漏原PNG/JSON/remap | 有限实际消费者闭包、真实PCK目录及资源字节检查，原35测试保留，后扩为42，再追加失败新家族隔离，共43；最终真实导出结果另列，不以夹具替代 |
| 非运行原图/离线文档缺精确来源覆盖 | 新资产记录逐文件角色与SHA；R1两次“伪标离线”falsePASS保留，R2独审实际41测试、原13临时Git及7新增探针通过，已知运行素材只能由运行记录覆盖 |
| 大证据仓库被每验证lane重复复制 | 实测tracked输入约3.85GiB；CI改单lane运行完全相同fresh集合，不删检查、不改timeout。曾发生零空间和实际矩阵中断，原失败保留 |

已更新 visual-director、art-director、scene-composer、region-generator、enemy-creator、encounter-director、animation-vfx、gameplay-reviewer 相关协作规则；既有 `level_lessons.json` 存放有来源、版本和能力范围的经验，短指令路由会实际加载，非全游戏硬规则。

[来源合同独审](evidence/region_production_v3/asset_provenance_independent/r2/review_r2.json)只接受有限Web适配器和完整 `res://assets/` 字面消费范围；实际还保留 `load("res://"+"assets/source.png")` 未识别的反例。它不是通用GDScript可达图，也不能宣称所有未知构造都自动拒绝。当前14份真实记录与189项已知消费集合另有实际SHA核对，原政策/旧26及37测试AST不变。

## 简短指令复用：真实森林演练

[完整原始执行](evidence/region_production_v3/forest_final_actual_loop/README.md)只以“制作荆棘森林。”启动现有路由。真实不同实施/审查代理执行，原Harness重新运行四项选定检查，并消费真实租约响应；终态 `completed`、2次host调用、`content_complete=false`。同命令终态重放未再调用worker，状态字节不变。

当前执行内容为已有权威下的 **H-only 技术样板**：真实185断言/169tick、缺锚点/无H各480tick故意失败；独立审查核对780项源码、56项Python测试和7个一致性篡改反例。原两个稀疏依赖失败与退出泄漏保留，不改写旧执行。没有开放森林、正式授予H、制作完整森林敌人/Boss/美术或宣称完成整个地区。

最小入口：

```sh
python3 tools/level_design.py route --request "制作荆棘森林。" --output build/forest-mission.json
python3 tools/harness.py --mission build/forest-mission.json --execute --worker-mode host --evidence-dir build/forest-production
```

第二条需要**当前真实 Codex 宿主**读取请求并调度不同专业代理；不是脱离宿主的后台模型服务。路由会读取已有S1–S6/H/W/D规则、单武器资源约束、美术标准及经验；缺完整消费者/资产/能力证据应阻塞对应阶段，不能套平原或伪造完成。完整地区自主创作与最终审美/真人认可仍未证明。

## 最终技术回归、失败与部署

提交 `9eef7a88003deaf924f895d585cb7e5de0cb48b0` 的 [CI run38821836985](https://github.com/zhipijun1996/gunman-rush/actions/runs/38821836985) 有两项失败：core 中的 generated-consumers，以及 Web 的 visual-director-tests。core 的原失败日志已保留；Web 子产物获取失败，不能认定其远端唯一根因。不同作者在干净 Python3.12 venv 实际重现缺 Pillow，安装固定依赖后原17测试通过，仅接受依赖准备修复；见 [Web依赖独审](evidence/region_production_v3/web_ci_dependency/review.md)。这不代表远端CI转绿、全部技术回归通过或已部署。

当前 Root 正执行 `generated_consumers_ci_repro01` 并调查生成器回归，Web依赖修复也待最终新源复验；最终完整适用 Harness、本地Web/Windows、真实浏览器输入和公开部署均待实际终态。V3尚未上线，不提供尚未产生的新build_id或把旧线上PR67当本轮发布。

Foundry 本次刷新56份 JSON：54份 replay 仅 basis/manifest_hash 变化，其 frames 数组逐字段与刷新前9eef完全相同；batch/export_basis 的所有变化叶也仅 basis/hash。实际准备日志报告36个开发短语、18条连续 itinerary，export stamp 已记录新basis；这是来源/哈希刷新，不是54条新动作或全平原路线改善。[发布准备安全凭据](evidence/region_production_v3/final_release_preparation/README.md)已归集；最终回归、PCK闭包、浏览器与部署结果未完成前不预写通过。

[80路线原件与恢复记录](evidence/region_production_v3/final_multiseed_80/README.md)已完成：10个Seed×两图×4策略，80份采集完整性有效、71到目标/9真实策略失败。26份完整旧回执逐一校验后仅补54条；原零空间exit1不抹除。6个实际Git提交的798项原生源投影逐blob重建相同。这批次发生在最后隔离资料/后续可选策略之前，不冒称后来源码重跑。9失败集中map2渡台遭遇：8例安全岸反冲守卫、1例无伤害进展；两条额外诱导绕过也失败并掉血，不能称问题已经修好或所有失败都仅是策略误报。两套20地图样本中，这批80所用20张**没有RootBell**；新敌人覆盖由独立专用15case/movie证明，40图准入另属样本，不当出现概率估计。

[矩阵不同作者复核](evidence/region_production_v3/final_multiseed_independent/review.md)实际检查全部80份原capture/receipt/log、连续tick、全局事件与逐帧接受事件的完整多重集合，并逐Git blob复建6提交的798项投影。接受的是来源和有界观察，路线设计仍review；798项投影不是1072项电影/完整美术闭包，也不把旧26次复用改称80次全新运行。71目标分布为fast20、growth20、deep15、return16；目标不是Boss/整局通关。9例均在map2高收益探索，失败时玩家均HP5，不足以判断地图无解，也不能将其全部归为策略误报。

### 可选 v2 驾驶实验不改写正式80结果

[实际四次对照及源绑定](evidence/region_production_v3/kill_bank_v2/README.md)、[不同作者独审](evidence/region_production_v3/kill_bank_v2_independent/review.md)仅接受保留显式 `kill_from_bank_v2` 的局部搜索实验。原v1和默认 `blind_legacy` 不变；仅在原±16/32/48/64候选之后追加±80/96，原全身/路径/反冲支撑/危险净空、40步移动、900tick/6shot及真实输入/资源约束全部保留。

seed03/map2/deep 原v1在931tick静岸停止，HP5；v2通过真实输入移至约x−50，931–1026保持HP5并用三次真实弹体击杀diver。之后1180、1284、1391、1489四次真实 fan_crossfire 伤害使HP降至1；最终6544tick到驾驶目标、由合法奖励回血至5，并不消除该失败段。只在单seed/单phase0验证，无正常影片、多地图、多相位、其它武器、玩家可读性或设备准入；不设为默认、不提升原71/9结论。

baseline/map2/fast 的v1修改前后都为3063tick，frames/events/edges/能力资源/Manifest等原始字段相同。与原80对应case还存在172处真实进程owner及其事件/来源别名差异，只有明确映射该唯一owner后其余字段相同，不能称原raw全同。四份native原source_commit均9eef，但实际是Git base加真实dirty overlay：每份806项投影，前两份742base+64overlay、后两份739base+67overlay。56份Foundry与8份失败家族JSON也在原overlay中，后两份再含三份策略源码。精确dirty原字节和3224项绑定已保留，不冒称clean9eef或覆盖全部PNG闭包。

已知真实缺口：RootBell和完整路线退出仍报告ObjectDB/资源泄漏；llvmpipe正式录像CPU/GPU平均约48–55ms（监视器重叠），不能据60FPS视频宣称设备60FPS；真实手机/手柄、音轨聆听、用户趣味与审美均未验。80路线中的自动策略失败与磁盘满中断不删除、不转换为通关。

## 最后一次岩壁源尝试：未获准入

[真实审计与失败源](evidence/region_production_v3/supported_bank_failed_02/README.md)、[不同作者复核](evidence/region_production_v3/supported_bank_failed_independent/review.json)显示，旧420×152包围盒实际包含末20×32薄悬挑；原完整矩形规格并非该地图真实实体轮廓。另冻结实际轮廓一次编辑，工具真实53.8秒返回2048×768（接口无尺寸参数，prompt不保证尺寸）。必要厚度最多139.9423<146、站线仅32.91%，悬挑也不符。未剪图/补alpha/放宽门槛，sampler与原418测试源码完全未改。新源只作失败证据，三个preset及PCK检查器显式隔离，bank方向停止。[独审](evidence/region_production_v3/supported_bank_failed_independent/review.md)实际看原图/guide/游戏参考并独立复算，接受的只是失败保留与隔离；43项Python守卫测试通过不代表下一次真实导出PCK已检查通过。这不是新增画质成功。

## 时间与预算

2026-10-15 17:02:25 UTC开始，硬截止2026-10-16 05:02:25 UTC。实际图生/编辑14次/上限18；原生产host请求44/44，包含中断和失败，无退款。接续直接工程/独立审查另有真实代理记录，不把44说成全部provider模型调用。模型token、价格、部分provider调用时长未暴露，不能编造成本。

具体已暴露时长：树林V2编辑38.041秒、高地原图54.608秒；新完整敌人电影原生采集7分11秒；当前整路线原生约3分59秒；森林实际控制器/检查、图生与静态返工原时间戳保存在各原记录。并行阶段不能简单求和当总墙钟时长。Boss、树林及共享渲染性能方向分别达到停止条件，不继续无界尝试。

## 后续最有价值的工作

先制作能够替代重复矩形岩体的完整自然断面/连接结构，与有真实根基的中景植物资产家族；采用同Seed真实镜头确认大轮廓，再推广。旧细柱/小风车支撑感与底部HUD切换需先定位正式消费者，不能继续靠调色/雾/小装饰掩盖。下一次敌人工作应扩展有明显判断差异且公平的空间类，而非把稀有1/40遭遇称为整区生态。必须优先修复退出生命周期并在实际手机上量测渲染成本。

建议下一次简短任务：**“基于V3实际失败证据，先重制平原自然岩壁与有根中景植物黄金家族，替换矩形重复，不改玩法；实机通过后推广并部署。”** 这不代表用户需要重新提供本轮全部规范。
