# 当前交接：D082 连贯平原与空间约束

运行提交 **63c56aa3ba7c45f7b306063a2c23a85d1fdfe79c**，分支 **feature/plains-cohesion-and-pressure**。后续提交只补验证工具、证据和文档，不改游戏。[PR51](https://github.com/zhipijun1996/gunman-rush/pull/51) OPEN，base 为 feature/plains-interactive-platforms，不自动合并。

初始工作区干净，fetch 核对远端后从 D081 d7cd4c3a 建立分支；最终复查 main 仍 ab51fca，前序 PR41–50 关系保持。没有覆盖用户改动。[D081归档](../archive/handoff_plains_interactive_platforms_d081.md)、[D082实现](../plains_cohesion.md)、[机器验证](../evidence/plains_cohesion/verification.json)。

## 公开试玩已更新

[最终试玩 da08f78fa687](https://zhipijun1996.github.io/gunman-rush/?v=da08f78fa687)。[发布CI38216711004](https://github.com/zhipijun1996/gunman-rush/actions/runs/38216711004) success。公开 build-info 的 source_commit 与运行提交一致；实际下载 PCK **32756968 字节**，SHA256 **da08f78fa687f208c9b193cad0484399f7c7b1cbda188ae73ba690c3ee80bbd9**，前缀与版本一致。[包核验](../evidence/plains_cohesion/public_package.json)。原版本化 PCK/引擎与缓存契约保留，不能只用 PR 或 HTML 牌代替发布。

线上三套普通 GUI 均 failed=0、build_id=da08f78fa687：

- [正式流程](../evidence/plains_cohesion/region_public_gui.json)：标题→家园真实步行/交互/9音符独立保存 fixture 的购买与重载→出发门→随机连通平原1/2；迷雾小图打开大图、隐藏未知目的地、定位/滚轮缩放/拖动/关闭；教学移动、跳跃和鼠标释放。9音符不是实际赚到；该行程未观察到新音符收入，不称自然全图探索。
- [新操作与机关](../evidence/plains_cohesion/cohesion_public_gui.json)：键盘家园起跳在站立高度上方产生761个实际变化像素，射击真实扣能；八个 MORE TRIALS 入口，远铃 OPEN、渡台 MOVING→PARKED→MOVING、异地双铃第一枪打开中间实体通道并提示 CLIMB/FIND REMOTE RING2；II/III实际AI形态。阶段24/12HP是命名练习 fixture，不称自然打出的阶段。
- [道具与命中](../evidence/plains_cohesion/energy_public_gui.json)：实际AI图标/介绍/效果选择，降耗20→16，库存保持；真实鼠标弹体造成训练敌人20→19，提交命中返能、未命中扣能与站地恢复。训练入口不是正式 earned 奖励或完整Boss胜利。

截图和录像在 build/verification/d082-public/{region,cohesion,energy}，公开图像来自实际页面。正式流程首次请求出现网络导航45秒超时，原判定不改的重试通过。另一次本地旧 pressure-browser 有限开场名观察超时，未计作通过的最终套件。

## 实际实现

家园接入关卡共用 InputSetup、TouchOverlay、PlayerController、瞄准线/慢时/射击精力与资源HUD；面板取消旧输入。正式 Boss 完整进入后警示/镜头 offset 震动，0.65秒后真实两侧门关闭；场内环境回退、暂停重载、死亡释放及胜利开门保持。

主动发现并修复两项正式消费者问题：高台合法起跳越旧触发框顶端会丢失射击资格；警示期间同类跳跃会重启倒计时。战斗和警示现在读取真实实体墙覆盖范围；真正侧向离场仍取消，未封场/侧墙外/死亡攻击仍拒绝，不改弱点或碰撞范围。旧八关/练习退场语义保留。

新刺格→移动齿轮→安全岛→第二段刺格、挡弹遮挡→登高→异地第二铃→远门等真实动作；刺墙/低顶/井底接齿轮、齿轮平台嵌刺，探索配方覆盖约束不往短教学刷危险。固定八种子的实际齿轮模块4–6、表面荆棘模块4–7；不是按总节点数宣称难度。16个配方中2个共用双齿轮模块，计数不等于16种完全不同操作。两张网状图、奖励预算与基础动作保持。

原创 AI 草石、岩层、外露根边、细木台和两种Boss死亡特效；原PNG不编辑，源SHA/裁剪登记。正式装配器补入原来漏执行的世界采样/实体 union 边缘消费者，地基/第三阶段断桥同步更新。敌人掉落0.65秒飞落/0.25秒吸收，mini有限爆炸、大Boss风叶消散与可见保证箱；0.9秒后才可打开结算，原12币/1血与金奖只付一次。死亡同帧优先，不生成奖励。

## 检查与边界

官方 Godot 4.7.2.stable.official.ed1daf0bf。最终运行提交完整CI：Core **5942/0**、原 **43套**、地区 **15套**通过；新生命周期 **19/0**、模块双向四危险相位 **63/0**、掉落 **17/0**、正式Boss **22/0**。100素材源哈希/尺寸/锚点检查通过，Windows/Web导出完成。[CI摘要](../evidence/plains_cohesion/ci_completion.txt)。

六轮独立审查依次保留基线否决、catalog/消费者失败、密度反例、视觉局限、真实高跳资格否决与警示计时否决；修复后独立复核，见 [第1轮](../evidence/plains_cohesion/review_round1.md)、[第2轮](../evidence/plains_cohesion/review_round2.md)、[第3轮](../evidence/plains_cohesion/review_round3.md)、[第4轮](../evidence/plains_cohesion/review_round4.md)、[第5轮](../evidence/plains_cohesion/review_round5.md)、[第6轮](../evidence/plains_cohesion/review_round6.md)。早期3b3版本曾成功发布61eb；17c发布因新反例主动取消；最终63c已替代中间版本。没有删失败测试/放宽人物物理；旧即时掉落/隐藏检查保留在新动画结束后，并增加飞行拒领检查。

PlayerMotor、player_tuning.json、input_profile.json 源 SHA 与 D081 相同（完整值在机器验证）；一跳/未命中两发、命中返能、独立慢时资源、段回退/账本/存档契约不变。只平原两张随机图，大Boss后开发边界，不发未实现大能力、不开放森林、不算全游戏胜利。

日志保留既有退出 ObjectDB/resources/RID 诊断。最终CI Windows/Web各两条 windkeeper.tscn:13 Parse Error: Busy 后完成导出；实际公开II/III消费者正常，不称所有导出诊断消失。[原文](../evidence/plains_cohesion/export_diagnostics.txt)。

仍有周期根带/土块切口和部分教学浅黄字对比的视觉局限；完整真人双图/Boss通关、主观趣味/画风、手机/实体手柄/Windows实机待验，不宣称Ori品质。下一步按实际试玩反馈细化这些，不能拿 headless 或 fixture 代替真人验收。

复验：`python3 tools/check_docs.py`、`python3 tools/run_tests.py`、`python3 tools/run_plains_ten_tests.py`、`python3 tools/run_plains_region_tests.py`；公开GUI使用 tools/verify_plains_region_browser.py、tools/verify_plains_cohesion_browser.py、tools/verify_plains_energy_browser.py，目标为上方版本URL。
