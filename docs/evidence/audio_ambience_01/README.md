# AUDIO-AMBIENCE-01 · 真实录音环境音候选

当前：首轮候选与真实实景已交付，内容保持review。手机[环境音工坊](https://clock-ambience-lab.zhipijun1996.chatgpt.site/)已由Sites v1成功发布，需以拥有者账号访问；[MP4](https://clock-ambience-lab.zhipijun1996.chatgpt.site/ambience.mp4)与[完整包](https://clock-ambience-lab.zhipijun1996.chatgpt.site/ambience-comparison.zip)可下载。旧动作工坊/主站不替换。准确原生/托管/发布身份见[发布收据](deployment.json)。

基线main `45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`；工作分支`feature/audio-ambience-01`，冻结运行/录屏源以最终capture报告为准。两区原Bible与既有用户选择在[工作线权威绑定](../../worklines/audio_ambience_01/authority.json)。

## 已生产内容

4个24秒/48kHz双声道Vorbis床声：平原轻风/远鸟，森林林缘/树腹风叶；另4个PCM点声。7个CC0实录原件约161.6MB留构建cache，输出约4MB与许可原页入库。详见[来源](../../audio_director/ambience_sources.md)、[实际增量事件](../../audio_director/ambience_event_catalog.json)、[运行规范](../../audio_director/ambience_runtime.md)。无BGM生成或替换。

GameAudio按需持有2床+2点声组件，复用Ambience总线/原会话音量，原12短SFX voice不变。正式默认original；录屏是开发显式增量床声，原森林短风仍保留。点声可单听/由API定位播放，未自动布满地图。

## 真实失败与修订

- import-01为新工作树冷导入，90秒耗尽，起始字体缓存未建立报错；后续同原件缓存完成导入，原失败保留。
- design-tests-01在配方作者编辑后manifest未重建时拒绝指纹漂移；design-tests-02的最终9项通过。独审候选ID原篡改误接受后修复，原/修后反例均保留。
- lifecycle-01真实发现与DemoApp父类成员/方法冲突；已按lab独有前缀修正。该首命令也漏传lifecycle-only，未签动作或死亡。
- lifecycle-02真实Controller6/0、退出0，但主控后验用了错误marker而失败；原报告不改。lifecycle-03用准确原生marker和全部6项JSON/退出/日志严格通过。仅证明明确Controller.die()入口，不称自然战斗死亡或森林死亡全覆盖。
- quality-diff-01缺完整affected_paths；02进一步发现通用scanner不能把新动态目录当资源文件，且.gdignore缺关联。已注册全部真实产物、许可/源合同，并新增精确loader SHA绑定的9文件有限adapter；原扫描/旧断言不削弱。17新测试/57原quality测试及独立5反例通过，后续diff收据单列。
- capture-01按实测1250帧/130秒预计超过原900秒有界停止；原前缀不是完整片。capture-02实测MovieMaker仍1280头，不能以CLI960或后期缩片冒充960渲染，停止保原。
- 读取Godot4.7.2原main.cpp后使用新建且有归属守门的临时override.cfg；保精确字节/指纹，只删自己未漂移的普通文件，已有/漂移文件拒绝覆盖。原project.godot字节保留；smoke-01证实真实960×540和配置已清理。
- capture-03因独审发现shader闭包遗漏停止；新guard覆盖3808文件/46shader与project/export配置，旧轮不追签。
- capture-04实际抽帧发现不透明试听Panel遮住中央动作区，媒体REJECT并停止；[原像素](first-scene-observation.png)保留。录屏改两行紧凑字幕；scene-smoke-01两区各120帧/总261帧真实图证明修后角色/地形可见，独审实际看两张图。其原报告9721为未提交修复工作树，完整source_before逐件等于后续de6b36c6，原报告不改。
- actions-01用原脚本作额外headless诊断，主控自定90秒耗尽/无完成收据，保FAIL，不放宽该诊断预算。它不能签动作；原900秒完整MovieMaker才作最终六段动作/音轨/循环验证。

各轮native/raw媒体留`build/audio_ambience_01`，本目录保精选原生日志/完整JSON、明确停止理由和原像素，不把未完成前缀伪造为成功。

## 已执行的限定检查

运行55/0、旧selected108/0、旧森林73/0、真实Controller6/0；加工9项、旧用户选择9项、有限adapter17项/原quality57项；独审另17+57+5有限引用反例与4临时配置FS反例。精确源码/输入/输出SHA见相应报告和[独审](review.md)。Dummy/headless不签听音；FS/mock不签引擎；静态pilot不签连续动作。

Production plan保守选择完整165，未将计划写作执行或降低门槛。全docs输入预检发现2734项稀疏输入、已知约2.53GB加未知对象；本轮按用户要求执行相关最小检查，不下载无关历史或称全量docs/CI通过。最终完整Integration以独立PR实际Actions为准。

## 验收边界

用户尚未选环境音，主观自然感/公共公园录音的现代背景/鸟声远近/疲劳/动作及BGM遮盖、实体手机/Safari/蓝牙未验。技术后验不签商业品质。新声音只在开发试听显式开启，正式原版不变；完整原生游戏工程lab可运行，但本轮手机交付主要是实际Godot原音轨录像，未声称旧完整游戏Web已带新环境声。

## 最终真实交付

- 运行与媒体producer：`de6b36c62f0640d9322973fffb687472755d25b7`。6×26秒、9943实际MovieWriter帧（165.7167秒，含启动/区间），60FPS、960×540物理渲染、1280×720逻辑。26秒包括前15秒原BGM混音、16–26秒环境；共12点播章节。原生8m42s，采集/编码/后验/清理总577.629秒，均在原900秒原生上限内。
- 完整[source guard/原生/音轨报告](capture/report.json)、[全部实际轨迹](capture/trace.json)、[实片](capture/ambience.mp4)、[章节](capture/chapters.json)。3808来源/46shader在前后完全相同，临时override已按归属清理，project原字节不变。同区三方案每帧位置/血量/着地/接受事件时序与角色屏幕位置全部一致。
- 四候选真实24秒循环各回绕一次；原生AVI声波与实际OGG直接归一dot分别0.9531、0.9048、0.9330、0.9154。独审独立重算，并用全静音/错候选实际反例拒绝；这些数值只证明指定素材进入真实音轨，不签听感。
- [本地手机GUI](browser-01/report.json)：390px Chromium，12章节真实pointer、原AAC实际解码、4点声、循环边界、单声互斥、Stop/后台/自然结束、迟到下载/播放取消、选择持久化和JSON指纹通过。导出的choices是自动测试数据，不是用户选择。原包四个章节/override/音轨身份篡改反例全部拒绝。
- 源仓`8d29d15465fab8cd3e2856d130373fb35a2dd8ad`对应静态工坊v1；它与原生producer分别记录。新独立Site避免旧站接近256MiB的容量问题，保留所有旧入口与权限。原生音画14,049,972B，SHA`69da1d4d924d79010be30468ba3f23a0831c469212f45cc38929a3b09de5fc8e`；同文件在Git与工坊/ZIP中交付。
- 没有发布新的可操作完整Godot Web包；“完整游戏（主站）”链接仍是主站，不能冒称含本轮环境候选。工程源的显式Godot Lab可在编辑器运行，正式推广与打包仍另验。

独立审查限定工程ACCEPT；完整连续人耳听音、用户选择、实体设备和商业品质均未验。完整CI以本轮独立PR实际结果为准，未从本地专项推断通过。

## 线上真实核验

[线上03收据](remote-browser-03/report.json)通过：完整远端MP4 HTTP200、14,049,972B与本地SHA完全一致，producerde6；390px实际pointer播放平原A混音/森林B环境段及Stop通过；直接AAC解码计数仅引用本地12章节报告，remote03未保存此计数，保存实际远端截图。原远端01用了错误通用Authorization等待超时；02页面已加载，但Node APIRequestContext直连IPv6不可达，未记通过。03使用Sites文档OAI-Sites-Authorization及浏览器同源fetch的既有网络路径，未改Site源码、访问权限或MP4。失败诊断请求头/cookie已移除，不保存凭据。

质量记录一致性校验通过，但内容verdict仍UNVERIFIED（用户听感/设备/全项目门槛未齐）；原schema构建期失败日志保留。当前完整diff质量/产物登记守门通过，完整CI未在本地运行。
