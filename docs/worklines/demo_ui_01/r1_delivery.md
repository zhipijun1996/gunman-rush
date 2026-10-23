# DEMO-UI-01 · 可操作交付与恢复检查点

- 基线：origin/main `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`。
- 已推送运行源码：`df5207ccc920f5d48813412a27d9d72dc79510ab`，分支 feature/demo-ui-01；Web构建 `5ae16004975a`。后续文档提交没有重建运行包。
- [独立Godot试玩](https://zhipijun1996.github.io/gunman-rush-previews/previews/DEMO-UI-01/df5207ccc920f5d48813412a27d9d72dc79510ab/5ae16004975a/) · [约30秒改前／改后视频下载](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/DEMO-UI-01/df5207ccc920f5d48813412a27d9d72dc79510ab/93b03ef086fc/comparison.mp4) · [15秒改后视频](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/DEMO-UI-01/df5207ccc920f5d48813412a27d9d72dc79510ab/93b03ef086fc/after.mp4)
- 托管提交 c676d703a80d1ba0eb47b9a04a40798c869286cf；[实际成功Pages运行](https://github.com/zhipijun1996/gunman-rush-previews/actions/runs/39843594774)。

## 实现

原生Control／Container／Theme统一旧铜、羊皮纸、深绿的像素钟表语言；标题含原生钟摆／风铃动态。主次操作、焦点、触控命中、设置、危险确认和结果页共用组件。首屏直接进入完整平原，地区页保留已有入口和明确的Forest开发说明，开发实验室保留FULL GAME返回。

真实health.current/capacity驱动逐单位爱心、失血残影与恢复反馈，小数生命才部分填充；10列换行，精确数值保留。射击精力为按实际消耗分刻度的条，空中弹药为离散单元；武器、共鸣、慢时、能力、金币和音符读正式数据。正常正式游戏移除旧黑板，F3和实验室兼容HUD保留；没有添加属性或改写玩法。

地图保留原迷雾、当前位置和地区／层数，手柄可平移缩放返回；不虚构探索记录。暂停、商店、出口、强制奖励、死亡／返回家园／再次出发沿原生命周期与结算。再次出发明确从平原新开一局，不改存档或能力授予。

## 共享接入供总控复核

相对基线DemoApp仅33行新增：HUD构造／绑定／上下文／解绑、原Start暂停入口、原结算后的只读结果页与原新开局、关闭界面释放焦点。HomeScene为3行替换；cloud_preview仅4行task_id专属挂接，隐藏游戏开发条、实验室保留返回。其余更改在UI、原生Theme与任务专属测试／文档；角色、怪物、环境、Motor、伤害／资源规则只读。

手机导航仍由原TouchOverlay.pause_requested唯一消费。任务HUD只调整既有_pause_rect的显示／命中几何，配全部IGNORE的原生Panel／Label，实际108×48px、字≥14px，地图读取此rect避让。TouchOverlay和InputProfile脚本未改。

正式数据源和Graybox／ModuleLab／FoundryLab／RandomStagePreview兼容消费者见checkpoint.md；旧ActorResourcesHud保留。并未逐个完整GUI走查所有实验室。

## 实际执行与证据状态

断连前实际执行通过（会话输出观察，**原始回执尚未归档**）：

| 实际专项 | 结果 |
|---|---|
| df520干净冻结源：新UI130、原Underworld UI255、Preview25、legacy101、settings14、grapple focus25 | 550项／0失败 |
| 原menu_scroll_touch_tests，取消／多指／生命周期／输入隔离 | 44项／0失败 |
| 实际公开Chromium桌面10＋模拟DOM手机11，设置→选项→滑动→Apply→平原→MENU→地图→取消 | 21项／0失败，engine errors=[] |
| 中文字体实际UI字符串，原7543字形子集 | 313个汉字，0缺字 |
| 公网完整PCK／合片SHA、build-info、main站部署前后元信息 | 匹配；main正式试玩未覆盖 |

原生布局与真实触控暂停包含960×540、844×390、720×1280、1920×720；含13.5生命上限、部分生命、受伤／恢复／消耗、死亡／重开、关闭地图后首次A／Space、中文与快速提交。模拟手柄／DOM触屏不是实体设备。

**环境断连阻塞**：最终执行git add／质量差异检查时，exec-server transport disconnected，环境变为unavailable。67MiB本地证据归档、原生PNG／日志、原始browser16报告与失败浏览器归档未能提交；不能声称这些文件已随本PR交付，也不补造原始日志。最后文档质量差异检查与提交树检查未完成。当前记录通过GitHub连接恢复到分支。

已从独立托管仓精确恢复真实电影report.json和after.json原件，逐SHA核对trace；见docs/evidence/demo_ui_01/recovered_movie_*.json。session_observations.json是对实际会话输出的明确摘要，**不是原始Harness／浏览器回执**。独立审查最终会话消息逐字另存，**不是完整review_v5.md原件**。质量卡保持review，技术归档与最终验收未签；完整Integration／Release与Windows导出仍由总控安排。原断言和预算未改。

电影为真实Godot MovieWriter，前后各900采样帧＋8清理帧，1280×720、60fps、48kHz双声道，合片30.287696秒。伤害／恢复是正式DamagePolicy／HealEffect的明确UI fixture，跳跃及瞄准松手射击是真输入；不冒称自然战斗路线、实体60fps或完整听审。基线电影按未变基线／驱动明确复用，after重新实录df520；媒体回执source_stable=true。

## 已修正问题与待验

真实浏览器发现并修正了设置初次滚动到底、Popup触控宿主挂错Viewport、Popup打开后原ScrollAdapter保留触点占用、旧触屏MENU过小。原生测试自身的逻辑／物理坐标混用已改用原menu_scroll_tests同样的root.push_input(local=true)。旧失败原件当时保留在本地，现在受断连阻塞。browser13取消后仍停在暂停页，旧断言漏识别高亮RESUME；最终公开16用两个暂停独有操作确认仍暂停，21项通过，不以OCR失败冒充行为成功。

实体手机／手柄、刘海屏安全区、硬件性能、全部实验室GUI、完整Integration／Release、用户视觉／密度／体验认可仍未验。技术结果不等于用户美术接受。可优先反馈爱心大小、资源辨识、菜单风格和标题氛围。

## 托管容量与恢复

最终站863411247字节，小于943718400预算。非latest旧CLOUD预览f3bd1c3/f6e7a0f8c6a1完整362文件逐SHA核对移至托管仓archives/previews，旧地址明确退休，latest CLOUD与各线视频保留；本线失败候选同样可恢复。并发FINE-SPACE-05页面／入口保留，main正式站未覆盖。

源码恢复检出df5207c；完整发布transport在托管提交c676d70。恢复旧预览从archives移回原site/previews路径，逐receipt核SHA、先腾预算，再运行 `python3 _tools/cloud_delivery.py verify-host --host-root .`。不需要破坏性reset或覆盖main。

若原环境恢复，先保全 /workspace/ui-workline/docs/evidence/demo_ui_01/ 与 build/verification/，尤其frozen-v7、native-v7、browser16、failed-browser.tar.gz；只恢复证据，避免覆盖GitHub新增恢复提交。环境无法恢复时，依据已提交tests/demo_ui_01/重跑必要专项，重新归档；不得按摘要补造旧回执。完整总控集成另安排。
