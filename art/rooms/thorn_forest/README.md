# 荆棘森林

房间、门、奖励、怪物物种和胜利条件以生产导入的世界数据为准。每间房的碰撞、站台、机关实例、怪物两岸、互动点和景片位置在 `production/rooms/world/F*.json`。

## 空间与回访

| 地段 | 玩家沿途能做什么 |
| --- | --- |
| F01、F02、F07、F08 | 从平原先看到古树背壁，携 W 从两壁交替起跳翻过高脊。根背横路进古树空地，下口进低冠。F08 保留林侧开闩再回 P01 的旧门线和接收台。 |
| F03、F04、F05、F06 | 巨木纵室中层回空地，西侧接峡谷，树梢进古堡侧冠，根底通倒木。西根谷可沿低床交战，也能取折返高龛。横谷倒木的上下表面分别接两层路径。 |
| F09、F10、F11、F13、F14 | 根颈下降到菌木洼地；在路牌处分向忍者支路或根脉圣殿。树腹外圈保留休息和通行，进入底台主动挑战枯枝角兽。低根扫可以跳过，半血后要离开锁定落点。 |
| F12、F15、F16、F17 | 墓穴林口区分现成墓道与从根冠牵开的石盖。古堡侧冠和风巢处于上层，根钩布置在侧枝上方，高冠闩从合法内侧开启。 |
| F18、F19、F_IN01 | 粗根横廊在岩门和隐居屋之间分路。屋外有竹帘敲门与休息处，进入不触发战斗。主动切磋后才能领取手里剑。 |

## 运行图源

`art/world-art-v2/assets/pixel/` 中的 forest_arch、forest_detail、forest_lamp、forest_plant、forest_slab，以及该库 v2 中的 root_bell、hook_root、seed_pods 作为原生部件复用。林缘全景、中层、近层和倒木继续用 `production/assets/world_elements/forest_stage/` 中的正式图。两种普通敌人的原生身体来自 `production/assets/forest_bible_v2/native/fine_32/`。

本目录四张无损 WebP 原稿由 ImageGen 为本区创作。运行 `python art/rooms/thorn_forest/slice.py` 从原稿裁出正式像素尺寸。角色姿态的足底共用同一原点。枝形依附可穿越平台，树枝的可站区由原有碰撞矩形决定。

| 原稿 | 用途 |
| --- | --- |
| forest_duels_source.webp | 角兽站立、压角与扑跃，忍者静立、投掷前摇与腾身。 |
| practice_house_source.webp | 林间竹帘木屋、一间连续的练习厅木墙。 |
| branch_construction_source.webp | 枝台、垂根、老树身和斜根承托。 |
| forest_depths_source.webp | 树腹、风冠、菌沼和林中古墓远景。 |
