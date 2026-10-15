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

原 Motor、武器/输入/资源、能力成长、RNG 服务、保存规则与 PR67 有效路线没有为本轮画面改动。新敌人生成版本为 `plains-region-v11-root-bell-v2`；旧 v10 恢复与单局模式固定有专门兼容检查。

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
| 动态素材只在源码存在、Web遗漏原PNG/JSON/remap | 有限实际消费者闭包、真实PCK目录及资源字节检查，原35测试保留扩为42；最终真实导出结果另列，不以夹具替代 |
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

最终完整适用 Harness、本地Web/Windows、真实浏览器输入、80路线矩阵和公开部署尚在执行。以最终原始结果为准，此处不预填PASS。

已知真实缺口：RootBell和完整路线退出仍报告ObjectDB/资源泄漏；llvmpipe正式录像CPU/GPU平均约48–55ms（监视器重叠），不能据60FPS视频宣称设备60FPS；真实手机/手柄、音轨聆听、用户趣味与审美均未验。80路线中的自动策略失败与磁盘满中断不删除、不转换为通关。

## 时间与预算

2026-10-15 17:02:25 UTC开始，硬截止2026-10-16 05:02:25 UTC。实际图生/编辑13次/上限18；原生产host请求44/44，包含中断和失败，无退款。接续直接工程/独立审查另有真实代理记录，不把44说成全部provider模型调用。模型token、价格、部分provider调用时长未暴露，不能编造成本。

具体已暴露时长：树林V2编辑38.041秒、高地原图54.608秒；新完整敌人电影原生采集7分11秒；当前整路线原生约3分59秒；森林实际控制器/检查、图生与静态返工原时间戳保存在各原记录。并行阶段不能简单求和当总墙钟时长。Boss、树林及共享渲染性能方向分别达到停止条件，不继续无界尝试。

## 后续最有价值的工作

先制作能够替代重复矩形岩体的完整自然断面/连接结构，与有真实根基的中景植物资产家族；采用同Seed真实镜头确认大轮廓，再推广。旧细柱/小风车支撑感与底部HUD切换需先定位正式消费者，不能继续靠调色/雾/小装饰掩盖。下一次敌人工作应扩展有明显判断差异且公平的空间类，而非把稀有1/40遭遇称为整区生态。必须优先修复退出生命周期并在实际手机上量测渲染成本。

建议下一次简短任务：**“基于V3实际失败证据，先重制平原自然岩壁与有根中景植物黄金家族，替换矩形重复，不改玩法；实机通过后推广并部署。”** 这不代表用户需要重新提供本轮全部规范。
