# PLAINS-REDESIGN-GUI-LOCATOR-01

C3原deliver12步和合并52项技术检查真实通过，额外正式迷雾地图GUI在截图可见MAP1/2EXPLORE处因全屏稀疏OCR漏字真实失败，原失败在build/plains_redesign/final_gui保留。修复仅限原verify_plains_region_browser截图定位：按实际地图芯片有限右侧上下候选位置裁取、灰度反相3倍OCR，要求同一实际文字行MAP+1/2+EXPLORE，拒绝缺失或歧义；返回真实OCR框中心，之后原点击/迷雾/focus/zoom/drag/Escape和动作断言不变。处理图仅OCR派生诊断，原截图/美术不变，不用固定坐标成功兜底或游戏状态注入。

先用实际失败截图做定位正例，真实家园/标题图做缺标签反例，再原浏览器路径fresh复验。原C3运行/资源/构建字节与本次测试工具/记录变更分开绑定；不能将C3全局source_digest伪改为新源。整区美术/趣味/设备依然未完成。
