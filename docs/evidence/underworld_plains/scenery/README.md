# Underworld正式平原景层与装饰

任务 `UNDERWORLD-PLAINS-01`。本目录是实际景层组件与正式地图定位检查，不代签整区美术、自然通关、实体设备或商业品质。

三个独立原PNG由3次真实 `image_gen.imagegen` 调用产生，参考已选Asouris Underworld原始TileSet；原图、完整prompt、参考/source/消费图SHA与处理步骤位于 `assets/underworld_plains/backgrounds/*_generation.json`。原图和消费图字节相同，没有把同图裁成三层。远景是蓝色黄昏天空和低丘，中景是透明天空的钟塔/风弯树，近背景是透明天空的低草坡/旧木风架。中/近原图分别82.18%/82.41%严格alpha零；模型、token与价格未暴露。Asouris自定义宽泛使用许可不是CC0，出版方文本保留于实验source/licenses。

`scenery_build.json`是实际消费者的唯一景层配置。三个横向相机系数为 `.035/.12/.28`，纵向为`.015/.04/.075`，读取真实 `Camera2D.get_screen_center_position()`。源图等比缩放；远景同边镜像重复保证覆盖，中/近层正常方向重叠并仅在边缘羽化alpha。纵向移动被限制为屏高±10%，远景额外限制确保全屏不露黑；不能声称无限纵向匀速。中/近材质把原图luma映射至受限冷灰蓝雾色，近背景暗于中景，不继承玩法的明亮绿色可踩边。没有Light2D动态阴影。

装饰复用选中的原创Underworld风铃树、风架、花簇，使用原完整region、根锚与等比缩放；另复用Asouris原生草region `[96,32,32,16]`，实际world height18。无碰撞、无伤害，与玩法RNG分离；macro-zone独立hash安排稀疏焦点。所有可见根扇宽度必须位于真实暴露静态solid顶面，整物bounds+8避开危险、敌人预告/巡逻、落点、移动平台扫掠和功能对象。one-way、移动平台不当树根支撑。最多2大物/1280宏观区、2小草簇/区；存在保护空间时允许省略，不能用元数据虚报每区焦点。12粒低亮微尘只做表现。

实际返工链：`before/`保留镜像近景造成成对风架的正式三窗；`after_repeat_fix/`保留去镜像、仅alpha退让版本。独审和主代理指出其绿色梁仍可能误读落点，最终改为明确冷灰蓝雾色且压暗highlight，见`final/golden/`。前后采集期间其他代理更新了演员，因此全画面并非严格只改变背景的像素A/B；只据局部景层现象说明修复，不把演员变化归因于景层。

`final/golden/`含正式map1的spawn、junction、merchant、deep creek四个实际GPU定位窗及回执。这是通过controller定位的美术fixture，`traversal_claim=false`。`final/limits/`含独立实际SubViewport的1280×720、720×1280、1920×1080各5个横纵极限/中屏接缝PNG与真实camera中心回执，450检查/0失败；不是手机验收。初次误用root Window size受项目KEEP_ASPECT影响，名为720×1280的图片实际720×405，反例保存在`nominal_window_resize_failure/`。修复后同时断言实际logical viewport与PNG尺寸，才取得真正720×1280渲染。

复验：`bash tools/godot.sh --headless --path . --script tests/underworld_plains/test_underworld_scenery.gd`。实际GPU另加 `--rendering-method gl_compatibility --audio-driver Dummy` 和用户参数 `-- --capture-scenery-limits`。正式窗脚本为 `tests/underworld_plains/capture_scenery_windows.gd`。所有实际组件覆盖、无缝条带几何、三种真实速率、根基/keepout、源数组重排和等并集分块反例由真实消费者测试，技术通过不证明审美。

性能返工：主代理发现原`_update`每帧读三幅PNG算SHA，真实8路线专项在原180秒门槛超时。现在只在`_ready`对真实raw source读一次SHA，tick读取缓存；系数、材质和像素未变。同机1000次直接update的真实CPU包络为12,108,252us→29,104us（约416倍），仅为该updater，不是FPS或整路线通过。`performance/`保留两份绑定source SHA的原日志、前后源码、真实benchmark脚本和15幅实际GPU逐像素相等回执。旧源码从精确差异恢复后与旧日志SHA完全一致。完整路线仍由主代理按原180秒门槛复验，不放宽门槛。
