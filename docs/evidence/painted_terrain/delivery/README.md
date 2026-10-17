# 本地双入口评审交付与生产脚本恢复

此次实际打包源码提交：`3ebb0d3af98855595f43c7bf4ec2b2a675b5d6cc`。原始收据、下载哈希见`build_receipt.json`、`download.json`，两张GUI图来自同一个导出PCK在空工作目录中的实际启动。`play.sh`进入首空间；`play-second.sh`经既有preview的`--formal-painted`进入正式08两薄岸。没有自动输入或中途传送，使用原清理关闭。

`prepare_local_review_bundle.py.original`是当时build-only producer的逐字节原件，不能直接在docs目录运行：脚本使用`parents[2]`定位工程根。必须恢复到项目根下的`build/painted_terrain/`后运行。在含完整归档的仓库根执行：

```sh
mkdir -p build/painted_terrain
cp docs/evidence/painted_terrain/delivery/prepare_local_review_bundle.py.original build/painted_terrain/prepare_local_review_bundle.py
cat > build/painted_terrain/alsa-null.conf <<'PCM'
pcm.!default { type null }
PCM
python3 build/painted_terrain/prepare_local_review_bundle.py --help
python3 build/painted_terrain/prepare_local_review_bundle.py
```

最后一条仅输出计划，不复制工程、不启动Godot。实际执行命令如下；输出目录必须尚不存在。`expected-commit`绑定正在恢复的实际HEAD，另外完整`expected-capture`源码清单必须逐字节匹配原3ebb媒体树，因此后续仅文档提交可以重新打包，运行源变化会被拒绝，不会被当前HEAD掩盖：

```sh
ALSA_CONFIG_PATH="$PWD/build/painted_terrain/alsa-null.conf" python3 build/painted_terrain/prepare_local_review_bundle.py --execute --expected-commit "$(git rev-parse HEAD)" --expected-capture docs/evidence/painted_terrain/records/final_e_01/visual_capture.json --expected-formal-capture docs/evidence/painted_terrain/records/reuse08_candidate_03/capture.json --output-dir build/painted_terrain/local_review_restored_01
```

上述ALSA配置是当前Linux宿主的null PCM（`pcm.!default { type null }`），用于宿主无音频设备时的严格GUI清退。配置只放build，不改游戏音频；若恢复环境无该文件，可用相同宿主配置创建它。当前机器官方Godot需位于`../toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`；有Xvfb或当前toolchain备用路径。脚本校验引擎版本、真实资源消费者、两个selected banks和原静态碰撞，并保存实际GUI图；任何错误/泄漏都会阻断ZIP。

这是本地有限评审PCK，不是正式发行。编码音轨未亲听，启动/清退和静态限定认可不等于完整G2、地区完成、真实设备或市场验证。
