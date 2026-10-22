# 最新交接：保留旧森林，纠正扩容方向

2026-10-22，分支 `feature/region-bible-v2-forest`，准确提交以Git为准；草稿 [PR101](https://github.com/zhipijun1996/gunman-rush/pull/101) 未合main。当前公开试玩、方向和未完成项见[当前状态](current_state.md)。旧交接原字节保存在[历史快照索引](archive/status_snapshots_20261022/index.json)，不再重复铺在入口。

## 已完成与证据

用户肯定旧关卡设计、否定v16堆台；v16 G5/player_acceptance实际记 failed。责任是误改范围、把ID/路线数当趣味、忽略既有ART_REWORK仍发布，不是用户未说清或CI失职。[返省与改法](design/forest_v16_rethink.md)。两skills只补短且可执行的取舍，没有新审批流程。

公开已恢复旧v15 build12ac/sourcebbf；完整PCK与真实鼠标冒烟通过。[恢复收据](evidence/forest_variety_03/public_restore/report.json)。保留旧包，不能把它冒充当前扩容。

v17是独立开发候选：旧producer与普通default15不动；保留实际旧正常探索，新侧根拆早270wu连续HH，旧HH/螺旋仍可走。东侧附林有实际旧spawn进入、双窗内外根、L金币/音符二选一、远出口与挂果按跳返程。round11全源/Git稳定，原600秒内117.829秒通过当时检查及六条实际输入路线；各失败、原生收据、源码闭包和两轮14张合屏在[证据索引](evidence/forest_variety_03/README.md)。八local goal不等于八新趣味；新增平台矩形布置其实每map仅1种；旧world把instance/program纳入差异签名，已独审揭出并用真实rect/one_way的排序去重guard纠正。round12真实失败2项；不得拿旧通过或果实坐标变化称随机扩容完成。

## 下一任务与命令

两轮实际画面仍ART_REWORK，附林不发布；不要第三轮改色/加粒子/调梁宽救矩形母版。重想自然根枝/空腔整体结构，先一个实际组合黄金再扩库。新入口的H2外肩只有约3wu完整脚余量，技术通过不签手感。旧good内容优先保留；Z、下降肘等只有各自孤立goal，不得直接拼入量产。先森林含美术，再平原；BGM保留用户后引入。

最终执行结果：文档/流程29项fresh通过；严格扩容feedback的harness真实失败2项、源稳定。原件见[最终收据](evidence/forest_variety_03/README.md#最终执行入口复核)。

本轮永久短反馈：`python3 tools/harness.py --profile forest-varied-feedback --release --jobs 1`。包含真实20种子/JSON拒变、菜单App、旧HH/螺旋、两map正式旧spawn往返和L实际音符领奖/远口返回，原90import/240native/600whole、fixed60保留；当前因严格随机guard真实失败；未加入full或CI，不覆盖原80/full141、全部模块或FUN。新脚本先正式import纳入UID再冻结；单独fixture输出必须说明首次Motor前定位，不作正式fullspawn证据。

结束前执行 `python3 tools/check_quality.py`、按PR实际base执行 `python3 tools/check_quality_diff.py --base 7be8c340372d1e20db6685cbd6a559191821eb0e`，提交后 `python3 tools/check_release_evidence.py --commit HEAD`。不默认合main。下一次试玩复用已验同源包/仅Web重建及必要影响验证，不绑定整套CI。

## 执行与存储边界

root唯一Godot/import/GPU/browser租约；源与Git冻结期间禁止并行生产写。只用 `bash tools/godot.sh` / Godot4.7.2。保护audit SHA `c47e366e9fbc1e3584a7c7e3eb8b983422156e21eb420a34456a2d8eb7219791`，保原80、预算和历史失败。不动 `/workspace/gunman-rush-ci-H`、唯一证据、`.git/.godot`。原生大JSON已可无损ZIP归档；本轮完整源码仅复制运行源，避免复制含海量历史证据的整个worktree再次ENOSPC。磁盘实际余量先 `df -h /workspace /tmp`，原失败与原件不删除。
