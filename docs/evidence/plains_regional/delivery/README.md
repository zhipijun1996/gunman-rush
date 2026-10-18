# 隔离完整区域失败候选：本地试玩与录像

艺术准入REJECT；仅评审，不是正式/Web发布或商业、真人、设备认可。运行源46c3c099，build_id ac57d1be87f8。ZIP准确路径、字节数与SHA见[download.json](download.json)，实际空cwd原生headless/GUI、原PNG/PCK闭包和严格退出见[build receipt](build_receipt.json)。仅Linux x86_64，解压后执行`./play.sh`；默认regional-art-02，`./play.sh --seed=regional-art-01`切换。角色可选，使用原控制，无自动驾驶/Meta写入。

范围是原campaign第一张完整大地图（HUD Map1/2），不是两图通关、全边或Boss击败。实际源码全路线与包内启动不同范围。原完整影片01为e450/v1，缺少后续四脚守门；完整影片02为46c/v2。实际影音文件与SHA见[作品索引](../gallery.html)及记录；仅抽帧审查，未完整播放或实际听音。

生产沿用原严格打包器，本地[adapter原件](producer.py)只绑定区域消费者及准确元数据，未改变PCK字节/素材/原生错误/音频/释放守门。新绘画的工具模型、价格、商用许可未知。原失败、取消AVI与源版本保留。不自动准入正式池，不合main。

附加包内Seed01仅headless启动实测通过：完整计划/Manifest与冻结源一致，61模块/13敌人/4宝箱/真实Boss及v2脚距有效，PCK/ZIP前后SHA不变，见[实际记录](alternate_seed01.json)。默认Seed02才执行包内GUI。原level-design-contracts在CPU空闲、所有仓库写入暂停时仍按原60秒超时；未降低门槛，未再扩历史修复。完整CI/Web未通过。

源码与精选证据已推送[草稿PR86](https://github.com/zhipijun1996/gunman-rush/pull/86)，基于PR85开发树，未合main。大文件草稿附件上传返回HTTP401，未成功上传；空草稿已删除并确认404，见[真实失败](remote_attempt.json)。本地MP4/ZIP路径保留于索引；不要把暂不存在的远端附件当成下载成功。493e704f的Git树证据可携带性检查通过，仅检查证据归属，不是完整CI/艺术/发布门槛通过；GitHub自动CI状态以PR实际结果为准。
