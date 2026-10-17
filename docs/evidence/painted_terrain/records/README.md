# 手绘地形历史采证与精确恢复

本目录只归档真实采集，不重签旧失败。最初五阶段（feedback_01、02、03、03b、04）采集时Git母提交为 `0905516bb8c996a5f79ee4ac242ea0a0ab2205de`，当时的dirty完整来源由原生产收据source_before/source_after及逐字节快照标识。后来的 `df197eb773aa3d3d89078616d7523da1d3922724` 仅是恢复锚点，并非这些录像的采集提交。

`index.json`仅汇总最初五阶段；新增正式薄岸/注册seed/最终A/E使用`delivery_index.json`，分别保留df197与3ebb的真实采集parent，不能统称090；每阶段`recovery_index.json`逐项列出实际快照SHA。与锚点提交一致的原件使用 `commit:path`恢复；不一致者保存在该阶段`originals/**/*.original`，保持原字节。恢复时将这些例外覆盖相同相对路径，并按原收据完整source_before逐一验证。原build证据保留。

- feedback_01：660tick局部预算耗尽，未完成完整路线；截图来自原生正常相机，不称完整通过。
- candidate_feedback_02：完整路线技术通过，但艺术REWORK；精选600/1080帧保留漏体、端连接问题。
- candidate_feedback_03：运行时typed Array错误，严格失败。新MP4仅为原失败AVI的正常速度审查转码，原AVI未改；转码来源哈希及命令见review_transcode.json。
- candidate_feedback_03b：仅类型修正后原生严格通过；独审仅静态地形family ACCEPT_SCOPED，不是整屏G2。
- candidate_feedback_04：原收据与精选媒体已在`../first04/`，此处不重复覆盖；43个快照逐一对比恢复锚点，41个直接Git恢复，2个例外保留原件。首空间静态限定认可见上级independent-05报告，不能推论动态、真人、整区或商业认可。

不复制整套纹理和测试，也不将后来源码状态改写进旧capture。媒体中的编码音轨未经人工亲听验收。

本地交付阶段另见 `delivery_index.json`：其锚点为 `3ebb0d3af98855595f43c7bf4ec2b2a675b5d6cc`，对各原生产收据的完整source_before逐项核Git blob，所有不匹配项另存真实原件。formal01有5项历史原字节缺失（逐路径/SHA列于该阶段recovery_index），所以明确不能完整恢复；不以稍后修正代码填充。formal02/03、其baseline03、两注册seed、最终A/E均无缺失。三seed的局部结构相同，不表示三种空间结构。

`underside_head_05`保留真实初始出生探针图/结果/日志，但当时没有完整source_before/source_after收据；`provenance_limits.json`明确该限制，后存的同文件原件不能冒充当场sourceguard。该探针不证明正常游玩能抵达头部位置。

最终A/E精选实际录像、同帧截图在 `../media/`，原严格比较和包含墙钟差异的逐tick报告在本目录。`physics_negative_index.json`保留当前源码下无枪/删恢复岸真实失败；预期负例验证通过与游戏路线失败是不同结论。导出原GUI截图与严格退出记录见 `../delivery/`；ZIP仍是本地有限评审包，非正式发布。
