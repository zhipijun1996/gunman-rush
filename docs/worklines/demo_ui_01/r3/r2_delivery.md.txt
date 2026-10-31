# DEMO-UI-01 · R2 可操作候选

R1 已被用户明确拒绝。本轮按五项反馈完成真实 UI 返工，等待用户评价新外观，不宣称商业品质定稿。

- [独立 Godot Web 试玩](https://zhipijun1996.github.io/gunman-rush-previews/previews/DEMO-UI-01/1d1d8368ffd03de38e59fbd1140d44c5ba95c403/7127eaf8cef7/)
- [29.95 秒 R1／R2 真实引擎对照视频下载](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/DEMO-UI-01/1d1d8368ffd03de38e59fbd1140d44c5ba95c403/4df0009a0175/comparison.mp4) · [14.8 秒本轮视频](https://zhipijun1996.github.io/gunman-rush-previews/deliveries/DEMO-UI-01/1d1d8368ffd03de38e59fbd1140d44c5ba95c403/4df0009a0175/after.mp4)
- [Draft PR105](https://github.com/zhipijun1996/gunman-rush/pull/105)，分支 `feature/demo-ui-01`；未合并源仓 main。
- Web／影片运行源码：`1d1d8368ffd03de38e59fbd1140d44c5ba95c403`；Web build：`7127eaf8cef7`。
- 干净原生专项源码：`dce1a7172fd122ed1fd7f1e7d3263c87caf5d74b`。它与运行版本仅差原测试 helper 滚动前等待4帧，运行／资源／项目／导出设置无差异。原件与独审见 `docs/evidence/demo_ui_01/r2/runtime-equivalence.json`、`export_review.md`，没有重标旧影片为新源码。
- 原 main 基线：`e9ab0e0743466b8983e34cc7de17bab1abf9d53a`。后续文档提交只补证据，最终分支头以 PR 为准。

## 本轮变化

1. 全游戏 Control、Theme 及既有 CanvasItem 字体统一到 Fusion Pixel 简中像素家族。未修改旧字体文件、角色或敌人脚本；字体兼容资源在运行时绑定同一数据，清理旧字形缓存并保持强引用。实际 UI／物品／Boss／家园中文检查零缺字。OFL 及上游依赖许可证原件保留，并验证已进入 PCK。
2. 按钮与面板使用共享圆角、铜边、底部厚度、阴影和焦点材质；修复透明焦点阴影压暗主按钮的问题。地图与 MENU 使用同族紧凑样式，原输入消费者不变。
3. 标题改为独立生成的全幅印象背景与右侧透明 DISORDER CLOCK 铜钟徽章，中文名称强化。两个原 PNG 不加工，按钮仍是原生交互控件。四个主项为开始游戏、继续游戏（选择存档）、设定、新手教程；开发入口为次级。轻微漂移／风尘沿现有减少装饰特效设定关闭。
4. 暂停提供暂停／行囊真实页签；设置与操作说明并排，移除重复行囊大按钮。装备分页保留禁用和未开放说明，不能假装已经实现。危险返回可取消。
5. HUD 改为小爱心独立铜槽、真实消耗刻度的精力舱、武器徽章和弹匣单元。金币／音符／地点只用局部衬底。手机地点短牌移开左摇杆；生命上限增长换行，真实小数才部分填充。没有增加属性或修改生命、伤害、资源、能力规则。

继续游戏只选择原有单一本地成长记录并回家园，不是多槽存档或局内位置恢复；独立 Preview 禁用持久化，明确区分本次会话。新手教程先显示说明，可进入正式平原原有教学起段，未新增教学关或授予能力。

## 实际验证

| 证据 | 实际结果 |
| --- | --- |
| 干净冻结专项 | UI146＋R2223＋原Underworld260＋Preview25＋legacy101＋settings14＋focus25＋touch44，共838项／0失败；另外222素材登记项通过 |
| 公网 Chromium154 实际画布 | 桌面鼠标10＋模拟DOM手机11，共21项／0失败，engine errors=[] |
| 实际输入 | 真实悬停／点击、原生滚动与弹出选项、设置Apply、暂停／返回／焦点、地图关闭后首次Space、取消／多指／touchcancel、无旧射击泄漏 |
| 布局与资源 | 960×540、844×390、720×1280、1920×720；中文、数值增长、13.5生命上限等明确资源fixture、受伤／恢复、正式死亡／重开／Home切换 |
| 影片 | Godot MovieWriter 1280×720／60fps／48kHz双声道；官方伤害／恢复API的明确UI fixture，以及真实跳跃／瞄准／松手消耗；完整对照29.954667秒 |
| 公网字节 | HTML、146855616-byte PCK、影片SHA及build-info完全匹配；main正式试玩部署前后元信息相同 |

旧测试的黑底色值快照改为验证实际共享 CompactButton 材质，仍检查原正式消费者。原生测试 helper 等焦点延迟恢复结束再滚动；R2滚轮 helper 补齐按下／释放。没有删除原断言或放宽原180秒预算，失败与定位原件保留。浏览器初始整图OCR失败也保留；最终用已实际查看、经原生精确标签和路由验证的控件材质边界定位，再执行真实鼠标／触控，不注入引擎假点击或状态。

本轮仅 Development 专项；按用户要求不反复全量CI、Windows导出或恢复全仓历史。源分支提交用 skip-ci 将全量Integration／Release留给总控，原workflow、断言和预算不变。全仓check_docs因稀疏检出缺少无关历史引用／证据文件而失败，原日志保留；本任务质量卡、差异范围和新增来源记录单独检查。

## 共享接入与边界

新增R2接入仅：project.godot字体autoload／custom_font；DemoApp._process六行选择器可见性，使旧外观选择器不浮在全屏菜单上；export_presets新增字体许可／来源include；assets/manifest追加两张本任务UI图。旧R1正式HUD／Home／Preview入口接入见checkpoint。角色、怪物、正式环境、拓扑、Motor、资源／伤害／存档规则保持只读。

托管提交 `33023e2c0be3b9369880f2c001e92cd17d24c6a6`，[Pages实际成功运行39880510414](https://github.com/zhipijun1996/gunman-rush-previews/actions/runs/39880510414)。保留并发FINE-SPACE、DEPTH-FRAME与武器V2页面／媒体和链接。预计站点934577261／943718400 bytes，剩余约8.7MiB；后续新增交付先核容量。

被拒R1试玩已可恢复归档；最初托管push因原始PCK超过GitHub100MiB被拒，已改为原精确gzip分片归档，实际重建SHA验证一致后成功推送，未强推。R1历史证据305文件已逐SHA恢复并提交，见r1_recovered_manifest及tar.gz。原R1交付／质量原文另存，不再作为本轮完成证明。

## 尚待评价与恢复

重点请评价字体风格、按钮大小／厚度、标题气氛、左上HUD是否协调及资源是否一眼读懂。低优先跟进为地图探索色对比和混合中英文文案；手机标题的次级开发入口需滚动。实体手机／手柄、设备性能、完整影片动态与音轨审查、用户审美和完整Integration／Release仍未签通过。

可从运行提交创建独立worktree，沿仓库Godot4.7.2工具链打开完整游戏；或运行 `bash tools/godot.sh --path . res://scenes/dev/cloud_preview.tscn -- --task=DEMO-UI-01 --entry=menu --seed=level-design-v2-baseline/08` 重现独立Preview。测试修正版使用dce1。源码、原PNG、字体许可、原始执行／失败证据和独审均已归档；不需要合并main即可继续迭代。
