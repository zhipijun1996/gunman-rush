# AUDIO-HOME-01 · 家园环境声最终独审

**工程范围 ACCEPT；家园审美、用户选择及实体设备 UNVERIFIED。** 无未解决的本轮工程阻塞。审查针对源码`745097b8c390502257a55c727444104c4f64cecf`，原生影片生产者仍为`a4b2113aa786193a1d653080365f6067dd020880`；没有把新HTML修订追签成旧影片生产者。审查者只读生产文件，独立执行Python/文件指纹/PCM分析，实际看了静帧；未运行Godot、未亲自执行浏览器、未进行人耳听音。

## 授权与内容边界

用户原要求是家园平原的平静和NPC生活声；已选quiet-02平原/森林A只证明原两床偏好，不等于家园额外−2dB或新生活声获准。沿用已选`plains_a`精确OGG字节作为家园床，新增布料、木件、轻工具、纸页各2条录音素材，符合小范围家园试听方向。四个keeper均从真实运行时active slot和Sprite `home_root`定位，包括运行时启用的arms；没有虚构NPC/动作帧，声音明确称所在地/室内拟音。

独立核对18条authority来源SHA全部一致；正式HomeScene、DemoApp、共享GameAudio/GameMusic/GameAmbience、两区manifest/recipes/选择、两选床及五原MP3均与`7b28301f`逐字节相同。GameMusic增益0.16、session0.7及正式默认original保持。见[authority](review-authority-lock.json)、[原件对照](review-frozen-baseline.json)。没有把此开发Lab称为正式家园已接入或已合main。

## 素材与运行机制

独立8项加工测试通过，7条实际输入和保留许可页SHA逐项匹配CC0记录；布料为Iochi Glaucus，木/工具/纸页沿用rubberduck记录。轻工具源原件`keys_02/03`身份未改写，不冒称真实挥锤录音。加工参数、原件/许可/配方/加工器/输出绑定和渲染中原件漂移拒绝均在窄测试范围验证。完整来源和反例见[前置独审](review-preflight.md)，不以CC0或加工成功证明悦耳。

原有限adapter闭包9件与原负例不改。新helper的8条literal WAV路径实际参与manifest验证，原scanner实际识别新manifest+8 WAV；独立5个复制夹具反例证明未引用sibling不采纳、缺资源/未知动态caller/路径漂移/错换森林床被拒绝。没有目录级跳过。

原两处生命周期漏洞已解决：同帧面板+pause先清点声，不续尾；重绑不同活audio服务在成功新配置后清旧owned服务，失败保原态。主控runtime-03真实60/0收据和测试源码覆盖这些反例、真实Controller.die、owner离场、距离/暂停等，审查者没有冒称独跑引擎。生活音12–22秒每源、全局至少6秒、最多一声、远处过期不补播、独立presentation RNG；正式伤害/物理/存档规则未修改。早期加工、parse、runtime断言、smoke与动作窗口失败保留，没有追签。

## 实际场景与原生音轨

完整原片3×26秒，4969帧/60FPS，实际960×540、逻辑1280×720；主控原生4分42秒、包络325.023秒，未提高900秒预算。MP4为7,900,638B，SHA256 `d56076d5610af5f50b7f835046e28b51f8b6286c6d195b299b164bd86cf843a4`。独立重验3838源before/after/current全同、原AVI/MP4/trace/manifest SHA、章节推导及自有override清理；同输入三段实际位置、HP、镜头等逐帧相等，五原BGM字节和Home音乐每帧实际轨/增益均保持。

独立对保留原AVI PCM对齐后直接差分，没有后期配音。床实际源归一化相关0.95305，幅度拟合0.53163、理论运行增益0.55603（差−0.390dB，保留下采样/整数相位和残差，未改门槛冒充精确一致）。3–5秒静止窗共同Home音乐联合系数1.000238（+0.00207dB），加床后整窗RMS+0.274dB；床相对原轨RMS−11.342dB。bed/life该窗差分RMS为0。这些是该窗数值关系，不证明感知掩蔽或音乐平衡已获用户接受。

正常排程实际只出现一次`home_cloth_1`：织时匠距离50.667wu、排程clock17.583秒，片段内约16.069秒；实际波形相关0.9999828，幅度0.55057相对事件预期0.55222差−0.02597dB。静音、固定种子噪声、真实错误纸页素材3个有界反例全被同身份匹配器拒绝。**另外7条素材/3个NPC来源没有在这条路线实际发声的证明**；它们是另行可听库候选。见[实际测量与脚本](review-native/result.json)。

审查者实际看了smoke静帧及完整片73秒、80.5秒抽帧：主角、织时匠建筑和地面路线可见，新增字幕不遮中央动作；后段明确是上层工坊下方行走，不能称上楼互动、自然交易或动画同步。对应抽帧在`review-native/`；没有声称看完整连续片或亲耳听过。

## 手机工坊、身份修复与发布

发现首版Home HTML只验状态、未绑定候选/报告版本及manifest身份，可能启用混合身份包。`745097b8`只修新页：候选、报告、实际manifest三份固定task/content/mix，SHA格式/相等检查及实际manifest原始字节WebCrypto SHA验证后才启用播放/导出。HTML不在原生闭包，修后未重标或重录影片。

只读核scene作者browser-02真实390px Chromium收据：三章节pointer播放及AAC计数、9个单声、边界/循环、Stop/互斥、迟回play Promise与真实MP4取消、选择持久化/JSON、受控visibility均通过；11个元数据/原manifest字节篡改在视频请求0次前拒绝。导出的life偏好明确是自动测试数据。独立核lab-final的27个delivery条目实际SHA，并确认lab02与lab-final共17个核心文件（含全部音频/MP4/HTML）相同，见[实际交付字节核验](review-delivery-local.json)。

独立读取旧/新实际Site TAR及其SHA：旧源码`06078828`的54个dist成员全部保留，新增`home/`28个文件逐一等于lab-final，hosting配置原字节不变，见[归档核验](review-site-archive.json)。Site源码`1bfc4d6bb36807d78108a084d6803c3f798f9f7c`，部署`appgdep_6ae2c3165a108191a46b6875af1fdca9`收据为succeeded；保持owner-private受众。

对[线上家园工坊](https://clock-ambience-lab.zhipijun1996.chatgpt.site/home/)仅据主控真实远端收据核scope：同源完整MP4 HTTP200/7,900,638B/SHA同上、实际manifest bytes身份通过；life一次真实pointer、960×540、AAC解码45827B且未mute、Stop通过。远端另核旧root/previous-v1两份manifest HTTP200与SHA；其余旧54件保留由实际源归档核验支持，没有冒称逐个远端下载。已实际看该390px截图，但不是亲自浏览器测试或实体手机。见[远端原收据](review-remote-receipt.json)。

## 最终限定

可作为本轮真实家园声音候选交付用户试听。该判断不覆盖人耳悦耳/平静/生活感、成熟商业美学、物理手机/iOS Safari、完整CI、全部NPC在片内出现、正式接入或main合并。两区A/A既有用户选择保留；**新家园original/bed/life选择仍待用户实际听音**。

原Home前置独审、两份旧区域review及全部历史失败保持，不用本次工程通过改写原结论。
