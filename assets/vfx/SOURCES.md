# 原生像素特效

项目源稿：`tools/vfx/effects/`，Gunman Rush 原创形状／运动及明确署名的上游配方改编；使用 patch-gg/pixelfx 的 MIT painter、渲染及检查工具离线制作。上游固定提交 `5294518ce7c72e48b6100a744596e0acf57f2826`。版权与许可见同目录 LICENSE.pixelfx；上游第三方通知见 `.agents/skills/animation-vfx/references/pixelfx-NOTICE.md`。未使用画廊字体、演示人形或第三方游戏精灵。

重建：`python3 tools/vfx/pixelfx.py export gunman`。每个子目录保留PNG、Aseprite JSON、可直接加载的Godot SpriteFrames和source.json（源文件SHA256、选项、锚点及上游版本）。透明辉光已克制地合成，不对整张贴图作二次加法混合；需要独立遮挡或加光时通过 `--split` 导出。

运行入口：`game/presentation/effects/pixel_vfx.gd`。实际时钟、空间位置、生命期和数量上限由各自原有表现宿主拥有，图集按宿主实际进度采样，不以离线动画结束触发游戏逻辑。纹理使用nearest、无mipmap、无有损压缩；源画布以1px/1wu绘制，个别调用的缩放与原效果实际包络共同验证。

当前重制参考：`projectiles/muzzle-pistol`的多层锯齿焰和卷烟、`impacts/hit-spark`的方向裂痕、`ice/ice-lance`的分面矛与移动高光、`holy/heal`的光瓣／升环、`impacts/ground-slam`的贴地尘浪、`pickups/chest-open`的扇光、`spawn/coin-drop`的尘团及`pickups/coin-spin`的厚边旋转。直接使用的flash/cloud及hit-spark配方在源文件头署名；其余按真实角色、事件和实际金币改编，不导出演示身体或伪造奖励单位。

新增六张图集及重制冰矛使用30fps保存造型，枪口／命中使用60fps；宿主仍按真实时钟连续采样。全18张图集解码共15,786,496字节（约15.06MiB），受16MiB检查约束。声音制作与正式事件映射见 `assets/audio/vfx_renewal/README.md`。
