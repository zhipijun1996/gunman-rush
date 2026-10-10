# 会话交接

2026-10-10 UTC。分支 **feature/random-stage-preview**，从干净feature/loop-boss-modules@d718779创建；实际重新fetch origin/main=64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226。PR23仍未合并，因此本轮叠加该开发链，未自动合并/强推。前轮证据见[八模块交接](archive/handoff_loop_boss_modules.md)。用户本轮明确要求先拼接随机整关看效果；D043/GEN-PREVIEW-01授权独立开发试玩，不假装详细设备验收通过。

## 当前实现

主菜单RANDOM STAGE实际消费RandomStageGenerator→RandomStageAssembler→RandomStagePreview，默认7模块（接口6–8），安全首尾/中间无放回挑战候选。横向平移、高低变化，既有台阶/下降/反冲升井/机关/摆渡/双路可组合；不旋转重力或改物理，Boss练习仍独立MODULE LAB。实体安全接桥连端口，世界镜头跟随/前视/边界夹取，MAP OVERVIEW暂停玩法并显示完整图。相同Seed重试重现实际图与初始相位，NEW SEED换组合。

版本化JSON布局Manifest包含seed/算法/校验/内容hash/能力物理快照/节点变换/动态初始phase/接缝/世界bounds/镜头配置；恢复校验已记录布局后直接实例化，不重新抽样。内容hash基于可导出Resource属性与显式运行版本，不读取PCK中不存在的源脚本。4次有界尝试后使用同开发preview的兼容全安全步行图；不存在正式类型隐式替换。运行校验是几何/净空/危险与能力筛选，完整Motor轨迹证据另外执行，不能声称每Seed做了物理搜索。

复用FrameDamagePolicy/SegmentRespawn，非致命伤害只回当前安全锚点，保留地图/实例/clock/精力/冷却和已扣HP；清旧动作/速度，零血结束回Home，取消epoch/异步出生。没有Run/Meta奖励或永久收益。正式房间类型/双出口/十关随机/Boss外围、纵向/方形/难度曲线/手机验证仍后续，本片是组合试玩。

## 实际检查与失败修复

Godot4.7.2.stable.official.ed1daf0bf Standard。Cloud spec77连接就绪，observations_current=true，network_policy=enforced unrestricted；正常Git/gh，不输出凭据。本地版本实际执行退出0。网络20–25秒、导入90秒、完整套件330秒、导出180秒、浏览器180秒，超时/失败非零。

首版JSON恢复全部80样本失败：GodotJSON数字类型变化，新增canonical数值/类型校验后修复；错误版本原先int/String比较会脚本异常，现明确拒绝。第一网页真实跨第一缝成功，但Pause失败：触屏MENU被Seed字段遮挡；缩窄字段并下移右侧按钮，路线条避开精力文字后重新导出/验证。独立消费者测试在physics_frame信号中切换暂停触发引擎p_elem->_root错误，定位到测试调用时机，UI事件实际idle；改在process_frame执行菜单动作，原冻结验收不降低。

最终完整测试/导出/浏览器/CI/提交与PR结果完成后在下方记录，未完成不称已过。日志保存忽略目录build/verification/random-stage与random-stage-browser；不提交引擎/SDK/密钥/本机绝对路径。

## 未验证与下一任务

A55仅横向开发切片，A50三拓扑/A52正式类型曲线/A53完整RunManifest/A54生成关真机未完成。详细Android/iPhone Safari手感、遮挡/帧时、Windows实机、实体手柄仍独立待验；本轮无新APK。旧固定3/10关与八模块保持回归，不把这张开发图替换正式Boss10规则。Q001–Q013保持待决策，永久经济/存档/剧情/Steam无新增。

下一步根据全图试玩反馈增加多动作组合模块、缩减重复安全走廊并验证新的动作轨迹；随后按正式GEN-LAYOUT门槛加入纵向/方形与六类型完成/奖励消费者，再做阶段多轴预算。复现：python3 tools/check_docs.py；python3 tools/run_tests.py；python3 tools/build.py web/windows；python3 tools/verify_random_stage_browser.py URL。公开页版本需以实际build-info为准。

## 本地证据与交付

实际完整`python3 tools/run_tests.py` **2380断言/0失败、退出0**：保留1501旧回归，854生成/JSON复现/完整路线+25消费者。运行中网页发现重试后全图按钮变更但实际镜头仍单屏，Camera2D在暂停时未更新viewport；补make_current/force_update_scroll，增加3个真实viewport canvas矩阵回归，不只检查zoom属性。最终独立消费者 **28/0、退出0**无引擎错误。完整2380证据是刷新修复前源码快照；最终源码及2383预期总数以远端实际CI结果另记，不能冒称本地旧快照已涵盖后续新增断言。

完整动作轨迹：seed0/0跳0枪，six-node safe_hub→square_loop→timed_gallery→descending_switchback→square_loop→safe_hub，1899–1900ticks；seed5/1跳1枪，safe_hub→square_loop→recoil_shaft→descending_switchback→stepped_crossing→safe_hub，1812ticks、1次真实松手弹体/反冲。每条5个实体接缝连续通过、全24×36身体扫掠无危险/无段间传送。不是每Seed完整物理搜索，也不把连续phase或任意属性改动当已证。

首轮Web与Windows分别导出 **退出0**，Web包 **3d620fc8e56a**。`python3 tools/verify_random_stage_browser.py`实际Chromium触屏模拟 **10项通过、退出0**：全图7模块、真实触控world_x120→1614/section1→2/camera640→1650，暂停/设置/原Seed相同静态图hash/新Seed不同图/Home原摘要。查看实际全图截图；网页只实走第一接缝，整条路径由上述headless Motor证明。单资源404保留，无SCRIPT/Page/Shader错误；真Android/iPhone Safari继续待验。浏览器可选依赖Chromium/Playwright/Pillow/Tesseract，所有OCR只读渲染截图，菜单滚动使用普通GUI滚轮，玩法使用真实触屏，没有浏览器内部传送。

文档29必需文件/40任务依赖检查退出0，git diff --check退出0。分支实现提交/PR/最终CI与公开部署结果随后记录；未自动合并。

## 远端失败与镜头归属修复

实现1230480，[PR #25](https://github.com/zhipijun1996/gunman-rush/pull/25) OPEN，base feature/loop-boss-modules（PR23及此前链未合并）。首轮推送Godot CI38018514590与PR CI38018537490均 **failure**：实际2383断言/1失败，只在“Retry替换镜头的暂停canvas缩放”断言失败；Windows/Web/deploy因此skipped，没有部署失败版本。文档CI通过。日志ci-first.log保留，不冒称CI通过。

复现默认/120/10FPS确认实际canvas=1、zoom≈0.118、camera.is_current=false：旧镜头退出会延后选择viewport继任者，抢走新镜头current资格。生产修复为激活就绪时、总览时明确取得current，正常跟随物理帧在丢失current时恢复。没有改玩家/地图或删断言。新增真实viewport镜头所有权断言，暂停冻结快照改在实际暂停事件后采集（此前在awaitidle前采集可合法提前推进clock）。默认/120/10FPS目标测试分别 **29/0、退出0**，无引擎错误。最新完整预计2384，当前正在执行且等待新CI，实际结果另记。修复提交及公开包完成后再记录。
