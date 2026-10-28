# 质量体系使用入口

普通怪物新建、补齐与逐物种盘点见[怪物完成标准](enemy_completion_standard.md)：E01–E12细化原G0–G5／十一维，并由[Enemy Design Sheet](../templates/enemy_design.md)记录实现、状态及缺口，不引入独立评分或另一套工作流。

规范版本 **1**。总流程见 [development_quality](../development_quality.md)，当前产品事实继续由 [current_state](../current_state.md) 负责（即 project_status 职责，不另造副本）。生成事实见 [generation_current](../generation_current.md)，风格见 [visual_bible](../visual_bible.md)，动画见 [animation_vfx_standards](../animation_vfx_standards.md)。

从仓库根目录开始：

```sh
python3 tools/quality.py init --id ENEMY-EXAMPLE-01 --type enemy --output build/quality/enemy.json
python3 tools/quality.py check build/quality/enemy.json
python3 tools/quality.py check build/quality/enemy.json --require-complete
python3 tools/harness.py --profile docs
python3 tools/check_quality_diff.py --base origin/main
python3 tools/quality_drills.py
```

init 产生全部未验收的记录；没有自动 PASS。普通 check 检查记录是否诚实且格式有效，允许未完成；--require-complete 还要求相关门槛已通过。终态 done 使用同样的完成约束；记录有效不等于内容合格。将任务记录放 records/，证据保存 docs/evidence/ 或实际可下载附件的本地记录；测试临时产物写 build/。未完成记录也应提交，作为下一轮的事实。

十一个核心 skills 共享 policy.json 与门槛，不重复创建同名阶段。主导 skill 填一次设计与验收记录，专业 skill 追加同一任务的视听、生成等证据。旧 game-iteration / level-generation / game-art 分别由 game-quality-gate / region-generator 或 level-module-creator / art-director 接替；project-integration 保留为 Git/结构工具技能。

官方 [Build skills](https://learn.chatgpt.com/docs/build-skills) 于 2026-10-12 核对：项目技能位于 .agents/skills，每项 SKILL.md 带 YAML name/description，可用 $skill-name 显式调用。官方源校验记录见 [skill_source](../evidence/quality_system/skill_source.json)。本项目采用简单单行字符串元数据；没有强制配置可选 openai.yaml。静态发现路径检查、模板演练和宿主实际调用分别报告。

## 证据与完成

十一维状态、G0–G5、任务类型和必要证据由 [policy](policy.json) 维护；自然语言判据在总流程和各设计模板。命令记录不是主观认可；视频文件存在不是流畅证明；声明 reviewer 身份也不能由脚本证明其独立性。自动检查负责发现缺失、冲突、过期哈希、伪终态和明显降标，审查者负责验证内容真实性。

历史任务和旧素材不会被批量补写 PASS。新任务和本次之后修改的内容遵循新记录；历史资料引用原证据，缺失的模型/授权/审查信息如实未验。新素材另附 asset_records/ 元数据，沿用原 assets manifest，不复制图像或运行参数。

完整交付报告与七条可复制任务示例见 [实施报告](implementation_report.md)。

内容可选维度如果确实涉及本次改动，也必须 passed；只有明确 not_applicable 才可省略。awaiting-device 要已有技术通过；--require-complete 在没有记录时失败。PR 差异会核对完成记录的 reviewed_commit 中工具/代码/Skill/策略文件内容，不能拿旧提交的完成证据覆盖新改动。

主角、武器整套动作/升级、新能力分别路由 player-creator / weapon-creator / ability-creator。大任务反复执行和停止/续做见 [生产循环](production_loop.md)。

## 人物动作规划

[设计收录与单武器规则](../design/player_actions/README.md)、[人物动作harness与skills计划](player_action_plan.md)、[动作覆盖卡](../templates/player_action_coverage.md) 是下一阶段入口。ACTION-DESIGN-01仅process规划记录，新运行专项均planned。
