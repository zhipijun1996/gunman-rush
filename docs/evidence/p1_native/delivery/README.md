# P1单首空间本地评审包

运行源`2be5e1f6f9a87cfa644b0c52b6ce8ff311c9a51b`，catalog`9b1c52058fdc8bcf6e2e4e913e1b83688233cb8bf727446f6771df8ed05c9e7d`，build_id`05810634c318`。ZIP路径/大小/哈希见download.json。解压后运行`./play.sh`，正常手动输入，只有P1首空间，没有第二入口；原关闭处理排空音频并释放App。此包不是Web、main合并、正式地区/发行或用户艺术定稿。

实际PCK目录、原catalog JSON、11个功能texture的真实导入mapping及所有导入后端字节已校验；非消费者视觉原图及其派生均被排除。隔离空cwd中headless和正常GUI实际启动，真实P1/root/saw/三岸mesh消费者READY、清退和无泄漏检查通过。first_actual_gui.png是导出包正常镜头截图，不是概念或仓库fallback。9个hero状态资源可用不等于9态均被实际演示；完整动作覆盖、亲听、真人设备、市场与完整CI保持未验证。

首轮747可读性REWORK与原片保留。第二轮仅获单首空间静态/运动抽帧ACCEPT_SCOPED；不能继承为概念同等精美、完整G2、商业认可或扩第二许可。metadata_clarification.json澄清通用helper的旧660模板，本P1两轮均1116tick，原生回执/电影没有改写。

## 恢复实际生产脚本

producer逐字节原件在`../producers/`。脚本依赖`parents[2]`定位项目根，不能直接从docs目录运行；在仓库根恢复到正确build层级。最终打包producer已包含P1单入口和实际PCK闭包检查，不要再运行prepare_p1_bundle生成器覆盖它。

```sh
mkdir -p build/p1_native
cp docs/evidence/p1_native/producers/prepare_local_review_bundle.py.original build/p1_native/prepare_local_review_bundle.py
cat > build/p1_native/alsa-null.conf <<'PCM'
pcm.!default { type null }
PCM
python3 build/p1_native/prepare_local_review_bundle.py --help
python3 build/p1_native/prepare_local_review_bundle.py
```

最后一条只输出计划，不复制工程或启动Godot。实际重新打包命令如下；输出目录必须不存在。expected-commit绑定真实当前HEAD，expected-capture完整原运行清单还必须与原2be源码逐字节相同，后续仅文档提交可通过、runtime漂移会拒绝。

```sh
ALSA_CONFIG_PATH="$PWD/build/p1_native/alsa-null.conf" python3 build/p1_native/prepare_local_review_bundle.py --execute --expected-commit "$(git rev-parse HEAD)" --expected-capture docs/evidence/p1_native/second_01/visual_capture.json --output-dir build/p1_native/local_review_restored_01
```

需既有Godot4.7.2 Standard工具链`../toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`和Xvfb。宿主null PCM只用于无音频设备环境的严格GUI清退，不修改游戏声音，不表示亲听。原project和export_presets没有被修改；只在隔离评审副本制作PCK。源码/Baseline/两轮原速片与严格对照、真实物理负例见上级目录与verification。
