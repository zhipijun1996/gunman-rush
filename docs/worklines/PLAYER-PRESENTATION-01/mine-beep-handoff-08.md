# 磁雷短滴声 V3：响应用户对旧radio提示的质疑

用户原话：“定时炸弹的音效比较怀疑，应该是‘滴滴’声。找网上的音效素材”。这是一次原V2之上的窄音色修正，原4件主角style保护资源、6秒引信、伤害/物理/Motor/资源/授予、Runtime音频钩子、原age调度和其他武器声音均未改。继续原开发分支，不自行合main；fetch确认共同main仍e9ab0e0。

选用 [Electronic Timer Beeping 4X](https://freesound.org/people/Rudmer_Rotteveel/sounds/536420/)，作者Rudmer_Rotteveel；官方页面明示CC0-1.0可复制/修改/商业使用。实际取公开HQ MP3预览，不是假称取得需登录的原WAV。源MP3 SHA f86391668ac41cf57423131f73545a90635dc259b9c1bca8a5ce44dc59bb45a3、信息页快照（删除脚本/表单）、完整CC0法律HTML和归因留在assets/player_presentation_01/mine_beep_v3/sources。备用查询比较了OpenGameArt Beep Tone Sound SFX(qubodup/CC0)、Beep Sound(Test User/CC0)、Short alarm(yd/CC0)及Countdown(Destructavator/CC-BY3)，没有把未选候选混入生产。

实际编辑：48k mono解码，取首声.045–.130秒，3ms边沿淡化，归一peak0.6，输出PCM16单声道85ms；保留原音高/音色，没有新合成振荡器或随机变调。实际输出SHA7b3945c565c4f669b0649f54417067e85ce9ccc48185242fcad825b7b3c42cf1。处理脚本build_mine_beep_v3.py可从保留源字节重建；独审从源独立复算得到完全同字节。

PlayerWeaponFeelAudioV2只将旧bank duplicate后替换mine_beep数组，三个选择槽共用同一个新短声。原V2 42WAV/14家族常量、旧radio3样本和generator不删、不改签历史。母版原12voice上限/最多8新武器声/清理守门不变。只由实体真实age/fuse推动越来越快的间隔，不烘焙整段6秒录音、不新增表现计时器决定爆炸。

运行冻结源 **4e5102af9abd16d322656375e94886a95deae38a**。实际Home正式UnderworldPlayer与原几何/显式stationary TRAINING柱采片，真实Router输入和原伤害路径，未注入主角位置/HP/资源或能力。ON/OFF各21.7秒、1294样本/3914检查，28字段和全部accepted事件相等，source clean/stable，双方0音频drop/preempt。另以旧3254984 V2 ON对比新4e V2 ON，同样1294×28及全部事件一致，仅音色绑定变化。

真实磁雷11声，tick823,880,936,987,1032,1071,1102,1127,1146,1160,1170；相邻间隔.95,.933,.85,.75,.65,.517,.417,.317,.233,.167秒，随后沿原6秒到期爆炸。[真实旧/新音画对照](../../evidence/PLAYER-PRESENTATION-01/mine-beep-v3/timer-comparison.mp4)按先旧后新；各取对应完整原生影片13.2–19.95秒连续片段，无替换音轨/静图拼接/假倒计时。[仅新版片段](../../evidence/PLAYER-PRESENTATION-01/mine-beep-v3/timer-countdown.mp4)；原完整双片、trace、实际命令与每成员SHA在同目录证据ZIP。MP4时间戳定义剪辑边界，不伪称已精确映射每个视频帧/玩法tick。

新真实binding/lifecycle测试继承原feedback，在实际ready音频服务核三槽均新WAV、85ms/nonloop、旧CLIPS三路径不变及12voices，并核Home/重进/Plains三次真实叶绑定同一持久服务。首次错误预期3个audio service导致853/1，第二次deferred审计拿已同tick替换的Home叶导致857/1和原freed参数ERROR；两次均为测试错误，原失败保留。改为在现有_attach_feel预赋audio后node_added立即观察，third为266样本844检查0错，无该ERROR，生产生命周期没有因此改动；冻结后复验为271样本859检查0错，绑定快照858检查/1个服务/3个叶；最后一条检查在父finish加入，两个检查数没有人为追平。

[限域独审](../../evidence/PLAYER-PRESENTATION-01/mine-beep-v3/engineering-review.json)仅签来源/字节重建/实际绑定与生命周期工程，不签已听音或用户觉得自然。此次未更改画面母版，未把上一轮32帧像素结论追标新源。十一维/全M1/旧run握持REWORK、用户听感/手感/审美、实体设备及正式全受影响Integration继续未验，仍由总控协调采用。原17消费者清单保留，没有只拿旧bank或Courier helper测试冒充正式主角。

原public325短片及build6952试玩包仍包含旧radio提示。本次窄音色修正没有重建/上线新Web，不说旧包已经更新；可通过本次独立真实电影和公开原素材直接试听。新素材/片段在开发分支普通Git提交发布，不扩大/绕开900MiB共享Pages站预算或删除历史入口。完整原Freedoom BSD许可/Credits和新timer归因在电影同目录；其余枪/爆炸仍遵守原BSD。

复验：`bash tools/godot.sh --headless --path . --script tests/player_presentation_01/mine_beep_binding_v3.gd -- --output=build/new-binding.json`；采片沿原`python3 tests/player_presentation_01/capture_weapon_v2.py --output build/new-clean-capture`（须干净冻结源/全新目录）。构建音源沿`python3 tests/player_presentation_01/build_mine_beep_v3.py`，保留源SHA不匹配时拒绝，不自刷旧通过。

最后专项记录：quality.py check本卡errors=[]、记录一致性通过，但任务/内容complete=false、总体REJECT，旧视觉/动画failed保留；check_quality_diff通过458文件，git diff --check通过。全库quality索引/稀疏历史依赖不因本次音色修正关闭；完整集成/用户/真机继续未验。最终提交再执行精确Git普通文件树release-evidence守门，公网链接须推送后全字节核验。

公开交付已核验：Git交付e23476341d553f8df6d1ba00e527d84753e51c8e；旧/新MP4、仅新版MP4、timer归因、完整Freedoom许可/Credits及4e源WAV均匿名HTTP200全量下载匹配本地SHA，见[公开下载收据](../../evidence/PLAYER-PRESENTATION-01/mine-beep-v3/public-download.json)。这是实际可下载音画，不宣称新的可玩Web已上线。e234精确release-evidence守门通过；全库check_quality.py本次仍因稀疏历史证据与中央planned索引不一致失败，没有重标通过。
