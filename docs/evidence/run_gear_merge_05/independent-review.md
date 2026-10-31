# RUN-GEAR-MERGE-05 独立窄审

结论：**ACCEPT，仅限声明的测试与输入守门修复**。最终审查源 `56f74fb0918d1cfbd1487a9734403975caf2e85f`，相对 `05200fc`；不同作者 `/root/bible_guard_review` 只读审查，未修改生产代码、测试、工具或 docs，所有产物仅写 build，由root原字节收录。

## 实际执行

先在 `80c3456` 独立运行原32 Bible与10 creative测试，42／0；此证据保留原源身份。随后在最终 `56f74fb` 的新目录 `reviewer/final56f/` 重新执行原三个CLI：

| 原命令 | 实际结果 | 原超时 |
| --- | --- | --- |
| `python3 tests/test_region_bible.py` | 32／0，exit0，3.324秒 | 30秒 |
| `python3 tests/test_region_creative_direction.py` | 10／0，exit0，1.397秒 | 60秒 |
| `python3 tools/run_forest_bible_reader_tests.py` | 55／0，exit0，1.513秒 | 60秒 |

最终合计97测试；200相关文件和Git HEAD前后完全一致，收据总墙钟6.268秒。原stdout、命令和源码守卫在 `reviewer/final56f/receipt.json` 与三个 `.log`。未用修改断言或mock原CLI来获得通过。

## 版本及历史守门

当前registry实际绑定style14，两区方向为creative-v17。测试将精确13改为14，没有改成与被测值同源的动态自比较。原36引用计数、正文／body closure、SHA、G2/content及禁止正式开放等断言保留。v14相对v13仍仅DemoApp一项SHA改变，另35项不变；真实v13原件SHA `ab8944e429a665aed6345aa5cc7d6e958a35b2b512255f7849fe3c9a82f57c97` 等于前驱main26e7f2a原字节。新增真实 `v13-responsive-navigation` 进入原superseded拒绝列表，最终原32测试实际执行该拒绝。

静态扫描的Python版本断言中，当前有效pin为style14及creative-v17；creative-v2/v10/v12等为冻结历史身份，未把这些合法历史期望一并刷新。

## 输入缺口及实际负例

审查发现原单项cloud_inputs曾在缺少tracked且标S的v12-fixed-status时返回ready；本机修复版本后的32测试因此先在第240行FileNotFound停止。两次候选日志都未执行到后面误拼的v13文件名，不能把它们描述成已运行到误拼路径。误拼本身经源码核对改为真实冻结文件。

现有Harness唯一manifest变化是region-bible-tests的inputs末尾追加11个真实v3–v14冻结JSON；所有原inputs原顺序完整保留，其他check和所有argv／30秒预算／success regex逐结构相同。新增列表有限，无整目录放宽、删原依赖或改变执行器。

我实际读取root的 `sparse-negative-04.json` 及原收据：在真正隔离Git索引、只读alternate对象、v12确实缺席且为S时，原CLI返回exit2／needs_materialization，并明确以literal input指出该v12。其他旧依赖也保持稀疏，所以这只证明点名缺v12会阻断，不代表干净clone完整闭包或玩法。该Git反例由root运行，我做原件审计；没有自称独立重跑。此前非Git目录／输出路径策略拒绝是基础设施失败，未改签稀疏负例通过。

## 只允许持有观测的精确迁移

实际两个策略helper相对26e7f2a的变化不是装备fixture或打法：ecology仅1处、lift仅3处 `app.build.item_ids()` 改为 `app.build.inventory.item_ids()`，保持原“持有道具”统计含义。反向替换这些精确调用后，两个文件逐字节等于冻结原件，原SHA仍分别 `ba4e4a24c43c9eaadbf1d48730200c205bf575267fe7ca0608064519183a4016`、`d973cb63ddf29838dd168e9f39584ce290b3ef805805264309b05685337a5762`。

新guard保留这两个原SHA，要求精确1／3个inventory观察且禁止旧getter，再只反向替换该固定字节串计算旧SHA。没有用新SHA常量掩盖其他策略字节变化，测试名称也明确迁移范围。独立用该真实test方法在临时copies执行：当前两文件接受；撤回任一持有观察、增加额外观察、改变任一observe hook名称均拒绝；lift的移动意图0→1也拒绝。共7个实际拒绝反例，未改根源文件，不声称这些源码检查等于真实Motor执行。

## 范围

完整CI、main合并和Pages结果仍由root核对。这份窄审不签Godot玩法、整区、视觉／音频观看、实体设备或用户认可。根源原失败、早期42及最终97保持各自真实源与结果，不追签。
