# 平原归档与重做接续

默认启动保留冻结的可运行平原。源码基线为 `4f2bb5e41573e930603789c64b52a0c15a6a3dc4`，包含 35 个平原房、钟心门厅和 7 个外区入口。平原归档保留整份工程以恢复共享控制器、资源、配置和工具链锁。历次逐房记录可在[冻结交接](https://github.com/zhipijun1996/gunman-rush/blob/4f2bb5e41573e930603789c64b52a0c15a6a3dc4/docs/project/worklines/plains_bible_v2_01/scope.md)查阅。

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

## 归档验证

平原源码包解压至空目录，逐文件比对固定 Git 树，7,829 个文件一致。按工程锁定的 Godot 4.7.2 运行日常四项 CI 全部通过。启动专项从默认标题新开存档进入 P-R03 并确认玩家落地。此轮未在实体手机上试玩。

TileSet 包独立解压后，16 套原生图集重新烘焙为 752 格；锁定引擎在独立工程直接加载包里的既有 TileSet，16 套均通过，256 种原始邻域全部匹配。15 个外区材质族按像素与来源清单核对通过；在固定材质源码检出中，地形专项 544 项断言通过。该结果覆盖资源、接缝及已测装载范围，新房的画面和玩法留到其实例制作时检查。

## 新房间接续

普通房间按[房间组装规范](../../../bible/room_authoring.md#普通房间组装)制作。已验证的制作思路可从[机关定义与实例合同](https://github.com/zhipijun1996/gunman-rush/blob/6af82000eae0c1b8a8fb1f9a36c5ee03b3a7dcd8/docs/bible/world_elements.md)取用；该分支的目录与运行实现仍归其版本。新游戏的房表、地图、起点、存档及导出清单独立维护，旧房号、旧布局、审批与实验成果不作为新内容输入。共享地形、机关或物种由新房间显式引用。

新房间就绪后，从新游戏入口实际启动，检查该房与所属地图、使用独立存档，并核对导出清单仅包含新入口用到的资源。随后同步切换默认场景、正式导出和启动冒烟测试。冻结提交始终是回到平原的入口。
