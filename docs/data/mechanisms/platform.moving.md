# C03 移动载台

cycle 按局部路线折线和平滑时钟往返，在两端停靠。call_dock 从指定岸停稳出发，在岸边交互召回或上车交互去另一端。manual_cart 上车后再次交互取得驾驶，左右驱动沿轨道弧长加减速；跳跃解除驾驶，玩家保留真实地面起跳，矿车无人时制动。follow_water 引用同房同挑战的水位并固定横坐标，水面受挡仍可前进，载台按水面速度追回。

原生端帽与铜边包住按区域选材的台身，真实顶面标明落脚边沿。呼叫停靠的岸边绞盘有独立基座，矿车轮对沿轨道转动，浮水模式在台底装设浮筒，水位越过台身时显出水痕。联动踏台的轴销与吊链或轮辐相接。[台面素材及尺寸](../../../production/assets/underworld_plains/mechanisms/mechanisms_fine_build.json)

[定义与可配参数](../../../production/config/world_elements/definitions/platform.moving.json) · [行为合同](../../../production/config/world_elements/behaviors/WorldMovingPlatform.json) · [设计定稿](../失序之钟_基本机关库.md#c03) · [真实角色验证](../../../production/tests/carrier_library.gd)
