# quiet-02 · 环境音退后

用户明确首版环境床声盖过BGM，要求微弱背景。继续同一AUDIO-AMBIENCE-01 / PR113，不推广正式默认。

原BGM的MUSIC_GAIN=0.16约−15.9dB，首版床源RMS−31经会话音量后仍可比原音乐更大；这次以实际混音关系修订，四床末端−14dB、四点末端−10dB。保原归一/峰值限制后施加output_gain_db，既保证峰值受限的树干/铃声也会等量变小，也不会双重运行增益。

配方与manifest/report/candidates都绑定quiet-02，HTML拒绝旧版本数据，独立localStorage KEY避免旧选择继承；单听与实际视频都使用同一新文件，不靠降低HTMLMediaElement总音量掩盖混音问题。五MP3、MusicGain及动作音效字节不变，旧Site全部27件保留previous-v1/。

运行/录屏源e55910ec7d5be218735fb7cade4ebdd4f662552a；新片capture-06用原900秒预算、6×26秒、原输入/Seed/地图/镜头、原生音轨，不是后期配音。

9加工、17有限资产适配、57原质量测试、55原生播放通过。0项旧质量测试的错误文件匹配日志保留，不计通过；正确文件test_quality.py实际57项通过。首次降低target无法使峰值受限细节等量变轻，已保留初次产物数值/两次失败；新显式输出trim实际解码验证四床约−14dB、四点−10dB。

完整165计划仅计划、未本地执行；这是相关混音修订，不把旧全量/旧媒体签当前版本。用户新听感、实体设备、完整CI和正式推广未验证。

## 实际新媒体与手机页

新原生录制完整通过：9943帧／60FPS，14,065,613B，SHA `a502ceef2eba28176520451791b2aa44c8dfcd401d1929e5e1f73cbb51827309`；总包络714.952秒，原900秒上限未改，source稳定且自有override已清理。四床实际24秒wrap、每帧同区动作/HP/位置与正常原音轨验证通过。

本地390px Chromium12真实指针/AAC章节、点声、循环/停止/取消/导出通过。额外真实浏览器4项验证新版KEY不继承旧A/B选择、未选导出带mix_revision、旧report/旧candidates分别拒绝。自动生成选择JSON是QA数据，不是用户偏好。

同工坊已由Sites v2成功部署：[轻微版](https://clock-ambience-lab.zhipijun1996.chatgpt.site/) · [较响旧版](https://clock-ambience-lab.zhipijun1996.chatgpt.site/previous-v1/)。托管源`060788289a4d04dd96b51904317beaa04c174320`，原生producer e55910ec分记；54个静态文件包含完整旧版27文件，权限仍仅拥有者，不改访问范围。准确发布身份见deployment.json/site-source.json；远端进一步实测见后续收据。

远端拥有者390px Chromium实测通过：完整MP4 14,065,613B的SHA与本地相同，真实plainsA混音和forestB环境单听指针播放，分别观测AAC decoded bytes 45,757／77,189，未mute，960×540并可Stop。这里有实际音频解码计数，不沿用首版远端收据没有计数的范围误写。仍不是实体手机或人耳听音。

独立原音轨后验（review/native-amplitude-and-bgm-check.json）：四床对新quiet源的播放增益拟合约0.63–0.67，与旧片对其旧源的拟合几乎相同，排除旧import仍播放较响原件；两区original段3–4.8秒静听音频与旧片对齐后RMS相同、相关1.0／增益比1.0，BGM未被提高。该拟合不是人耳验收；森林旧短风仍叠加，不要求整个混合窗口都严格−14dB。

独立审查已冻结：[review.md](review.md)，SHA `ceed708cca741be9f84d8ec12c3313d995cbe866fb3fcddbb8b34c0f34954e3c`，仅工程范围ACCEPT；旧听感否决保留，新用户听感/设备仍UNVERIFIED。源码同PR113更新，不合main。
