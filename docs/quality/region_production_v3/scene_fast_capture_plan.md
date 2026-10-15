# 冻结两族pilot的fast主路采集计划（未执行）

使用仍冻结的 `/workspace/gunman-v3-scenes`，保留原相机/玩家/HUD/敌人/输入driver。父宿主安排独占引擎后再运行，不外套同一flock锁：

```sh
GODOT_BIN=/workspace/gunman-rush/build/region_production_v3/godot_locked.sh LP_NUM_THREADS=1 python3 tools/visual_director.py capture --composition --seed level-design-v2-baseline --map-index 2 --strategy fast --phase-wait-ticks 0 --encounter-policy kill_from_bank_v1 --max-ticks 6000 --timeout 900 --output build/region_production_v3/pilot_map2_fast_v1
```

现有实际Manifest与原aware driver的几何最短路规则预推路径：教程→area_0_1→area_1_1→area_2_1→area_3_1→area_3_2→area_4_2→area_4_1(prep)。这是对现Manifest的只读路线推演，尚不是Motor/影片成功。

预期新覆盖：草甸后岩肩横向经过；工坊左岸从x2140..2560方向完整接近，随后经过商人桥/营地向东离开。原growth由下方回营地只露部分屋墙，fast有机会先看完整塔/翼/根与屋体；是否进入正式原相机与HUD可读窗必须看实际新片，不能按世界bounds推PASS。fast策略不保证完整原路回程，若需要专门回望，应由协调者另安排原真实路线，不把fast离屏当完整return证据。

三观看窗口检查：进入时是否先见残屋整体而非裁翼/灰板；经过时商人、唯一落点与预告是否优先；离开/可见回望时能否保持独特屋体方向。工坊若主路也缺完整可读窗，再讨论真实岸位/独立后景基础，保留完整源图，不改相机和碰撞。岩肩继续检查840附近旧窄竖条与新后崖接合，母版近岸规格失败不被该片追认。

原growth和新fast路径/策略不同，不能作为同输入的性能/像素before-after比较；它们补同一冻结静态候选的观看覆盖。新clock/grove须单独阶段合成，不能改这部旧growth的绑定。全片不实时读PNG，片后抽帧保留video index/time，正常速度/音轨/实体设备分别记录。预计native wall约3–6分钟仅作排队估算，实际耗时/失败以后填，不预签完成。
