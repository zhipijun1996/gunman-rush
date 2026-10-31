# 单独原缺陷的有界真实 App probe（计划，未运行）

原静态说明及C59绑定：../p11-cache-composition-design/preexisting-defect-note.md。此probe不加入P11 production/正式测试，不将原拒绝标成重构新成功；是否修复是另一功能范围。

一次新App、一箱、一seed，原native flags、90秒硬上限、总最多96 physics frames，不循环寻seed/调参：

1. 真实DemoApp，meta persistence disabled，start_plains("cache-unregistered-item-original")。按既有cache_app await64帧让保护期自然结束，关闭App自动拾取/真实contact/hazards以隔离交易（与现有fixture一致披露）。玩家保持真实满血。
2. 选一个原medium箱；既有ItemV5Pool.configure seam提供原B03/B11（均blue/当前catalog），调用原 _v5_cache_items 一次冻结draw，要求恰两eligible；否则 setup_failed，不换seed。设置该箱 resources模式、原coin16+heart2声明。确认 RewardService.get_offer(chest.id)==null。
3. 只作既有fixture入口定位 player.position=chest.position，原 _region_interact。记录 offer完整types/IDs/kind/amount/rarity、service有无offer、真实pool manifest；预期coin + frozenItems[1]。不新造选项或直接调用policy。
4. 原 _claim_modal_item(实际第2项ID) queued request，await原3帧；记录未提交：库存/count、wallet、meta、chest.claimed、ledger、modal仍开。不能直接读/写service私有表、不能重写claim返回。若实际接受则假说被反证，保原数据。
5. 仍在同一modal选择实际coinID，再await3帧，记录只钱包+16/claim完成/物品未入库存。用于排除整个modal坏掉；不是修复第一项。
6. abandon，复用AudioTeardown.drain_world（其原1000ms拒绝保持），free，再2帧；strict errors/leaks拒绝。输出真实前后receipt+source/editor SHA。任何setup失败或缺字段不算已复现。

这确认的是原资源模式fallbackitem未向service登记，不能代替自然seed覆盖/GUI/全面奖励验收。独立修复需决定“资源模式排除物品”或“登记该补位物品”等产品合同，P11不代作选择。
