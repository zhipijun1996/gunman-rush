# 创作任务执行协议

本页是 `tools/production_loop.py` 的手动执行协议。创作设计从 [区域创作入口](content_pipeline.md) 开始，日常 CI 与手动检查见 [Harness](harness.md)。

## 规划与执行

```sh
python3 tools/level_design.py route --request '制作荆棘森林' --output build/creative/start.json
python3 tools/production_loop.py --mission build/creative/start.json
python3 tools/production_loop.py --mission build/creative/start.json --execute --worker-mode host --evidence-dir build/verification/creative-start
```

前两条只生成／显示计划。执行使用当前手动检查 ID；`tools/harness.py` 只负责 `--check`，不接收 mission。未选定地区 Bible 时先预制作；已选定时沿当前路由处理。prototype 仅验证声明的能力和切片，不能代表整区交付。

codex 模式需要可用账户。host 模式需要活跃宿主实际接收请求、调用真实 worker 并提交响应；独立 Cloud 会话使用工作线交接，不能当作可实时唤醒的 worker。是否启动多代理由当前会话授权与可用能力决定，工具文档不自动授权。

## 调用和验收

全局任务表只登记父议题，内部阶段 ID、质量记录和恢复状态留在该议题工作线；默认路由提供工作线路径，接续既有议题时沿实际工作线放置。逐阶段质量检查仍由执行器直接验证。

执行顺序为实施 → 选定检查 → 不同实际身份的只读审查 → 任务质量记录。mission 和每任务有调用数、轮数与超时上限；失败和重试消耗预算。检查失败停止该任务的后续检查和无意义独审，无依赖任务可继续。

每次调用前后校验地区 Bible、创作方向、来源 SHA、写集与实际源码。新任务启用原生导入预检：分配 worker 前运行固定 Godot 导入，只允许既存且未改变源码对应的新 UID sidecar。已有源／UID 被改、孤儿 UID、未知产物或导入错误停止为 calls=0，保存真实日志与前后摘要。恢复既有状态不重新导入。

工程通过、阶段完成、内容完成分别记录。ACCEPT 仍须通过任务质量检查与独立身份校验；REWORK 在原范围内有界返工；RETHINK 停止依赖并回到设计；DISCARD 停止投入并说明撤出范围。反复相同非空审查问题停止投入，工程失败不冒称创意判断。设备、听感、审美和用户认可只按实际证据签署。

## Host 协议

请求位于 `<evidence>/<task>/<round>/<role>/host_request.json`，包含原 nonce、request_hash、过期时间、任务／Skill／来源、完整 prompt 和角色。宿主完整转交给 worker，原子提交响应：

```json
{"schema_version":1,"request_hash":"请求原值","task_id":"请求原值","attempt":"请求原值","role":"implement","agent_id":"实际代理身份","result":{"status":"ready_for_review","summary":"实际结果","findings":[]}}
```

实施者不能接受自己的成果，审查者不得改源码。过期、重复、错角色、来源改变和未知状态被拒绝。取消撤销租约并中断原 worker；不要伪造响应或改旧失败记录。越界检测不自动回滚他人改动。

## 检查点与交接

检查点绑定 mission、源码、角色调用元数据、检查日志和实际产物 SHA。实施／检查阶段可暂停恢复；篡改结果、日志、身份或检查点后，即使重新计算外层哈希仍不得借用旧成功。外部源码或规格改变使用新的 evidence 目录并重验依赖。

证据目录位于 ignored `build/verification/`。同工作树按顺序写；独立会话用隔离分支／工作树和 [工作线模板](templates/cloud_workline.md) 交接分支、SHA、写集、证据、阻塞与下一命令。compact 反馈传递最近结果与证据路径，完整历史留在磁盘；字节数不是 token、成本或模型算力统计。

日常验证为固定四项 CI。创作任务显式运行相关手动检查；执行器没有 full/profile/lane、缓存复用、release 或自动发布协议。计时只报告真实调用和日志中的耗时。历史配方由 `historical_recipe_plan` 返回参考元数据，不能提交执行；当前视觉任务使用 `visual_director.route`。
