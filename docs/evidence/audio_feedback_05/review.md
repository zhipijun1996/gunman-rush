# AUDIO-FEEDBACK-05 · 独立工程审查

**当前音频接口与所列窄验证范围 ACCEPT；实际浏览器、长自然路线、手机听感和商业品质 UNVERIFIED。** 基线 `5f55716a838a754a938997920ff18cb3b17452b5`，审查当前未提交实现以文末SHA快照为对象，未冒写新生产提交。root冻结源码后须核相同字节再绑定准确提交。审查者只读生产，没有运行Godot、亲自执行浏览器或人耳听音；本轮仅获准新增此审查文件。

## 实际根因与修订边界

主角APPLIED负HP损失原经PlayerFeedback调用hurt C；正式Motion/Underworld表现没有额外hurt音频层。墙/地经terrain_impacted和正式PlayerPresentation身份守门进入独立wall家族，原用Freedoom dstink裁剪，没有误借enemy_hit B。非致命敌人既有enemy_hit B+enemy_hurt B两层不是本次墙声错误，保持未顺改。旧hurt C及选择原件保留；本次为另名hurt_feedback_05，不继承旧C用户认可。

新hurt两变体及wall三变体复用六条已登记CC0原件；独立核六原件SHA、五输出SHA匹配manifest，11条保护输入（含五MP3/旧C/旧选择）全同。实际输出RMS/峰值只是技术指标，未据此宣称材质悦耳。处理器沿现V3层加工与明确配方，新文件/参数/许可索引均可追溯。主控加工validate及原件/许可/锁定输入漂移、变体顺序、渲染中漂移/不覆盖、字节复现反例记录已读，审查者未冒称自己重跑加工。

## 接口与生命周期

- 新cue_committed_reward只接chest_open/item_get及confirm/note旧回退，由实际caller COMMITTED检查承担事务真实性。新入口沿origin祖先的自有GameAudio寻找，不使用全树首项；原池仍12，原优先级/并发/静音/关闭保持。普通世界声仍受pause阻断，已提交奖励可在暂停菜单完成。
- 独审发现直接play_director_event显式original分支未转发奖励flag、legacy奖励没有可清理标记；现已修为仅两奖励语义安全转发，legacy具弱origin、director_event及committed_reward，离场/默认清理与selected同通道。stop_regional_cues窄保已提交奖励尾音；run end和title跃迁明确清理本App声音，正常换层不剪断本帧成功反馈。shutdown仍停止全部声音，不因保留标记越过销毁。
- 独审发现revision id非字符串会抛方法错误；现先拒类型。revision只覆盖selected默认入口，显式C/hurt_c与original/A/B仍可听原件；新提案在setselected前配置，失败不误开selected。没有把新声音覆写到历史C文件。
- 墙声只改表现素材与60ms/最多2声限制，共用原weapon/12voice池；没有修改子弹伤害、碰撞、武器速率或玩法RNG。机制铃仅该cue增益/优先级调整，暂停/静音和池上限不放宽。
- 首轨沿真实_input授权后以原MusicGain0.16和session音量开始，重复手势/同轨不重启，后续0.9秒交叉渐变保留。标题Web LinkButton复用字幕位置提供真实手势触点，原五MP3不生成、不替换。

旧GameAudio静态cue/stop_region仍存在global-group首项路由边界，本次仅核新奖励入口及新增App清理的owner，不把它称为全部旧API已实例隔离。

## 读取的实际验证与限制

1. 主控native-01：30/0，严格退出passed，8.699秒；真实formal scene、原HealthState APPLIED/REPLAY、真实Home向下发弹碰地、新hurt路径/显式旧C、墙60ms/2声、原12池满载机制抢占、pause/mute、首音乐/重复/后续过渡及原bounded teardown。首手势是native人工事件模拟，不能代签浏览器自动播放；机制铃是直接API饱和夹具，尚非真实shot_latch+BGM可听性。
2. selected-01：原专项63/0，严格退出passed，11.785秒，保留选择/源验证与正式组装边界。没有据此宣称新材质得到用户确认。
3. rewards-01：70/0，严格退出passed，13.628秒。实际平原物品/资源宝箱、森林物品宝箱、V5商店付费/实际库存取得，offer查看/错选/晚回调/REPLAY无新增成功声；开箱先于item_get且资源不发item_get；菜单暂停真实共享voice为ALWAYS；区域清理保已提交尾音，title/run end清尾；original profile暂停note回退和原backend释放通过。原日志汇总3次chest_open、5次selected item_get、1次legacy note，释放true。

奖励专项明确使用位置重定位、500金币、取消敌攻击并停controller physics等夹具；森林用已有debug入口，不冒称正常探索、自然战斗/击杀Boss或长路线。70只有一个App，新入口多App owner是源码核查，未伪称该专项实测；legacy title/death的标记/清理源码已核，其独立行为不由selected title/run-end用例代签。

首import-01 fresh字体缓存错误保原件，import-02清净，不以之后通过改写首失败。当前无未解决的所审接口工程阻塞，可进入同源相关门禁及开发试玩验证；真实Web标题触摸/音频输出、shot_latch铃与BGM混音、完整奖励交互听感、实体设备和商业品质仍需后续实际验证。此审查不表示main合入或部署已完成。

## 当前源SHA快照

以下为审查时当前字节；基线不冒充这些新增实现生产者。

| 路径 | SHA256 |
| --- | --- |
| `scripts/audio/game_audio.gd` | `72706df898c09f1fa1c3955278a96b541fce374a0c960a54146311a6bbca1781` |
| `scripts/audio/game_music.gd` | `46f0e771883351b9c41566c9f0de4b6d080f0fb7ae32e82fbe940174db782ce8` |
| `scripts/audio/selected_sfx_runtime.gd` | `f90bef12397307bd1e9f3d6657c2a239506a93aebb8c225e14ee0aa0248cdeec` |
| `scripts/demo/demo_app.gd` | `3e9e9baf24da3e08cc53890d41d1f995f78c280d90666f514e47b4cda6555c5f` |
| `scripts/dev/player_presentation_01/weapon_audio_v2.gd` | `7d800d5b0e3eabe03305bf96ecc7cae3d8f3bf134c6e15e7029f592022532836` |
| `scripts/items/v5/item_v5_shop_presenter.gd` | `2b803f8f23154de50f1471033d030eb1329196d0505a4119706742879cfa7a7b` |
| `scripts/ui/demo_menu.gd` | `af2f5a92ca800bcbe4340c23d3007e9d37b93dff96e9720df102cb17040c930d` |
| `tests/audio_feedback_05.gd` | `a0df222d697c939d0f94959e4953fbc41551ae28724e5641fd67fea8282e53a4` |
| `tests/audio_feedback_rewards.gd` | `ba2010bd790c5404e0e6e05558884a8577ba91330c20bec8d38792ef7ade1f11` |
| `tests/selected_sfx_runtime.gd` | `04f832fb557c6f03f07941bd079771c67ed029da8d9403d184c0b67183aedb87` |
| `assets/audio/feedback_05/manifest.json` | `799a69de37b291bde7229072aa9ec2d877bfeb949b79133cb558142945c87d13` |
| `config/audio_director/feedback_05/recipes.json` | `e6fb036049d796036b5fed5814b65abef6772380d81714d41b5a4461c332c875` |
| `config/audio_director/feedback_05/sources.json` | `b2c44b5061545fb6830a1df3af581f1f44f26186529cd0a1d4e26ab8f91f0068` |
| `tools/audio_feedback_design.py` | `8b3c5c7a728b7bcdbe3f5fa6fbfc00b8128fcae67ef370f4f7c33f525fd1d8d3` |

原始运行记录位于 `build/audio_feedback_05/{native-01,selected-01,rewards-01}`，不把工程计数当听音结论。
