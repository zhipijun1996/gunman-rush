# 多武器细节候选交接

承接用户“多种武器的音效和子弹特效也要优化细节”。采用 player-creator、weapon-creator、animation-vfx、game-quality-gate，并由独立 gameplay-reviewer 审查。任务仍 in_progress；本次为可配置 Development 候选，不是整套角色动作、正式集成或听感验收完成。

## 实现与接口

全部生产新增在任务目录，入口 `scenes/dev/player_presentation_01/weapon_feel.tscn`。原 Home / DemoApp 正式 Plains 实际创建的 UnderworldPlayer 为宿主，原身体、角色切换、枪口、武器 Runtime 与伤害链保留。两根标有 TRAINING 的静止靶仅为新增 fixture；不代表敌人美术、正式遭遇或武器授予。Preview 的十五装备选择通过原 equip 接口，六技能测试靠真实命中积累共鸣，不注入玩家资源。

`weapon_feel.gd` 只订阅已有 accepted 射击、每颗真实弹体接触及 Runtime phase / blast / entity transition；直接读已存在的 runtime，不调用懒创建 getter。`weapon_projectile.gd` 用原 presentation 视觉叶入口，OFF / 卸载恢复原指针和可见性；正式 Plains 原 PixelPlainsProjectile 恢复也有实际测试。旧 muzzle / impact 保留，Boss 特殊接触分支不伪造事件。配置 `resources/player_presentation_01/weapon_feel_v1.tres` 限定强度、尾迹、声衰减与瞬态数，非法值和无宿主保持关闭。

新增六声音家族、每家三种离线细微变体，共18 WAV；CC0 原始来源、字节 SHA、处理公式与自制有限 beam 声见 `weapon-audio-provenance.json` 和每条独立 asset record。仍共用原12 voice 上限，受伤／死亡／警告保护；同帧齐射合并一次 release，后续连射 tick 保持节奏。没有记录本次完整 voice 丢弃／抢占计数，不宣称零丢音。beam 是0.8秒有限声段，未制作任意持续循环。新增真实轨迹渐细尾迹、枪弹明芯／轮廓、接触碎光、薄爆炸断环、激光实际接触端与地雷附着微光；保留原飞刃图及转速。

原 Runtime 的 phase / catch / blast 通用音层仍在。GameAudio.cue 丢失来源，独审拒绝了按 cue 名计数吞原声音的提议，该方案未实施。正式来源明确的音频事件需要总控协调 actor / epoch / packet / event / kind 接口，保留旧消费者。本线没有改共享通用音频或用全局静音绕过。

## 版本和验证

基线 main `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`；武器实现冻结 `5a1c640bdfd8c5889ae88efd9bdb10596aab00d2`。电影和主专项严格绑定此版本。之后只有任务 Preview UI 两次修正：`2fc73ded1bc5fc8ed67e26133fe82bb0b7f67d42` 复用现有 CJK 字体；`3a8320327ba22683cd455c9c9a476cedceabaaf0` 把选择器移至(350,90)，避开摇杆并使下拉在按钮下方展开。音频、表现消费者、弹体、Profile 和测试脚本相对5a字节不变；没有把旧电影重新标成3a。最终 Web build `b01ee2694450` 绑定3a。

实际同源 GPU MovieMaker ON / OFF 各998样本、3026检查、0错误；28个物理／资源／枪口／镜头／弹体／实体／目标字段及整个 accepted 事件数组完全一致。9 Mode 普攻连续短片各16.7667秒、1280×720、60fps、48k stereo；前后对照33.53秒，非静图拼接。15装备普攻＋6个真实攒资源技能的 headless 冻源测试各4189样本、12679检查、0错误，同28字段与事件相等。生命周期1039样本、3175检查、0错误，含实际正式 Plains 旧视觉恢复；两次 UI 修订各复验3175检查。原 `underworld-projectile-vfx` 专项2450断言、0失败。

Development 影响计划因未知依赖保守升级 full；用户本线仅授权专项，完整受影响 Integration 由总控安排。本轮不执行完整 Integration，也未开会触发自动 Integration 的 PR。docs Harness 因稀疏工作树缺少已有历史证据链接失败，原日志保留，不改守门。早期 lifecycle 被释放对象错误／测试 parse 错误／过严拒绝技能音频断言，以及早期两次浏览器菜单失败均保留；第三次 lifecycle 的合法旧弹命中应允许 contact，修正只检查拒绝请求没有 release / phase。

复现（产物目录须新建）：

```sh
python3 tests/player_presentation_01/capture_weapon.py --output build/NEW_WEAPON_CAPTURE
bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/player_presentation_01/weapon_trace.gd -- --comprehensive --output=build/NEW_WEAPON_ON.json
bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/player_presentation_01/weapon_trace.gd -- --comprehensive --candidate=off --output=build/NEW_WEAPON_OFF.json
bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/player_presentation_01/weapon_lifecycle.gd -- --output=build/NEW_WEAPON_LIFECYCLE.json
python3 tools/harness.py --check underworld-projectile-vfx --base origin/main
```

实际参数以脚本为准。重新录制要求干净已提交运行源，旧录制的源码绑定不能改写。

## 交付和未完成项

真实带声电影已发布到 previews 仓库 commit `ea169c3939f5ee36d86308f04017b3451a63fa2a`，匿名完整下载字节／SHA 已核对；下载记录在本次证据归档。浏览器试听不等于已签听感，解码音轨 mean -27.3 dB / peak -4.3 dB 也只说明电平。

- [16.8秒候选电影](https://raw.githubusercontent.com/zhipijun1996/gunman-rush-previews/ea169c3939f5ee36d86308f04017b3451a63fa2a/site/deliveries/PLAYER-PRESENTATION-01/5a1c640bdfd8c5889ae88efd9bdb10596aab00d2/3125af7a9895/after.mp4)
- [同条件先前后后对照](https://raw.githubusercontent.com/zhipijun1996/gunman-rush-previews/ea169c3939f5ee36d86308f04017b3451a63fa2a/site/deliveries/PLAYER-PRESENTATION-01/5a1c640bdfd8c5889ae88efd9bdb10596aab00d2/3125af7a9895/comparison.mp4)

独立可操作包在 `build/player_presentation_01/weapon-v1/player-weapon-preview-b01ee2694450.zip`；真实解压、原 PCK 逐块重建与全部交付文件 SHA 已核。解压运行 `python3 start_preview.py`。上方选择15装备；鼠标蓄力松开发射／激光按住，F 召回／遥爆，Q 已攒够共鸣时放技能，Space 跳、A/D 移动；原角色外观选择保留。顶部 WEAPON FX ON / ORIGINAL WEAPON FX 只切武器表现，移动候选两边一致。RESTART SAMPLE 用实际正式 Plains，HOME / FULL GAME 移除本次消费者和训练靶，HOME DROP 重开家园样板。

最终实际解压包浏览器专项通过：15条鼠标装备选择、DOM touch 选择 remote_boomerang、左摇杆对角拖动使围巾像素重心从161.32移到115.57，及真实正式 Plains 重开／Home 返回重入；AudioContext 在真实 Space 后 running。console 仍有一条未定位 URL 的 generic404 和 autoplay 提示，不宣称网络全清，也不猜404来源；完整原 console 已保留。

最新 build 的 `stage-preview` 仍明确拒绝：共享站重建 PCK 后超过900MiB。没有发布新公网可玩入口，不能以旧站链接冒充。先前 Release 上传401／查询404和 tunnel 网络阻塞没有重试。总控需安排站点容量／历史保留方案后再沿已有部署工具发布；本地包不等于公网交付完成。

独审工程限域 ACCEPT；36张实际原分辨率视频抽帧与数据独审整体 UNVERIFIED。枪弹亮芯和薄断环的局部存在已观察；接触碎光、beam 端点、mine 附着增益太弱，尚不能签可读性提升。未听音／未观看全速连续体验，15装备／6技能的 GPU 美术覆盖不足；三外观、完整受伤／恢复／死亡链、低帧率及全部正式消费者 Integration 待办。之前握持连接和 run 美术 REWORK 不因本轮专项通过而关闭。用户听感／审美／手感、真机认可均未验。

受保护 UnderworldPlayer 脚本与三件 body、旧 style SHA、DemoApp、正式场景、共享配置、Motor、输入、物理、伤害、资源、授予和通用音频均未改。本线在主题分支推送，不合 main；中心任务索引与完整 Integration 交总控。

最终 UI 独审限域 ACCEPT（见 `docs/evidence/PLAYER-PRESENTATION-01/weapon-v1/ui-review.json`）：中文15项和1280×720布局／所记录本地 DOM 操作成立；未知404、用户听感、真机、整体Web与完整工作线不在此接受范围。质量卡一致性0错误，整线 verdict 仍 REJECT／task_complete=false，明确保留失败／未验门槛；diff登记与守门保留检查通过不代表内容完成。
