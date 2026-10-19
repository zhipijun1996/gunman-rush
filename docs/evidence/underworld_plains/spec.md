# Underworld正式平原与Tile生产流程

任务 UNDERWORLD-PLAINS-01；基线 feature/windchime-five-style-lab @8382a41cb0ccf9a8e2e56075ade9edaceb4ff67a，继承本轮最新开发源2f25083。用户原话：我更偏向于Underworld风格；整理好harness和skills的修改，怎么参考开源tile/生成tile/做关卡、3层3速度景深、装饰，然后整体修改风铃平原；荆棘或接触伤害tile要和平台融合。

已授权方向：Underworld暗体/薄苔缘/风铃焦点；16区同画法各有色域/材料/大形。本轮只重制正式平原两图，不开放森林工城、不改Motor/物理/武器/资源/伤害矩形/随机流/存档/既有布局。原五风格实验保留。

准入：真实永久47TileSet+TileMap核心和非整格精确边界适配分开；来源许可、原像素/参考/生成/裁切可回放；3张独立景层根据限位后screen center以不同速率移动，移动/回望/横纵限位与竖屏无露边；装饰无碰撞/有支撑/keepout/独立seed；危险四向材质有根与端角，外侧原伤害band不变，不把无支撑落坑画作悬浮刺。

先独立几何/三窗黄金，再接正式两图10seed与Boss破桥刷新；原强验/失败不删除，正常速度走跳影片与静态定位明确分开；独立实看像素和有界返工；最终Web准确source/build/fullPCK/license/真实GUI。用户审美、全部动作/听音、完整自然通关与实体设备没有证据就未验。

真实分工：tile_pipeline负责5份Skills/审计/harness；formal_terrain负责同源Tile及正式几何；terrain_hazards负责融合危险材质/原伤害接触；underworld_scenery负责3真生成景层/装饰；root负责正式整体演员与入口/集成/记录；production_review为不同作者只读审查；underworld_delivery负责准确源导出/公开字节/实际浏览器。未把计划路由或模板当模型后台服务。
