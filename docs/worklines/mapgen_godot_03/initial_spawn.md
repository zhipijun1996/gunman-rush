# MAPGEN-INITIAL-SPAWN-01

独审在M35准入复核时发现新生成入口缺陷：生成期间controller.active=false，原PlayerController.return_to_segment会明确拒绝，宿主忽略false。5b0实际Web loaded为[0,0]；原8项和浏览器检查通过没有证明按绑定出生，原报告不改签。准确事实见[独立缺口记录](../../evidence/mapgen_godot_03/failures/initial-spawn-gap.json)。

修复单独提交231049be，只在同步初始定位调用期间临时激活controller，核原方法bool后恢复原active；期间不yield、没有Motor step，不改PlayerController/Motor或资源规则。生成仍待当前ticket提交才启用持续输入。补真实segment_returned唯一事件与身体位置==Plan.spawn断言，后续浏览器也须核loaded点[-448,846]。最终新源验证待收口，不以旧截图代签。

恢复边界独立提交8033aa15：generated adapter从/1升/2，旧错误装载实现的run-local记录拒绝恢复；上游fingerprint、map content身份与Frozen身份不变，不改永久schema。原身份runner新增4个独立oldv1构造/恢复检查，实际48/0；修正三模块入口实际56/0。最终同源集中回归和浏览器位置重验仍待收口。
