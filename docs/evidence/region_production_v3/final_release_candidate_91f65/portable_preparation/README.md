# 最终便携证据准备草稿（不是最终发布/全量通过）

本目录只在忽略的build内归集原件；未运行引擎、未修改源码或docs。每个原始来源路径、SHA、字节数及mtime等见archive_index.json；复制件逐SHA一致，两个新ZIP逐成员SHA与CRC全验。后续由Root统一复制至docs，不能据本草稿宣称已发布。

- failed_release_91f65/：原53文件ZIP及原index逐字节复制。原总交付failed，失败check为level-design-runtime，不改签。
- storage_cleanup_final04_originals.zip：零合规旧cache/零删除审计、完整硬链接去重前后清单/回执及审计、去重、恢复脚本。仅授权6个终态目录54份纯Python反例capture，45次硬链接原子替换释放620257280 allocated bytes；证据逻辑路径/内容/SHA保留，inode/ctime/nlink及部分mtime/atime并非原样。恢复脚本可重建独立文件及原mode/owner/atime/mtime，但不能恢复原inode/ctime。完整每项目标原mtime在回执；dedup_progress.json仅重复终态operations，因此未重复收录，原件仍保留原处。最初quick glob未命中也是实际发现过程，未改写。
- current_default_headless/ + current_default_rootbell_native_originals.zip：独审原JSON/MD、1084项运行投影及关联新原生四文件。真实默认v11 map2切片15cases/5145连续物理frames/9pulses；独立Python验证实际capture与27反例，不冒称27次原生或新的独审引擎运行。原invocation是启动时保留的临时failed字段，最终producer report实际passed，二者原字节都保留，不回填启动文件。
- 1084项运行投影在该producer before/after/启动invocation及独审投影相同；它不是全仓clean Git身份。独审时analysis及其test的dirty/excluded SHA和Git状态原样保留，不用后来的R3来源替换旧运行来源。
- analysis_r3_peer/：新R3 addendum与真实30测试日志原件。范围仅JSON数字0.0/1.0的有限兼容，bool/非有限/分数/越界仍拒绝；原addendum的fresh native gate pending保持原字段。父任务后续已取得的新运行不能倒写旧addendum，须另留相应终态来源。
- ci_38831828144/failed_console.log：gh run --log-failed普通console原件，经签名URL标记检查。原CI的core/level-design-runtime失败保留，后来的R3修复不改签原CI。父协调报告prepare/windows/web成功；此文件自身仅含failed console，不冒称全job状态JSON或全部运行记录。未复制artifact403下载日志或短时签名URL。

本包不签完整campaign/Boss通关、多seed全路线、商业美术、用户/音效/设备、生命周期clean或新Web部署。最终冻结源码的剩余Harness/公开部署须由真实终态另补。
