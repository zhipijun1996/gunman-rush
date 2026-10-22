# PLAINS-GOLDEN-01 · M1 两候选，待独审

可玩源码 `931211b`，场景 `res://scenes/dev/plains_golden_01.tscn`；A/B 可随时新开，真实 generic-scene Preview 可返回完整原游戏菜单。尚未 Web 导出或发布，不使用旧 URL 冒充。

[连续实机比较 MP4](comparison.mp4)：A 7.233秒，随后 B 4.117秒，原生1280×720 /60fps，真实 MovieWriter 画面与音轨。原片在本工作树 `build/plains_golden_01/m1/movie-a-01`、`movie-b-01`，各自完整 runtime/trace/source guard 在本目录对应子目录；MP4 hash/大小与编码命令在各 report。比较只拼接两段真实动态影片，没有静图拼接或插帧。两片驱动同字节，但实际路线与输入因候选不同而异；不是逐tick纯美术 before/after。

| 真实输入策略 | A | B |
| --- | --- | --- |
| 目的：开铃、拿6金币、实际回出生岸 | 424ticks，1shot，5jumps，HP5 | 232ticks，1shot，3jumps，HP5 |
| 安全/分离动作替代，同奖并返回 | 488ticks，1shot，6jumps，HP5 | 292ticks，2shots，4jumps，HP5 |
| 低路主出口 | 163ticks，0shot，2jumps，HP5 | 248ticks，0shot，2jumps，HP5 |
| 去射击消融（保留实际输入与失败） | 卡在关闭奖励门前，未取奖，exit1 | 未登上回流桥、未开铃、未取奖，exit1 |

ticks是此fixture的引擎旅程，不是真人时长。所有旅程从场景初次真实创建的位置出发；不做中途搬运、手动 Motor.step、资源注入、关闭敌人或修改物理。低路提供保底主路；射击的新增价值限可选奖励/更短回流。A退化打法相对目的只多一次跳跃，差异偏弱；B把开目标、向上位移和转向返回合在一发中，有较明确假设，仍需独审与真人操作判断。

原生 `lifecycle.json` 为14检查/0失败：真实 generic-scene、原角色/怪物视觉、原能力边界、正式接受弹体、暂停冻结、换候选取消旧life/actor/弹体、独立会话账本、返回完整菜单及无Meta持久化。它不是Web浏览器/真机检查。

保留两轮pilot失败：A初版driver把第二次跳跃立即释放，停在领奖阶；B初版便宜打法地面反冲后仍从低位置起跳，未重新到计划发射点。只修driver的持跳计时/实际到位条件，没有改 PlayerMotor、参数、资源或布局。无射击消融是预登记对照的真实未达成，绝不改签成成功旅程。

作者已看实际影片抽帧 A1.5s/4.0s、B2.7s/3.3s（时间相对各原片，非精确物理tick）。A现在可见阶梯状低恢复与高接收岸；B可见向前射击、向后上桥、门后领奖的关系。仍有大项未解决：同族黄昏与Bible晨光不合；A仍以矩形石台为主；B长直木梁及高位门箱靠近HUD；环境仅原尘点，未形成Bible的草浪/风车生命力。diver存活并启用攻击，但这些旅程没有击中/击杀它，不能由存活演员签战斗反馈或战斗压力完成。未完整听音，不签音频审美。未进行独立像素/机制淘汰，不推广第二空间。

总控下一步：只读看电影、抽帧及原生原因果，并实际尝试最便宜替代，给 A/B 分别继续、REWORK 或 DISCARD。内部独审不代签用户/FUN/艺术/设备/商业黄金。总控安排最新源码的轻量Web导出、独立托管与实际GUI；本工作线不建PR、不跑完整CI、不合main、不改共享文件。

恢复：source专属env，直接运行场景；复采使用 `python3 tests/drivers/plains_golden_01_capture.py --candidate A --output build/plains_golden_01/<全新目录>`，B同理。未出现新代码/新失败不重复既有检查；未验项在本任务卡保持unverified。
