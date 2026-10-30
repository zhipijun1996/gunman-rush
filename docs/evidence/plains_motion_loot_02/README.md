# PLAINS-MOTION-LOOT-02 开发证据

用户确认每怪固定金额必掉，音符和回血保留原概率额外触发。本轮沿现有平原七怪与1wu画风，只打磨全身动作、伤亡音画及物品运动/实际结算。

[范围与金额候选](../../worklines/plains_motion_loot_02/scope.md)。当前分支feature/plains-motion-loot-02，前轮81ccd与主线5f557已正常合并为2ac54f9f。

开发阶段原生03实际231/0；后继04实际339/1，唯一失败是测试错误要求已dispose/queue_free的尸体仍有效，不能记PASS。拆分真实host/remains弱引用释放与零孤儿声音的检查后另行实跑。旧掉落消费者原17/4保留，按新真实面额迁移后30/0，原17标签/等待预算未删；自动近距链由新App反例补验。[迁移原件](guard-migration/README.md)。

两例headless smoke01~03的功能marker虽为0失败，退出资源泄漏，均为失败；driver静态依赖环修复后smoke04完整840帧/2例、无引擎错误或泄漏。Headless不签GPU视觉或听感。所有development文件属于dirty开发源，不能追签后继冻结提交。

[资产追加证明](asset-registration/append-proof.json)保原299记录，仅追加9WAV、生命球runtime与同字节源图。生成生命球模型/许可未暴露，保持unknown；9WAV保原CC0实录来源及处理配方。

当前正常速度GPU影片、整套适用Harness、独审、听感、设备与用户G5仍待实际证据；未签艺术完成。
