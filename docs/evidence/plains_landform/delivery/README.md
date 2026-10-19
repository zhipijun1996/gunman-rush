# 可手动试玩的未准入候选

运行源`2c615d3d4762c51edfe1bc1e970f28f60807a1f8`，build`f7a0fd956887`，Linux x86_64，Seed默认`joint-recoil-01`。它进入正式完整随机地图中的上层岩脊—下层溪廊候选；其余地貌仍含旧实现，**不是完整平原美术完成或正式发布**。原操作、外观选择、地图、敌人与资源仍在，核心及森林未改。

- ZIP：`/tmp/plains-landform-review-2tzzr0om/delivery/plains-landform-candidate-linux-x86_64.zip`，255,310,009字节。下载路径、SHA和build ID见[download](download.json)。解压后执行目录中的`play.sh`（包内README有操作）；不需项目源码或另装Godot。
- 实机影片：`build/plains_landform/movie_v6_final_01/gameplay.mp4`，98,036,325字节，1280×720/60FPS/75.583秒，音轨48kHz双声道。影片的8案例路线真实完成；不是包启动测试重跑了路线。音轨存在不等于实际听音。
- [verification](verification.json)与[build receipt原字节gzip](build_receipt.json.gz)记录1506项PCK输入逐条SHA、五幅PNG实际PCK字节、ZIP CRC、空工作目录headless/GUI、真实4体/6权属及后层/开口/岩拱/材质核对、Godot严格退出。
- [producer](producer.py)只做本轮薄绑定，复用原joint/shared生产器；不修改历史原件，不重建打包框架。大体积PCK、引擎与ZIP放系统临时目录，避免工作区磁盘不足；路径是本会话本地交付，不冒称永久公网下载。

艺术状态`NOT_ADMITTED`、golden=false。最终独审[RETHINK](../independent-art-03.md)：灰墙、直边天空槽、接口与景层仍失败。未扩另一布局或多Seed美术，未签用户风格、真人设备、全片播放听音、全CI/Web。图生模型和商业许可未知，见[来源](../image_provenance.json)。保留候选供复核，不进入正式池。

当前分支末尾可继续有工具路由/文档修订；准确运行源码、PCK与影片始终以上述冻结SHA和各源字节证据为准，不用后续HEAD冒充该片版本。

完整PCK源闭包回执约7万行，只按需解压读取；[索引](receipt_index.json)保存原文与压缩SHA及解压字节一致性。实际构建目录中的原始JSON仍保留。
