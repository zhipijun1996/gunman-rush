# 当前交接：D071 风铃平原与牧风者

当前检出目标为`main`。运行提交`1e0e2981fdd943bace39ecde2174fe0865499aec`，由开发提交`d94480427354837a9b2dc70c5a68ff74d16df03d`经[PR39](https://github.com/zhipijun1996/gunman-rush/pull/39)正常合入；开发分支`feature/windkeeper-plains-release`，基线`f749db9`。本交接仅更新文档与任务状态，经独立docs分支PR回main，运行文件保持已验版本，未强推。上一轮[归档](archive/handoff_plains_living_d070.md)。产品权威见[本轮设计与验收](windkeeper_plains_iteration.md)，仍未获得用户真机手感/趣味性确认。

## 实现与优化

正式首区8关保留一跳、两枪、260移动速度、0.55地面反冲、0.20空中慢时。保留已实现的分岔、教学风铃、反冲组合、三类主动敌人、商店/奖励/永久音符与家园。地形增加原创土根/草缘过渡与荆棘扎根，纯表现不扩大碰撞；厚实体岩体与木制单向板分别可读。

牧风者替换正式第8关占位Boss，独立组件管理三个阶段、核心受伤窗口、局部气流、攻击与美术；PlayerMotor仍是唯一位移入口。阶段1冲击波/低头冲撞/颈铃，阶段2旋转风叶/安全草台/背铃，阶段3短段断桥追逐/桥墩暴露窗口。新增六张真实关键姿态及独立旋转风车，不冒充完整逐帧动画。暂停、回退、死亡与离场取消旧攻击，胜负/金奖励继续遵循既有确定性政策。MODULE LAB新增WINDKEEPER直达练习，不写永久奖励。

HUD压缩调试文本，资源细条9px，血量闪烁、尘叶/射击轨迹/风铃共振环均为有界事件表现。风铃新增原创合成短音，非生成音乐；手机静音策略与实际听感另验。原PNG母版不改，新增图有SHA/alpha/裁切/锚点与来源说明。

## 发现与修复

完整Core两次被16GB内存限制终止；新增材质浮点tile步长在边界不前进，导致无限追加。已经改为有限整数块枚举，真实preview-contract-proof全图计划/绘图与边界覆盖回归735/0、故意失败736/1退出1；未删覆盖断言。修复后完整Core5942/0退出0。

首次完整专项在密度350/2失败：Boss版本升级参与地图随机派生，旧低顶荆棘回归Seed被意外重抽。地图随机派生与Boss/整体manifest版本分离，保持原地图/危险/角色标准；原低顶回归保留，最终密度359/0退出0。审查还发现阶段3可走底层地板绕过断桥、攻击引用数组长期增长；已修为阶段III真实撤地板/支撑、ENV损血段回退及每tick清理失效弹体。实际射线确认无隐藏地面，落桥回退保留BossHP/阶段，120轮生命周期检查有界。不能把先前底层缓冲版本称正式断桥验收。

## 验证与发布

Godot `4.7.2.stable.official.ed1daf0bf` Standard，经`bash tools/godot.sh`调用；PATH旧Godot不用作证据。所有长命令都有timeout。最终核心5942/0退出0；最终牧风者173/0、故意失败174/1退出1；实际完整12HP战斗12发射击经过三阶段，玩家剩1HP，非无伤。正式App第8关独立结果fixture19/0：真实III断桥、安全桥面金奖确认/领取、重复拒绝→Home，以及同帧双方致死→Home且无金无大关进度；不冒称手动打通8关。文档33权威/105任务依赖、世界16候选区、新素材检查及diff检查通过。退出时部分旧/新headless进程仍报告ObjectDB/resources/RID清理警告，日志保留；不声称全日志零警告，实际GUI无脚本/页面/着色器错误。

本地Web包`67eae954eaa8`真实GUI：标题→家园行走→花5音符买永久升级→刷新保留→正式第1关→鼠标松手射铃OPEN→实际拾取音符至5→回家刷新仍5，退出0。另独立GUI从可见菜单进入牧风者练习并普通移动/跳跃触发攻击，角色受伤至4/5，无脚本/页面/着色器错误。只代表该包该流程，不冒充三阶段GUI或真机。最终源Web与Windows分别重新导出退出0；最终本地Web包367691a671a9再次通过家园购买/刷新、正式第1关真实SHOOT BELL→OPEN及普通移动；该次路径未实际增加音符，拾取后刷新证据仅属于早先67eae954eaa8，不混称最终包。最终包独立GUI通过牧风者入口、阶段目标可见、真实移动/跳跃触发攻击，资源条9px，原调试背景已隐藏。

日志在`build/verification/d071-*`与`build/verification/d071/`；该目录为本机未提交证据，最终CI链接/公开包hash会记录到本文件。新workflow仅main部署Pages，开发分支保留artifact。仓库github-pages环境尚无分支限制；API修改返回403 Resource not accessible by integration，未改变环境配置。用户需Settings → Environments → github-pages → Deployment branches选择main，才能同时阻止仍携带旧workflow的历史分支日后部署。当前无在运行的旧分支部署；本次正常main发布继续。

## 未验证与下一项

Android APK本轮未构建；Android/iPhone真机触控、听感、性能、镜头防晕与主观趣味性均待用户验收。Windows导出不代表Windows实机玩通。后续优先按本轮真实试玩反馈调Boss窗口/桥段难度、关卡节奏与风铃组合；不开放未验证后期地区或二跳。

最终本地完整平原35套通过退出0（密度359/0、正式App160/0、完整路线12359/0、空间2489/0、生成5014/0），日志d071-plains-final2.log；最终核心5942/0退出0，日志d071-core-final2.log。最后仅缩小INFO字体并将按钮收回HUD边框内，Web重新导出包35dbb85547cb，该包实际浏览器重验已通过家园购买/刷新、正式首关真实射铃及普通移动，无脚本/页面/着色器错误。公开CI包与本地包证据独立，不能混称对公开URL完成全部GUI操作。技术发布已完成；下一项为Android/iPhone实际试玩与反馈校准。复现命令：`python3 tools/run_tests.py`、`python3 tools/run_plains_ten_tests.py`、`python3 tools/build.py web`、`python3 tools/build.py windows`、`python3 tools/check_docs.py`。不承诺后台无限迭代，不自动开放后续地区。

## 最终main发布证据

[main CI 38075961899](https://github.com/zhipijun1996/gunman-rush/actions/runs/38075961899)全部成功：核心5942/0、平原35套（含牧风者173/0、正式结果19/0），Windows和Web各自导出0，Pages部署success；Android job明确skipped。main文档CI38075961913成功，开发分支push CI38075358880与PR CI38075367804均成功。合并后的运行文件树与开发提交完全一致；最终交接仅文档变更，不重建或替换已验证公开包。

[公开试玩](https://zhipijun1996.github.io/gunman-rush/?v=49be6ac84a3a)：build `49be6ac84a3a`，PCK 27244592字节，SHA256 `49be6ac84a3ab12430748f41835dcbfe52bc323e9ba00bd3486673ede069bb85`。实际GET HTML/build-info/完整PCK相符且SHA匹配main CI。日志`build/verification/d071-ci-main-full.log`、证据`build/verification/d071/public-final.json`（本机未提交）；CI链接和本段hash为仓库持久证据。

快速练习：标题 → DEVELOPMENT DEMOS → MODULE LAB → WINDKEEPER；正式流程由Home进入8关。APK本轮未重建，Windows实机、Android/iPhone真机、实际音效听感/性能/主观难度/趣味性继续awaiting-device。Pages环境main分支限制的403与用户UI设置步骤见上，未假装完成。
