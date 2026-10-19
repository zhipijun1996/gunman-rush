# FOREST-PLAYABLE-01：可审查检查点，发布阻塞

森林两图、钩索地块／活锚、两敌人／两Boss、能力及下一地区选择、四个调试入口已经接入正式DemoApp。当前不能称完整验收或发布完成。分支`feature/playable-thorn-forest`，草稿[PR76](https://github.com/zhipijun1996/gunman-rush/pull/76)，不合并main。美术仍是玩法原型，S3保留明确开发边界。

## 实际CI失败

源`cda8c30ed375a97a53de27d8348a79f137199427`的[run38974548573](https://github.com/zhipijun1996/gunman-rush/actions/runs/38974548573)选择原gameplay+art全部68项fresh检查；实际51passed、1failed、16未执行。prepare／Web／Windows成功，core失败，deploy／public验证跳过，发布checkpoint为ci_failed。本轮没有更新公开试玩，旧公共包不能标作森林版本。

失败项level-design-runtime原720秒内6.765秒退出1，触发原资源退出守门，不是超时。实际下载的172成员gameplay artifact缺少重定向的capability.log，故远端具体对象数和owner未知；不得把本地232/170倒签为远端数量。准确API摘要绑定原ZIP、完整report、完整core连接器日志保存在[CI失败原件包](ci_monitor_cda8c30_failed_remote_evidence.tar.gz)。新增profile artifact_paths仅上传build/level_design_v2以修复这一观察缺口，没有取消断言或放宽守门。

## 已有有限通过

[两部GL影片包](actual-GL-60fps-two-routes-cda8c30.tar.gz)含1090帧／18.17秒growth03 map2、1121帧／18.68秒high_return04 map1，均60fps真实输入／Motor。后者实际领取缓存、异路返回；前者至女王竞技场，不等于两Boss完整击杀电影。完整源库存、引擎4.7.2、原始轨迹、关键帧时码与MP4解码均保存，见[电影独审](movies-independent-review.json)。未签全音轨听审或实体设备性能。

[准确CI ZIP浏览器原件包](actual-ci-zip-original-72-and-8-gui.tar.gz)绑定同run Web artifact12078358527，198620463B，完整ZIP SHA256为6150076d6ecf471545a6695ba588e2dc787c195f0174a104c09e3588af905aa8。build_id=d6881c6f5416，PCK90010956B，完整SHA=d6881c6f54168ca53b5d6284f778ef541dded17812066ea2da416b385a6809a2。三个原消费者24+40+8=72检查通过；四触摸入口在先、四鼠标入口随后，8GUI入口／16检查／每入口恰一次进入事件、零引擎错误，实际可见MENU暂停恢复。不是实体触屏、自然整战役或全部武器通关，见[三消费者独审](ci-three-browser-independent-review.json)及[GUI独审](forest-gui-independent-review.json)。浏览器通过不冲销完整CI失败。

## Foundry真实资源对齐

同GitSHA不等于所有导出资源相同：上述电影读取CDA committed Foundry basis5ec10e74…；CI prepare真实重建并验证后basis583c805c16cef038a6950f5bff76aa4966e1693d0e4dc854f5748a7c56a8827d。因此电影不能签为与CI PCK全部Resource字节一致。

[准确CI validated-foundry原件包](cda8c30_exact_ci_validated_foundry.tar.gz)来自artifact12078162091，完整ZIP488021B／API SHA a79bc82f7aa42e92035a20c40619c0cc03d33e8d360d7fdb5715b0f07e70b9f3。当前160个basis输入逐个与CDA Gitblob相同，独立重算basis与实际CI一致。56份原JSON已逐字节复制入resources/foundry，未人工生成stamp。仅basis及关联hash变化，去除签名字段后56份内容结构相同；实际记录36短语／18路线／0拒绝，仍awaiting_playtest、production_pool=false。见[逐文件报告](foundry-dependency-and-json-diff.json)、[复制回执](foundry-actual-copy-receipt.json)、[独立来源审查](foundry-ci-promotion-provenance-review.json)。这是已有真实生产者结果的对齐，不冒称本地fresh重建或G5通过。

## 有界退出诊断与隔离失败

[完整诊断包](capability-exit-and-two-lane-failures.tar.gz)及[逐成员回执](capability-exit-and-two-lane-failures-receipt.json)保留原41/0但232ObjectDB／170resources的严格失败、load-only、8加载次序、真正退栈、匹配类型A/B、ownedNode和动态Build+Trace组合。所有失败候选均未采纳，生产角色物理／玩法脚本未修改；没有已证实的唯一根因或修复。Node实例释放不等于Script资源释放，不能凭功能summary或native0放行。

原core+generated-consumers两lane实际尝试分别41.043秒clone缺对象失败、73.9546秒原clone60秒超时；两次checks=[]、零native检查。普通Git拉取真实3461个缺对象后复核missing=0，未改refs／源码；不能把这一恢复称两lane通过。日志、完整原Harness report和物化盘点均在诊断包。jobs2仍仅保留[静态提案](workflow-jobs2-proposal.diff)，workflow已精确恢复原jobs1，68原检查／18serial／全部预算不变。

[最终独立审查](final-blocked-delivery-stop-review.json)拒绝完整release，保留各局部技术通过。按game-quality-gate通用“预算、无进展、越界或外部工具依赖阻塞才保留现场并停止对应依赖”与原严格资源退出规则停止重复候选方向；视觉连续两轮条款不作为运行时停止依据。恢复应先获得新的判别性因果事实或上游最小复现，再走原完整wrapper／新源fresh68／同源电影／准确CI ZIP浏览器／公开完整PCK核验，不重复已失败组合。

四份CDA主包的完整SHA、成员数量见[便携索引](verified-portable-index.json)。本检查点不签用户趣味／审美、实体手机／手柄、完整自然战役或商业美术；content_complete保持false。

最终元数据检查：原docs profile21项fresh通过，原report／日志和源守门保存在[文档回归包](final-docs-profile-portable.tar.gz)，仅证明文档／工具范围。PR base质量diff依然退出1，原因是总independent_review已如实failed，现有checker要求passed才能认可以前测试修改；见[实际拒绝日志](final-quality-diff-rejected.log)及[独立范围意见](final-independent-dimension-scope-review.json)。不为变绿把总审查改签通过，不修改checker或原断言；这是另一个明确未放行守门。
