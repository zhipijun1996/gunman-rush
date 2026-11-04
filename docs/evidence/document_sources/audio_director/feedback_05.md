# AUDIO-FEEDBACK-05 · 真实试玩反馈修订

2026-10-30用户报告标题无BGM/Home晚开始、主角受伤违和、子弹墙地声违和、风铃听不见、宝箱取得道具无音效。新原话覆盖hurt C在真实混音中的先前偏好，不改写旧选择或删除旧音轨。

正式修订从main5f55716a开始，实际实现d466ed27；独立分支fix/audio-playtest-feedback-20261030，未自动合main。保五首原MP3、原jump/land、敌伤B与武器选择。首个真实手势即以原MusicGain开始；Web标题提供原字幕位置的音乐触点，后续换曲仍0.9秒渐变。首次冷浏览器播放需要真实手势，不伪造自动播放授权。

受伤另名hurt_feedback_05、两条柔软身体/布料变体；显式C试听仍为原C。墙地保持solid contact独立事件，三条短石粒/消散声，60ms/至多2声，不借敌伤B，也不影响子弹和RNG。新[原件许可索引](../../config/audio_director/feedback_05/sources.json)、[配方](../../config/audio_director/feedback_05/recipes.json)、[实际manifest](../../assets/audio/feedback_05/manifest.json)及[加工器](../../tools/audio_feedback_design.py)是下一轮hurt/wall的当前上下文；旧V3原件仍保留。

宝箱原来只有通用confirm，实际chest_open/item_get仅存在开发fixture。现沿正式COMMITTED领取/商店提交发声：实际claimed开盖才响锁盖声，真实物品入包才响长获得句；资源有自己的反馈，查看、取消、拒绝、REPLAY不冒领。已提交反馈可在菜单暂停期间完成，普通换层保尾，真run end/title清理。机制铃保现原件，只独立提高瞬态增益与优先级，普通暂停、静音及12声预算保留。

技术计数、真实原生音轨和实际浏览器混音分别留证，均不等于材质悦耳、手机或商业品质认可。当前新音色仍awaiting-user；后续简短“优化受伤音效/碰墙声音”由brief自动读取本页及新指纹，不应回到已在实玩中被拒的旧C或Freedoom墙声作为当前方案。
