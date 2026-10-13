# ColorRect绘制迁移：独立局部复核

审查者 `/root/independent_gameplay_audit`。只读生产/仓库测试；另写忽略目录独立探针，**保留全部旧Polygon探针与日志，未替换或改写旧通过/失败原件**。

开始读取时HEAD `796890546c0573c35cd1940785f75ceaf2200561` dirty；结束时实现者提交到 `aa40f9071575325884ed523dc66f92145d41913e`，工作区干净。精确文件SHA256和前后状态见 `independent-colorrect-source.json`。

## 结论

**几何覆盖、预算及输入属性迁移限定ACCEPT；WebGL修复成功仍须实际GPU证据，本报告未独立确认。** 不作美术、玩家、性能或全路线通过声明。

实际独立执行5个headless Godot探针，Godot/wrapper均exit0，原日志 `independent-colorrect-review.log`：

| 检查 | 结果 |
| --- | --- |
| 原348案例，实际ColorRect几何、孔洞、分块/逆序/重复输入 | 22854 checks，0 failures |
| 7种宏尺寸×2棋盘相位（新增16×1），实际quad覆盖/预算 | 14 cases，1884 checks，0 failures |
| 原whole/2px split及隔空隙邻体圆角 | 2 checks，0 failures；2.5/2.5、.5/.5 |
| 相同100×20并集的100条分块 | whole与100strips均成功 |
| 原0.005极细空隙 | refused=false、empty_gap_painted=false |

新脚本为 `independent-colorrect-canonical-probe.gd`、`independent-colorrect-budget-probe.gd`、`independent-colorrect-corners-probe.gd`、`independent-colorrect-thin-gap.gd`；不依赖具体绘制类的100条probe直接复用。348案例仍为原始固定JSON，未删孔洞或精度反例。

此次覆盖读取 **Rect2(child.position,child.size)** 作为真实几何，然后对照authored_piece；并非只相信metadata。原Polygon顶点检查合理迁移为实际Control矩形检查，不是降标。每个实际quad检查face/corner预算、鼠标忽略、无focus、shape_origin与position一致。预算压力用actual size计算覆盖格，检查无重叠、不填洞、无漏格，并对照macro metadata。

## 坐标、输入、生命周期源码复核

`paint_quad`设置实际position/size，将mouse_filter设IGNORE；ColorRect默认focus_mode=NONE，独立运行也实际读取确认。它不应吞掉鼠标/触摸GUI命中或新增键盘焦点。未独立进行真实触屏测试，不能推广成设备输入通过。

新quad局部VERTEX从0开始；shader使用VERTEX+shape_origin恢复原shape边界坐标，MODEL_MATRIX乘局部VERTEX保留节点position和父transform的世界采样。该变更没有改cell/mask、规范化边界、分块或碰撞/RNG代码。真实GPU插值和浏览器buffer生命周期仍不由CPU矩形证明。

既有拥有者仍将art作为Node子树添加/释放，页刷新、study重建与stage退出无需依赖Polygon2D类型；未发现新Control引入的确定输入或节点清理异议。此前Boss破桥/退出生命周期ACCEPT属于原已执行范围，本次未重复整段引擎测试；也没有凭headless无报错认定WebGL buffer问题根因已经修复。

## 旧GUI通过结论更正

已实际读取 `webgl-diagnostics-failure/report.json` 与console：原report.status=passed、build=c74e69b1f987，但日志有 `WebGL: INVALID_OPERATION: bindBuffer`及`bufferSubData: no buffer`。旧checker只拒Script/Shader错误，漏掉真实渲染诊断，因此**该次GUI整体验证passed无效，应判失败**。像素差bbox=null只证明采样到的两图相同，不能覆盖同次渲染错误。

原report/console保留不改，失败归档即证据；新版checker增加INVALID_/CONTEXT_LOST拒绝条件属于收紧门槛。本审查没有独立重跑GUI，ColorRect是否消除该错误要看新构建普通入口、页面切换、region生成/销毁的完整console及退出结果。
