# 平原归档与重做接续

默认启动保留冻结的可运行平原。源码基线为 `4f2bb5e41573e930603789c64b52a0c15a6a3dc4`，包含 35 个平原房、钟心门厅和 7 个外区入口。平原归档保留整份工程以恢复共享控制器、资源、配置和工具链锁。历次逐房记录可在[冻结交接](https://github.com/zhipijun1996/gunman-rush/blob/4f2bb5e41573e930603789c64b52a0c15a6a3dc4/docs/project/worklines/plains_bible_v2_01/scope.md)查阅。

冻结试玩的逐房入口、能力阶段与调试参数见[原版开发与内容审查](https://github.com/zhipijun1996/gunman-rush/blob/4f2bb5e41573e930603789c64b52a0c15a6a3dc4/docs/project/development.md)。

## 恢复平原

[下载固定提交的源码 ZIP](https://github.com/zhipijun1996/gunman-rush/archive/4f2bb5e41573e930603789c64b52a0c15a6a3dc4.zip)。已有仓库可用下面的命令在独立目录恢复同一棵文件树。

```sh
git worktree add --detach ../gunman-plains-archive 4f2bb5e41573e930603789c64b52a0c15a6a3dc4
cd ../gunman-plains-archive
```

解压或检出后，在该目录运行。独立数据目录让归档试玩使用自己的用户数据。

```sh
export GUNMAN_DATA_HOME="$PWD/.local/plains-archive-data"
python3 tools/setup_environment.py --engine-only
python3 tools/world/build.py
python3 tools/ci.py --check import
bash tools/godot.sh --path .
```

现成的 Android 和 Windows 平原安装包见[公开版本 v0.1.0](https://github.com/zhipijun1996/gunman-rush/releases/tag/v0.1.0)。它是较早的发行版本。要还原本次冻结的精确内容，使用上面的源码入口。

## 独立 TileSet 包

可复用地形的保存单位是图集、Godot TileSet、来源和材质实现。原生 32px、16 区 × 47 邻接来自主线；分区材质、上下与左右接缝、表面和危险外观取自固定提交 `6af82000eae0c1b8a8fb1f9a36c5ee03b3a7dcd8`。源码恢复工具只取地形文件清单；旧房间、世界布局、整包 schema3 迁移和实验场景均在清单之外。

```sh
# 在含本交接的开发仓库中运行
git fetch origin 6af82000eae0c1b8a8fb1f9a36c5ee03b3a7dcd8
bash tools/archive_tileset.sh
```

输出为 `build/archives/tileset-6af82000.zip`。将包中的 `art/world-art-v2/godot/terrain47/` 复制到新 Godot 工程的 `res://terrain47/`，即可在 TileMapLayer 的 Tile Set 属性选择对应区域的 `.tres`。纹理按资源内的原路径解析。独立 TileSet 带整格碰撞；如果共享装载器已经按权威几何构建碰撞，绘制层关闭碰撞，避免两套形体。

材质接入另取包中的 `config/terrain_materials.json`、`config/surface_styles.json`、图集、制作源与相关渲染代码。共享实现及地形专项可在[固定来源](https://github.com/zhipijun1996/gunman-rush/tree/6af82000eae0c1b8a8fb1f9a36c5ee03b3a7dcd8/game/presentation/world/terrain)复核，接入时按新房间几何选择直接依赖。这些项目级脚本使用原工程的类型。16 套原生资源可独立装载。包内保留已裁出的内角和重烘所需图块；更早的四张内角生成母图原本分包交付，未随 Git 跟踪。

## 独立特效包

取 [PR160 的最终版本](https://github.com/zhipijun1996/gunman-rush/tree/4c0a7e5820f90f4d04283c2fafc7c70ef3fa80a7/assets/vfx)。保留攻击与命中、共鸣回血、牧风者全屏咆哮入场、宝箱喷币和怪物掉币。包中有 18 套图集及 Godot 资源、制作配方、15 个声音、声音生成器、pixelfx 固定版本与许可、专项及原事件接线。查看方法和运行宿主见包内 `docs/project/worklines/vfx_pixelfx_01/scope.md`。

```sh
git fetch origin 4c0a7e5820f90f4d04283c2fafc7c70ef3fa80a7
python3 tools/archive_vfx.py
```

输出为 `build/archives/vfx-4c0a7e58.zip`。在解压目录用 `python3 tests/test_vfx_export.py` 验证图集重建；首次需要网络取得指定版本的 pixelfx。包内 `integration.patch` 保存完整版本差异，包括共享脚本的修改和原资源的删除，用于在独立的冻结基线上恢复参考实现。新游戏按实际事件选择效果，例如回血事务成功才播放恢复音，Boss 入场结束或取消时归还镜头并清理音画。原版射线淡出时可能产生零面积多边形；重做工程的绘制器处理取整后的退化图形。[问题定位](https://github.com/zhipijun1996/gunman-rush/pull/160#discussion_r4567330312)

## 归档验证

平原源码包解压至空目录，逐文件比对固定 Git 树，7,829 个文件一致。按工程锁定的 Godot 4.7.2 运行日常四项 CI 全部通过。启动专项从默认标题新开存档进入 P-R03 并确认玩家落地。此轮未在实体手机上试玩。

TileSet 包独立解压后，16 套原生图集重新烘焙为 752 格；锁定引擎在独立工程直接加载包里的既有 TileSet，16 套均通过，256 种原始邻域全部匹配。15 个外区材质族按像素与来源清单核对通过；在固定材质源码检出中，地形专项 544 项断言通过。该结果覆盖资源、接缝及已测装载范围，新房的画面和玩法留到其实例制作时检查。

特效包独立解压后，18 个效果源检查通过，图集重建测试通过，15 个 WAV 重新生成后与归档逐字节相同。将集成差异应用到冻结基线的临时 Git 索引，所得文件树与 PR160 最终提交完全一致。锁定引擎在该提交上通过特效运行、声音及 Boss 咆哮三个专项；本次未重录五组画面或验证实体手机性能。

## 新房间接续

[当前开发工程与模块](../../module_map.md) · [重做工作线](../room_rebuild/scope.md)。上文归档保留固定来源和完整恢复方式。
