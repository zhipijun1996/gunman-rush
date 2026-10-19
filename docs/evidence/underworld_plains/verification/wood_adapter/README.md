# 木平台检查的明确兼容适配

只修改tests/wood_platform_runner.gd，不改生产代码、物理、shader或原wrapper。普通两图先检查并截图真实默认Underworld绘制，再在test-owned视觉上显式legacy replay，保留每个旧formal实例的shader/scale/outline/原碰撞断言，并核对原body/shape实例ID及生产flag。原width/端点/translation阈值和legacy-strip负控保留。

原wrapper headless4533/0，实际GPU4546/0；原legacy-strip GPU exit1/7fail，缺材质+未知绘制节点双负控exit1/2fail且无脚本中止。F原runner、新runner、patch、实际日志/像素与justification并列，首失败见上级full_f_before_wood_adapter。此测试工作区与committedF不同，正式游戏/素材/export仍逐字节F；后续完整报告必须保留test-only diff，不能称947旧路径仍全部同于E或声称整树清洁F。
