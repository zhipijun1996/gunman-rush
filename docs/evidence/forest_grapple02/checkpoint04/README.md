# 80px返程树洞：原严格拒绝与正式单例通过

本包保存 `migrant_hollow04` 与 `migrant_hollow05` 的原始收据、完整raw、日志和按各次真实输入SHA匹配的代码/配置。此前[检查点03](../checkpoint03/README.md)两次返程失败及淘汰决定不覆盖。

## 原结果

- **04：native exit0，40段已完成，但外层仍严格FAIL。** 原reader拒绝 `leg_28_crossbranch_return_via_twelve_support`：中继2px窗口未满足。保留全部失败，即使原生自报完成也不能签过。
- **05：同 Seed00/图2/growth 单例 strict PASS，source_stable=true，完整40段。** 驾驶端收紧稳定站位到≤2px后，原reader未放宽。实际经中继/drop穿过新树洞并返回W，继续完整取奖/幂等与门状态流程；实际raw `cache_claimed`、`duplicate_checked`、`gate_saved_open` 均true。玩家全程最低HP5、最终HP5，不是靠补血把有伤写成无伤；末能量100、2枪。

实际树皮在原600返回高度开 `560..640` 的80px孔，保留上段516..560和下段640..846，只做region实例派生，不改原共享factory。05 leg28实际身体与树皮横向重叠区的20个记录帧中，24×36身体竖向包络约581.924..617.925，位于孔内；对应原真实Motor与碰撞轨迹，不是纸面通路。leg28在tick2150于W/step1支持完成，最终40段与接收稳定条件由原严格consumer验证。

这证明**这一个正式图2成长/返程消费者**的接缝与取奖闭环，不是完整16矩阵、固定80、全profile、最终CI、影片或发布通过。`matrix16_final02` 在本包截止时仍运行，其最终结果须另外归档。NPC及RHR局部进展不能外推所有相位、Seed、普通替代或体验认可；真人/设备/趣味仍未验。

## 原件与来源

[selected-originals.zip](selected-originals.zip)含两次原receipt、import/native log、完整capture。包内 `ARCHIVE-INVENTORY.json` 和外部[inventory.json](inventory.json)给成员/ZIP的SHA与大小，全部成员已读回验证。未复制缓存、音频或AVI，没有重跑游戏。[source-custody.json](source-custody.json)列出两次输入库存对应的真实代码/配置：只有当前读取字节与该次记录SHA完全匹配才保存到 `source_blobs/<SHA>`；缺失或不同者标明未捆绑，绝不把修后代码冒认04原源。05当前源的实际匹配情况以清单为准，不承诺从共同HEAD即可重建完整历史项目。

[package.py](package.py)只是证据producer，不调用引擎/验证器。这次整理不构成机制作者独审，不替代后续不同作者玩法审查、最终矩阵或玩家签字。旧02/03包保持原字节，所有原始失败仍在原路径。
