# FOREGROUND-CONTINUITY-08 独立限定审查

2026-10-23；独立审查者density_art_review。未实施前景生产代码，未启动engine或运行CI，仅审源码、实际1280×720原图、状态/像素记录，独立重算已有GPU图像差并写本报告。唯一写入路径为本文件。

## 范围结论

| 范围 | 判断 | 依据与界限 |
| --- | --- | --- |
| 固定逻辑身份、完整离屏回收、一次推进计时/暂停 | ACCEPT（限定技术样本） | 冻结源码及Home506采样/23身份回执，非全区或正常路线 |
| 严格局部保护GPU像素 | ACCEPT（限定当前图对） | 独立读取并重算387080严格保护像素，差异0；1262非零前景采样避免空白验证 |
| 632fce6分支局部遮罩的自然轮廓 | REJECT / REWORK（失败保留） | 08_m1横切和悬浮叶，Home右下只剩叶簇；技术安全没有签艺术通过 |
| 6befe56修后的指定Home/map1/map2静图 | ACCEPT（仅关闭已观察断枝缺陷） | 完整枝提前退出受保护窗口，新图不再出现该悬叶；不签整区精美 |
| 完整运动、全部战斗/预告、音轨、用户和真机 | UNVERIFIED | 本次没有完整播放/正常战斗/设备证据 |

## 真实失败与修后范围

首先实际打开632fce679f0f6168b59da846611d5fc217d98c6b版本captures的home、08_m1、08_m2，以及check的with_foreground、with_guard_foreground、without_foreground_guard原图。旧08_m1右上枝在约y325横向软切，x1058/y355附近留下与枝干脱离的叶片；Home右下也只剩分离叶簇。它们说明局部安全遮罩可技术正确但美术不自然。本代理报告后由实现者返工，没有由本代理修改生产代码。旧断枝图另保留在 `docs/evidence/foreground_continuity_08/branch_cut_632fce6.png`；早期first_failure仍独立保留，不追认成功。

最新运行source为 `6befe56b8802ac2472264b866deac1d7efdf649f`。实际再次以original打开最新captures/home.png、08_m1.png、08_m2.png。08_m1右上断枝已退出该受保护窗口，画面更开阔，左侧仍有少量近叶；Home保留底部两草，右下叶簇不再出现；08_m2主体/落差可读、未见新的断叶或HUD遮挡。接受范围仅是这些静图里的原缺陷已消失，不能据此签提前fade过程自然、所有镜头都有前景或所有前景安全。

本次未逐张看home_east/highland_m1/highland_m2，不将“6窗已采完”升级成6窗都获独立视觉通过。还未查看本轮MovieWriter影片或抽帧。

## 源码与状态证据

完整读underworld_foreground.gd及shader，并审6befe56相对632fce6的最小diff。

- `_object_spec`只从world cell/seed确定asset、world anchor、scale及wind phase；resident字典固定Sprite，隐藏或alpha归零不释放身份。已入屏对象只有完整bounds+4wu离屏才回收；新预建对象可在96wu缓冲区外回收。回程完全离屏后新建实例允许换instance_id，但逻辑身份/素材/尺寸不变，不是屏内换叶。
- `refresh()`只调用delta0刷新；`_process(delta)`以Engine帧号防重入推进一次。淡出.18s，恢复先安全.3s再以.7s渐入；暂停不推进wind/alpha计时。root_guard12与至64wu的root_gate让可见挂点入屏前渐退，不因root_gate0释放resident。
- 永久UI/terrain对草只作局部mask，动态危险在实际暴露区参与64wu提前fade。修后branch改用完整原bounds对全部保护矩形计算64wu距离，提前淡整枝，避免细茎被永久遮罩切断；grass仍保留dynamic-only策略。没有回到每帧挑另一张/另一尺寸替代原resident，也没有可见敌人预警触发全局隐藏。超过64保护矩形的overflow仍是保守全隐藏例外，不能称所有场合绝无全局消失。
- Shader保留实际SCREEN_UV屏幕坐标mask，严格区已grow3，内部alpha恰为0，外侧24wu软衰减；突然出现HUD/弹体不等待慢fade完成。原挂点风剪切约最大1.6wu，仍受3wu裕量覆盖。此为当前源计算，不外推未来增幅。

实际读tools/verify_foreground_continuity.gd：它是正式Home+诊断相机往返，外加真实CharacterBody2D/CollisionShape2D保护刺激，不是实际敌人攻击或玩家路线。对象asset/world_anchor/display_scale/wind_phase每采样比对，离屏断言已从grow2恢复grow3；不是为过关放松。回执506采样、23逻辑身份、failures=[]。状态timeline每6次记录一次，共84行，不能说每个样本都保存完整图像。

草home_grass/1的guarded、held、recovered状态保持相同instance_id=254392929134与素材/尺寸：alpha依次.9、0、.7285714；safe_time依次0、.1833333、.85。它支持危险后归零、恢复等待和渐入，不是换株。timeline的暂停两条wind_time=8.3666667、advance_count=502，resident身份/alpha/safe_time相同；重复refresh20次未推进counter的断言也保留。

旧样本时间线里可见17处相邻保存记录instance_id变化，逐项核对新bounds+4均完全离屏，符合离屏回收重建，不隐瞒为“实例永不变化”。完整采样的细节以回执为准，本代理没有重跑验证器。

## GPU局部保护核查

with_foreground实图底部草有实际像素；加真实guard后只在相应局部被挖空，其他部分仍在，without_foreground_guard用于同画面无前景对照。独立用Pillow/NumPy读取最终with_guard_foreground与without_foreground_guard，按guarded保护矩形grow3、像素中心规则重建mask：387080严格像素中changed=0、max_channel_error=0，与pixel_audit.json一致。1262非零前景采样来自with/without前景差，说明不是全隐藏后签保护。

这项证据只说明当前Home诊断图对的保护效果，不证明所有来源inventory完备，不证明全部攻击轨迹、绳索/触屏/resize、快速camera变化都安全。前景纹理与叶形的自然程度也不是像素差的验收对象。

## 剩余问题与未验

整枝在长期UI/地形附近可能长期淡出、已admitted但alpha0的resident仍占槽，局部前景会更稀疏；这是稳定身份与避免断茎的取舍，不能用计数称层次一直丰富。高速运动下局部mask先切、整枝fade后退的短暂过渡是否可见，需实际连续片与战斗反例。草的局部mask仍可能改变叶尖轮廓，当前Home没见严重问题，不推广成全画面自然。

未完整播放影片/音轨，未签正常Motor路线、全战斗预告、所有危险/全地图/设备性能，也不代签用户觉得效果舒服或精美。技术与指定静图范围ACCEPT，整体动态/审美仍UNVERIFIED。

## 字节绑定

| 本次对象 | SHA256 |
| --- | --- |
| scripts/underworld_plains/underworld_foreground.gd | `0720a2a307c497e1b65bdef3f44d72fc62da32b01298cf80bbd4941b215ad9ed` |
| shaders/underworld_foreground.gdshader | `e8c2c8ecd4d32ce2d35ee3de2f679d96b8558a1de847004731c4baa8a726a011` |
| tools/verify_foreground_continuity.gd | `0e2d73dda61c90fbd3f12d186b81674aeff57534aee17757a6b8e5d6a79194ed` |
| build/foreground_continuity_08/check/check.json | `d48deb072f8538ba69c883ae5ebc18b69c4f92f3df236a2d0e48d6ec9e74abf6` |
| build/foreground_continuity_08/check/pixel_audit.json | `52135a1d196b2420ebf39b0dbe3a80bdffa1ef69840322f0b2e02d49ca2d23e1` |
| build/foreground_continuity_08/check/with_foreground.png | `f182a85bdb3e625668166361c2cba4645ac168a69e83ace8c54a64f38c2d9808` |
| build/foreground_continuity_08/check/with_guard_foreground.png | `eba6dd031b8a08f202c9622b0258fa50e8805e8034071e84868b0a20e90812c9` |
| build/foreground_continuity_08/check/without_foreground_guard.png | `2568c0eaa2694e108dfc51d8937b295bfef6fa4d5a8e7b63275b74667aaa77e1` |
| build/foreground_continuity_08/captures/home.png | `3db73a056f042400a776ff38a09fa6451b77288f0789493421834a20710fb170` |
| build/foreground_continuity_08/captures/08_m1.png | `9b431fb5ea99eb6b3b3e276a697b28092fcb1e6e87accc0fa202db0d099e06cc` |
| build/foreground_continuity_08/captures/08_m2.png | `a43243bd394ed8cab55a4d57a5f7d208c8cd5afc9c97051d5a042d2ef2eae252` |
| docs/evidence/foreground_continuity_08/branch_cut_632fce6.png | `99e69ed6a4449d71c04e771f32d171921f42bfc63cfe73691653a7d169703372` |

本报告唯一写集为本文件；不自改实现，不追认旧first_failure或632fce6艺术失败为最终通过。
