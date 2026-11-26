# G34 可穿遮掩藤幕

藤幕绘制在前景。玩家真实身体中心附近逐渐显露，离开后该处按独立恢复时长重新合拢。场景移动与缩放沿藤幕的本地坐标采样；重新定位后新位置显露，原位置的叶片逐渐恢复。每个实例保有自己的遮罩，只修改本实例的绘制透明度。区域 `texture` 槽可覆盖[原生藤叶贴图](../../../production/assets/world_elements/native/hanging_vines.png)，这张 64px 可平铺像素图由本项目绘制。其余区域沿用本区挂件、晶枝、菌丝或配重链，编成连续可平铺的前景纹理。 [区域原图与裁切](../../../art/mechanisms/regional-perception/provenance.json)

[版本与参数](../../../production/config/world_elements/definitions/zone.foreground_cover.json) · [字段和端口](../../../production/config/world_elements/behaviors/WorldForegroundCover.json) · [设计合同](../失序之钟_基本机关库.md#g34)
