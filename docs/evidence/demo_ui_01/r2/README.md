# DEMO-UI-01 R2 精选原始证据

运行/导出/影片源1d1d8368ffd03de38e59fbd1140d44c5ba95c403；原生冻结源dce1a7172fd122ed1fd7f1e7d3263c87caf5d74b。二者仅测试helper三行不同，运行树相同；详见[runtime-equivalence.json](runtime-equivalence.json)。

- [838原生专项及222素材项原始报告](native/report.json)，native目录保留各命令日志、两组原始断言与Godot截图。
- [最终公网21项实际鼠标/模拟触控报告](browser-public/report.json)，该目录保留原始画布截图、console及真实region_assembled事件；原始OCR表空列、终端输出和patch上下文无损保存在raw-terminal-and-ocr.tar.gz，逐文件SHA与恢复路径见raw-terminal-manifest.json。完整driver的SHA与报告相同，见[driver](drivers/browser-public.py)。材质边界定位用于已看过的原生标题/触控按钮，未注入引擎状态或发射假按钮信号。
- [公网完整PCK/HTML/影片哈希与main前后元信息](public-bytes.json)；[导出信息](build-info.json)、[许可证实际PCK条目](pack-font-licences.json)。
- [真实电影原报告](movie-report.json)与before/after trace。影片本体由独立托管提供，下载地址见[交付说明](../../../worklines/demo_ui_01/delivery.md)。29.954667秒；先R1后R2。官方策略伤害/恢复为明确UI测试fixture，射击经真实输入，不冒称自然战斗路线。
- [初审](title_review.md)、[完整静态复审](complete_review.md)、[源与导出限定独审](export_review.md)。独审当时的手机OCR失败保留；后续最终公网21项通过另有原始报告，不能倒改独审历史。
- failures目录保留旧字形缓存方框/native崩溃、手机标题/摇杆遮挡、旧颜色断言/焦点时序、首电影失败和浏览器OCR失败；underworld-diagnostic保留两次原预算的实际定位。原始build目录有未精选的重复图/分析派生及不完整AVI，不作交付效果证明。
- [R1试玩可恢复分片归档与重建回执](host-retirement.json)；初次托管原PCK超过100MiB被拒的日志也保留，最终已成功发布。其他工作线页面/媒体未覆盖。

全部为Development及模拟设备证据。没有实体手机/手柄、用户美术认可、完整影片播放/音轨评审或Integration/Release认证；质量卡保持review。
