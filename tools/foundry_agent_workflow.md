# 下一次 AI 会话的实际工作入口

用户希望近乎全部内容生产由 AI 完成，手动只抽查体验。先读取仓库 AGENTS.md、docs/platforming_foundry.md 和当前 docs/handoff.md，不改基础Motor/默认输入/正式两张地图范围。

1. 执行 `python3 tools/foundry.py sources --fetch`。检查 `build/foundry/reference_fetch.json` 中完整解码、部分解码、失败的区别。读取 `reference_jobs.jsonl` 并实际观察相应联系表；需要动作时机时抽更密帧。没有看到的内容标为未核实。
2. 从 `docs/references/foundry_analysis.json` 接续案例。先增加不同判断与动作依赖，再编辑 `config/platforming_foundry.json`。不能仅换名字/镜像/多加刺就称为新玩法。只选择有实际模块消费者与动作driver的机关。
3. 运行 `python3 tools/foundry.py build --count 24 --promote`，读取所有rejected，修复后重跑。关键代码变化使旧basis失效是正常保护，不能删除校验或放宽危险扫掠标准。
4. 运行 `tests/foundry_lab_runner.gd`，复测真实节点回放，尤其移动平台。文档、必要原回归、Web消费者分别验证。新能力实际组件未接入前，不标成implemented；已实现能力要独立生成/验证。
5. 浏览器/原生批量预览新模板；读取用户导出的 foundry-feedback.json，执行 `foundry.py next --feedback ...`。AI实际处理revision_jobs中的高优先模板，修改后再运行验证。
6. 保留失败、版本、来源、当前能力与趣味性待验。根据已授权仓库流程提交、PR和更新已验证试玩，不合并PR。

本入口供 AI 代理实际执行工作，不是一个永久后台服务；CLI不会自行调用付费模型，也不把参考视频采样误称为模型训练。
