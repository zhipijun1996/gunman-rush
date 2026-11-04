# 阶段A恢复独审：源码身份一致，历史默认认可保留，原件未恢复

这是环境恢复后**新写的独立审查**，不是丢失的旧报告、旧六图manifest或旧strict join。审者为同一会话的 `/root/death_event_audit`；本次未启动Godot/browser、未跑测试、未改生产。

当前实际读取 `/tmp/gunman-rush-mapgen-04`：HEAD `d37b37075144c7a7550ad0fe9d3bd7118d6dae1d`，tree `fecc23d4860a08ad5c3d49df7de503f13578c68c`，工作区干净。16个已有历史SHA的宿主/测试/recipe/锁与输入叶逐项重新哈希，全部一致；18个SDK源文件也全部与原lock吻合。具体全SHA列于同名JSON，不以Git status空代替内容哈希。当前包仍是原0.4.0 SDK，不是0.4.1。

关键已审源保持：job34084f99、只读库缓存26b59aec、generated e22e71f5、Provider6a45efd2、runnercb839a5d；base5b7d6157、profile65040947、selection6515df69、gears0bab0105、两recipe182b4b50/ef7fab51、lock09c2c213。已修的失败结果null-map摘要守门、summary先计时再复制metrics、每job独立SDK/PreparedLibrary/solver/RNG及只读ModuleArchive边界，没有因为恢复变成另一份源。

用户明确允许按源码身份一致承接历史default，不重跑它。本审者此前确实完成：原报告/actual PCK/35798向量/55guard核读；6张原PNG逐张实际view_image（包括两张相同bytes的Title各自打开）；用冻结offline CLI实际finish。新授权流程的自动双fresh为209.255767秒/原300，离线六图审查213.163965秒另计。原raw状态保持AUTOMATED_COMPLETE_VISUAL_PENDING，严格合流另存；不是把模型审图追放进原300。PR129持久附录和本审者当时消息保留这项认可，源、数值与范围相符。

**现在原始附件没有恢复。** 已直接检查原report、six-review、join路径不存在；原6PNG、before/after gzip、timing、原生12附件及先前独审不因这篇文字变成可重新读取的原件。旧report bf7fdf77、six-review7b14a13e、join73438f0e、512c1ea0包/218926492B、源向量434c05a3等只作为历史消息指纹记录。它们不是这次重新哈希到的文件；不得由摘要补造raw JSON、日志、PNG或带旧SHA的新receipt。当前新PCK f547fc79与旧512c不同；同源码不等于同包字节。

可有出处地重述历史画面判断：首图是930001 conformance受控切片，玩家在右侧苔藓平台；D后相机/平台布局与约+52世界x一致，A后回近原布局；首ESC后是完整Title。第二fresh取消后的两图已经是Title；当时逐张实看过，未声称它们显示了更早的生成画面。真实generate-before-ESC、无迟到committed/loaded/physics、清理先于Title依据的是当时实际事件链。这里只承接历史观察，不是再次看见丢失PNG。

持久见证来源为 `../pr129-recovery-handoff.json`（同名JSON列其本次SHA与body SHA），PR129仍旧46eb/Draft，其附录清楚区别本地d37及待做的最终精确head CI。旧f6 actual02/03预算FAILED不改；旧gears启动前环境中断是NOT_RUN，不是300失败。历史observed-PID/SwiftShader进程CPU、异步边界与覆盖缺口也不升级成算法独占CPU或手机/FPS证明，完整boot/PCK解码/编译CPU拆分仍不完整。

Root另报告远端新commit `c9416f16fcce53f64ce456f8eb33df42429627cd` 与本地d37 tree完全相同。commit ID仍不同，不能把c941叫d37；本次当前Git实际HEAD是d37。精确remote API/tree收据尚待本审者单独读取，不能把root消息升级为此文件已重新校验remote metadata。本地历史d37的bundle由root持久保存，不以新的metadata历史替换旧commit。

恢复后的fresh native69、新f547包、原112c driver单case300、7张新原图/3WAIT，以及最终精确head full CI均需各自证据；不由默认历史认可替代。新gears只有实际看见对应PNG后才ACK。本轮仅阶段A，不进入B/0.4.1，不合并、部署，也不签整图、连续路线、实体手机或用户手感。
