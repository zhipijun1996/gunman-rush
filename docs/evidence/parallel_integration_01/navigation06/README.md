# 原d86包真实导航诊断：鼠标通过，触屏失败

旧d86 CI包与新严格导航消费者的真实小范围实验，**非完整72项通过**。桌面进入ACTIONS并实际装备shadow_shuriken且接受一次；844×390触屏4次真实DOM滑动后标题仍未滚动，保留失败。内容gutter和真实thumb拖动同样无效。Godot4.7.2上游源码/URL/SHA证明ScrollContainer/ScrollBar处理鼠标和Pan，不处理ScreenTouch/ScreenDrag；BaseButton能点造成“能点不能滚”。该证据不由后续新生产适配回填绿。

ci05-extraction-cleanup只移除完整ZIP每成员SHA相等的可重建Web展开，原API绑定ZIP保持，不删失败原件。新UI适配、新源完整CI和72项必须另验。
