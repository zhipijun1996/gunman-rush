# 返程整合两次失败与设计淘汰

本包追加保存真实 `migrant_return02`、`migrant_return03`，不覆盖[检查点02](../checkpoint02/README.md)的任何ZIP或原失败。两次请求各一例 Seed00/图2/growth，均源稳定、whole **FAIL**；完整16/80及CI没有因此通过。

- **return02**：真实经396中继、drop到600下层及step1成功；旧步行回程随后被新实体树皮 `[35,516,60,330]` 挡住。最终leg28/candidate_same_reward_return_to_W预算耗尽，原末帧中心约 `[22.991,599.998]`。不是整段完全不可进入，也不是H未命中。
- **return03**：明确的清脚跳越过树皮，但落到north_court的450支撑面；tick2118真实NPC接触伤1，HP5→4；最终在该支撑、leg28/candidate_return_bark_crossing预算耗尽，W600未到。末帧HP恢复为5，不能把中途受伤直接写成最终血量4。普通跳局部成功不能改签完整返程。

**设计决定：淘汰继续补清脚跳这条返程方案。** 若为挽救它继续加入north/drop/等待NPC，就会把自然回程变成重复劳动；不以加动作数量充当更有趣的探索，也不更换断言签过。以上结论是有据的局部设计取舍，不证明所有输入都物理不可能。

替代假设是正式region派生的树洞：在原600返回高度保留 `y560..640` 的80px开口，上树皮仍516..560（44px），下树皮640..846；保持原共享factory不动。它把旧回程接回同一共享树体，而不是再加攀爬台阶。**截至本包整理时该内容正在实施、尚未实际验证**；24×36身体的纸面余量不等于真实碰撞/射线/NPC出返成立。后续成功须追加新收据，不回填本包。

[selected-failures.zip](selected-failures.zip) 包含两次原receipt、import/native log、完整实际capture及可按原输入SHA匹配的源文本；包内 `ARCHIVE-INVENTORY.json` 与外部[inventory.json](inventory.json)记录逐成员SHA和全ZIP身份。所有原raw仍在原build，没有复制缓存/AVI/音频。[source-custody.json](source-custody.json)明确哪些历史代码仅有原hash库存而未捆绑真实文本，不声称完整旧项目可离线重放。[package.py](package.py)只整理原件，不运行游戏。此为证据整理，非该方案作者独审，也非真人/趣味验收。
