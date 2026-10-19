# 空间黄金交付准备：只读来源与轻量检查

记录时间：2026-10-16 14:28:30 UTC。基线PR72 `1597db583a6ade25a469cb9ecb99b5762d6f76db`。本报告审查新增资产来源、当前三个导出preset、实验消费者入口和冻结核心文件；不审核首片03美感，不授予G2准入，不证明完整CI或发布。

本次结果只适用于记录时的来源/配置和只读检查输入。之后计划进行的联合宏观RETHINK、空间地形/平台/镜头布局修改不在这些检查的验证范围，必须另做适用的真实路线/像素验证。135文件核心证明可在改布局后再次按同SHA核对，无需为未变核心重复无关测试。

## 实际轻量命令与时间

从原`tools/harness/profiles.json`读取实际argv，均通过原`tools/production_timing.py run --stage verification`运行，真实stdout/stderr分别写新log，没有改源或调用Godot。以下全退出0：

| 原check | 实际命令 | 原输出 |
| --- | --- | --- |
| docs | `python3 tools/check_docs.py` | PASS: 33 required documents, local links, 210 task dependencies and tuning. Game runtime not tested. |
| world | `python3 tools/check_world_design.py` | PASS: confirmed 16-region pool / six-stage framework, candidate 29 whitelist edges, source hashes and plains-only runtime boundary. Runtime not tested. |
| structure | `python3 tools/check_project.py` | PASS: project structure, 15 skills and harness profiles. Runtime not tested. |
| creative-direction | `python3 tools/region_creative_direction.py --directory docs/creative_direction` | PASS: 2 versioned creative directions; no runtime, art or player acceptance inferred |

原运行记录在`build/spatial_golden/delivery-readonly-checks/`；精选原字节复制到本目录[readonly-delivery-checks](readonly-delivery-checks/report.json)，含四个log、append-only timing.jsonl和聚合report.json。原event的command/log路径和来源不回写。四项并行区间并集0.142989397秒；各命令包络约0.041337/0.057465/0.084503/0.142987秒，求和不等于墙钟时间，更不外推整轮模型或生产成本。该计时仅含这四项，不包含本报告静态读审、资产验证或SHA盘点。

## 新资产来源与catalog

`assets/spatial_golden/bell_rib_kit_v1.png`、`kit.json`和`docs/quality/asset_records/spatial-golden-kit-v1.json`共同指向原图SHA256：`20cf8c0a5c36761dc247d4e6df61fae00b8d7b91886092cc6c217d5584cbeafb`。实际PNG为1536×1024，与catalog一致；六个Atlas region均在画布内；生成prompt存在，catalog.source_original原图仍存在且与运行PNG逐字hash一致。调用原`quality.validate_asset`返回空错误列表。

这不等于艺术认可：record明确runtime_candidate、显式实验用途、visual_status=unverified、license_status=unknown，无用户认可；alpha尾部及padding问题已在catalog如实记录，需实际GPU/边缘审查。来源记录保留一次真实图生44.75秒的原时间，但本次没有重新调用图生或验证其美感。

实际消费链：显式preview/capture把`DemoApp.spatial_golden_requested`设true → `PlainsSpatialGolden.generate`以FileAccess读`resources/generation/spatial_golden/against_wind_v1.json` →碰撞和画面共享golden_manifest → GoldenStage在有脚本时动态load `scripts/art/plains_spatial_golden_art.gd` →其_ready以FileAccess读kit.json、以load加载PNG，按组件region/pivot/等比尺度构造AtlasTexture。不是把整幅概念背景冒充正式空间。

## 默认运行与导出边界

DemoApp的spatial_golden_requested默认false；本次找到的true设置只在显式tools/spatial_golden_preview.gd和tools/spatial_golden_capture.gd。普通生成走原分支；实验禁meta持久化，也不自动登记为正式Manifest内容。上述结论来自源码调用链，不代替原生生命周期/保存/两图回归。

Windows、Android、Web三个preset的exclude_filter都显式包括`assets/spatial_golden/*`及`assets/creative_direction/*`；运行kit/catalog/提示来源均匹配排除。默认普通地图没有动态调用这个Art._ready，因此未发现默认流程消费新kit的源码依据。

限制：所有preset仍是all_resources；实验generation脚本、art脚本与新shader没有全部被显式排除，DemoApp还有PlainsSpatialGolden静态类型引用。因此不能宣传“所有实验字节均不入默认包”。本次没有运行导出、检查PCK导入映射或公开包，不能据exclude配置宣称实包已证没有kit/候选资源。布局JSON也不是当前preset显式include的raw FileAccess载体；若以后制作实验导出，必须另核JSON和动态kit的实际入包与匹配消费者，不能直接使用当前默认preset并声称实验可玩。

## 核心字节证明与剩余风险

[protected-core-sha256.json](protected-core-sha256.json)逐文件列出135个tracked保护文件的基线/当前SHA256：Player、Combat、Build、Run、Save、资源定义、随机流/Manifest、核心config、Player/Weapon资源等与PR72逐字一致，差异0。该证明不包含本轮允许改动的DemoApp实验接线、地形生成或新表现脚本；“核心文件没改”不等于新增实验几何已经可玩或所有运行行为无回归。

剩余风险：首片03像素仍待独审且计划宏观RETHINK；新的地形/镜头必须重新验证真实路线和完整屏幕，不能沿用旧片或旧Manifest准入。新kit仍是未知许可/视觉未验候选；第二结构/多Seed/扩产须先过第一黄金真实G2与独立媒体/路线门槛。完整原生/性能/导出PCK/CI、手机手柄、玩家与商业评价均未由此报告验证。没有借轻量四绿替代这些门槛。
