# 原候选组件锁与当前引擎验证

发行提交93c5221a9708d079c2864f3c14b415e81bb5de07的0.3.0候选ZIP原SHA为9ea87854c96cf7c2189b4c6ad25a8056454a3150721bead79c335aca8678acd0；75份manifest成员全部实核。包内source_commit508b558e8a9925862e8a26c20fea008b9a772007与发行提交分开记录。运行仅安装原15个addons/mapgen脚本，逐文件字节不改；一份模块1.1.0 ZIP、请求和配置按config/mapgen_candidate.json锁定。完整候选/参考/测试包与Python不进入游戏。

开发工具tools/install_mapgen_candidate.py复用原verify_mapgen_reference安全提取；install无覆盖，重复安装19项均unchanged，verify核包和已安装原字节。Godot生成的.uid不冒充上游源文件。

实际引擎为主游戏锁定4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf，binary SHA eeaec2b65dc3234168be1e1cbcc89731514bbb78dfb2c1b502920c50830a0638。调用新工作树tools/godot.sh，在包原项目运行未改基础脚本：foundation123断言、verify_bundle75源文件及成功/失败语义样例、jobs32项全通过；无退出错误/泄漏。命令、原预算、退出码、实耗见[收据](../../evidence/mapgen_godot_03/candidate-basics.json)，不沿用上游4.6.3结果。

另在主游戏项目内直接运行包原generate.gd，输入仅真实模块ZIP/请求/配置，930001实际生成PASS：46实例、55连接，原fingerprint 9a5c671e93a6cbe2a11dde3e54fe2e722810bb5745d694f1b59921f6444639d7；不读取冻结图，不回退，约13.96秒。首次主项目因新工作树缺字体导入缓存失败，原日志保留；恢复同仓真实import缓存后通过，不改游戏字体或solver。

调度预算是操作单位，不是毫秒。当前引擎包原jobs测得budget1/17/128/4096最大单advance分别25.481/40.133/229.771/4025.719ms；主项目128实测233.865ms、713calls。同步archive解析与prepare也有长调用。无硬帧预算保证、未签手机性能或全图可玩。M24奖励封死已知未修，semantic PASS只作算法一致性，不代替物理/内容验证。

PR127的e7d保持原样；run41569062806四job均SUCCESS，原172项fresh通过、0reuse/0failure/0未执行。完整原始API/两lane/合流artifact已核，摘要[收据](../../evidence/mapgen_godot_03/pr127-ci-final.json)。更早run41510336068的scope hash失败仍原样保留，不以新结果重写旧失败。
