# 世界行动宿主

给可交互对象绑定本房行动 ID、作用半径与所属 section。配置 `action_owner_id` 时，由 G16 的射击锁扣启动这次行动。独立宿主使用接近交互。宿主读取行动的资格和收据，开箱等庆祝效果在提交成功后才播放。

[行为与字段合同](../../../production/config/world_elements/behaviors/WorldRoomInteraction.json)

[版本和默认参数](../../../production/config/world_elements/definitions/interaction.action.json) · [机关目录](../world_objects.md)

## 区域外观

可直接交互的世界行动在底座上显示区域支座和顶饰；由预组代办的行动仍通过该组的可见机关呈现。

## 木台金币宝箱

房间行动使用 `type: coin_chest`、正整数 `amount`、承重台面的实例 ID `support_id`，宿主外观选 `chest`。箱脚由宿主位置向下 18 世界单位对齐台面。进入半径后，只有脚下实际碰到该承重面的角色才能主动开箱。开盖收据与实体金币掉落同次保存；钱包在玩家实际拾取后入账。重复交互、重访或读档保留开盖状态，尚未拾完的金币从存档恢复。
