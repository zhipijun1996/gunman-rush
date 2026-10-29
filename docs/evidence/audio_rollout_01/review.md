# AUDIO-ROLLOUT-01 · 合入前独立工程审查

**当前冻结装配工程范围 ACCEPT；完整CI、main合并及新公开Web仍由后续真实门禁决定。** 审查源码`06a76d18fa5c11410aa98f9dd82b9e7936086db2`，基线`3e6bf6921cfdb37f27258ac837f02474962e78a9`。独立确认[冻结文件SHA](review-source-hashes.json)六项生产/专项均等于该提交实际blob；另外两项文档原件按当前字节记录，待证据提交。native03执行的生产/专项字节与此相同，未把原失败重标通过。root后续精确head完整CI仍须实际完成。审查者未运行Godot、未改生产、未亲自浏览器或听音。

用户“快速合入main，并部署试玩”授权本轮推广；实际两区选择“ 两者都选A ”及家园“底音+生活音”分别有原SHA绑定记录。此次只推广quiet-02区域A/A和home-quiet-01 life，不把已选家园继续写成未选择，也不顺带推广13项SFX或签实体设备。

## 正式装配与反例

正式`demo.tscn`仅新增SelectedAmbienceRuntime子Node，deferred后只取父DemoApp自有GameAudio，旧DemoApp/HomeScene/共享loader/选音和五原BGM字节不变。启动title无声且不分配环境池；真实可见Home委托原HomeAmbienceAudition；区域须由真实stage类型、实际generated.manifest.region和App region同时确认，只选A，不调度未选区域点声。未知/标题无平原fallback。

独审发现森林类继承PlainsRegionStage，原plains分支会接受森林类+两字段伪装plains；现显式排除森林子类，专项反例在无await区间恢复假元数据，未让游戏物理消费它。Controller.died实际连接、同owner死亡闩锁不因session自增误重启；owner退出、重配、暂停/面板/静音沿原生命周期。观察到audio关闭即停止，避免teardown等待期间再启配置。相同context不重启床；另一真实App不会被全树group首项串音配置。

Web首次Home组件错过标题手势的问题，由父GameMusic开机已存在且真实_input接受的`_unlocked`继承解决；没有无条件解锁或模拟输入。此处只签源码，实际Web须另核真实gesture后的unlocked、床路径/playing/播放位置推进。

## 实际窄验证及保留失败

主控native03严格收据实际**45/0、退出0、16.966秒，无ERROR/退出泄漏**，两App原backend teardown均released；通过真实load demo.tscn→Home→平原→森林→返家、面板暂停/同床、静音恢复、实际Controller.die与防重启、选择/指纹/布尔/类型错配反例。森林采用既有debug入口提供真实消费者，不冒称正常跑完两区域或自然战斗死亡。审查者读取原日志/源码与[严格收据](review-native03-receipt.json)，没有冒称独跑引擎。

native01/02的45/0伴随两脚本资源泄漏，均严格FAIL并保留。compile-only不创建App/0动作仍同漏，动态service边界的16选择检查clean，定位为新专项编译图。修复只让test的service边界使用Variant、直接Script继承链确认原GameAudio类型；生产仍用真实`is GameAudio`。独立比较45个检查理由顺序完全一致，exercise动作体除两局部Variant注解和诊断cutoff外相同；等待/原runner/断言预算未放宽。最终完整45严格通过才收口，见[等价性核验](review-test-rewire.json)。

## 导出闭包与旧证据修复

独审指出JSON之外还需原音频字节：新runtime用FileAccess核16个原OGG/WAV SHA，旧实际PCK只有imports时会让Web全部静音。现三个正式preset均精确追加4 JSON+16 raw，原raw exporter新增有限16件、实际manifest SHA/bytes和冲突守门，`add_file(...,false)`保原imports。无目录通配免检。独立核全部16实际产物、9条原authority SHA和三preset精确条目，见[闭包](review-static-closure.json)。主控新导出专项26/0、旧PNG30/0和旧Python导出2/0严格通过；尚不以这些代替最终实际PCK读回/浏览器。

旧CI实际发现audio-style-v1冻结证据失配：当前Style Bible在原4586B后追加391B环境反馈。现仅把旧证据path迁到原字节`.md.txt`档案，独立SHA仍为`08371f6f…`；原sha/source/version/method/observed全部保留，当前live Bible `28248cc9…`及quiet-02规范不改。文本档案保原相对链接语境，不复制假README或改旧字节/校验器。见[无损迁移实证](review-style-freeze-migration.json)。旧失败CI不追签；新精确head须走既有完整门禁。

## 接受边界

无未解决的本轮装配工程阻塞，可提交并进入既有完整CI/普通合并流程。完整Production双通道/affected、实际main导出及metadata/完整PCK/20 raw+16 cooked音频/Web真实输入播放仍须root按真实收据完成；本审查不提前签发布成功。保旧Home/区域review原件及用户已选声音；不新增“商业品质达标”、实体手机/iOS Safari或全游戏混音认可。
