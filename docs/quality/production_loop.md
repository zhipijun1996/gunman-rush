# 当前生产循环执行协议

创作入口只在[区域总谱](../creative_direction/README.md)；本页解释原`tools/production_loop.py`的执行与证据协议，不另建质量框架。旧历史实录完整保存在[基线原件](../archive/creative_system_baseline/manifest.json)。

```sh
python3 tools/level_design.py route --request '制作荆棘森林' --output build/creative_system/start.json
python3 tools/harness.py --mission build/creative_system/start.json --execute --worker-mode host --evidence-dir build/verification/creative-start
```

route仅规划。CLI模式需要有效codex账户；host模式需要当前活跃宿主实际读取request、分发真实专业代理并原子提交response，不是独立shell后台模型服务。简短Prompt默认先预制作，方向选定后沿mission.continuation以同短Prompt和`--direction`生成后续完整分解；显式prototype只验证当前合法能力技术样板，不代签完整地区。

新创作mission启用`native_import_preflight`：在分配任何worker预算和冻结租约前，由原Harness运行固定Godot导入。只接受有对应既存不变.gd/.gdshader源的全新UID sidecar；已有源/已有UID改变、未知产物、孤儿UID或引擎错误均calls0 blocked。日志、前后摘要、变更、退出与实际时间在finally落盘。已有state恢复不重新导入；不把导入当游戏质量PASS。

原执行链仍是专业实施→已注册短检查→不同实际代理只读审查→原质量记录。命令失败保留前缀，停止其后继检查与无意义独审；独立无依赖包不因它失败自动停止。每任务/mission保留max_calls/max_rounds/超时；失败、重试、中断不退款。task的scope/stage/content分别检查原质量契约，stage不是content_complete。

选定总谱的path/SHA/region/version和authority_sources每次调用前后完整校验并实际进入prompt，手工mission不豁免。创作任务默认compact反馈：保留最近result/findings、证据和checkpoint路径，原始全history仍在磁盘；旧mission默认full，可显式恢复。context_metrics保存实际prompt/feedback字节，不能据此推token或价格。两次相同非空独审finding会停为RETHINK；工程Harness失败不冒称创意失败。

REWORK沿原有界局部返工；RETHINK停止后继并要求回预制作；DISCARD停止投入并记录隔离要求，另做可逆撤出，不自动删除历史或正式消费者。ACCEPT仍必须原check_task_quality通过且独立身份成立，审美决定不能绕过工程错误。

host每次在`<evidence>/<task>/<round>/<role>/host_request.json`写原nonce、task/attempt/role、request_hash、expires_at、任务/Skill/源摘要、完整prompt。宿主必须完整交给真实worker，实现与审查不能同一agent。response原子提交：

```json
{"schema_version":1,"request_hash":"original","task_id":"original","attempt":"original","role":"implement","agent_id":"/root/actual-agent","result":{"status":"ready_for_review","summary":"actual result","findings":[]}}
```

实施者不能accept；只读审查不得改生产源码。真实结果和原最终消息保留，不由宿主编造。过期/规格改变/来源改变/未知状态拒绝，不偷偷重放；宿主需中断过期子代理。执行器检测越界而不擅自回滚。完成review收集器继续校验原lease/nonce/身份/证据，旧collector兼容测试保留。

检查点绑定规格、实际源和阶段；实施/检查可暂停恢复。外部源或任务规格改变使用新evidence目录并重新验证依赖，不能修改旧失败或把旧绿挪签新源。目录必须位于ignored `build/verification`。生产loop同一工作树仍顺序写任务，跨专业并行需隔离工作树+单消费者整合者；原Harness检查继续支持隔离lane，并非将多个独立测试合成串行巨测。

阶段实际计时沿`tools/production_timing.py`：实施/图生/集成/验证/独审/返工/网络等待/发布分列；只有实际日志时间可导入。重叠包络求和与并集分开，纯模型compute/tokens/价格不暴露就未知。开发选相关check，局部验收原正反例，冻结/发布完整适用profile并`--release`强制fresh；缓存还验证输入和实际产物SHA，旧结果不能冒充新源码。

## 独立 Codex Cloud 工作线交接

跨Cloud组织与四种开发模式见[生产入口](../cloud_production.md)，任务使用[工作线模板](../templates/cloud_workline.md)。本页的nonce／lease／身份、源漂移拒绝、有界返工和检查点仍为执行权威；不把独立Cloud会话当作能实时通信或自动唤醒的host worker。独立会话以任务文件、分支／精确SHA、PR、原始证据与恢复命令交接，不能伪造`host_response`替代真实worker。

Long Production允许阶段内长期自主工作，在方向／共享接口／体验质量或下一阶段前提交里程碑；复用原检查点绑定规格、源码、阶段、证据及下一命令。用户直接反馈进入原线下一轮，保留原话和新版本，无需先写长设计文档。审美／手感／趣味由用户认可，技术ACCEPT不代签；连续无改善沿原RETHINK，不无期限修补。

同一工作树仍由单消费者整合者持有引擎／导入／构建租约。并行线先登记共享文件、Definition、UID与配置所有者，接口变化由总控协调或前置PR；每个PR的开发交付和最小验证可独立更新，正式集成仍验真实消费者及存档／Manifest兼容。
