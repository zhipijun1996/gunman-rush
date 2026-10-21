# ACCEPT_SCOPED — 16-reference 玩家本体闭包

独立接受范围：新共享补充 v2（`d1b797ff…5ddcb9`）绑定16个实际参考，包括 UnderworldPlayer 直接读取的 `animation_build.json`、`run_sheet.png`、`states_sheet.png`。新增的是三个显式角色/路径及当前实际 consumer 关系，没有递归扫描框架。

三个有效内容反例已逐一独立复验：JSON实际全局anchor加1，两张PNG各改一个原本不透明像素且保持合法图像，Player脚本保持不变。production与proposed均在调用前calls=0阻断；真实controller的worker返回后保存calls=1并阻断；实际创建的paused阶段在恢复时拒绝、checkpoint原字节不变、没有第二次调用。原件恢复正例、完整prompt/source_inputs、缺角色即使刷新补充/registry SHA仍拒绝、旧v1绑定拒绝也通过。

实际证据：[validation-first/report.json](validation-first/report.json)。**77个选定Python单测 +31个独立body probes +68个原共享风格反例 +14个旧绕过反例全部通过**；48个明确审查源前后及最终SHA稳定。另36个真实cache selector的合成反例均因三个body、helper、asset新增/删除而失效；这不是实际完整cache复用测试。原132个check定义逐字段不变，10个原profile前缀原样保留，7个原snapshot/预算/恢复/视觉准入函数AST不变。

原v1补充、impact-v1、creative-v5归档与上次审查源逐字节一致；新creative-v6/impact-v2的旧新绑定SHA逐项匹配。两Bible原字节与staged原件仍一致。首次漏检报告保留：它只证实绑定/input漏检及恢复进入无关history守门，未证实fullresume成功；本次没有重签旧65+68或旧像素ACCEPT。

77个单测为32 Bible、24 routing、10 context、2既有loop、9 creative；明确排除会扫描完整源的creative inventory测试。未跑引擎、完整snapshot/inventory、112/31、owner21合成suite或完整Harness；root另持正式引擎/回归证据。无生产修改，不签实际图像/动画、整区或用户认可。
