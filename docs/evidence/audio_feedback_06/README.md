# AUDIO-FEEDBACK-06 · 标题即播与受伤再选材

用户：“进入标题页面直接开启bgm；弹丸碰墙新版变体1试试；主角受伤感觉都不太对，参考空洞骑士受伤的声音”。这是PR121的后续迭代，main基线仍5f55716a；不是已合main或新声音获批。

实际运行、捕获和导出源为 **d8a894c28957aca4f5b7ab1bd55827d4f93259c7**，Web **80377273a40d**。随后仅增加离线工坊打包器、来源登记和验收/发布收据，没有将已有包改标成后续提交。

- 标题直接调用原Music播放器，不再以应用层手势状态阻断；字幕恢复，原曲/增益保留，进入Home不重新开始。浏览器自己的无手势限制仍有效。
- 墙地固定feedback05/wall_1；原三slot都指同一author take以兼容旧索引，不冒称三种新变体；60ms、最多2wall、12共享voice与原衰减不改。
- 受伤旧C及05两变体已被否决并保留原字节。新CC0断裂/竹条/气息/通用打击加工为A薄壳裂隙、B实体受创、C短促气爆；开发默认A。`audio_hurt=A|B|C`只换表现候选，未改变伤害/无敌/物理/RNG/save。五首MP3、原跳落、敌伤B、既有武器与奖励反馈保留。
- 空洞骑士仅为用户指定的功能/情绪参考，没有下载/复制其商业原轨，也没有声称实际听评或测出其配方。当前新声须由用户试听确认。

## 实际试听

新入口为 <https://clock-audio-feedback-05.zhipijun1996.chatgpt.site/feedback06/>，沿原owner-private Site，同一ChatGPT账号。旧05页面和视频比较继续保留；当前`/game/`明确更新为06。本轮已实际发布成功：[原生发布收据](publication.json)／[精确源码与archive收据](site-package.json)。线上为owner-private，原生成功验证发布；账号内实际线上GUI未代签。

[20.2167秒真实影片](feedback.mp4)／[七条WAV对比包](audio-comparison.zip)包含可实际试听文件。片中原Home BGM与原生SFX同步录制，1213帧、960×540、60fps MovieMaker；前三段标题无输入/家园跳落/对地射击，后三段同Home同镜头的实际HealthState扣1HP并恢复fixture。没有后贴声轨，亦非自然敌击、自然完整通关或实体手机FPS证明。[完整捕获报告](capture-report.json)、[压缩逐帧trace](capture-trace.json.gz)、[章节](chapters.json)。

工坊用同一实际影片Blob做可靠跳段，支持新A/B/C、旧C/05两条、固定wall1、循环/Stop/单声互斥、实际游戏入口、来源/许可及带候选ID/version/SHA的选择导出。[打包记录](lab-package.json)／[实际手机尺寸GUI14项](lab-browser.json)／[真实章节篡改拒绝](lab-negative.json)。GUI中的B选择与备注是自动化fixture，不是用户选择，不能导入正式偏好。

## 已执行的工程验证

- 原Harness两项均fresh通过：[最终报告](harness-final.json)，audio-feedback **219/0**（55+70+63+31）、原BGM **89/0**。命令/原生错误/退出/释放守门及预算保留；[四消费者结果](native-suite-final.json)、[BGM原日志](bgm-final.log.gz)。报告如实绑定d8及当时的文档/离线工具工作区状态，不冒称完整166。
- [实际Web16项](web-autoplay-final.json)使用精确Sites暂存的chunk-only包和普通HTTP。**初次观测全程CDP `Runtime.evaluate userGesture=false`，且实际navigator.userActivation两值均false**：允许自动播放时标题已有原生PCM；严格策略时真实context suspended且静音，首个真实背景触摸恢复标题BGM，进入Home继续有声。A/B实际query装配、原pulse A输入、COI/SAB及错误扫描通过。[实际driver](web-driver.py)／[无录音的被动分析器](web-observer.js)。不是私有线上账号浏览器/实体手机证明。
- 原创作CLI、Bible35/0、direction13/0及selector21/0通过。style21/creative24只技术重绑DemoMenu **1/81**，其余80、原Bible/用户原文、style20及creative23原件保留；[迁移说明](../../worklines/audio_feedback_06/binding-migration.md)、[精确差异](binding-migration-audit.json)、[原方法/断言保持](binding-test-retention.json)。
- 新采样配方实际build/validate与独审重建通过；[新来源登记](../../../config/audio_director/feedback_06/sources.json)、[配方](../../../config/audio_director/feedback_06/recipes.json)、[manifest](../../../assets/audio/feedback_06/manifest.json)保输入、每层响度校准、裁剪/滤波/速率/包络、输出完整SHA及CC0许可页。六个选中原件小规模留存，未使用大包仍在忽略缓存。[实际PCK及三条导入样本逐字比对](pck-proof.json)。
- [独立工程审查](review.json)和[九个真实拒绝反例](review-checks.json)绑定d8并已冻结。该审查未签听感、HK原轨听评、Web或设备。其非阻断建议为未来扩配方前严格校验profile/id映射；当前固定ABC映射和运行时白名单已正确，不把此次固定输入证明升级为任意配方通用保证。

## 保留的失败与未验

初次Bible旧current-version20期望在21上失败，[原件](bible-tests.log)和修正后[35通过](bible-tests-02.log)分开；未删closure/旧版本反例。初次Harness遇新增离线工坊文件，source guard正确拒签，[interrupted报告](harness-first-interrupted.json)保留；冻结所有文件后才取得最终fresh通过。

最初Web检查用了带录音的探针及Playwright普通evaluate；随后被动探针仍使用普通evaluate，严格策略均未得到预期suspended。[首次](web-recorder-first-failed.json)及[第二次](web-passive-first-failed.json)保留，不能当成真实阻断策略通过。最终改用不带激活的CDP观测并同时核navigator实际状态，16项通过；没有改生产音频或伪造手势。最初质量范围遗漏精确子文件，[原失败](quality-scope-first-failed.log)保留，按实际路径与离线来源登记补齐，没有削弱守门。

本地历史docs预检仍缺稀疏原件，[输入计划](docs-input-plan.json)只说明可用性；已知历史物化量超过本轮剩余磁盘，不签docs/full166通过，不删历史换空间。远端最新PR完整CI、用户新声审美、私有线上账号GUI与实体设备、长自然敌击路线均须按真实结果另验。此开发试听不自动合main。
