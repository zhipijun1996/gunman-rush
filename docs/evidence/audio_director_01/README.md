# AUDIO-DIRECTOR-01 · 第一阶段交付证据

固定审计基线 `26e7f2a4459623f35613a857da8a75e89daa3e62`，分支 `feature/audio-director-01`。本目录记录已实际执行及失败，不把自动指标等同商业品质。

- Inventory：113独立音频、13个ZIP原成员、50事件、132调用行；105现有来源指纹及5BGM逐字节匹配。3历史媒体未取完整字节，明确unknown。两次审计重建一致。
- 候选：16事件×A/B×2变体，共64个PCM16 mono 44.1kHz WAV；峰值≤−4dBFS。修改指纹守门后全64重建字节相同。6项配方/来源/工具/partial漂移反例通过。
- 运行时：新专项最初41/0，独审后补关键旧声在A/B满池抢占，最终60/0；原生命周期37/0。仍共用12voice，无伤害、物理、输入或随机写入。
- 真实Lab：CloudBootstrap→单一正式V2音频→当前默认角色Home；三profile真实Router射击/跳落；平原/森林真实加载及现有debug能力准入；取消回家与实际音频释放，25/0。未签完整自然战斗或钩索路线。
- 浏览器单声：390×844/DPR2软件Chromium，16卡片无横向溢出，79个可听对照变体解码非零，循环停止、选择保存/导出及5原MP3混播通过。原版hook_pull无持续声，保安静不造假。
- 独立审查初版REVISE及修订见[review.md](review.md)：配方指纹、离线包BGM缺件已修；旧失败保留。

## 发布边界与恢复

既有预览站本地文件757861283B，加未恢复PCK184479868B，合计942341151B；900MiB上限仅剩1377249B，不能容纳新候选/音乐或新游戏包。保留旧入口、未删任何历史。新GitHub托管repo创建实际被integration拒绝 `Resource not accessible by integration (createRepository)`。

改用独立私有Sites托管。单声Lab约24MB；下载包含候选、原版对照、许可与五首原MP3，仅本项目试听。Godot导出仍用原build/check_bundle；备用静态托管按原hash分块重构大PCK/WASM，显式要求ServiceWorker+DecompressionStream，不冒称有raw fallback。最终部署地址/版本/公开或私有访问边界将在实际结果后追加。

首次引擎导入出现字体导入前依赖错误，增量导入10.019秒exit0干净。Lab首轮test类型警告，第二轮暴露缺director_origin元数据日志错误，均保留；修复后第三轮25/0。测试成功标记、原生exit0与无ERROR同时守门。

当前为review；用户听感、手机Safari/实体扬声器/耳机、蓝牙延迟、完整自然战斗、Integration/Release均未签。工具链原安装已核4.7.2 Standard及模板SHA。完整Cloud影响计划因新目录保守升级full，仅记录计划；本轮遵用户指令执行相关专项，不冒称完整CI通过。

## 最终交付（实际成功）

[手机声音工坊](https://clock-audio-director-lab.silkyball18.chatgpt.site) · [真实Godot动作试听](https://clock-audio-director-lab.silkyball18.chatgpt.site/game/) · [完整对比包](https://clock-audio-director-lab.silkyball18.chatgpt.site/audio-comparison.zip)。页面为owner-private，需登录同一账号；不是公开匿名站。完整部署ID、Site版本、托管源SHA、游戏源SHA与包指纹见[deployment.json](deployment.json)。

游戏运行源58a9f0ac，build90764dd14d4c，完整PCK185314972B / SHA90764dd14d4c91328b6a813921da4e0161bb2e0510629b766bdaba657e8cd447。备用静态托管以原ServiceWorker逐块SHA核对并重构PCK/WASM；没有raw fallback，旧浏览器应使用单声工坊/下载包。托管源3d3e0648，和游戏源分开记录；原生部署成功由Sites回执确认，私有公网浏览器登录未代理操作，实体手机未签。

实际冷启动Web进入正式Home、当前角色及A候选，音频probe采到非零输出；1280×720与844×390横屏画面见[game-browser/report.json](game-browser/report.json)、[桌面](game-browser/home-desktop.png)、[横屏代理](game-browser/home-mobile-landscape.png)。软件Chromium非真机，不签Safari或自然完整战斗/钩索。初次浏览器等待30秒超时而游戏已打印Home就绪，修正采证等待上限后通过；旧超时[原件](game-browser/failure.json)保留，不改游戏加载来签通过。

原docs首轮3项通过后structure发现本机sparse缺build/.gdignore，恢复原tracked隔离文件后33/33全部通过，355.608秒；[原失败](initial-docs-isolation-failure.log)、[完整结果](docs-harness-report.json)、[日志](docs-harness.log)。它是缺件纠正，无源码/门槛放宽。此前Web导出结束泄漏另保；同一源重新导出无ERROR/ObjectDB泄漏，[clean receipt](web-export-clean.json)与[原完整包核验](web-bundle-final.log)通过。未确定旧泄漏根因，不追改旧失败。

可恢复命令：`python3 tools/audio_director.py brief '优化钩索声音'`；`python3 tools/audio_director.py validate`；`python3 tools/run_audio_director_tests.py --output build/audio_director/runtime-FRESH`。现阶段请按事件选择A/B/原版/都不合适并导出JSON，候选审美仍awaiting-user，不将本轮工程交付称商业品质完成。完整Integration由PR原流程另跑，不以本地专项或部署冒签Release。
