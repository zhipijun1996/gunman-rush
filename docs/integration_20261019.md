# PARALLEL-INTEGRATION-01：并行分支整合与重新部署

整合基线：森林 `ac002e7641fd282c291cdd7c25c9cf5d2450ce0a`。新分支 `integration/forest-plains-20261019`，保持未合 main。

| 输入 | 冻结 SHA | 整合范围 |
| --- | --- | --- |
| PR83 森林 | ac002e7641fd282c291cdd7c25c9cf5d2450ce0a | v12、15%双瞄准、斜下钩拉、挂环、历史存档及区域流程 |
| PR91 像素平原 | 2f25083da11da11604a3535a2feae20d119ac001 | 正式两图地形、演员、道具和三层视差；旧风格失败保留 |
| PR90 累积场所实验 | 913d77afa4019a0a2e6c84f270f3fe30ac2f00ba | 含前序PR81/82/84–89等祖先；显式候选入口，不替换正式池 |
| PR80 剧情 | 3e0ce1caf02ab8c400f85d85f9540405b977cee6 | 重复末日剧情、地区叙事及写作Skill；非完整剧情运行实现 |

按实际 ancestry 收敛累积链，不逐个重复合并祖先PR，不关闭原PR、不强推。main 当前为共同基线 e8ee34446aa82b4e64f5cdc414a22f5b6e2a6ca7。

共享入口按实际装配的地区同步角色和背景，防止平原像素皮肤污染森林以及跨区复用玩家留下旧皮肤。原始基础物理、钩索231射程、碰撞体、能力、资源和15%瞄准未改。Foundry冲突保留森林现行来源；各测试保留已实际修复且严格清理的森林消费者，未降断言或预算。

一次冲突脚本误吞DemoApp主体，独立审计及时发现；在部署前从三方完整原件重建，核对三来源全部函数，并增加实际消费者验证。该错误提交留在整合历史，最终文件以修复后源码为准。一次过早Harness定向运行因源在冻结期间变化实际失败，不计PASS。

存储：仅删除210个可重建.godot缓存（90,795,592字节），以及逐字节SHA校验后将1499个重复文件换为硬链接（约4.87GB）；源码、失败原件、日志和电影内容保持。原始路径清单在本机build/integration-{cache-cleanup,exact-dedup}.json。两个旧本地ZIP链接原环境路径不可取得，改为明确标注历史路径，不造可下载链接。

验证与发布尚在进行；最终CI、公开source/build_id/PCK及实际GUI以本页后续原始记录为准。原区域设计仍REVISE：冠叉反冲可省、尾路可跳过末两句、上层收益、Boss钩索价值和随机探索差异未解决；本轮整合不冒充新关卡设计完成，用户趣味/审美和实体设备未验。

## 冻结前实际回归

原生基本5676/0、钩索手感/挂环/输入系列、保存122/0、正式像素地形2097/0、像素样板19/0、共享表现30/0与原战役UI56/0通过。战役原Boss/奖励定位仅是结算fixture，不当自然通关。三个历史20%消费者保留全部旧hash与原断言，另对真实15%默认整份Manifest严格重建比较；world125/0、art-language2507/0、joint-recoil250/0通过。world新增真实几何与未知调优hash变造负例另验。原world124/1和像素样板缺父目录的真实失败保留，不追认成功。

独立只读审查接受源码整合、有限资产适配、元数据保管与表现消费者的限定范围，未观察实际画面/听音或签手感。72份新增资产carrier记录逐项保留实际来源，license unknown、visual unverified，不把Git来源等同商业许可或艺术准入。完整CI与新公开包仍待；原失败、专项日志与独审见[证据目录](evidence/parallel_integration_01/review01.md)。

三族消费者原CLI复验全通过；world随后新增两项重新派生hash的变造负例（地形位置+未知调优）也被严格拒绝，最终127/0。质量记录criteria格式错误曾被静态校验拒绝，随后修正记录格式，未修改校验器或豁免记录。

首候选2cb的push docs CI39229170834实际FAIL：107测试中4项缺ffmpeg（52.576秒），准确artifact12176782322/SHA绑定原ZIP保留；本地原107项45.396秒PASS。完整dispatch39229199208在已知CI缺依赖后终态cancelled（prepare成功，后续四任务取消、汇总缺lane失败，部署跳过），不能标完整通过或发布。修复只给docs/core/web安装ffmpeg/ffprobe，原测试与60秒预算不变；新源另跑正式CI。

## 第二候选实际超时与词法优化

第二候选d7f74556的push docs39230300225实际60.040秒超时；准确artifact12175224986/SHA93e8070ae230dce6c4fa0c715899881650e97ce8297f48c21aeb9f24e2640eb5原ZIP保留，不能把未完成107项计作通过。完整dispatch39230314758终态cancelled，未部署。原件见`evidence/parallel_integration_01/ci02/`。

一次完整只读profile定位112次真实输入预检中的重复纯词法路径计算；只优化POSIX component前缀与相对名称切片，Windows保留原pathlib规则，不缓存文件系统或预检结果。107个原测试和60秒上限保持，原symlink案例补祖先symlink→还原→fresh成功的实际反例。最终冻结源原CLI实测107/26.802秒，process27.034秒/exit0/60秒cap，完整raw及前后3个保护源SHA一致；此前29.380秒观察缺raw与Windows补前的局限单独保留。独立21项/路径等价及最终日志审查见review04/05，最终新CI仍待。

本机一次去重错误使固定可写aim_save输出与两历史文件共用inode，随后真实测试更新了历史路径。已从两份未改写的Git原始ZIP精确恢复两原件并将可写输出隔离；全1870路径核对仅current raw合法变化，另212个潜在可写路径断开。此为真实保管失败及恢复，不能称原去重安全。原件、SHA、恢复方法见`evidence/parallel_integration_01/custody01/`；现行测试与历史证据未互相冒名。

## 第三候选与最终文档预检

ff143c91的push docs39232313993中，生产原107项实际39.996秒通过；随后路由24项/16errors因旧总谱的20%/旧controls权威被正确拒绝。准确ZIP artifact12178082160/SHA4085967e50a2f3449c028a4faeff4d644afbd8e636b0b5666c3503a4762dad8b保留。full39232336288终态cancelled、未发布，不标完整通过。

现沿既有总谱schema升级两active creative-v3，完整归档旧v2字节/SHA，旧版用当前权威仍被拒绝；正式Plains对应PR91像素，森林对应v12/15%/挂环及REVISE。旧P1/PR90配方与素材没有升为当前默认；generic美术planner仍走旧候选，当前像素生产用途明确blocked，本轮不执行这类mission。原校验器未改；当前版本精确断言更新v3，新增原v2身份/bytes/拒绝反例。相关专项2方向/10creative/原24routing全通过。

本机原docs Harness --release一次完整24项实际PASS，原收据/全stdout日志无损ZIP在`evidence/parallel_integration_01/docs_final01/`；这是工作候选的本机证明，不冒最终CI。两原生正常速电影真实源ff143c91，2038/1769帧、60FPS、无注入/手动Motor、严格source_stable；后续只有docs与独立Python版本测试变动，2716项采集库存仅该非运行Python测试不同，运行/电影驱动零字节变化，最终Git绑定另验；绝不改签raw影片源。独审实际看8原AVI样帧，限定角色/树壁/环可读，没有全片听音或玩家认可；map2 HUD边缘可读性候选未证新回归，仍未签商业美术。见`movies01/`及review06。
