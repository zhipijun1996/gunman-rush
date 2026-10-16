# 独立敌人有限试玩准入证据

原始 [review.md](review.md) / [review.json](review.json) 为当时gate=false源码的**有条件接受**，逐字节复制，不追认原任务或后续运行。

[默认路径局部复核](default_native_partial_addendum.json) 单独记录后来三个文件的真实修改、原强断言保留，以及新 `root_default_final_01` 默认入口原生执行的独立核对。当前仍须默认版本兼容40audit/原165、最终合屏普通电影与Web实际检查才能满足全部建议条件；不表示完整G0–G5或用户认可。

[27张实际看图索引](observed_pixels_index.json) 记录原电影路径、SHA、零基帧索引及真正看过PNG的SHA。原电影载体在同仓库 `docs/evidence/region_production_v3/enemy_encounter_v2/`。完整电影/PNG不在本目录重复复制。

复现连续攻击帧可用标准ffmpeg从原MP4原尺寸取样：

```sh
ffmpeg -v error -i docs/evidence/region_production_v3/enemy_encounter_v2/movie02_gameplay.mp4 -vf "select='between(n,2698,2703)+between(n,3943,3946)'" -vsync 0 /tmp/root-bell-sequence-%02d.png
```

六连帧攻击/四连帧弹体与其余稀疏帧支持实际像素观察；不等于审查者正常速度看完电影或听音。原电影01失败、电影02退出10 ObjectDB/4资源错误、旧正式任务和修验任务的失败原件均保留。当前新默认headless日志干净不覆盖历史电影失败。
