# G34 可穿遮掩藤幕

藤幕绘制在前景。玩家真实身体中心附近逐渐显露，离开后该处按独立恢复时长重新合拢。场景移动与缩放沿藤幕的本地坐标采样；重新定位后新位置显露，原位置的叶片逐渐恢复。每个实例保有自己的遮罩，只修改本实例的绘制透明度。区域 `texture` 槽可覆盖[原生藤叶贴图](../../../production/assets/world_elements/native/hanging_vines.png)，这张 64px 可平铺像素图由本项目绘制。其余区域沿用本区挂件、晶枝、菌丝或配重链，编成连续可平铺的前景纹理。 [区域原图与裁切](../../../art/mechanisms/regional-perception/provenance.json)

房间可在单个 G34 实例的 `texture_path` 指定项目内可加载的 `res://` 纹理，留空时沿用本区皮肤。编辑器保存路径，原生与 Web 使用同一导入纹理。贴图左上角对齐 `bounds` 左上角，一个原生像素占一个世界单位。单张前景的范围取图片原尺寸，更大的范围会平铺。纹理的透明轮廓保留。

入房和重置时先显示闭合的前景。进入 `reveal_radius` 后，身体周围的像素按 `fade_out_s` 淡到 `revealed_alpha`，离开后按 `restore_s` 恢复。地图发现由独立探索事件写入存档，已发现的入口在玩家远离时仍会重新被遮住。

[版本与参数](../../../production/config/world_elements/definitions/zone.foreground_cover.json) · [字段和端口](../../../production/config/world_elements/behaviors/WorldForegroundCover.json) · [设计合同](../失序之钟_基本机关库.md#g34)
