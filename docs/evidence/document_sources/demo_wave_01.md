# 商业 Demo 第一批并行工作线

总控为当前主会话。先完成 CLOUD-EFFICIENCY-01、通过相关检查并合入 PR103，再以实际 merge SHA 同时启动下列独立分支／工作树。各线先记录精确基线和写集，PR直接向main；总控负责共享文件、托管容量及集成，不允许生产线自行合main。此页是本批调度合同，不另建任务或质量状态系统；状态沿用 [tasks](tasks.md) 及每线检查点。

## PLAYER-PRESENTATION-01 · System Engineering

初步Prompt：从最新main审计正式主角的身体、上身／武器、锚点和动作事件，优先复用当前UnderworldPlayer、PlayerVisualAdapter及现有动作资源。用“移动中转向／射击反冲→受伤中断→恢复／死亡”作为第一里程碑，先找真实连续画面的最明显缺口，再交付一个正式消费者的可配置表现改进。表现只消费已接受事件，不改Motor、输入、物理、伤害、资源或授予。保留不同角色与旧消费者；本阶段不批量制作全套动作。

写集：`scripts/underworld_plains/underworld_player.gd`及自身UID、`scripts/art/player_visual_adapter.gd`及自身UID、`assets/characters/courier/courier_visual.gd`及自身UID；新增任务专属资源／测试／驱动／文档／质量记录。现有共享动画母版和引用它的Bible绑定先由总控协调，不能直接改PNG后刷新旧SHA。`DemoApp`、正式场景、共享配置、Harness与通用音频不归此线。

交付：同条件真实Godot短片＋可操作独立Preview；先Development专项与真实正式主角，合入前由总控安排受影响完整集成。采用player-creator、animation-vfx及game-quality-gate；用户手感／审美和真机保持未验。第一检查点给出实际消费者清单、拟改接口及一个可证伪的样板目标。

正式平原与家园实际创建UnderworldPlayer；pixel分支禁用PlayerVisualAdapter并隐藏Courier身体，后者仍提供枪口锚点，不能只验ActionStudio／Courier。共享style直接绑定UnderworldPlayer脚本和三件body资源：任何一件变化先向总控提交版本化影响分析，由总控组织独审及显式重绑，不自刷SHA；平原线在共同基线继续只读比较，消费新主角前统一重验。

## ENEMY-FEEDBACK-01 · System Engineering

初步Prompt：盘点当前普通怪物已有命中、受伤、死亡、恢复与卸载反馈，复用EnemyPresentation、UnderworldEnemy和正式伤害事件，避免另造重复系统。选择体型／运动方式不同的两个现有普通怪物，完成共享但可配置的反馈样板：只对已接受命中响应，死亡／掉落幂等，暂停、重载、旧epoch与恢复死体没有重复演出。保留各自材质、动作节奏和轮廓，不改AI、伤害数值、碰撞、奖励或Boss阶段，不批量推广。

写集：`scripts/enemies/enemy_presentation.gd`及自身UID、`scripts/underworld_plains/underworld_enemy.gd`及自身UID；新增任务专属表现组件／测试／驱动／文档／质量记录。`EnemyActor`、Definition、ForestBibleActors、共享材质母版、音频与正式场景由总控持有；需要新信号先提接口请求。

交付：真实弹体造成命中／死亡的同条件短片，机制需要操作时补独立Preview；不得直接调用反馈方法冒充正式命中。采用animation-vfx、game-quality-gate，行为范围扩大时采用enemy-creator。先Development反馈专项，合入前完整受影响系统与正式消费者回归。第一检查点给出现有系统复用结论与两代表对象选择依据。

UnderworldEnemy继承PixelPlainsEnemy／WindchimeEnemyVisual，正式安装器会替换旧EnemyPresentation。两套继承链必须分别接入所选共享组件并验证，不能改一个就宣称统一完成；父类死亡计时／可见性保持只读，确需调整先请求总控分配。

## PLAINS-GOLDEN-01 · Creative Exploration → Long Production

初步Prompt：完整阅读风铃平原V2 Bible、当前创作总谱及共享Underworld16px／32wu母版。审计正式平原的空间、构图、环境动态与战斗读图，只选择一个能体现跳跃—射击—反冲决策的黄金切片。先用现有合法资源和真实Godot消费者对比两种构图／探索组织候选，说明目的打法、最便宜退化打法和取舍；通过独立实际游戏审查后，才扩展到第二空间和正式整区。不是完整平原重制，也不能以技术可运行签艺术或趣味通过。

写集：新增 `scenes/dev/plains_golden_01.tscn`、`scripts/dev/plains_golden_01.gd`及自身UID、任务专属测试／驱动／文档／质量记录；现有正式生成器、模块池、共享资产、角色与怪物系统只读。需要改正式消费者或母版时由总控前置分配，不向本轮另两线抢文件。记录完整Bible／style来源SHA；BGM仍待用户提供。

交付：两个真实候选的必要短片和一个可操作独立Preview，允许先交前期检查点再继续长线制作。采用region-generator、visual-director及game-quality-gate；第一检查点给出缺口证据、候选假设、真实入口和明确淘汰条件。

## 总控交接边界

各线在自身分支保留任务版本、阶段、源SHA、证据／失败、下一条命令和依赖；不修改主工作树，不假定独立Cloud会话能自动唤醒。当前工具能启动同一会话中的隔离代理；真正另开的Cloud会话使用上述Prompt、远端分支和PR恢复。发布按独立托管容量排队，不覆盖活跃Preview或正式试玩。接口变化、第二空间推广和里程碑进入下一阶段前由总控组织审查，人工反馈可以直接触发原线修订。

各线只写自身ID命名的记录／证据／检查点，不并改中央tasks、current_state、handoff、Harness或配置；现有UID保持身份，新增资源才生成自身sidecar。已审计的正式主角／怪物路径有Development有限映射，Integration仍full；新组件与dev场景默认保守full，由总控在真实消费者审计后登记精确映射，工作线不能自行缩减计划。平原候选可由现有generic-scene Preview直达，不需抢DemoApp菜单文件。
