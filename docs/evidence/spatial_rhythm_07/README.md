# SPATIAL-RHYTHM-07 沿前进方向的疏密变化

用户指出06“中景过多喧宾夺主，应该有的地方多、有的地方空旷，前进过程中不断变化”。本轮不再把完整聚落全景循环满铺：连续低草坡作底，独立画中风车/钟塔组放在固定世界锚点，中间保留无建筑窗口。正式Home、Plains消费；Forest仍是独立背景，不把其无Underworld记录误算成开阔窗口。

基线 `17080176146c28510559a814c9c3c9f7a7470855`，运行源 `f554e6bbea6c4f7282ed762a4880a92cae4e7918`，分支art/formal-fine-depth。继续使用scene-composer、visual-director、art-director；用户明确快速迭代、不跑完整CI。原Bible/style-v5/物理/保存/RNG/前景保护不改；地标位置只用独立art hash。

## 构图

- 低矮草坡/浅溪谷底图：无建筑、桥路或高塔，材质去饱和且弱化细节对比。
- 两风车小聚落→开阔谷地→偏侧单钟塔→更长草甸留白；4000wu世界格，周期[风车、空、钟塔、空、空]，地标横向视差0.24。组宽390/260wu，显著小于06满幅地标。
- 保留06高细源，只通过Sprite区域选取一组建筑，完整画中石基两侧渐隐，并由后绘连续草坡埋住根部。地标不提供物理/站立边界，旧跨峡石桥不在新裁块中。
- 地标自然从边缘进入/离开，未按相机区间切换整层opacity；同Seed固定世界锚点，回头不会重抽。Home仅一组更小偏侧风车，把首要焦点还给人物与功能建筑。

## 实际检查和证据

- 正式Home三镜头、两Plains图×三个Seed/出生高低分岔机关，加Forest消费者保留图，共30张1280×720，退出0，无脚本/shader/退出泄漏错误。不是路线通关。[采集记录](capture.json)。
- 29个实际Underworld窗口中，25有一组可见地标，4个完全无地标；采样集中出生/分岔，不代表路径等间距占比。许多“有地标”窗口仅边缘一角，物件计数不代表喧宾夺主。[当帧审计](rhythm_capture_audit.json)。
- 原景层覆盖/支撑/keepout检查450项、0失败，保持所有旧断言/预算。[日志](scenery-check.log)。未跑完整CI/Harness。
- 真实MovieWriter约24秒：4秒Home真实Router走跳，随后20秒Plains图一8400wu连续镜头扫描，轻微纵向起伏。角色留在出生区，这是较快的镜头观察，不是正常角色路线/通关。120个10帧抽样里19个无建筑，约3.17秒；静图不能代替正常行走节奏认可。[轨迹](movie_trace.json)。
- before使用06同Seed/镜头实际PNG，启动时间/角色姿态有差异，无同输入before电影。独立审查实际看11张新图，确认局部疏密/主次改善，未签完整动态或用户审美。[独审](independent_review.md)。

## 来源、失败与限制

一轮image_gen编辑安静草坡，36.8秒，实际模型/价格未暴露。原图字节、Prompt、来源/hash/未知许可保留在 `assets/underworld_plains/backgrounds/spatial_rhythm_07`。原06地标与许可保留，不重绘为代码噪声；新machine asset record/global manifest登记实际采用图。请求最高轮廓在下35%，实际左树稍高，按合屏结果采用，不追认数值命中。

首GPU使用上一回合失效的X100失败，未进行采图；新X101成功。[失败日志](display-failure.log)。首次统计误把Forest空parallax数组当Underworld后报IndexError，已显式跳过并记unobserved，未将其算开阔成功。

仍待用户看沿途节奏；草坡纹理偏密、地标侧肩雾化、长空段是否同质以及背景与真实场所的对应关系继续review。未看完整影片/音轨、未实测回程/全路线/移动设备FPS，不签美术完成。前景仍沿用06完整bounds+3wu保护和显隐策略，没有趁本轮减少功能保护。

## 恢复

`bash tools/godot.sh --path .` 正式入口。定位图：`--script tools/capture_spatial_rhythm.gd -- --output=res://build/spatial_rhythm_07/<fresh>`；quick加`--quick`。电影：`--fixed-fps 60 --write-movie <file.avi> --script tools/capture_spatial_rhythm_movie.gd -- --trace=res://build/spatial_rhythm_07/movie_trace.json`，真实GPU显示及兼容渲染；headless不能代替视频。未合main。

## 交付

[视频与对照图页](https://zhipijun1996.github.io/gunman-rush-previews/reviews/SPATIAL-RHYTHM-07/f554e6b/)。真实MP4为24.283333秒/1280×720/60fps，17236480字节，独立不可变媒体提交 `5f2d1e4c018c57e8e58bba49fbbe93d0c058ba13`，与公开完整字节匹配且Chromium已实际播放超过1秒。宿主80bf5e7，精确重建939101176字节，小于900MiB；页面部署与公开浏览器收据待最后补录。

为保留现有站点，视频放在独立媒体分支，Pages只增加约4.5MB图文与轨迹；没有删除历史或放宽容量预算。Release上传尝试401被拒，未作为已发布资产；原始rawURL首次在push前查询404被短时缓存，稳定内容版本query重新实际验证成功。页面更新前先fetch/rebase保留并行UI/武器入口。
