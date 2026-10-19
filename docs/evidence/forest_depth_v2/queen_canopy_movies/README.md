# 棘冠女王 Canopy-v3：两场完整正常录像

| 实际打法 | 完整MP4 | 视频 | 击杀／落稳帧 | 末HP／精力 |
|---|---|---|---|---|
| 钩索借结、反枪剪网换向 | [H](H/gameplay.mp4) |626帧，60fps，10.433秒|614／625|4／80|
| 普通保网，离开锁定旧岸 | [keep](keep/gameplay.mp4) |512帧，60fps，8.533秒|500／511|4／65.5|

两片都从实际初始24HP打至死亡并正常落稳12物理帧，使用真实Player、弹体、碰撞、Policy及命中退款，没有剪辑、加速、搬角色或修改战斗资源。普通打法更快，H打法末精力较多；不能据动作数量宣称H必要或全指标占优。

H片包含真实首H→背射反冲→侧H→对实际迁移身体射击，以及高侧活结、接收活结的真实借取。接收结剩1HP由反向普通弹实际提交剪断，反冲将玩家送离旧S；不是H信号自动剪网。keep片在S被锁定后使用普通横向反冲换至右岸，保留两张网与两个结至击杀。所有阶段由真实HP触发，核心持续可伤。

实际Xvfb／OpenGL compatibility软件渲染，1280×720，正常60fps。单片采集预算60秒，实际引擎18.965／15.397秒；原生CLI120秒未改，后处理各45秒。非headless黑片：作者检查了一张H中段原PNG确认实际场景和字幕可读，未据此声称人工全速看完或听音认可。音频使用Dummy驱动；玩家、设备、视觉风格、音效和整体趣味仍未签准入。

[完整索引与每件SHA](index.json)、[影片／原AVI账](movies.json)、[精确2083路径源码域](source-inventory-2083.json)、[13件精选源码](selected-source-index.json)、[历史失败与原件引用](prior-evidence.json)。原AVI保留在build，不进Git。两片各自目录包含完整无损gzip轨迹／partial、native日志、receipt、MP4、实际视频关键帧与索引。这里没有新增editor import；复用02已实际成功的冷导入缓存。各片`source-golden/`保留此前同源原生的完整capture／partial无损gzip、原import／native日志及receipt，和本次MovieMaker的原件分账，不把缓存复用称为新的冷导入。

每张关键帧索引记录实际video frame、秒数和PNG SHA；没有捏造视频帧到physics tick的直接映射，可读取画面中的真实tick字幕。影片物理625／511帧与视频626／512帧分开记录。

**来源边界：** 两片绑定封闭快照`queen-canopy-v3-02`，其2083文件含01完整生产内容及02单runner输入迭代；所有文件前后SHA一致。电影02后，活结HP文字等只读性补丁也不倒签此处像素。这不是当前App消费者或root后续生命周期补丁的封源，也不是正式自然入口：黄金起点为Definition的S观察台。旧Queen-v2及194测试未改，不用其结果签此新Boss。正式App、保存／取消／畸形快照与独立整战评审另验，影片通过不能代替它们。

01原H打法HP1、普通keep真实死亡、lure未采，以及更早越界／API误用／物理失败全部保留。新影片不倒签旧失败。原01普通cut626帧／HP5／精力100仍是合法强对照，但未为录像重复采集，不混成02影片。


独立电影复审已按原字节封存于 [independent/Queen-canopy-movies02-REVIEW.md](independent/Queen-canopy-movies02-REVIEW.md)，审计及推广 SHA 清单同目录。复审采用离线关键帧与密集抽帧，未冒称全速真人试玩或音频认可；两片最后一帧为 fixture teardown 空场，不作胜利反馈证明。后补 HP 数字文字属于另一版呈现，本报告未据新像素签认该改动。
