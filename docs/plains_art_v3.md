# 风铃平原精修 v3 交接

基线feature/plains-polish-home faecae2（提交前再次核对远程未变化），独立分支feature/plains-art-v3。用户已认可16区精细手绘画风，平原作为第一大关。此轮完成美术资源和素材合屏，不合并或部署、不变生成/物理/输入/经济，不覆盖另一个Codex游戏代码。

## 覆盖与保留

| 类别 | 交付 | 最新消费者接入位置 |
| --- | --- | --- |
| 角色 | 6类动作16帧无枪身体、独立枪 | CourierVisual接口保持，依据hero/manifest脚底/肩轴；旧四种分层SVG继续作正式运行回退，角色body/leg/scarf/weapon_arm四SVG只作技术回退 |
| 平台 | 草覆石灰岩/木铜桥、三款短台、自然岩体 | PlainsTerrainSkin；端头固定尺度，中段clip，落脚线取新manifest，不套旧硬编码 |
| 背景/装饰 | 有限平原远景、8件独立风车/遗迹/花草 | PlainsBackground；背景画幅使用纹理真实尺寸，另有background_layers/{sky,hills,meadow}.png可独立接入，不把整图当无限循环 |
| 机关/补给/奖励 | 12对象：锯/地刺/锚点/弹跳/双补给/金币/音符/心瓶/出口/箱/摊 | PlainsTerrainSkin、GeneratedDemoStage；所有位置/半径/拾取/奖励归原代码 |
| 敌人/Boss | 8个静态键，独立旋翼，两个Boss阶段+残骸 | EnemyPresentation/BossPresentation；保持实时预警/HP/碰撞与攻击，不因体型画法扩大危险 |
| 特效 | 12短促特效/弹体静态键 | PlayerFeedback/Projectile；复用事件与64粒子预算，护盾等储备不用作新能力 |
| UI | HUD货币/HP/双动作资源、六出口徽章、四品质框 | ActorResourcesHud、DemoStage出口、StageRewardModal；枚举0蓝1紫2金，白备用，币种分离 |
| 标题/家园/触控 | 保留已统一title_home字标、NPC与UI材质；触控边框可复用互动徽章 | 不假定衣装师/成就功能已开放，不改变输入热区和手指捕获，文本由引擎提供 |

所有PNG源文件保留原像素，图集在运行时按region读取；统一hash/dims与默认运行接入标志见assets/plains_v3/manifest.json。源图风格批准与新图运行完成分开。正式UI需保留Health/Stamina现有读数，本样板HP图标不抹除精力条消费者。

## 随机地图与具体限制

端头不横向拉伸，短板裁取缩窄而不改碰撞。岩体先用organic_cliff_fill.png（自然层理），浏览器交错镜像覆盖厚墙；limestone_fill.png为替代材质，普通repeat未过接缝要求。草中段/镜像岩花纹仍需真实长岸/高井/镜像检查，不能声称已无缝。平台变体是装饰造型，不自动增加新机制。

角色16帧支持独立枪视觉旋转，身体小手仍下垂，未做手臂追踪；枪口/伤害仍由原逻辑定义。动作图尺寸/轮廓略有变化，以逐帧脚底pivot对齐，不从像素改变Motor。Boss和VFX是静态状态键配程序运动，不是完整逐帧动画。背景新增天空/远山/草甸3层，均为有限画幅，长横/纵镜头覆盖仍需正式消费者验证；预览用轻柔饱和/虚化保持可读，正式shader须合屏校准，勿沿用0.08极低饱和而再次灰化。

## 预览与验证

preview/plains_v3.html：探索、Boss、道具二选一、78区域画册，六状态/朝向/枪旋转/可变宽平台。五张场景PNG及一张全素材画册可下载。截图为Canvas实际素材合屏，非Godot游戏截图；HUD数字/道具文案为明确样片。

检查python3 tools/check_plains_v3.py、python3 tools/check_docs.py、python3 tools/check_world_design.py。Chromium Playwright验证78区域、16人物帧、六状态、翻转与瞄准、两种平台宽度和探索/Boss/UI模式，无JS错误。当前安装Godot4.6.3，目标4.7.2；本轮未改运行脚本，未以4.6测试冒充目标验证。正式接入后另一Codex需目标引擎player_visual/enemy/boss/menu/home_ui总测试与真实镜头/设备验收。
