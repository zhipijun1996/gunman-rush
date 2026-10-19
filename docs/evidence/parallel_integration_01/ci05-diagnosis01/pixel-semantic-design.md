# Pixel semantic integration 01

方案A给旧草花贴identity无法提供地标轮廓，淘汰；方案B沿当前palette新建四种透明像素纹理，选择B。无旧母版、无新碰撞/随机数，无更换现有props或三背景。

- 风车：24x36px塔座、四条阶梯帆、铜轴。
- 溪井：24x20px石井口、蓝色水面、双柱横梁和吊桶。
- 钟庭：24x32px双立柱/开放拱口、铜钟面/两针、石基。
- 修理架：28x24px开放工具架、锤/扳手、工作台和双脚。

默认2x整数倍像素，真实平台余量不足时允许1x。opaque底行接真实solid顶面，left/right留8px，protect grow6px及其他solid严格避让，地标之间grow12px；area原点纵差<=80px、横向邻近<=600px，按距离排序支持并8px确定性扫描。每身份最多2件；无合法支持则显式omitted，不凭空浮放或补metadata。全部Sprite2D centered=false，无碰撞，z=-1，纹理nearest。原有草花仍保留。

PixelRegionScenery直接暴露presentation_manifest.items和compositions，均只在真实Sprite创建后登记；Sprite有landmark/composition，actual display_bounds由真实texture尺寸/位置/整数scale构成，包含identity/area_id/support/foot及当前程序源SHA。旧scene原实际bounds/raycast/floating mutation可检查这些对象。此时没有引擎租约，未运行Godot或宣称8路线/视觉已过。
