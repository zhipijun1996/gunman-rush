# 操作与输入合同

重做工程的角色从 InputRouter 接受移动、交互、跳跃、瞄准和释放射击。地形、射击、技能和界面各自消费已接受的动作。设备映射、摇杆阈值和半径以[输入配置](../../production/config/input_profile.json)为准。

## 键鼠

A/D 或左右键移动，空格跳跃，W 或 ↑ 对世界内可用目标执行互动。鼠标指向决定瞄准方向，左键按住瞄准、正常松开发射。向左下射击可产生向右上的反冲。取得钩索后可用右键或 E 瞄准并释放。键鼠边沿与失焦取消由[键鼠适配器](../../production/game/platform/input/keyboard_mouse_adapter.gd)处理。

## 触屏

左侧摇杆移动，右侧拖动瞄准、松手射击。横屏 HUD 提供独立跳跃、互动和地图按钮。跳跃与瞄准捕获不同手指，UI 触点由该控件消费。显示动作、按钮位置及当前设备提示按[真实触控层](../../production/game/platform/input/room_touch_controls.gd)和[输入路由](../../production/game/platform/input/input_router.gd)核对。

## 地图与提示

M 或触屏地图按钮打开地图。M、Esc 或轻触地图关闭并恢复游戏。地图展示当前房间、已到访的已绑定房间和已实际触发的隐路发现。打开地图不自动发现邻房。[世界地图](../../production/rooms/world/world_map.gd)

新进度从 P01 起身、走近地上枪械互动拾取。在风坡告示附近才显示阅读提示，读牌和拾枪各自消费交互。P02 让玩家尝试空中反冲、观察落点和恢复路线。提示说明眼前可执行的动作，成功由真实动作或收据判定。实机回放与对应版本见[开场三房](../project/worklines/room_rebuild/scope.md)。

根工程的手柄校准、标题／暂停面板和 P03、P21–P24 教学顺序见[冻结输入合同](https://github.com/zhipijun1996/gunman-rush/blob/f27b46819d2d95e7bad1a8572f85a57d117cfdb9/docs/bible/controls_contract.md)。重做版本的设备覆盖以真实适配器和该版本输入验证为据。
