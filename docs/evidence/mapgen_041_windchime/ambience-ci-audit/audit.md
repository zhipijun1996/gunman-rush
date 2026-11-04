# Forest ambience CI saturation failure — read-only audit

原head9ba7/run41679005631的真实失败是native73断言/1失败、exit1、9.6602秒、cleanup released=true；不是job输入恢复超时。原native90秒、Harness原预算/命令见audit.json，均未更改。本审计未启动Godot或修改源码。

## 结论和证据

这是“先后接受12个声音”被当成“第13次调用时12路仍同时播放”的不稳测试前提。原pool.capture实际played含13个不同cue各一次，但只有12个voice/tag，click已从tag消失，coin复用其槽，note占剩余槽。恰好只有13th-drop断言失败，原12节点和其余真实cue流/计数/playback断言均通过。ffprobe实测click.ogg只有0.010023秒。

同源GameAudio.MAX_VOICES仍12；play走original→_play_original，note没有抢占例外，只有找到!voice.playing才计数并返回true。AudioServer的实际短clip可在无await的GDScript循环期间结束，--fixed-fps60不冻结异步音频墙钟。累计played不是活动数。当前证据未见voicecap实现错误；不能据此更改正式声池、延长已选声音或冻结生产释放政策。

## 最小修复建议

保留现有12个真实原始流的load/play/count/voice_id/has_playback/stream pointer断言和全部六case。将“饱和拒绝”建立在可验证、可保持的12路actual playback前提上，随后保原第13路返回false、note累计0、节点仍12和12唯一tag断言，不改成“可能接受也算过”。

推荐保持第一段原始真实流验证不变，再在测试局部独立fixture通过原audio.play(id, stream_override)填满12路：override使用一个已加载真实WAV的局部duplicate，只开启loop并确保loop区间有效，不改原asset/_streams/正式音频。先断言12路实际playing/has_playback及全部已接受ID，再执行原拒绝检查。另释放恰好1槽后要求note成功且计数1、不分配节点，明确保留完成声音可重用的正式语义。in-memory loop只用于稳定声池占用测试，不代表试听或原clip时长。Root可先验证4.7.2暂停voice的最小替代方案，但不能假定play()/set_stream不会复位pause；必须实证playing与has_playback同时成立。

新增pool前后被动快照（wall时钟、voice.playing、stream_paused、cue_id、playback_id）能诊断未来失败；快照不暂停/停止/启动声音。不要用删cue/提高cap/新增GameAudio实现/放宽预算来解决。

本建议仍须root引擎租约下真实复现/修复后原wrapper及原Harness专项验证并独立审查。原失败保持身份，不用后继PASS追签。
