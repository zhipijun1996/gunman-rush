# 2D与2.5D纵深实验

目标：同一套原有素材、同一份实验房间布局及镜头路径，比较平面2D参考与分层贴图／三维体块。固定相机朝向，比较正交／38度透视，观察遮挡、厚度、像素稳定和运动感。二维参考是本实验的平面组装，不冒充当前主游戏完整渲染。

分支codex/depth-lab，基线6af8200（依赖PR156的目录与房间工作，尚未合并）；只增加独立实验场景与捕获工具。源素材复用原文件，没有新生成美术。遵循项目godot-room-art实机方法和Visual Bible；该实验不修改正式房间、发行入口或保存。

## 运行与复现

- 场景：game/presentation/experiments/depth_lab/depth_lab.tscn；主脚本共享布局，左侧真实Node2D平面参考，右侧BoxMesh实体与Sprite3D纵深贴图。两侧共用简化CharacterBody2D碰撞，箭头／AD移动、空格跳跃、O切正交／透视、Z切体块厚度与图层纵深。它不是正式PlayerMotor、战斗与关卡路线验收。
- 交互启动：`bash tools/godot.sh --path . game/presentation/experiments/depth_lab/depth_lab.tscn`。
- 在可用图形桌面运行 `python3 tools/capture_depth_lab.py`，真实窗口捕获两段12秒1280×720／60FPS原速录像，并生成三栏对照。环境使用Godot4.7.2、GL Compatibility、Mesa llvmpipe及Xvfb；没有目标设备性能结论。
- `bash tools/godot.sh --headless --path . --script tools/export_depth_lab_scene.gd`输出build/depth-lab/editable.tscn：实际节点及几何可在原项目编辑器中调整，去掉生成脚本，作为静态快照；交互入口仍用源场景。

## 实际结果

实机图与日志位于build/depth-lab/。comparison.mp4与orthographic.mp4均为12.016667秒／60FPS、721个渲染帧；三栏图three-way.png依次为2D平面、透视3D、正交3D。preview.gif为前6秒8FPS缩小预览，判断像素质量应看原始PNG或MP4。

透视样本中，相机从首段移到第二机位时，同一个世界坐标在后景（-560wu）、玩法平面、近景（170wu）的屏幕横向位移分别为-91.969、-136.303、-159.669px。正交三者均为-136.303px。capture.json和ortho-capture.json保存原始投影及机位；证明透视自然产生深度相关位移，正交仅放远近层不会自动产生该位移。

已查看同机位三栏截图及不同机位PNG：门框侧面、地面厚度、前柱遮挡存在，透视图层有明显相对偏移。整体仍保留旧素材的拼贴特征，不能据此宣称达到正式美术目标。远景缩小及透视移动改变像素采样，不能宣称1wu始终对应一个屏幕像素。Sprite3D保留源图既有光影且使用无光照材质，三维体块接受方向光与阴影，两者尚未形成完整统一光照。这轮没有景深虚化、法线贴图、正式动作、完整战斗或手机性能验证。

两种投影的实际渲染捕获、媒体编码、投影数据、静态可编辑场景导出均成功，捕获无脚本／引擎错误；日常CI四项与文档检查通过。下一步的取舍应由这些画面决定；选择该方向后，需要专门适配体块边缘、二维素材和光照，而不是把所有正式房间直接批量搬入3D。
