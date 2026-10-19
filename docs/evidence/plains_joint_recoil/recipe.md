# 一个真实反冲挑战的联合制作实验（未准入）

任务 `PLAINS-JOINT-RECOIL-01`，分支 `feature/plains-joint-challenge`，母版本 `b5fc02706348d93da3cbd2df91eb0db6871e246e`。本轮只验证一个真实 `plains_recoil_span`，不把局部成功外推完整区域。

同一 `PlainsJointRecoilPlan.source_spec()` 先定义站面、完整岸体、转肩、根部、外接口及动作留空；原 Definition 派生站面，Assembler 安装真实岸体碰撞，ArtPlan 实例化世界空间，Composer 消费冻结源图和 UV。碰撞归 Assembler，美术不写物理。默认正式生成不开启。

两区域在看图前从 `joint-recoil-01..20` 登记集合选择：01 为首个含非教程目标的 Seed；07 为后续首个无标签非同构区域。两者目标左右的竖向路线和右向延伸亦不同，见原始 scan/local_contexts.json。目标相同不是复制两张独立测试房。

手动候选（需 Godot 工具链）：

```sh
bash tools/godot.sh --path . --script res://tools/plains_joint_recoil_preview.gd -- --seed=joint-recoil-01
bash tools/godot.sh --path . --script res://tools/plains_joint_recoil_preview.gd -- --seed=joint-recoil-07
```

局部技术合同：`python3 tools/run_plains_joint_recoil_tests.py`。这不等于路线、美术、设备或正式发布验收。

源图及失败首稿见 image_provenance.json。P1 是候选方向，尚未获得本轮实机用户认可；模型与商用许可状态 unknown。未进入正式资产池。不修改森林、Motor、武器、能力、资源、RNG 实现与保存。

运行源冻结 `3188a5a088d1fdb2989ae0a3d439b24c2a536cb0`。当前v4为可逆失败候选，不是黄金。01实际可见8案例，4529tick/75.483秒、13枪、0回退、最低HP4最终5；07只做结构/碰撞合同，未获第二艺术空间准入。93原生断言含真实JSON保存/重载；原1310分支断言与正常/镜像无枪反例通过。两次独审均REWORK，见[原始结论](independent-art-02.md)和[同条件作品](gallery.html)。冻结源新片已严格通过：`build/plains_joint_recoil/movie_v4_failed_01/gameplay.mp4`，4530实际路线tick/75.5秒，实际视频4535帧/60fps/1280×720/48k双声道；与旧4529tick PNG采样不是同一次运行。MP4 SHA256 `3772a4fa53a815f9b1d580a347c6a97f6949a666962ae85ac0f6d12d26adb461`。本地包由delivery记录给出真实状态；不冒称正式Web发布或艺术成功。

被证伪的假设：完整岸体＋共用轮廓不自动保证世界整体性。环境身份、实体母体/背接、洞室负形和支持关系仍未前置生成；当前bank_left/right只是位置。停止本家族补丁；最后绘改与同尺Atlas未接入，保留设计/失败原件。40px旧厚度是本次实验边界，不是不可变玩法契约。

下一不同制作实验应先共同设计连续草坡岩脊中的裂隙＋下层溪洞，再导出两层碰撞/完整地貌与有理由的连接。尚未实现该方法，不能作为成功Skills。只读审计已有identity确实影响挑战及支撑深度，不写成“identity完全没用”。原始运行/JSON失败/独审/源快照见records，gzip仅压缩保存原始字节，index有解压前后SHA。

[本地可玩失败候选与完整原片](delivery/README.md)已就绪；准确build/SHA/版本/原失败均保留。包启动严格通过不改变艺术REWORK。
