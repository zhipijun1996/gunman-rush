# 平原七怪修改 · 实机复审证据

任务`PLAINS-MONSTER-REVISION-01`，基线`0d33ab56cb06d5bb37b30bd82387415ae5c7725e`。本轮落实用户七只怪的身体、材料、整套动作、差异受伤、死亡与退场要求，移除普通怪HP及纯辅助瞄准／路径线，并将“像素粒度要对齐整体美术”列为真实同屏复审项。[制作卡](../../worklines/plains_monster_revision_01/spec.md)仍是目标与证据索引，不是整怪完成声明。

## 最新实际媒体

两片均来自干净、冻结、前后source_stable的运行源 **`7edda9f5f2a20c5406391ff3f7edebbeb2322047`**，原Godot MovieMaker 60fps录制，保留实际引擎音轨，无替换配乐。

| 媒体 | 实际覆盖 | 范围及限制 |
| --- | --- | --- |
| [七怪连续实机片](media/plains.mp4) · [原报告](capture/plains-report.json) | 76.166667秒，7个实际Underworld消费者case，基础coverage gaps=0 | 明示初始实验场，真实AI、输入、弹体、FrameDamagePolicy、受伤和致死；不是自然生成路线，也不由basic0签所有动作／艺术品质。 |
| [真实平原比例同屏](media/comparison.mp4) · [原报告](capture/comparison-report.json) | 30.266667秒，6页；每页原玩家、未改尺寸的俯冲及一种修改身体 | 原DemoApp生成地形与相机，同一seed；明确保持样本／玩家用于比较，非战斗或自然移动。原Manifest不改，真实支撑与安全岸条件不降低。 |

[原始采集包](capture-originals.zip)保存两片各自trace、原PCM、完整report、日志及相关来源；不重复外置MP4。[全文件清单](manifest.json)记录字节大小和SHA256，ZIP内有原member清单。新片普通血量／辅助线与身体动作必须看实际画面；shader使用1wu nearest不自动证明与整体美术一致。

当前为复审候选。[最终有限独审](review/plains_revision_visual_review_final.md)已确认死亡问题修复及实际同屏粒度可进入审核；用户审美、实体设备、完整正常速度听审及G5未签。新视频已原生私密发布至[怪物工坊](https://gunman-monster-workshop.zhipijun1996.chatgpt.site)，站点源c2de0bff；原75版本与意见归属保留，详见下方实际发布收据。原163回归attempt01只执行8项、在旧登记/任务索引处失败，修复后同一范围继续；未执行项不记通过。

## 当前实现的明确边界

六个新中性体保留原始母版与逐字生成来源，通过固定世界比例及关节驱动同体动作；俯冲保留原身体／尺寸，仅精修衔接和落地。新身体运行采样采用1wu／nearest，仍需玩家、俯冲、地形合屏判断轮廓与高光密度。原生成许可／模型未暴露之处保持unknown。

普通HP及纯辅助路径／瞄准显示移除；真正造成伤害的弹体、危险实体、脉冲与Boss玩法对象保留。死亡身体无伤害，需落地者先找真实支撑；冲锋／俯冲稳定留尸，其余停留后淡出。实际身体接触是否满足动作目标须以逐器官画面审查，不能仅凭Remains.settled或新rig的4..7报告索引。

根铃碰撞40×48，冲锋28×28，扇射22×18是明确主身体拟合改动；不能称物理几何完全不变。冲锋的真实sole支撑探测也已修正地面边界漏判。草籽从中心到配置喷口先做原半径真实扫掠，近墙／近玩家处理不由动画伪造。HP、伤害、相位时长及权威结算不因美术改变。代码／物理限定结论见[碰撞审查](review/plains_revision_collision_review.md)，不把有限物理fixture当自然玩法平衡。

## 保留的失败与后继

[首批原件包](history-originals.zip)完整复制既有251份原文件及其manifest，ZIP SHA256为`2332262fbbd1081cfc03d704063618c72b54fdc60a2ed79e28b59c6439d1b186`。不覆盖旧影片和拒绝。

- 初始native314／0；补真实death=0反例后323／4，修后323／0。旧消费者测试曾因过时feedback_body假设实际失败，迁移后480／0；后加恢复几何断言及其独审是后继证据，不能回填旧源。
- 原formal01内部66／0，但退出52ObjectDB／32resources及RID泄漏，整体FAIL。受控load-only A/B把原因定位于测试脚本嵌套类型依赖，原wrapper后继formal02才clean66／0。[完整诊断](review/plains_revision_leak_review.md)保留已撤回的RootBellPulseArt猜测和反证，不把早期猜测当最终原因。
- [视觉R1](review/plains_revision_review_r1.md)拒绝巡逻薄片尸体等问题；[视觉R2](review/plains_revision_visual_review_r2.md)拒绝草籽仍直立、跳跃腹部未落地、根铃高拱／叶冠仍承重。R2影片虽clean4ff、76.13秒／7case／basic0，仍不合格。
- comparison01实际pages0／frames2：spawn附近未找到原256wu安全岸，且退出6ObjectDB／1resource；整体FAIL。后续扩大同一真实地图的候选岸搜索并修测试依赖，未加假地面或降低原安全条件。

[后继原件包](history-followup.zip)保留clean`71ccc385ee181fb055c1c6970ce5fa12132869f5`的review03／comparison02及clean`49176c04589c9b156b6a9e34543ff25eb01d2022`的review04。这些录制技术成功；R3三只死亡有实质改善，但真实根铃下缘／铃舌仍悬空，继而R4修正死亡mask、用原源opaque像素反例验证并获得[根铃接触限定接受](review/plains_revision_visual_review_r4.md)。当时碰撞／冲锋支撑还未完成，不能作为最终7edda9源证明。

[诊断原件包](diagnostics-originals.zip)保留全部当前`plains-revision-*.log`、native/runtime报告、首次输入预检及物化原件。`native-r3/parse.log`来自首次wrapper尝试：Python结果输出层KeyError中断，不能误称Godot parse失败；`native-r3-02/receipt.json`是另次真实执行。原337／0碰撞fixture后，实际支持冲锋339／2失败原件仍保留；sole探测修正后340／0是后继限定结果，不改写旧失败。原生日志没有完整source snapshot的轮次，不补造精确最终提交的fresh验证。

## 守门与内容审查分开

[三份旧测试守门迁移独审](review/plains_revision_code_review_r3.md)限定接受真实rig消费者适配，并独立核三测试在最终7edda9源的字节与原R3一致。它不签整怪视觉，也不把此前native/formal执行追签为最终head新执行。旧Frames四组资源、真实受伤／死亡／暂停／慢时／epoch／支撑／保存／掉落／释放与严格退出仍各有守门。

[来源清单](manifest.json)列各原始文件；[目录转换helper](capture/add_plains_revision_catalog.py)要求真实视频／trace／captureSHA和可读取的media commit，保旧版本与反馈归属；[平原比较录制wrapper](capture/capture_plains_revision_comparison_03.py)保实际生成场景与声明范围。Sites反馈DB、旧视频及历史意见继续保留，新版发布实际收据另列。

## 私密工坊新版已发布

[怪物工坊](https://gunman-monster-workshop.zhipijun1996.chatgpt.site)已原生Sites发布成功：站点源c2de0bff9db68bd6ab03af661e60823c10e6e880，部署与源码/归档见site/。25条目/88版本，原75版本原ID/revision/actions/provenance保留，新增7战斗片＋6实际平原同屏片。API13＋UI19测试、artifact验证均通过；两部原片完整HTTP200/SHA实核。D1/API/UI/schema不改，不写伪用户意见。

原回归attempt01实际仅执行8项：7通过，quality因两旧registry source hash/新process任务索引缺失失败，后155未执行。保integration/attempt-01，不称全量跑完。技术登记追加证明与独审另保asset-registration/及review/；随后重跑同一163项。实际输入物化仅恢复3个原tracked文件共约1MB，不修改原内容/阈值。

comparison初页300条观测为movie9..308，声明可播10..308；转换器保持原可播区、排除首个前导观测并取poster10，不改原trace/影片，其他5页无排除。独立46项回归及18篡改拒绝见site/comparison-safeclip-*。
