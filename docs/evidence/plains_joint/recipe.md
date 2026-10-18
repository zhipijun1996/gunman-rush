# 联合场所候选的实际制作入口

任务 PLAINS-JOINT-01，母PR84；运行冻结 f959e4a9，森林写集为空，P1只是用户偏好候选。先看[独审](independent-native-02.md)与[完整作品](gallery.html)，不默认读取历史全部PR。

同一输入不是把重复坐标放在同一个JSON：`resources/generation/environment_grammar/places_v1.json`的共享source_families保存实际源轮廓、站面和锚；joint_synthesis保存体块依附、有限变体、支持面语义绑定、树的保护路点、建筑脚点和景层绑定。`PlainsPlacePlan._joint_measurement`联合推导碰撞、完整图体、端口、安全站位、路线、敌人、焦点、设计视点和景层。旧重复世界坐标仅[归档](baseline_places_v1.json)按需读取，不是失败回退。

实际修改动作：

1. 从场所体验和正常相机窗口出发，选择能表达它的完整源家族；源不能表达就更换设计/家族，不任意拉伸。
2. 修改源轮廓或语义关系，让所有输出重新推导。不要分别手改碰撞、像素锚、路线和背景位置。本轮只证明0.3/0.4/0.6等轴变体，未证明任意形变。
3. 将具体可计算冲突变为真实拒绝。例如树根避开声明的arrival/rest/departure路点距离，棚的四源脚必须落在同一实际站面。`clear_regions`本身不是通用构图求解器，背景可与人物背后空间重叠，不能只靠AABB签遮挡或美感。
4. `python3 tools/run_plains_places_tests.py`检查当前真实编译、拒绝与数值结构。源→世界坐标先标量计算再构造Vector2，保留精确桥跨度检查，不能放宽消费者挽救错误坐标。
5. 手动实机：`bash tools/godot.sh --path . --script res://tools/plains_places_preview.gd -- --seed=places-contract-01`。严格捕获仍用原`visual_director.py capture`、`tools/plains_places_capture.gd`和原输入/退出生命周期。初末art.omitted、实际完整体/桥/附件/景层及显示站面与碰撞节点必须匹配；影片录制完成不代表全部美术已消费。
6. 先由不同作者看实际像素，区分局部可读性、连续构图、素材本身与工程问题，再决定是否复现第二结构。未达到黄金不扩正式池或整区量产。

当前方法只证明有限联合推导与局部入口改善，不证明自动艺术创作、商业黄金或用户风格认可。实际相机继续原玩家跟随；计划视点用于景层映射，不冒充新镜头导演。整岛轮廓重复、行经树根对比和高频景层仍需作品解决。短任务沿现有`tools/level_design.py route --request '制作风铃平原美术' --output build/next_plains_art.json`，route只建计划，当前状态与此范例提供实际消费者/已证伪假设。
