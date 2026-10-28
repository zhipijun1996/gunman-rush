# AUDIO-DIRECTOR-04 · 用户选择与组合试听

用户于2026-10-28回传[原始13行选择](../../../config/audio_director/selected/user-20261028.json)，SHA256 `56a0dd359fe5c53169794e28dcd7f333cea686d9f1d147ca70d3a3419d2ed072`。逐字保留，不把复合事件推导伪写为用户另一次批准。

| 事件 | 已选 |
| --- | --- |
| 金币、生命恢复、宝箱、脉冲枪 | A |
| 道具获得、点击/确认/拒绝、主角受伤 | C |
| 命中、敌人受伤 | B |
| 手里剑、反冲炸弹 | 原声家族 |

[归一映射与来源指纹](../../../config/audio_director/selected/selected.json)保存14事件：13明选，其中11新候选/2原版；bomb_explode只是同一炸弹原版试听的复合推导，user_selected=false。缺选保original且unknown。CLI `tools/audio_reel_choices.py`以保留reels/manifest/WAV指纹核验版本/ID/段边界与唯一性，9项实际篡改测试通过。未来brief已读取这份选择，旧V1否决和V2未选历史不覆盖。

[用户所选组合点播](https://clock-audio-director-lab.zhipijun1996.chatgpt.site/selected-20261028/) · [下载原音轨MP4](https://clock-audio-director-lab.zhipijun1996.chatgpt.site/selected-20261028/selected.mp4)

78.4秒/4704帧、6281615B、20章；MP4 SHA256 `2103c528bedb5dc7a9e59621a55b353d174f8eca3cf7ee2fd1b05de8ffa96141`。页面/视频不后配音、不重排动作，手机可按事件原/所选跳段，整片以fetch/Blob缓冲以兼容原私有托管无Range。部署状态见本轮实际收据，未以旧入口冒充。

## 来源与实际范围

合并最新main `879b39eaa869be70cb799dedd1bb6ffc35e0b92f` 后继续PR109。原生专项运行源 `39bb62cd`，本片运行/录制源 `a8350cbf5ceecb401933a1a9263672019ce20f49`；后续工具/网页与原片身份分记。原42个V3 WAV与五首用户MP3逐字节同旧4d原件，不重加工、不换BGM。

仍复用GameAudio及共享12voice池。显式configure_selected_profiles后才允许selected逐事件分派；非法配置原子拒绝，bank重配清旧映射。原武器和动作回退走真正旧消费者，不能把manifest通用legacy cue冒充原武器。正式默认仍original，不隐式读取用户文件或自动推广。基础枪声替换不改变物理/伤害/输入/资源/RNG/存档。

实际录屏是10组明确Home开发fixture，每组原版/所选同Seed同动作；上下文重建明示，不签自然完整关卡。最终mix在拾取后重建战斗fixture，BGM连续；命中/敌伤沿原Lab分层焦点比较，未据此签正式双层叠加混音。新候选有实际director_events路径与稳定波形后验；旧bridge日志先广播父类coin_selected占位再修最终trace，所以不把该旧日志占位ID当候选证明。

原武器使用原serial%3变体；替换脉冲枪后不推进该旧serial，故原段blade1/blast2，所选段blade0/blast1。保留的是原家族，不声称两段这两声逐波形相同。

## 精确影片与验证修正

原始[影片回执](capture/report.json)严格拒绝了Godot JSON.stringify对26个evidence.start/end秒数约3e-14的十进制截短，不是声音丢失。原报告failed、原trace/AVI/MP4全部保留。之后仅后验证允许这两个已知时间键在1e-12秒内往返，其他JSON用类型严格比较，拒绝bool冒充版本/钱包/行号。

两个mix/profile的明示上下文重建各跳过一个采样tick：physics_gap=movie_gap=2，enemy_hp -1→3，action_frame仍连续。窄守门只准每段此一次精确边界，其余tick必须+1、MovieWriter帧与tick同增；缺样本/双方同步删帧不放行。成功[独立后验证V3](capture/post-validation-v3.json)绑定运行a835、验证66d400ec；[V1](capture/post-validation.json)/[V2](capture/post-validation-v2.json)各原件不覆写。3663输入闭包仅capture校验器变化，原producer Git工具SHA核实；所有实际运行/素材/配置/引擎不变。原影片没有为修守门而重录。

18次实际候选播放，以原生音轨波形支持11已选新声；原手里剑/炸弹真旧路径、状态/事件身份/同Seed动作HP序列20章通过。1280×720/60fps、48k stereo AAC，整体peak -8.8dBFS/mean -32.7dBFS仅技术量测，不评听感。实际[手机尺寸20章](browser-final/report.json)在普通无Range HTTP、真实指针、无autoplay豁免通过；段末停止、自然结束、Stop、受控visibility事件、真实延迟MP4取消均验，不能当实体后台行为已签。

## 分层验收

- 新混选严格原生108/0，0.884秒；原reels严格126/0，55.628秒，原90秒硬界限保留，无ERROR/泄漏。见[native-selected](native-selected/report.json)、[native-reels](native-reels/report.json)。
- [输入反例9项](import-tests.log)通过；JSON原件与新候选路径/指纹闭环，缺选和复合原版不自动采用ABC。
- 首次十场景聚合录制被主动中断，原[失败回执](capture-interrupted/report.json)/[原因](capture-interrupted/reason.txt)保留；新聚合录制采用独立900秒边界，非放宽原native测试，仍1280×720/60Hz。
- 全局docs/quality检查受本次稀疏工作区未物化历史证据阻塞：原preflight分别约1.26GB/1.40GB且仍有未知大小。不为本次选声恢复全历史；仅恢复音效相关原质量回执11.5MB，并执行当前音效质量与PR实际base diff守门。不能把这些局部检查记全局检查通过。

用户逐项音色选择已记录；整组混音、自然战斗、正式消费者全面采用、实体手机/Safari/耳机/扬声器/硬件延迟和完整Integration/Release仍未验。PR保持review，不合main。

## 网站打包边界

首次新站点包超256MiB expanded上限，被Sites实际拒绝，[原拒绝](deployment-first-rejected.json)保留。完整proof留Git，页面report.json只含可验证的状态/运行源/媒体SHA及完整proof链接与SHA；[播放器消费字段/核心文件一致性](compact-summary-equivalence.json)通过，未删除旧V2/V3媒体或改所选MP4。修订包expanded267898880B小于268435456B，绑定网站源码051e429f65e23bd5ea8c30f684c58f29909b8b91。

Sites版本6实际成功，网站源051e429f65e23bd5ea8c30f684c58f29909b8b91，[发布收据](deployment.json)。原owner-private受众保留；原生工具本轮返回新的规范域名zhipijun1996.chatgpt.site，按该实际URL交付，旧历史收据不重写。

发布后[实际私有站点浏览器](remote-browser.json)验证金币所选及最后BGM混音所选真实指针播放，整支Blob SHA与原片完全一致，20章/14映射及4d选择源/a835录制源身份正确，errors=[]；依旧是软件Chromium，不代签实体设备或听感。
