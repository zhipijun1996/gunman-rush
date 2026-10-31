# AUDIO-AMBIENCE-01 · quiet-02 增量独立审查

审查者`/root/ambience_review`与实现主控不同；审查者不修改生产实现、不运行Godot、不冒称人耳听音。本轮沿同一任务消费主控转述的用户实际反馈：首版环境声盖过BGM，需要微弱环境衬底。该反馈是旧混音的听感失败；原工程ACCEPT不能冲销它。quiet-02是否已符合听感仍待用户实际试听。

原首版审查`../review.md`保原SHA `35f3500e720abd479405dc4b453222340ee47c267f576aff405ddc6c3fec50d6`，没有追加或改写。本轮为独立新记录，不追签原媒体/用户反馈。

## 设计与实现边界

冻结实现`e55910ec`：保原归一目标、EQ、选材、时长/loop、变体、原12声池与显式2床/2点预算；在normalize之后使用独立`output_gain_db`，床为−14dB、四点为−10dB。BGM原文件、GameMusic的0.16增益与会话音量语义不变。降低环境与音乐的相对电平，而非调高/加工音乐。

`mix_revision=quiet-02`贯穿配方/manifest、capture report、打包candidates与页面双检验；候选ID可相同，但文件SHA与manifest SHA/producer/混音修订区分实物。网页新localStorage key `clock-audio-ambience-v1-quiet-02-choices`，不读取旧`clock-audio-ambience-v1-choices`。旧版计划在同Site的previous-v1保留；是否实际复制/上线需后续字节/URL收据，单个HTML链接不能证明旧版已保留。

## Q2-1：只改目标RMS未实际降低全部点声 · 已修

首轮把四床target由−31改−45、四点target各降10dB。独立读取实际新/旧产物发现：四床约−14dB，但plains_chime_a完全同SHA/0dB变化，chime_b仅−5.693dB、forest_wood仅−0.0525dB、forest_leaf仅−4.653dB。原因是既有normalize取RMS目标和峰值上限中更小增益，原短瞬态受峰值约束，降低目标并不必然降低真实音量。该轮不能声称“所有点声低10dB”。原数值与主控两次失败日志保留，审查原件[initial-level-delta-failure.json](review/initial-level-delta-failure.json)。

主控修为保原normalize目标，归一/峰值处理完成后显式乘负输出增益；新validate撤销trim后仍检查旧(−45,−20)dBFS故障范围，峰值天花板随trim降低，并检查不超target+trim+0.5；trim须是真实int/float且位于[−24,0]，拒绝bool。没有为通过而放弃原峰值/静音/指纹/接缝守门。

独立实际解码核对后的四床变化分别−14.001381、−14.002335、−14.012951、−14.003232dB；四点分别−9.999889、−9.999939、−9.999953、−10.000058dB，与作者gain-verification原件及当前manifest metrics逐项相同。微小差别来自PCM/有损编码，不把“14dB”伪装成逐样本绝对相等。现在plains_chime_a也真正降低约10dB。证据[levels-and-preserved-inputs.json](review/levels-and-preserved-inputs.json)。

## 局部工程验证

独立实际执行：

- 原9项加工测试全过，19.396秒，[日志](review/design-independent.log)/[退出收据](review/design-independent.json)。
- 原17项有限资产适配器测试全过，0.308秒，[日志](review/adapter-independent.log)/[退出收据](review/adapter-independent.json)。
- 临时复制夹具的5个负例：output trim为False、正数、低于−24、NaN，或manifest混音修订漂移，全部拒绝；未改变正在录制的生产源。[反例](review/gain-and-mix-counterexamples.json)。
- 独立与旧提交a14cd04c比较：五首MP3、GameMusic、GameAudio、GameAmbience、source registry共9件字节完全不变；无新来源/许可、游戏规则、伤害/物理/操作/RNG/保存变化。[字节证据](review/levels-and-preserved-inputs.json)。

独立执行当前HTML原脚本的4个Node VM负例（stub DOM/fetch/storage）：旧report与旧candidates、仅旧report、仅旧candidates、错误修订版本均拒绝ready。每例只读取quiet-02新storage key，旧A偏好未导入且旧storage原字节保留。[脚本绑定与结果](review/html-mix-storage-counterexamples.json)。这仅验证版本/隔离逻辑，不代替真实浏览器、音画播放或实体设备。

主控另报告55项原生专项通过；审查者未运行引擎，不能将其写为独立Godot执行。计划器保守full165未执行，不把本次有限反馈迭代夸大为全量CI/全游戏验收。

## 录制前检查点（历史，已补证范围以下方最终结论为准）

本轮静态/加工幅度范围可继续后续交付，Q2-1已修。四床和四点输出较旧版实际更弱、BGM文件与增益不变为已证事实；“恰好微弱衬底”“不会主观遮盖”“悦耳”不能由RMS签字。实际原生capture-06、BGM原混音关系、网页新版标签/旧选择隔离负例、previous-v1字节保留和同Site发布身份尚待实证。

原森林周期短风仍保原消费者；本轮四点只作库候选，不冒称全地图细节已布设或所有环境事件都降低。用户听感、实体手机/扬声器、Safari和商业品质继续UNVERIFIED。

## 最终媒体、实际音乐关系与发布复核

完整capture-06已真实完成，producer `e55910ec7d5be218735fb7cade4ebdd4f662552a`、mix_revision `quiet-02`，9943帧／60FPS、960×540物理／1280×720逻辑、14,065,613字节。MP4 SHA `a502ceef2eba28176520451791b2aa44c8dfcd401d1929e5e1f73cbb51827309`。原生约10分54秒，采集/编码/清理总包络714.952秒，原900秒native上限与全部6×26秒覆盖不变。

审查者独立实际重跑trace/override生命周期/章节重建和媒体SHA检查：6段真实同区动作/HP、4候选24秒loop证据通过，3808件实际源before/after/当前完全一致。证明见[capture-identity-check.json](review/capture-identity-check.json)。另实际打开新`capture/plains_A_action.png`和`forest_B_action.png`：空中角色、接收平台与路径清楚，小字幕未遮角色；不把这两帧写成完整连续观看，也未进行人耳试听。

### 实际录音中的降低，并非只看源文件指标

审查者实际解码旧capture-05与新capture-06的native AVI，对相同BGM-off末尾2秒窗口与对应旧/新源波形对齐，独立验证两份原AVI完整SHA均匹配各自report，排除用错原件。

- 新四候选拟合播放增益分别0.667429、0.633421、0.661123、0.651295；旧为0.667270、0.633323、0.660209、0.651438。8kHz整数对齐/解码拟合不等于精确会话0.7，不伪造“刚好0.7”的通过，也不事后放宽原相关守门。
- 以新旧各自同方法估计的候选分量比较，实际原生分量变化分别−14.004613、−14.007360、−14.004200、−14.014970dB；播放增益新旧比仅约−0.0019～+0.0120dB。新音频确实进入真实录音并降低，未出现源文件已静、旧import仍同样响的情况。
- 森林新normalized dot降至0.765455/0.685740，原平原为0.953443/0.905003，仍通过原≥0.45门。森林旧周期短风保留，减弱新床后其残余相对占比提高；不能把总混合RMS或归一相关下降等同于候选未播放，也不能声称所有旧环境事件被降低。
- 两区original段，以章节+3至+4.8秒无移动窗口在新版+2.5至+5秒搜索对齐：实际偏移均0，归一相关均1.0，新旧拟合增益比均1.0／0dB，RMS分别保持0.014159127856985866、0.02350245722795328。该原生静听窗口没有调高BGM；配合五MP3与GameMusic字节不变，支持本次确实降低环境相对音乐的工程事实。它不证明音乐全曲每一时刻均无主观遮盖。

[原生幅度/BGM实测](review/native-amplitude-and-bgm-check.json)保完整系数、残余、窗口、原件SHA与分量相对值；[独立分析脚本](review/native_mix_measure.py)记录核心对齐/拟合方法。听感“微弱且恰好”仍需用户确认。

### 工坊、新旧选择与旧版保留

审查者只读交叉核对主控真实浏览器/发布收据，没有冒称自己执行这些浏览器动作：

- 本地390px Chromium原checker12个真实指针章节全部实际解码音画且未mute，ID/时段逐项匹配新native章节；4点声、停止/循环/异步取消/选择导出仍通过。另4项真实浏览器身份检查确认新key不继承旧选择、默认BGM混音、导出显式quiet-02与未选择ID、旧candidates/旧report均在播放前拒绝。QA选择不是用户认可。
- 远端两真实指针分别为plains_A_mix、forest_B_environment，实际audioBytes计数45757/77189、videoFrames117/183，未mute，Stop同时暂停媒体，errors=[]。远端完整MP4响应200，字节/SHA/producer/mix_revision与本次原件完全一致；本轮远端有实际AAC解码计数，区别于首版远端03的更窄观察范围。
- 同一owner-private Site主链接已原生发布succeeded：`https://clock-ambience-lab.zhipijun1996.chatgpt.site/`，版本2，deployment `appgdep_6ae2b330b07481919110efad2df5519d`，saved version `appgprj_6ae228bff25c8191a704958f043b1ee0~appgver_13c6709977108191968c416ba3c8a692`。网站源`060788289a4d04dd96b51904317beaa04c174320`与Godot producer e559分列。
- 审查者独立读取Site checkout：previous-v1的全部27文件实际SHA均同时匹配保留清单与原Site提交8d29d154中的各自Git blob；旧片69da、原页面/JSON/ZIP/8音频/许可都未改写，新旧root共54文件。旧版响度反馈及原独审文件仍保留。证明见[site-and-browser-receipt-check.json](review/site-and-browser-receipt-check.json)。

## 最终结论：限定工程 ACCEPT，听感/设备未签

本轮实际完成用户授权的环境衬底工程修订：四床源与实际原生分量降低约14dB，四点实际降低约10dB，BGM文件/增益与原生静听窗不变，版本/选择隔离及同Site新旧媒体可追溯。首轮目标RMS误用与tight-target失败保留，不追签其结果。原计划器full165仍未执行，不宣称本轮完整CI或全游戏正式推广。

本轮局部工程可接受；用户是否认为不再盖音乐、是否舒适精致，以及实体手机/扬声器/Safari和商业品质仍UNVERIFIED，整体内容继续review。未完整连续观看新片或人耳听音；四点未自动全图布设，正式original默认及原森林短风语义保留。

本审查到此冻结；后续提交/PR与新用户意见由主控另存，不改写原review或本轮失败。
