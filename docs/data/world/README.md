# 世界输入

重做版采用[世界探索网页](https://clock-world-explorer-1117.zhipijun1996.chatgpt.site/)的版本化设计输出。固定入口、稳定身份、导入命令和边界见[内容通道 V1](content_channel.md)；当前采用版本由 `production/config/imported_world/current.lock.json` 持有。

[本地版本锁](../../../production/config/imported_world/current.lock.json)指向不可变内容包。[房间绑定](../../../production/config/imported_world/bindings.json)给出每个已接入房号与 schema 3 文档的关系；核对某房是否可玩时，从对应入口验证实际路线与恢复。

网页提供世界连接、能力条件、剧情和经济定义。正式房间仍按[普通房间制作](../../bible/room_authoring.md)施工，schema 3 持有地形、实际敌人组合、数量和位置。网页候选敌群用于估算路线压力与金币，实际房间无需与候选数量一致。散币的奖励意图与参考位置供关卡设计使用，实际落点由房间决定。

旧地图和房号可在[冻结版本的世界输入](https://github.com/zhipijun1996/gunman-rush/blob/4f2bb5e41573e930603789c64b52a0c15a6a3dc4/docs/data/world/README.md)查阅。

本目录的 `metroidvania-migration-handoff.md` 是 2026-11-06 的迁移原件，其内容哈希供冻结工具校验。重做装备的实现与摆放按[永久装备定稿](../items.md)和[房间接入说明](../../project/item_authoring.md)维护。
