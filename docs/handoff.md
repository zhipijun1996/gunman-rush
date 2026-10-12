# AI 关卡工坊交接

分支 `feature/ai-platforming-foundry`，基于用户提供仓库 main **6568e9a41e6268001ae7d132017f409ea83ac475**。本次使用现有 Godot Demo 引擎，无新造一套移动物理。旧D083证据完整保存在[归档](archive/handoff_d083_foundry_start.md)。

实现与操作见[关卡工坊](platforming_foundry.md)。开发菜单 LEVEL FOUNDRY；现有基础物理、输入、正式两张平原地图、奖励/精力/保存保留。六结构模板，每个两种动作顺序，基础24组合片段；二跳/四发容量各6兼容样本，总36。每个能力配置六条三段连续路线，总18；全部经过同一实际Motor、完整危险扫掠、内存及磁盘输入回放。runtime回放只执行输入，不搬玩家；随机入口只选整段已验证清单。

公开视频已自行搜索并获取 Ori1、Ori2、空洞骑士与丝之歌的有限样本。丝之歌请求300秒而实际224.43秒解码成功，时间近似、仅覆盖前置与第一段雪山衔接。YouTube代理403和另一个B站片段解码失败均保留。共有13个分析窗口，AI观察与推测分离；不是四游戏全部段落库。影片和联系表仅在build，不发布到游戏包。

能力扩展：二跳/四发复用已有真实组件配置，默认文件一跳/两发不变，射击仍受精力/冷却限制。本次高级池是兼容证据，不是专属四发动作链；钩子明确implemented=false，后续须有实际能力/对象/动作driver再入池。正式能力发放未变。

技术证据：Godot **4.7.2.stable.official.ed1daf0bf**；Core **5942/0**，地区 **15套通过**，历史回归 **43套通过**；工坊消费者 **34断言/0失败**，独立代理六模板实际回放全部误差0、准确落地出口；追加实际消费者18条整段路线均误差0、精确出口，[整段记录](evidence/foundry/actual_itineraries.txt)。首次JSON磁盘校验、暂停Esc和移动平台初始化一帧差被独立否决，修复并保留；[审查](evidence/foundry/review_round1.md)、[独立复测](evidence/foundry/independent_consumer_recheck.txt)、[消费者](evidence/foundry/consumer.txt)、[批次](evidence/foundry/batch_generation.txt)。headless消费者间歇出现ObjectDB/资源仍在使用的退出诊断，34项断言与退出码通过，但不宣称零诊断；原日志保留。

当前趣味性/手感/手机/实体手柄 **awaiting-device**。技术通过不等于像原作一样好玩。视频新结构提炼与模板修改由AI代理处理，CLI负责机械流程与任务队列，没有接入一个持续后台视频大模型。下一轮AI直接读取[执行入口](../tools/foundry_agent_workflow.md)。

本地Web实际GUI通过：开发入口、中文、真实手动输入、两种完整输入回放、暂停恢复与评价JSON下载；[浏览器记录](evidence/foundry/browser_local.json)。Web/Windows导出与Web分块完整校验通过。公开版本 **[1ca9017cc17e](https://zhipijun1996.github.io/gunman-rush/?v=1ca9017cc17e)** 已发布，实际source_commit为 **4ed7ba67818c204070c8dca95e152ea0f1095e4a**；[PR56](https://github.com/zhipijun1996/gunman-rush/pull/56)不合并。[发布CI38282778069](https://github.com/zhipijun1996/gunman-rush/actions/runs/38282778069)core/Web/deploy均成功，原43/15套和新工坊检查通过。线上实际GUI两种输入回放、暂停恢复、评价下载零脚本错误；[线上构建](evidence/foundry/public_build_info.json)、[线上GUI](evidence/foundry/browser_public.json)。当前后续提交仅记录证据，玩法与已发布4ed7ba6相同。大陆网络可达性继续沿用D083未实测边界。

命令：

```sh
python3 tools/check_docs.py
python3 tools/check_world_design.py
python3 tools/foundry.py sources --fetch
python3 tools/foundry.py build --count 24 --promote
bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/foundry_lab_runner.gd
python3 tools/run_tests.py
python3 tools/run_plains_region_tests.py
python3 tools/run_plains_ten_tests.py
python3 tools/build.py web
python3 tools/build.py windows
```
