# B演员候选动作图：VISUAL-LANGUAGE-01

实际image_gen调用3次：Hero、RootBell原版、RootBell唯一一次alpha有界返工。两张稳定B参考每次均被引用，原PNG与失败原图均保留；来源/提示/参考SHA见同目录provenance JSON。模型未暴露，许可未知。

Hero为4×3/362px方格，RootBell为3×2/512px方格；按行读取。所有regions均直接量原PNG，无像素重绘/抠图/归一化。JSON的anchor为alpha>=128包围盒水平中点/下缘测量候选，和旧RootBell atlas方法一致，不冒充骨骼或枪口校准。

单一body缩放：Hero idle帽顶至脚底40worldpx（scale=0.13745704467353953）；RootBell按旧可见高度44.205worldpx保留（scale=0.10968982630272953），仍须原bodyfoot/碰撞/Presentation实机核验。不同动作绝不逐帧归一高度。

实见缺陷：Hero RunA/C前导腿形近似，未形成完整交替步态；两图底行脚底明显上移，原始图片不满足同格固定脚底，需要所附测量pivot做有界接入验证；Hero低alpha彩色边与RootBell残余低alpha尾巴未做像素阈值清理；RootBell釉面碎纹比B母版更密，recovery与idle差异较弱。只有动作关键姿态，不是完成的原生连续动画。

Hero11身体格全为空手，第12格独立pistol；枪/手/枪口须原WeaponArm校准，禁止双枪。RootBell6格仅body，不烘焙预警环、共振波或判定；原Presentation/attack_goal/state_time继续决定预警与攻击。

**未接正式消费者，未运行Godot，未签G2/用户/设备/商业品质。**

| actor | pose | region x,y,w,h | measured anchor x,y | alpha128 height |
|---|---|---|---|---|
| hero | idle | [0, 0, 362, 362] | [180.0, 352] | 291 |
| hero | run_a | [362, 0, 362, 362] | [191.5, 353] | 285 |
| hero | run_b | [724, 0, 362, 362] | [184.0, 351] | 264 |
| hero | run_c | [1086, 0, 362, 362] | [203.5, 352] | 278 |
| hero | jump_start | [0, 362, 362, 362] | [199.0, 341] | 180 |
| hero | jump | [362, 362, 362, 362] | [209.5, 323] | 288 |
| hero | fall | [724, 362, 362, 362] | [188.0, 326] | 280 |
| hero | recoil | [1086, 362, 362, 362] | [190.0, 340] | 253 |
| hero | land | [0, 724, 362, 362] | [183.0, 295] | 220 |
| hero | hurt | [362, 724, 362, 362] | [203.0, 294] | 255 |
| hero | death | [724, 724, 362, 362] | [192.0, 294] | 110 |
| hero | weapon | [1086, 724, 362, 362] | [187.0, 228] | 87 |
| rootbell | idle | [0, 0, 512, 512] | [278.0, 478] | 403 |
| rootbell | telegraph | [512, 0, 512, 512] | [267.0, 481] | 368 |
| rootbell | attack | [1024, 0, 512, 512] | [251.5, 482] | 391 |
| rootbell | recovery | [0, 512, 512, 512] | [276.0, 408] | 370 |
| rootbell | hurt | [512, 512, 512, 512] | [277.5, 409] | 375 |
| rootbell | death | [1024, 512, 512, 512] | [251.5, 403] | 239 |
