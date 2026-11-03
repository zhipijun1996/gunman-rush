# CI 输入工件独立审查

结论：当前被审实现未发现阻断代码漏洞，可进入最终精确 head 的真实 CI；尚不能签实际 4.43GB 传输、磁盘容量或完整 CI 通过。源码 SHA 和实测日志见 review.json。

- 同 run 名不含 attempt；失败 job 可取原成功 prepare。manifest 绑定精确 HEAD、完整 plan 原字节 SHA、完整有序 full checks；原 prepare 收据字节随包保留并重新核 SHA、scope 和物化清单。
- 文件逐项与当前 Git tree/index 的 path/mode/blob 比对，内容核 Git SHA-1 和 SHA256；当前在场文件仅核验不覆盖。HEAD/index 前后批量快照、原 preflight 仍执行。
- tar 仅流式读到数字 staging 文件；不 extractall、不采用归档路径创建节点；拒绝路径逃逸、symlink、链接／特殊成员、稀疏成员、未准入 PAX、错序、缺项、重复、尾部非零数据与不完整终止。发布用 atomic no-overwrite hardlink；失败只回收自身仍相同 inode 且内容未被改的新增文件。
- 独立重跑 41 输入 fixture、4 workflow fixture、54 selector fixture 全通过。另以 AST 验证原 24 输入测试完整保留；原 178 顺序和全部 check 字段逐项一致，harness.py 原字节一致。
- 共用 Python 3.12.16：production 三处、environment 七处；verify_public sparse 包含配置文件。仅两处 main Pages 条件增加 skip-playtest；manual 分支和检查逻辑保留。最终 merge message 必须包含 [skip-playtest]，不能用 skip ci。

## 实际资源成本

原 run 物化 5061 文件，4,434,365,875B；约 4,018,299,499B 已是 MP4/ZIP/gz/PNG，因此不能指望 Git 或 tar 自动显著缩小。按本包格式，无 PAX 最小 tar 为 4,438,273,536B。prepare 在已存在物化文件和 Git objects 之上再增加该 tar；consumer 同时持有 tar 与 staging，合计至少 8,872,639,411B，加基础 checkout／Git／工具链。发布是 hardlink，无第三份 staging 数据；成功后 tar 已删除。

每 consumer 至少读整 tar 做外层 hash、再读 tar 校验抽取、再读文件核发布结果，约 13.3GB 读取，加约 4.43GB 写入；并非零成本。prepare 上传约 4.44GB，两 lane 和 affected 共下载约 13.31GB。收益是复用 prepare、避免 151 次 fetch 序列和逐文件 Git 子进程，不是声称无需传输／解包。

旧日志未记录 runner 可用磁盘或 Git pack 实际字节，不能证明标准 runner 容量必够，也没有已复现磁盘不足。建议最终 CI 前最小补上 export/restore 前后可用磁盘、预计 tar/物化字节、峰值阶段统计；容量不足明确阻塞。不要据猜测建设缓存平台，也不要删输入／放宽预算。真实 full 4.43GB 仍须在最终 CI 核实。

## 证据限制

本次仅有限 Python fixture；未造大包、未执行 Godot、未触发或取消 CI，不签游戏行为或整图验收。旧 head 失败保持原身份。源码在共享 WIP 中，后续修改需按 SHA 确定本审查的覆盖边界。
