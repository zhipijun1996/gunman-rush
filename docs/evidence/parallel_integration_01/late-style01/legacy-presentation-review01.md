# 历史表现测试夹具初审

当前 **UNVERIFIED**，只读源码阶段，不签compile／真实stage／原四wrapper。原四runner153条check（27/79/31/16）逐字保留，四wrapper timeout／env AST不变，旧negative／GPU／双环境及原mode枚举保留；新增presentation_scope明确历史表现非当前默认。四profile显式flag在卸画前验证，无flag／wrongflag前后仍实测Pixeldefault与invariant，不改生产正式Pixel。

当前必需待项是refused_cleanly显式bool及真实CollisionPolygon2D完整签名（points／build_mode／disabled／one_way／margin）；现阶段只签CollisionShape2D、且var_to_str(resource)+AABB不足同边界换形，建议同步margin／实际polygonShape属性。作者正在修。第一次原wrapper类型推断FAIL、后三未执行以及更早旧consumer失败均保留，不由静态原check保持改签。

没有运行Godot、修改生产或tracked文件。完成源码冻结／compile／实际首stage／四原wrapper后另补最终限定审查。
