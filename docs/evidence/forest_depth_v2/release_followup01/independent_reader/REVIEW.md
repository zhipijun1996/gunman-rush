# Guardian→Map2 identity reader migration

**ACCEPT，限定单文件读者迁移源码与离线原件。** 绑定 immutable commit `df3f162ac7c49f0bcdfe56c3d4093a3f49d289aa`；reader SHA256 `5b4d88c2060b0ed0ebccfb7a53be91f4a51e29e9f9e508793657d84355848851`，Git blob／实际工作文件逐bytes一致，审查时Git clean。不是新native、完整CI、森林内容、device或fun准入。

## 实际问题

原0cf/run39089359464完整日志明确在旧reader line132要求experimental_whole_boss_pending时AssertionError。API digest绑定原ZIP SHA b786aeaf9cbfd51c92b56c75d232eec22a515cab8e813bc903a2ad44b8e225c9；选取capture SHA0a0828d2b95c515e239df6cb634bede4a806eb107c18e4a7941eddfc9b3f6ae4。实际native为25/0且map2实际装配Canopy scene/resource；新v10合同本来是candidate_whole_boss_pending。独立离线原完整reader仍拒该CI raw，新完整validate接受。只证明该首败是reader过时，原CI失败与49已过范围不重签。

## 改动与拒绝边界

实际仅tools/run_forest_depth_campaign_boss.py +37/−3，新增一个身份helper与有限常量，原validate／validate_canopy只替换身份检查。其余既有函数AST相同，包括真实输入／伤害因果、pointer／map2、旧Queen、Canopy ledger与main；Godot消费者、输入、原断言、阈值、超时、strict错误过滤与sourceguards未改。

新分支同时要求region version／forest／严格int map2、成功bool ok、v10布局、exact三键contract/scene/resource字典、geometry version/boss_contract及candidate admission。旧分支只能显式allow_legacy=True且布局属于v2/v4/v7/v9四白名单，无boss_content并要求旧完整version/contract/admission。Canopy调用不允许legacy；未知／空／错误类型布局不会fallback。商业或旧admission也不被新v10接纳。

## 独立实际离线检查

复跑原audit一次（结果仅写本目录，不覆作者原件）：真实CI完整Guardian case与两个完整历史v4/v2 case均接受；36个新源错误／删除／混版变体加8历史混版变体共44拒绝。另读取真实v7/v9原Manifest，两者身份helper接受（非完整Guardian实例复跑），Canopy默认拒两者；新增6未知／错误类型layout拒绝。再从durable Canopy App03原包直接读取actual03/capture.json.gz，新完整validate_canopy接受，未重采。全部哈希／实际结果见AUDIT.json。

未发现本次身份迁移造成unknown／new-old混版放行。这个helper刻意不是全Manifest几何重建／跨字段完整性证明；既有RunManifest检查、几何／保存／combat验证仍按各原消费者范围，不能据身份一致推断所有内容已准入。两历史完整case不冒称四旧版本所有case全重跑。下一目标native7／最终同源CI由主代理执行，本审不预签其结果。
