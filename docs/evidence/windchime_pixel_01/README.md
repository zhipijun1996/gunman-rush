# 最新交付：已上线正式两图候选

[HTTPS试玩](https://zhipijun1996.github.io/gunman-rush/?plains=1&v=d2c684ef8fc0)，build `d2c684ef8fc0` / source `c0f8e50770145795db5affd4afdbffff2479f1ea`。[交付身份](delivery.json)、[独立终轮范围报告](formal_review/report.md)、[发布后实际GUI](root/published/report.json)。下文进行中的历史说明已由本节复验结果覆盖，原失败不删除。

原15套区域回归分批完成；冻结源4套当前/原断言再测2097+19+27+488均0失败，实际正式consumer原探针冻结复跑21000/0。最初脚本退出依赖环、艺术工具Nil、破桥悬空与竖屏覆盖均有修复/复验链；旧双层默认断言保留为明确legacyfixture，当前三层默认另测，不冒充旧consumer仍默认。

最终专项harness五项fresh通过，原始报告/日志在[root/harness-final](root/harness-final/targeted-summary.json)；完整适用profile仍在历史docs断链处失败，不冒称全绿。

正式地形是精确矩形并集适配，不是dual-grid/47正式TileMap。完整视觉状态、用户最终整区审美、实体设备/音轨和最差Seed仍未签；不能将技术与定位检查升级成自然全战役或商业品质通过。适用全量harness受历史稀疏docs证据断链阻塞，继承asset-consumer路径审计也未解决。

---

# WINDCHIME-PIXEL-01：晨光像素风铃平原

最新用户已认可小样感觉并授权整个正式平原、三个独立远景和简单纹理；允许dual-grid替代47。完整原话见[user_request.txt](user_request.txt)。旧暖色失败方向未复用为创意输入。本任务使用game-quality-gate、art-director、scene-composer、animation-vfx与独立gameplay-reviewer；没有改造敌人AI/Boss机制、地图生成或玩家物理。

## 实际消费者

- 标题主按钮与`?plains=1`进入真正的两图正式平原，而非一屏材质场。新主角、普通/特殊敌人、Bellstrider/Windkeeper、拾取、箱子、商人、风铃/开门/封门/荆棘/移动铜台均迁移新表现。
- `PixelFormalTerrain`描绘原平台矩形与支撑体的精确并集。已有地图大量偏移与24wu窄墙、18wu薄台，强吸附32格会改变碰撞。**这是精确边界视觉适配，不是dual-grid或47 TileMap已经迁移正式地图。** 未来网格原生模块可用dual-grid；原一屏样板仍真实47态×3。
- 三张工具原始PNG分别是parallax_far/middle/near，不是合并图的三份。实际相机系数分别(.035,.015)、(.12,.04)、(.28,.075)。水平周期复用，alpha层端部淡化；未宣称原图本身无缝。GPU导入后原始PNG字节有可能无法从res读取：Web日志空hash不当作源核验，原始hash在assets/manifest和generation记录，native消费者另测。
- 装饰使用独立坐标hash、完整图框保护区、实际外露支撑面；不消费玩法RNG，不加碰撞。材质以安静体块/少量破面为主，没有颗粒叠层与复杂纹理。
- `?pixel_plains=1`是原一屏小样。`?plains=1&pixel_inspect=1`或2是明示**定位艺术检查**工具，不是通关证明；正常入口不注入位置/能力/血量，也不关闭伤害。

## 来源与生成预算

[generation.json](generation.json)记录同一任务5次imagegen：1张小样远景、1张用户简洁纹理要求后未采用的石材尝试、3张正式分层远景。正式PNG逐字节复制工具原件；无旧失败美术作输入。生成模型/成本未暴露，许可状态unknown，不签商业发行素材终审。地形/小物/角色/图标为本轮原创像素程序；[tools/build_pixel_plains_art.py](../../../tools/build_pixel_plains_art.py)可复建47图集和8件小物。

## 已取得的证据与边界

- [独立几何审查](formal_audit/implementation_review.md)：32231/0；正式地形专项2097/0。原始/拆分矩形并集、对角触碰、重叠、子像素缝隙和4套真实地图矩形均核验。
- [演员身份检查](actors/README.md)：实际两图110/0，伤害反馈12/0，未改Motor/Actor/Health/Definition/shape身份。
- [正式独立消费者](formal_review/formal_inventory.json)：普通菜单map1、同hash重载、明确第二图outcome fixture实际实例，21000/0；后者不是赢Boss/路线通关。
- [真实教程路线与视差](formal_review/formal_route.json)：574帧、2次跳与3次射击，无reset；实际相机横移超过1700wu，三个实际源及相对位移分开测量。原逐帧采样邻帧失败保留，稳定相机后复测。
- [root/core.log](root/core.log)：完整基础5676/0；[root/study.log](root/study.log)：小样真实Motor与生命周期19/0；[root/foundry.log](root/foundry.log)：36短句、18连续行程。
- 初次定位检查的真实GPU孔洞/分块像素oracle每图552960/0，但检查工具自然死亡后点击触发Nil错误，原失败保留在[root/inspect-initial-failed.json](root/inspect-initial-failed.json)，修复guard后另复验，不能追认原次无错误。
- 旧15套区域回归第9套功能2871/0但退出资源泄漏，原失败[root/region-initial-failed.log](root/region-initial-failed.log)保留；正定位/复验，不把0断言失败写成整套通过。
- 适用docs/art/gameplay/web harness已实际尝试，先被稀疏历史证据断链阻塞；并行隔离另受partial clone历史对象缺失阻塞。根本不删除旧断言、补假证据或降低门槛。

用户小样感觉认可不自动签最终整区审美；实体设备、完整听音/触屏手感、全区长路线与全部最差种子未验。最终源/部署版本/新GUI与独审补充在交付记录，不用旧Web冒充新风格。
