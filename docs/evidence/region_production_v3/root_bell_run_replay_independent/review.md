# Root Bell版本化RunManifest：独立兼容性复验

**限定ACCEPT**：已实现v10/v11正式内容版本的RunManifest回放修复。审查者`/root/v3_ecology_admission`不是两生产文件或新测试作者；独立实际执行新auditor和原campaign，不以作者自报代替。

## 静态边界

`enable_plains_region`只接受已实现v10与v11，未知值在任何`_data`写入前拒绝。无参数默认仍v10，原字段/值/写入顺序相同，增加布尔返回供正式DemoApp处理失败。首图从实际生成结果记录根版本，兼容校验以该唯一版本约束每图stage_generator、generated_layout.version和enemy_layout。完整根字典相等检查使未知/混合根版本不能掉回默认v10误收。

原Boss/地图身份/transition/shot-latch、Definition合法modifier、资源/参数类型与完整随机重生成/hash检查均保留；旧fixed/generated非整区分支不改变。没有改schema、RNG、保存、物理或资源。原root_bell_formal_tests完整字节前缀保持，runner只新增两行新测试分发，原campaign3705源不变。

## 真正独立运行

共享锁两项顺序执行，实际启动HEAD `7e253830129770fa8f9b4caaabd0b76c3ef275b5`。每项完整806输入在执行前逐字节SHA和Git blob核对，执行后源相同。新日志/实际argv/时间/完整source_before/after原字节附在本目录：

- `audit_independent`退出0：旧40唯一rows/1合格、10物理拒绝、旧mapState loader全部保留；新增5正例与9负例通过。v11与显式历史v10分别真实生成首图与两图RunManifest，native和JSON各自回放精确保真，合法StringName brake_boots modifier保留；逐图重新生成精确Manifest，v11第二图实际1个Root Bell、v10为0。
- `campaign_independent`退出0：**原3705断言/0失败**，没有ERROR。原来真实3项回放失败与两个新增测试自身失败仍在作者原包，本次不覆盖。

[独立检查程序](check_replay_evidence.py)另对作者全部4×806源投影逐Git blob或保留overlay SHA重建，并校验ZIP全部原始文件索引。作者helper没有记录startupHEAD，事后7e5 Gitbase+5真实dirty源码只能称字节重建，不倒填启动标签。本人两个新执行则真正记录了启动HEAD并重建为clean7e25383源。

未知根版本、混根/单图生成器/manifest/enemy版本、重哈希后敌位置或Root Bell行为篡改、无来源空中资源改值、未知enable版本原子性均在真实新Godot中拒绝。native与JSON数字表示允许int→float，回放要求各自输入精确保留，不错误要求两种表示间canonical字节相同。

## 不能外推

两图测试使用真实DemoApp/BuildState/RunManifest，但以明确mini-Boss outcome fixture推进及合法item Definition注入验证序列化，**不是通过输入打赢Boss、自然取得奖励、完整遍历或磁盘存盘**。旧map2形式轨迹通过explicit stage技术入口且缺正常mini transition，不能因新修复就追认为合法完整campaign回放。

根v10/v11刻意禁止混配。开发中把旧map2 state塞入新v11 run的局部hashfallback不等于任意混版本整run兼容；本修复不创建不存在的旧run磁盘恢复服务。

新auditor仍有**20 ObjectDB/17resources退出错误**，原日志完整保存，不授予干净生命周期或性能PASS。原campaign该日志没有此诊断。没有设备/音效/用户/完整商业品质认可，也不改签其它旧失败。

独立Python归档核查曾因closed ZIP访问与遗漏实际transition.id自身报错，两个原错误日志保留；只修本目录检查程序，原生/生产/测试断言未动。完整命令、源和限制见[review.json](review.json)、[结果](audit_results.json)。
