# MENU OCR 窗口修复限定独审

**ACCEPT，仅限实际像素OCR定位修复；不签完整GUI／游戏／趣味。**

实际view_image看过原失败截图，MENU在右上按钮清晰可见。只在自有audit目录复制图后调用原／新定位器，public-forest01全部原件及其旧派生图逐项SHA保持不变。

新代码只在原boxes最前新增归一化MENU文字窗口。AST逆向删除此一个元素后，整个脚本与原HEAD源码一致；所有原ROI、480秒预算、断言、八案例、输入、身份与布局检查不变。仍放大真实图4倍，用原Tesseract PSM6 TSV，只在严格norm(word)==MENU时返回实际文字中心，未加入固定点击或无字形状识别。

原图使用旧locator仍拒绝，新locator识别出实际文字中心。五个负例——空白、仅擦掉MENU字样、改成EXIT、只有MAP1、只有三条形状——均未误认。详见同名JSON与menu-roi-audit原输入／原Tesseract派生图。

这是有限OCR窗口漏覆盖修复，不是放宽产品验证。原public-forest01失败保留，新完整CLI尚待独立实际执行，不能把本审核当20项GUI通过，也不需因静态OCR工具改动伪造新游戏构建身份。
