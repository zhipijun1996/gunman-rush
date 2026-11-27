# 正式世界的配乐与环境声

标题及安静聚落使用《The Kindred Hearth》。目前可用的区域原曲来自风铃平原和荆棘森林。正式混音复用五首用户提供的原始 MP3、quiet-02 A 版风声和鸟声。其余十四区暂缺专属探索曲与首领曲。

| 世界区域 | 探索音乐 | 环境底声 |
| --- | --- | --- |
| P 风铃平原 | Where the Path Bends | 平原风 |
| F 荆棘森林 | Vines Beneath the Canopy | 林间鸟声 |
| A 破碎浮岛、Y 风蚀峡谷、I 霜镜冰川、V 星桥天门 | Where the Path Bends | 平原风 |
| G 齿轮工城 | Where the Path Bends | 降低 10 dB 的风声 |
| S 萤雾沼泽 | Vines Beneath the Canopy | 林间鸟声 |
| T 根脉圣殿、C 月影墓穴、E 熔火腹地、K 月冠古堡、M 蕈灯地穴、N 回声矿井、R 沉水遗迹、Z 世界钟心 | Vines Beneath the Canopy | 降低 10 dB 的风声，作为室内气流 |

钟外小镇、轮轴工坊和工城值班房、矿务值班房、沉城住屋、根屋使用家园音乐。主线首领、已接受的可选挑战和精英战，均在首波进入实房时换战斗曲。使用平原探索曲的区域进入《Across the Wooden Sails》，使用森林探索曲的区域进入《Beyond the Knotted Vines》。胜利确认后恢复探索音乐。

标题壳持有一个 GameMusic 和一个 GameAmbience。同曲跨房保留播放进度；换曲交叉淡化 0.9 秒，环境底声交叉淡化 1.2 秒。暂停页压低音乐、暂停环境底声。总音量由独立用户设置驱动 Master 总线。试听设备、系统混音与浏览器自动播放策略会影响最终响度。

五首曲目的逐文件 SHA-256 和游戏使用授权见 [BGM 来源清单](../../../production/assets/audio/bgm/provenance.json)。风声、鸟声均来自 Thimras 的 CC0 录音，使用 quiet-02 已选原始渲染，未加鸟叫或钟响的备选 B 版。原始资料见 [环境音来源与母版](../../../assets/audio/ambience_v1/manifest.json) 和 [用户选择](../../../config/audio_director/ambience/user-selected.json)。
