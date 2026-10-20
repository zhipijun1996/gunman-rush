# W4 菜单触屏 fixture 独审：限定 ACCEPT

精确提交 `7a58c819de52bba68594b406c07b2a940b2c5a8f` 只修改 `tests/menu_scroll_touch_tests.gd`，生产零改。审查者只读原代码/原始日志，未修改验收器或作者证据。

独立比较证实原29处 check 表达式逐字保留，运行时43业务检查不变；正式 DemoApp 共享 Menu 与真实 Player/Controller/Overlay 成为拥有者。只替换 ACTIONS 导航回调为原测试真实角色回调，原手势、取消、Slider、抑制尾指和零 Router 动作判据不变，另加真实音频清理及拥有者 WeakRef 释放。

实际完整 parallel wrapper 73/0＋56/0＋44/0，原生日志干净、exit0。build-only 负例与当前测试仅差末尾一条 check(false)，实际45/1、exit1、无额外泄漏。旧 W3 的43/0后49对象/38资源退出失败继续保留，不能被功能摘要或新正例追改为通过。

本结论只接受当前正式消费者 fixture 与正反退出判据，不代 Web/DOM/真触屏、任意独立脚本拼装缓存修复、原80、全CI或玩家/设备。具体逐源及日志 SHA 见同名 JSON。
