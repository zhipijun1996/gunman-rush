# 区域入口示例材质

七组现有区域47邻接素材的原生32px机械重排，供平原外接示例房使用；不重绘、不缩放原像素，不持有碰撞。来源归属沿用 [区域素材包](../../art/world-art-v2/README.md) 及其源清单；生成资产不冒充Underworld原作者作品。

`python3 tools/art/bake_region_thresholds.py --verify` 核对源哈希、原生输出与记录。完整记录见 [manifest.json](manifest.json)。`RegionThresholdMaterial` 接入现有精确边界采样器；`RegionThresholdArt` 只为明确登记的入口示例提供该区背景和灯光，不代替正式整房制作。
