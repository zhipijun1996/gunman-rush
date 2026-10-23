# E2：独审三项与调用token闭环

权威版本 `5c835d58af0a0f1db8d48be1e68594818ce4bcc8`。此说明仅映射已发现的有限漏检，不扩为通用解析器或视觉验收。

- 实际工具 SHA：`4bacf26c5f9059987701e91c0f1e75d9d3f14a009db2788d247f940d6c9794be`。
- 实际测试 SHA：`bf921e14ec31baef082a6fdd0ce1650823c8e5232a465964f7ea66c07d53303f`。
- 原125测试方法AST全部逐项相同；当前152，新增27。见 `E2-source-identity.json`。最终完整原路径suite由root执行，本说明不预签通过。

| 确切漏检 | E2实现 | 真实否定条件与证据 |
| --- | --- | --- |
| Fine atlas为128×32，旧内部64×16条件跳过根／尖检查 | 内部条件与外部尺寸断言同为 `(4*tile_size,tile_size)`；legacy默认16不变，selected明确32。继续要求root>0、external>0、sum=tile_size；两段alpha各有实际非空像素。 | `test_selected_fine_hazard_root_and_tip_dimensions_required` 拒root0／external0／sum33；`test_selected_fine_hazard_empty_root_or_tip_alpha_rejected` 在真实文件读取后仅注入明确的decoded alpha损坏，分别清空尖／根区域，必须拒`hazards.selected.material_continuity`。未修改图片／hash／危险来源。 |
| `_build_slot`将建筑root换ZERO，原只看下游_place，桥未闭合 | 必须从entry.x/y建立root，且实际建筑_place调用使用当前building image/region/foot、该root、entry.building_height和原source-height／grounding参数。下游仍核真实CONTACT.origin的source-foot表达式。 | `test_home_build_slot_must_pass_actual_asset_and_root_parameters` 独立拒ZERO root、错image、错foot、固定height及root变量本身改ZERO。原12槽／四服务／三阶支撑及所有旧反例保留。 |
| Shell名字和_ready.theme存在却extends CanvasLayer，实际非Control | 实际已解析DemoUiModalShell类须声明extends Control；三个真实root仍必须构造、安装该shell，并由其_ready调用真实共享theme factory。Map保持Control.new直接赋theme。 | `test_ui_modal_shell_must_be_an_actual_control` 将同文件extends改CanvasLayer，三个modal root都必须拒绝。不是以CanvasLayer自然继承theme推断。 |
| `_unrelated_place`包含_place子串而误认为当前HomeWorld方法 | 真实完整建筑调用前增加token负向边界 `(?<![A-Za-z0-9_.])`，排除更长名字及别的对象方法。 | E2原 `test_home_build_slot_cannot_disconnect_actual_place_call` 拒`_unrelated_place`；`other._place`由独审在E2内存覆写复核，不添加新整轮要求。 |

保留的失败：前一scratch完整152在72.879秒结束为151通过／1失败，原件 `all-tests-independent-fixes.log`，失败就是 `_unrelated_place` 漏检，不追改成PASS。根E原路径同一失败由root保存。token修复后，只针对建筑桥两个方法执行过（含同类dot变体，3.346秒PASS），原件 `place-token-dot-boundary.log`；不据此签完整152通过。

冻结消息抵达前scratch测试文件曾增加同方法内dot subcase，SHA `21fd7478588326f30d8f2776c7863d17aef10566172c1cf8164dca45ff38ae84`。**该scratch测试变体没有采用，不要复制覆盖E2；最终测试以bf921上述实际原路径文件为准。** 已停止全部候选和测试写入，不再开启套件；仅此映射文件作为交接。

独审已在精确E2另行执行5个新增方法，exit0；三边界均实际拒绝，额外内存`other._place`也被`home.actual_asset_slots`拒绝，真实baseline1022/0，工具／测试before-after SHA稳定。原件 `/workspace/scratch/integration-four-20261023/independent-E2-targeted.json` 及同名`.log`；独审给出的log SHA为 `eeafe73ab770eb90ab154cfe5e708f8332376e9bea84ba2c7f7909ed33c36909`。最终完整152／10／32仍按root实际原始日志及独审报告判定，以上定向结果不替代它们。
