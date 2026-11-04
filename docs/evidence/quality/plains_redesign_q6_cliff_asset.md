# PLAINS-REDESIGN-Q6-CLIFF-ASSET-01：唯一资产生成失败，停止接入

本阶段 **FAILED / blocked**，没有改善为可验收的庭院/井口美术。唯一一次真实 `image_gen.imagegen` 已按原 brief 的固定 prompt、两张实际看过的项目参考图、`transparent_background=true` 执行。工具返回 PNG dataURL 和真实本地原件路径；逐字节复制保留，没有图片编辑、重新编码、抠图、调 alpha 或第二次生成。

[新证据索引](../evidence/plains_redesign/q6_cliff_asset/index.json)保存原PNG、真实prompt/返回元数据、参考SHA、完整brief原件、alpha测量与本请求；旧 Q6 源码、四片失败电影和卡保持原字节。参考仅沿原 v8 暖白石灰岩/冷紫阴影绘画语言，不冒称新资产被用户认可。模型与许可均为 `unknown`：实际工具没有披露，不根据图片 hint 臆造。

## 可复现的资产失败

原件 `/workspace/generated_images/exec-d2392eff-e74c-49d9-b62f-00497138957f.png`，SHA256 `ccf7260f710b014b3fc0e145e887c01841e78524b098eecf37870cb369805ea2`，2452007 bytes，1536×1024 RGBA，alpha范围0..254。原图确有透明像素，不能误述成不透明整图。

冻结规格要求贯穿全高的完全透明中缝至少约宽度2%（此图需31px），实际中央最长仅7px；上边51个、下边548个像素alpha非零，主体alpha>0范围触及y0和1024，没有完整外透明padding。实际view原图可见低alpha灰/光晕背景残留，两侧宽底地质体落在近同一水平裁切底，未达到两块高侧壁及自然下延根部规格。低alpha噪点与主体≥128的测量分别保存；不能切掉噪点或放宽全高gutter条件来得到PASS。实测半幅仅作诊断，没有被注册为可用Atlas采样区。

这些是原始输出可证伪的准入失败，不是游戏物理失败。没有启动Godot、浏览器、ffmpeg、两处新黄金或原十项运行回归，因为最前置资产已被拒绝。没有修改Composition/Scenery/原59断言/14实际Node/14收据反例、19driver、133core、Camera/UI/Gen/Definition/物理/资源/能力/RNG/save或已有资产。

## 未推广与停止边界

未创建正式PNG/JSON/import，未添加assets/manifest或宣称真实运行消费者。旧资产记录格式要求真实runtime消费者，因此仅在本阶段证据树保存“未接入的失败资产来源”，不伪造consumer填入全局asset_records。原有失败构图也未自行回滚或覆盖，等待父任务在本原controller真实blocked终态后按明确授权恢复已验C2表现。

实际生成额度已用1/1，不重新抽图、不改旧阈值、不加预算。本记录的透明技术合同与视觉准入failed；正常游戏合屏、完整音画、独立品质审查、实体设备及用户趣味/审美认可均未验。整体品质任务仍未完成，不能因保存了原图或工具成功返回就称关卡美术完成。
