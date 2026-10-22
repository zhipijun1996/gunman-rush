# FOREST-VARIETY-03：纠正方向与有限开发样板

公开恢复[旧森林v15](https://zhipijun1996.github.io/gunman-rush/?v=12ac19e2ec02)，不是发布新v17。原v16因用户否定而G5/player_acceptance失败；历史技术结果原样保留。

## 实际结论

- [恢复网页收据](public_restore/report.json)绑定旧source `bbf5b24dc6a27374119f67f11fc2eed92a57ba00`/build `12ac19e2ec02`、完整PCK 141559396字节/SHA、真实鼠标map1进入与暂停恢复；[部署run](public_restore/deployment-run.json)。仅轻量部署/冒烟，不是新源码发布。
- [原生迭代ZIP](iterations.zip)与[逐成员SHA索引](iterations-index.json)保存原round01–11（03为隔离运行源副本）、失败、完整源码闭包、日志、轨迹及两轮实际14张GPU图。204成员均实际解压核SHA，原件未删；round01没有完整变更源ZIP，不追签其可移植源码完整性。其他closure按各原收据重建到原基线Git blob，不自动等于最终HEAD。
- 八个模块goal只获[局部独审](independent-reviews/round03-independent-first/REVIEW.md)，首两件是普通连接变体，强跳/反冲替代合法。不是八个新机制或已入整图随机池。
- [round11独审](independent-reviews/round11-independent-first/REVIEW.md)：3665源逐SHA重建一致，六条路线15925帧、271段真实末12帧完整落脚、连续静态危险扫掠0。包含当前165wu休整枝下旧HH/螺旋、map1旧spawn出返、map2旧spawn L领奖返营、金币或音符的真实指针选择及重复领取不变、远出口与固定果挂跳返程。map1有真实灯笼伤害后旧camp心恢复，不能写全无伤。正式两路线去程已经枪杀weaver，不签返回时活weaver策略。
- [第一轮画面](independent-reviews/round09-art-first/REVIEW.md)与[第二轮画面](independent-reviews/round10-art-second/REVIEW.md)均实际看完14张：巨矩形背体减掉有效，但直角梁/长横根/奖台仍ART_REWORK。停止第三轮调参数救该母版；新附林不发布。
- **随机性未完成**：[独审](independent-reviews/random-guard-independent-first/REVIEW.md)发现旧world签名混入instance/program，误把同一支撑布置算变化。真实新增平台矩形布置每map仅1种、果实坐标各2种，箱口有限变动；不是丰富地图。新guard仅取排序去重的真实rect/one_way与目标坐标，排除ID/program/order和重复描述。实际round12退出1，两项支撑布置变化断言失败；这是正确拒绝当前不达标候选，不删断言改签通过。

[永久反馈与严格拒绝原件](feedback.zip)、[成员索引](feedback-index.json)分别保存125.037秒的首永久wrapper通过（**早于严格随机guard**）及后继round12真实失败；两者不可互相覆盖。[流程修正独审](independent-reviews/process-correction-first/REVIEW.md)只签反省落地，不签内容完成。反省正文见[设计取舍](../../design/forest_v16_rethink.md)。

## 当前边界与重建

v17是独立候选，默认/保存仍v15，未合main。旧producer、核心物理、资源、能力和原80/600预算保留。当前新可选 `forest-varied-feedback` 会因真实支撑布置恒定失败，不加入full或CI去假装正式内容；完整模块库、总体曲线、地图身份、视觉/FUN/设备及风铃平原优化均未完成。支撑矩形变化只是必要条件，挪1wu或拆矩形不能签新趣味。

`iterations-index.json`/`feedback-index.json`列ZIP所有原成员与SHA；用Python zipfile读成员并核SHA即可复原到新目录。原.source closure以原baseline commit和changed-source.zip/源快照组合，不能用当前文件补旧证据。独审中的ignored build或/tmp路径是原执行定位；普通Git中有对应原件，未宣称那些临时路径会永久存在。

## 最终执行入口复核

[本轮harness原件](harness-runs.zip)与[成员索引](harness-runs-index.json)保留两个分开的真实结果：[严格扩容反馈](strict-feedback-harness-report.json)非零失败，两项支撑布置恒定且源稳定；[文档/流程profile](docs-profile-report.json)29项fresh通过。没有把原生失败改成通过，也没有扩大到完整CI/设备或玩家认可。reviewer的原始Markdown源快照另在[无损源ZIP](review-source-snapshots.zip)，[成员索引](review-source-snapshots-index.json)保留原路径与SHA；恢复后才按原源根解释链接，不当活动文档。
