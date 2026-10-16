# FOREST-DESIGN-01 验证边界

内容 forest-design-v0.1，基线 e8ee34446aa82b4e64f5cdc414a22f5b6e2a6ca7；没有运行源变更。

| 实际执行 | 退出／结果 | 范围 |
| --- | --- | --- |
| `python3 tools/harness.py --profile docs --jobs 1 --release` | 1，首个docs检查失败，后续未运行 | 稀疏检出缺历史链接原件；初始report/log保留，不算新设计问题或全部通过 |
| `python3 tools/quality.py check docs/quality/records/FOREST-DESIGN-01.json` | 0，无记录结构错误 | content_complete=false，设计以外和G1–G5仍未验；原输出quality.log |
| 新设计／审查本地链接、12来源哈希、运行源diff检查 | 0 | scoped_links.log，仅源检查，不能证明Motor通关 |
| `python3 tools/check_quality.py` | 1 | 全库历史证据／素材未完整检出；check_quality_sparse.log保留，新任务记录单独一致不冲销全库失败 |

生态初审REJECT恢复合同，修复后复审ACCEPT；空间设计ACCEPT，均只签候选设计，见review.md。没有运行新森林、生成Manifest、录制正常速度玩法或出图；没有新构建，因此不部署旧游戏冒充森林预览。

一次 `git diff --check` 在补取历史链接原件的checkout并行期间进程SIGSEGV（shell退出139），没有修改守门；收尾停并行后另做范围校验。不得把未完成的docs profile写passed。

收尾：历史链接原件补取有界停止（checkout退出-15）；后续直接`tools/check_docs.py`仍退出1，缺失历史链接保留于docs_sparse_final.log。并行停止后`git diff --check`退出0。未扩展任务到全库历史资产修复，未改检查器或历史日志。
