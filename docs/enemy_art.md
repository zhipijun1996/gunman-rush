# 平原 Demo 敌人美术

交付路径：`assets/enemies/plains/`。使用原创 AI 编写的 SVG，象牙白外壳、黄铜骨架与深色轮廓沿用平原机械遗迹；敌方采用红橙眼、菱形瞳孔与下方齿状轮廓。训练靶采用琥珀色同心圆，避免与青色补充物混淆。

全部素材透明背景、128 × 128、中心锚点 `(64, 64)`。每个分层文件保留完整画布，body、rotor、eye 使用同一锚点即可叠加。转子实际旋转中心为 `(64, 25)`；运行时转子节点需使用这个局部中心，不能围绕整个角色中心旋转。

## 状态和集成

- `patrol_drone_idle / patrol / patrol_alt`：待机和巡逻两帧。运动由敌人 Motor 驱动，图像不能决定移动、命中或碰撞。
- `patrol_drone_hit`：短暂受击反馈，由 damaged 事件驱动。
- `patrol_drone_dead`：停转与熄灭眼睛，由 died 事件驱动；碰撞和奖励由玩法系统处理。
- `patrol_drone_body / rotor / eye`：可组合的静态层，用于连续程序化转子动画。
- `patrol_drone_telegraph_reserved`：仅预留攻击提示图，当前巡逻敌人没有新增攻击行为或计时。
- `training_target_active / hit / dead`：训练战斗靶状态。
- `health_pip_full / empty`：可选血量符号，实际渲染可縮为 12–20 像素，纹理需采用线性过滤。

图案最大范围留有画布边距。随机模块只引用 enemy definition 或 target definition，不从贴图透明度生成碰撞，也不让装饰随机流选择敌人状态。新区域可更换壳体材质，但红橙眼与齿形敌方识别规则保持稳定。

## 生成与验证

运行 `python3 tools/build_enemy_art.py` 可确定性重建 14 件 SVG 与独立清单片段。生成脚本使用 Python 标准库，逐件解析 XML。资源属于游戏用矢量套件；与精细绘画概念图相比细节密度更低，以保证小尺寸状态识别。清单含尺寸、锚点、碰撞边界约束、来源与生成方式。

Godot 导入、实际敌人场景挂接和目标手机可读性必须由集成阶段另行验收；XML 通过不能替代这些检查。
