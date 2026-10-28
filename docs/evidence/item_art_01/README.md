# ITEM-ART-01：道具美术与实际主游戏证据

当前候选已接入 **72个独立道具图标、32个单帧语义特效资源和P24／P14／G16三套八帧动画家族**。图标、奖励、商店和暂停菜单共用数据目录，世界效果只订阅实际施放／状态／伤害回执，不决定玩法结果。[逐件映射](../../worklines/item_art_01/coverage-plan.json) · [维护入口](../../item_authoring.md)。

全部图像由生成工具制作，10张原始PNG保持原字节。采用当前细像素方向、旧黄铜／冷钢材质与克制青光；专用世界shader沿原1wu顶点／光照语义，仅修复高分母图集的采样浮点和REGION_RECT边界，原全局shader不变。注册RGBA上界62,908,904字节，小于原64MiB限额；这是纹理上界，不是总显存或设备帧率测量。

- [原始请求](generation/)与[采样失败链](source-and-sampling/)保留未达到原生64px／安全边要求的原件、非等格ROI、黑色alpha1边缘及精确源图身份。只按实测用途准入，不将大图称原生64。
- [扩产前独审](review-golden-expansion-01.json)先核首8／三家族真实菜单和两区画面，再批准其余64图标／32单帧源图。单帧配合既有时间轴，不称32套手绘帧动画。
- [全部图标真实UI](ui-stages/ui-all72-02/capture-manifest.json)：534断言／0失败，1280×720与960×540均完整显示72／72个52px图标，另核G01／P16／G19的90px详情；26张真实截图。显式初始化展示库存，不是自然获得72件或实体Android测试。旧滚动采证失败保留。
- [最新原生专项](native-stages/full-art-native-06-spend-context/receipt.json)：1185／0。保留原1077并补P27／N02扣能回调与空凭据的108项检查；真实重复旧通用特效的40／6失败与40／0修复分开保存。
- [独立采样GL](independent-shader-probe/review.json)：11／0，旋转／高比例边界和原shader／nearest反例；[完整节点边界](native-stages/body-pose-native-07-envelope/)83／0。G05、P20、针雷按所有非零alpha及原brief校核；G19每级完整节点与原回退实测，光学中心差0.167wu。
- [独审更正](independent-integration-review/ui-body-review-02-correction-and-envelope.json)：原“下排间歇消失”判断被原PNG与字节相同重播反证，未为错误假设改生产代码。旧报告与真正边界修正均保留。
- [技术绑定历史](source-bindings/)保留每轮原件与影响分析；当前style16／creative19 R13为68真实引用，最新原32＋10及四项Harness fresh通过；同步main11e359音频的实际WeaponFeel单叶另行绑定，其他67项不变。哈希和原生断言不代替审美认可。

冻结运行源 **56e639d712cab0604807992cce0e6eaeaf56ac08**，已同步main11e359音频：

| 当前证据 | 实际结果与范围 |
| --- | --- |
| [主游戏完整操作录屏](movie-main-56e639d7/movie.mp4) · [收据](movie-main-56e639d7/receipt.json) | 54.066667秒、222／0；标题→家园→正式平原宝箱→入包→8槽装备→实际攻击→原生换装→B11最大生命5→6→5→8→10扩容精确扣35；不免费治疗，关菜单不误射 |
| [平原实战补片](world-plains-56e639d7/world.mp4) · [收据](world-plains-56e639d7/receipt.json) | 12秒、19／0；真实敌人AI、刺面与落点，P24／P14；明确初始道具／站位／35共鸣fixture |
| [森林实战补片](world-forest-56e639d7/world.mp4) · [收据](world-forest-56e639d7/receipt.json) | 12秒、18／0；真实敌人AI／枝面，G16／P14；明确65共鸣／开发区域fixture，末HP4／5。G16两次实际HP提交，第三段目标已死不造命中 |
| [最终33项Harness](final-harness/report.json) · [命令](final-harness/invocation.json) | 33 fresh／0复用／0失败，原命令、预算与拒绝条件保留；core5686、ART1185、catalog1553、authoring451、森林74、gearUI158；不是full164或远端CI |
| [导出包隔离加载](packed-resource-check/packed-catalog-03-isolated/receipt.json) | 实际191MiB级PCK，六份配置原字节匹配；无项目文件的目录中加载72独立Atlas／42片段／10纹理／world shader；不是Web浏览器试玩 |
| [共享音频回归](final-audio-merge/receipt.json) | 原transport／selected两个native检查成功、source_stable；不签听感 |

三段均实际Godot4.7.2、1280×720／60fps、原游戏AAC48k立体声音轨、cleanexit、source_before==source_after。主片已知奖励／训练靶与宝箱位置fixture持续注明，末段测试金币通过原RunWallet账本明示初始化，不称自然赚取；两区补片是真实敌人而非主片训练靶。多GB原AVI留在build并保留哈希，不提交Git；MP4是同一原始采集编码，非静图拼接。此前[旧黄金片](movie-golden-7afe71a3/)与旧开发补片保留原身份，不签当前源。[最终独立复核](final-independent-review.json)接受本次限定技术／实际像素与回执范围；[隔离打包附录](final-packed-review.json)另列。公开下载与PR状态以推送后实际核验为准。

仍未验证：实体安卓／手柄、低端性能、用户审美、听感、全72自然实战和完整G5。来源许可及工具未披露的模型保持unknown，资产visual_status仍unverified；本记录不伪造商用许可或玩家认可。
