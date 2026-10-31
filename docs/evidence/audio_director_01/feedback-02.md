# 第一次用户试听反馈 · 2026-10-26

来源：本会话，第一阶段Sound Lab与PR109交付后的用户直接反馈。原文保留：

> 没有真实场景没法很好的对比。但是我炸听之下，新的两个方案都不太满意。原声音部分挺好的，比如起跳落地，但是ui，拾取，命中，受伤等不太符合。没有开源的建议音效吗？

## 已成立的判断

- audio-director-v1 的 A/B 两套方向均未获接受；按用户听感拒绝保留，不推广到正式默认，不把工程通过或CC0许可当听感通过。
- 原起跳、落地获得本次正面反馈，作为下一轮保留基线；这是相应原声音的认可，不是全套原声或全新音频的批准。
- UI、拾取、命中、受伤是下一轮重点。用户指出缺少对应真实场景，不以已有全游戏入口/Home样板声称该问题已解决。

## 修订约束

下一轮先筛现成、可商用的单素材，提供原文件听音与最小剪辑版，不再成套重做所有动作或用装饰层遮掩不合适的选材。保留原起跳/落地，其他未明确评价的原声保持现状。旧A/B及失败记录保留用于溯源。

试听需直达三种可重复的实际消费者：真实UI菜单确认/拒绝；实际金币/生命/普通奖励拾取；真实敌伤/主角受伤战斗。必须同一场景、同BGM、同事件切换原版与所选素材；不要求用户为听一个命中先走完整地图。当前站点未更新这些专用场景，不能宣称已交付第二轮。

## 现成素材研究（许可已核，听感未批）

| 来源 | 许可/作者 | 适用筛选 | 当前边界 |
| --- | --- | --- | --- |
| https://kenney.nl/assets/ui-audio | CC0 / Kenney | 按钮、开关、点击；优先实体触感 | 官方50文件；OGA早期51文件是同一家族，不冒充两个独立来源 |
| https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks | CC0 / Kenney | organic clicks/switches原录音 | 页面说明预览为低质MP3，最终以原WAV包选材 |
| https://opengameart.org/content/80-cc0-rpg-sfx | CC0 / rubberduck | item_coins/item_gem等金币/宝石/物品原声 | 上轮已取部分原料；这次应直接比较原素材，不假装全是新来源 |
| https://opengameart.org/content/100-cc0-metal-and-wood-sfx | CC0 / rubberduck | 木/金属小机关和对应材质命中 | 不将金属/木命中无差别用作主角受伤 |
| https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx | CC0 / rubberduck | 敌人接触、破裂与材质命中 | 与主角受伤警示分义；重破碎声未默认接受 |
| https://kenney.nl/assets/casino-audio | CC0 / Kenney | 筹码、卡片等小物件实体声，可作旁选 | 不是金币专包，不将chips错称coins；先筛匹配的原声 |

CC0可商用、可修改、无强制署名；本项目仍保留作者/来源。此处是素材包级许可与语义核验，不是已听选出最佳文件。原下载与新研究缓存保存在workspace/scratch，未用整包不进入游戏仓库。JRPG Style UI Sounds为CC-BY3.0，不能标CC0；本次优先名单不依赖该包。

## 实际取得的原包

本轮成功取得Kenney UI Audio、OGA同族UI原WAV、100 Metal/Wood、75 Breaking/Falling/Hit四个包；Casino下载超时，保持只研究未取得。全包只在本机缓存，不提交运行资源。包级来源/下载日期/许可/原ZIP/页面SHA见[source-research-02.json](source-research-02.json)。文件清单已核，未宣称这些文件已听选通过。
