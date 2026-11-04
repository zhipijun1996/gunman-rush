# V3-ASSET-CLOCK-01 原画生产与限定源预检

实际作者 `/root/v3_art_director`。真实implement请求hash `47ba2041141ab020fd2b3ca46e7cfbfa33c11fd733b4febc2932312a26249386`、nonce `d0051abefd2b4814bd24b278757a78b3`；source commit `d64a5273006973dadcfc68c69d9e19bcd19cb5ac`、source_hash `2436121ee778490c68be29128f81d3563a44627bc7ed8471d1e7fcc7ba14ede8`。父宿主核对有效租约后正式派发，完整prompt/Skills读取完成，三份实际references先view_image(original)，随后唯一image_gen.imagegen调用47.851秒。没有第二次生成、引擎、代码绘画、抠图、缩放、调色或alpha清理；WOODLAND尚未启动。

完整原返回1983×793 RGBA已原字节复制为 `assets/region_production_v3/spaces/clock_regulator_court_v1/source.png`，SHA `548f48f1d719585abeafaebb73289e079e51918bd9f0b16f8613b18c863caedd`。tool真实返回只有image_url/output_hint；原PNG与output_hint、精确工具入参、ref SHA/原字节参考和耗时已保存。model/license/cost均not_exposed；不重复巨大inline base64不等于拥有工具未暴露原始模型/用量。

## 原数值规格对照（未改阈值）

| 项 | 原冻结规格 | 实测 |
|---|---|---|
| 主体宽高 | >=2.8，约3.0 | alpha128 bbox[18,150,1949,608]，3.205592，符合 |
| world尺寸 | W760，目标H260/max270 | 完整主体等比760×237.085685，符合max270；与目标260偏差如实保留 |
| 基础 | 完整，水平包络<=840 | 下部y636..758 alpha128真实包络x18..1967，world760<=840 |
| source画布 | 宽轮廓，尺寸可变，不靠裁切拉伸 | 1983×793，未裁/拉伸；不是要求精确1536×1024的合同 |
| 根/姿态 | 完整world锚定、不镜像 | 选source根[992.5,730]，central底轮廓median730/q10..90=728..731；本任务不运行接入 |
| 主残钟 | worldx500..760 | 实图选中心[760,493]，按根650,-489算worldx559.338，落区内；源点为作者实际看图判断，非运行观测 |

实际原图是低矮完整横墙/断钟/维修残轴，不是旧大拱、第二高风车或全景背景。大形有左右高低变化、右上透明留白、完整石基础，材质继续暖白岩/冷紫灰阴影/旧铜与上左柔光。原图尺寸/形体合格只覆盖上述源预检，不能升级为实景轮廓/商业美感通过。

## 必须由独立像素与正式pilot判断的点

- 左侧短碎石壁仍偏亮，真实铃330,-572附近能否退让，需要正式合屏。源看上没有青色靶/发光盘，但灰金残钟、竖向轴槽是否像第二功能机关仍是候选风险。
- 下部连续石基含横边；作为后方遗迹不能暗示额外落点。源图“有基础”不能证明实际世界基础已正确接上。右gate/上方小台、角色/敌预告/HUD都须三窗口看。
- alpha1 bbox[0,17,1983,776]触左右底边；alpha2 bbox[14,145,1958,617]，alpha128外padding18/150/16/35。极低尾部与透明处隐藏RGB不同于游戏中有底；原图预览有红黄细边候选，红RGB alpha1/2/128/250像素4277/411/50/50。没有GPU采样证据，不自称没有halo，也不抠图救源。
- alpha128主体内无完全空竖列，未见意外全高切缝；这不等于每条裂隙与所有采样通过。完整source无可动齿轮独立件，首pilot只静态；不旋转整墙冒动画。

## 范围、验证与下一步

`family.json`完整写实际alpha/锚点/ground_line/canonical size/基础水平范围/光色/镜像与角色限制；source和family已冻结，shared spaces/manifest与游戏脚本未改。正式消费者拟PlainsSemanticLandscape，经parent/scene独立租约接线，本任务没有修改正式碰撞/相机/路线。

PIL/numpy原字节/SHA/RGBA/透明与冻结数值检查exit0，原日志和测量载于自身portable目录。独立执行现`python3 tools/check_art.py`exit0只说明既有全局manifest，不含本轮未晋级source；原Harness接下来的art-art执行由controller实际完成，不预签。质量卡G0声明仅作者已完成的生产/来源/原数值测量范围，最终stage接受必须有不同实际代理审查与controller终态；所有G2+、正式三窗口/动态/原生GPU、性能/设备/用户审美保持unverified。

独立preflight若认定光色、alpha或用途不符，保留此候选与原规格失败；本包图生预算已耗1/1，不能偷开第二图。另一个树林包不依赖本包黄金或此源最终认可。
