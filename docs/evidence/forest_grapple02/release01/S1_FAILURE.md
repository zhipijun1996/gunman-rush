# S1 真实CI失败与本地定位

源码S1 7ba2e92d2c3cb5449ac6648b820f79679548ee89，选定run39194694146终态completed/failure。publisher为ci_failed/live_verified=false，deploy跳过。不是仍在等待或已成功；没有新版发布。原89全profile没有通过，当前forest80未执行。

## 原始与推断严格分开

原普通run/jobs/check annotations显示parallel的root-bell-tests nonzero_exit；外层的“producer failed or leaked resources”只是通用拒绝文字，不证明资源泄漏。精确parallel artifact单次403，原phase报告/所有内层stdout未获得；不能用API成功或源码顺序冒充已经审完报告。serial18及5额外只有原普通API的独立成功范围，不代当前80或完整89。

源码把失败check放在parallel39/71，因此前38和后32未执行是按原顺序/首次失败停止推断，不是逐条原phase结果。旧scope审查是当时in-progress快照，后来的terminal note追加失败而不覆盖原件。

本地原Harness单check复现报告保持S1、failed/nonzero_exit，1.867秒。其完整inner strict_formal_python.log明确 ValueError: Actual tuning mismatch focus_time_scale：固定旧capture的20%配置被当前15%authority检查拒绝。错误在Python validate，Godot未启动，不是已证Ogg或其他泄漏，也不是60分钟超时。原调用、日志、报告与S1 Git对象原源保存；不以正在改的测试文本冒充当时S1。

test-only历史authority隔离由另作者实施中；此包不认证修复成功、S2 CI或新游戏结果。runtime/game生产没有因本失败归档而改变。早先18局部黄金、代表16、额外HH一例及两部受控影片各有原范围，但不补签80、全CI、上层吸引力或真人设备。parent仍REVISE。

## 便携和脱敏边界

s1-failure-originals01.zip包含普通API/annotation、parallel403脱敏收据、publisher终态脱敏元数据、verifier scope/terminal说明及metadata、本地原Harness报告/log及完整root_bell/formal_v2指定inner，排除cache/大媒体。publisher终态仅用已有redacted JSON，不采live checkpoint。所有文件均已扫描签名URL/token模式；不包含临时签名重定向。API元数据和脱敏下载收据不是下载到的原CI phase报告。

s1-failure-inventory01.json及ZIP内ARCHIVE-INVENTORY.json逐成员SHA/大小完整读回。先前57成员s1-preflight-originals.zip保持SHA1b7a8bab69987f490b47f059d842fd3af4fc4d79570d3071a9ded07c94e627a7不变。新的失败原件只追加，不回写此前局部通过或in-progress历史。

所有产物只在ignored pending_release01内准备，不修改tracked、不提交；本整理不执行native/full tests/浏览器或网络请求。正式收录与S2提交由root处理。
