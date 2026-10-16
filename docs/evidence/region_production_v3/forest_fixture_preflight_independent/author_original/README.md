# F-02：真实历史fixture漏物化的最小修复

本包是**后续生产基础修复**，不改变、重签或删除已完成森林演练的真实失败/worker/租约记录，不称旧preflight当时已完善。无Godot、图片或新宿主调用。

原实际失败两段逐字节保留于[初次缺capture](actual_original_failures/test_level_design_contracts.log)、[部分物化后仍缺verification与真实review](actual_original_failures/test_level_design_contracts_after_materialization.log)。原知识引用物化不足以覆盖`test_level_design_contracts.py`动态读取的整套冻结森林证据；旧profile只有argv，preflight当时未声明这些输入。

只改现有`required_input_preflight`中literal声明输入：复用已有Git tracked列表，按目录边界展开目录成员，再交原`require`/可读性/sparse/外链/精确ordinary repair逻辑。文件系统中缺失的skip-worktree成员仍可被发现。不新增全程序依赖图，不做新glob解释器。未知或未来未tracked路径只给明确warning，不伪造存在，也不阻塞新产物创建。

`level-design-contracts`这一个check增加真实Python消费者、policy/spec、设计fixture与整个现有forest_h_slice目录前缀；不硬列115个历史文件。该check设`cacheable:false`，避免显式较窄inputs误缩旧缓存依赖而复用旧证明；全局sourceguard和其它profile/check不变。

[真实命令/源码绑定](receipt.json)记录：

- 原81个测试函数AST及其断言全部保留；新增3个真实Git/files测试，完整84项通过。
- 旧无inputs元数据在真实sparse缺capture情况下仍错误绿，是保留的反证；新元数据在实际CLI产生calls0/blocked且没有host request。
- 缺positive/verification/真实review均定位；精确Git物化后同preflight通过。每个文件ordinary删除仍阻塞；相邻同名前缀不被误纳入；未知未tracked输入留warning。
- 第一新增测试自己的non-cone hydrate pattern不足导致失败，实际日志保留，修为正确目录后完整84通过。未修改旧断言消错。
- 当前真实`test_level_design_contracts.py`30项通过；这是既有native载体的Python消费测试，不是新Godot证明。
- docs与55项质量记录一致性通过，保留所有原failed/unverified，不认证游戏品质。

before/after源码与[source_diff.patch](source_diff.patch)绑定本小切片，最终仍须由不同作者独立审查；本包作者不自签独立PASS。
