# R2：拒绝已知运行消费者的离线来源伪标

原独审实际抓到两个 coherent false PASS：正常资源引用 source.png 却声明 rejected_evidence_only；正常 preload live.png 却只用 associated documentation 掩盖运行来源。原 R1 独审 REJECT、13项原 probe 结果和源码原件保留在本目录与父级，不改签旧PASS。

修复在原 diff gate 中建立有界已知消费者集合：复用现有 check_web_bundle.runtime_contract 的 semantic family/root-bell/terrain/background 实际有限闭包，再保守扫描 scripts/scenes/resources/config 和 assets 内 GDScript 的显式 res://assets 文件引用。不是从 main_scene 证明全图可达：所有生产源分支都保守纳入，可能覆盖未激活分支。已有旧 loader 的明确 source+模板使用有限目录全文件集合保守覆盖；新动态模板或缺件明确报 unresolved，而非猜测后绿灯。

已识别的 changed 运行资产仅能由整份有效运行类 record 的 source_path/runtime_paths 覆盖；非运行 record 与 associated role 均不能代替。source manifest 中的动态PNG已通过复用闭包识别；离线 guide PNG 未被运行消费者使用时仍能由正确 associated reference 绑定。任何已发现解析、缺件、权限或适配器错误都会使 diff gate 非零。没有跳过资产路径，也没有修改 exact affected_paths 要求。

新增四项实际临时Git反例测试：原两个漏洞拒绝、动态 semantic family 原图/JSON 伪标拒绝且未知 read_family 参数拒绝、合法离线PNG仍通过且缺件/未知动态模板拒绝。原37测试及全部旧方法AST原样，原CLI现41测试真实exit0。真实ROOT相对PR68的差异门槛也通过，完整原始日志保留；这不消除原R1漏洞，不签美术/游戏/用户认可。

明确边界：有限适配器与显式字符串不是任意GDScript/C#程序解析器。字符串经任意变量/外部数据构造且没有可识别 res://assets 根的加载，不在自动已知集合证明内；未来新loader必须扩展有限适配器并经独审/实机消费核对。本轮不声称覆盖所有运行路径。现有适配器文件若未集成则其 pending 仅代表不存在的可选消费者；一旦出现而其声明无法解释，runtime_contract 明确拒绝。

没有再次运行Godot，没有新worktree/图生/host或资产记录修改。源已冻结，R2独审另行执行。
