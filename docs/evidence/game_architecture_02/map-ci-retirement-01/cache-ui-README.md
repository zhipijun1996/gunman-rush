# 通用 cache UI 义务承接（外部候选，未 native）

范围仅 tests/chest_art_runner.gd；未写 main、未运行 Godot、未触碰 P11 frozen 包。HEAD仍C59，但root已独立应用P10 App到工作树；candidate.json逐叶SHA是读取基准，不冒称全工作树原C59。

旧义务来源：tests/forest_depth_region_trace.gd :drive_cache/_process/send_pointer 实际交互/模态/鼠标路径；tools/run_forest_depth_region.py :1532–1536 要求 duplicate前后相同、pointer顺序press/release、至少5pausedframes且支撑非空、position/motion_steps冻结。这些是通用App/输入/奖励义务；80旧地图路线、节点ID、路径求解、地图验收不迁入默认CI。

最小接入：已有 repeated_w_cache 先箱保全部原直接queued claim和W恢复断言，第二个原high箱本来已真实W打开且supported；在原清理前插入一次 cache_pointer_carryover，复用同App/箱/Player/ItemCard/UI，不新增路线、种子、场景、游戏规则/地图。新增 mandatory completion 总断言保证异常提前返回无法打印成功。原52个check call sites与所有原动作/函数正文反向删除插入后精确恢复。

观测/动作：

- 五轮原 frames(1)（physics+process），真实slide floor contact collider IDs、is_on_floor、position、motion_steps固定，非标签或离线支撑预测；不注入位移/速度/HP或手动调用physics。
- 以实际选项ID定位真实ItemCard按钮，经 get_global_transform_with_canvas 取得viewport坐标；原route的同一Viewport.push_input(mouse press/release,true)协议，随后原App排队/实际领取。记录实际item_selected只一次、库存+1、箱子/ledger、原bonuscoin与解除暂停。此处没有 _select/_claim_region_chest/_claim_modal_item直接调用，首箱原断言继续保留。
- 领取后第一项操作为真实W重复交互，Controller.interact_requested实际只观察一次，避免“键被吞但没变化”假通过；8帧后modal不重开，claimed/inventory/coins/notes/health前后一致，motor步骤恢复，W阻挡/GUI焦点清除。
- 复用外层release_app/AudioTeardown，新增receipt写现有build/underworld_r3/objects/cache_ui_carryover.json；该文件是观测，不代替native marker/strict错误及mandatory完成检查。

复用取舍：现有各click函数（demo_ui contract、forest discoveries、route trace）均绑定其SceneTree/route实例与_initialize、frames/check/observations，不是可直接调用的公共utility。为一次两事件流程不实例化另一个runner/复制route driver，也不新增万能ClickService。只将现有两事件协议放在唯一新增实际consumer中；支撑只读get_slide_collision，不拷贝旧route支持IDs/manifest geometry解析。

差异边界：旧80矩阵是在连续森林路线claim后继续路线；本例是现有明确pose-only setup、真实原平原第二high箱。它承担通用UI/pause/重复claim/首操作义务，不承诺森林路线完整性。现有 formal_region(plains/thorn_forest)仍保原两区真实拒绝/claim/reload，用户允许退出的旧地图算法检查未重引。

外部 git apply --check/apply/reverse --check/reverse 及逐字逆还原通过；未native，点击坐标、当前第二箱环境、实际支持冻结仍需root真实运行，不预签成功。

唯一原wrapper：`python3 tools/run_underworld_r3_object_tests.py`。Harness underworld-world-objects outer240s，原editor90s，两个native共用150s（不是各150）。本候选不改命令/预算/profile/inputs；原inputs已包含改动测试。root运行原严格wrapper后比较新receipt与marker，旧结果原件保留。
