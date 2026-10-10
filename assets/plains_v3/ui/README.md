# 平原 v3 UI 补充

继承用户认可的风铃平原精细手绘、象牙石、黄铜、少量花叶风格。新增三张透明原图；已合格的主标题、家园、NPC 与旧按钮/面板素材保留，不重复生成。所有数值和文字由引擎 Label 显示。

`icons.png` 提供满/空血心、蓝跳跃菱晶、金双反冲箭头、局内金币、永久音符，以及金币/回血/商店/道具徽章，另有技能与武器备用徽章。金币与音符不是同一资源，蓝菱晶与双金箭头不是同一动作资源，不替代 Health/Stamina 的数据契约。不预设最大血心、动作次数、兑换率或价格。

`combat_boss.png` 补充双枪战斗与独眼钟械 Boss 徽章。最新正式六类出口为 combat/item_reward/coin_reward/health_reward/shop/boss，精确映射见 manifest.stage_type_mapping；技能/武器图仅额外候选图标，不新增关卡类型。

`rarity_frames.png` 提供白、蓝、紫、金四框。现有 `StageRewardModal` rarity 枚举 0/1/2 仍分别对应蓝/紫/金；白框为备用样式，不能据此新增白品质玩法。卡框为等比整体贴图，不是已验证九宫格；建议未来卡式布局使用，当前 260×100 奖励 Button 不应直接拉伸套入。引擎可在透明中部放低对比填色面板，后叠图标/标题/效果与按钮焦点。

`manifest.json` 的 region 来自原 PNG 主体 alpha 测量，不按机械等分网格。使用 AtlasTexture.region，保留各图的宽高比，以 recommended_box_px 作最大显示框居中。`safe_content_rect_local` 是未缩放区域内的文字安全区；卡顶部风铃与四角花饰不得覆盖文字。新 PNG 均未经裁剪、抠图或像素编辑，原文件仅复制，哈希可校验。

现有 ActorResourcesHud 保留资源订阅和输入穿透，新的装饰只由资源 snapshot 决定显示。血心美术不代替连续 HP 数值条，非整数 HP 或大容量建议继续显示原数值与条形；动作图标只能由真实跳跃/射击余量消费者使用。DemoMenu 保留设置、帮助、构筑、返回确认及 App 动作取消控制。

验证：3 PNG 都为 RGBA，含完全透明像素；18 region 全在原尺寸内；哈希写入 manifest。未运行运行时接入或目标设备可读性验收。
