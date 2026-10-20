# W4 真实触屏菜单 fixture 所有权

源 `7a58c819de52bba68594b406c07b2a940b2c5a8f` 仅修改 tests/menu_scroll_touch_tests.gd，生产零更改。原独立拼装 Menu/Player 的全部49泄漏为编译图GDScript/Resource等、无存活Menu/Player/Overlay节点；原失败在../compat-W3保存，不冒称任意组装已修。

现在使用正式App共享Menu，将唯一ACTIONS导航回调换回原测试真实player callback；保原43业务检查且增所有者释放1。原完整parallel wrapper保120秒子套/300秒外限，实际73/0、56/0、44/0、严格exit0（31.36秒），无script/shader/leak诊断。显式build-only反例只追加check(false)，实际45/1、exit1且无泄漏；源与原件哈希见receipts/fixture-scope，反例不进入生产。

独立审查：../review/W4_menu_fixture_review.json。全80、完整CI、真实浏览器触屏或用户设备由各自证据决定。
