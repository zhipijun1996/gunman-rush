# CI效率修复与N失败保留

N=14472bd9888d93161790d7c245d0cf5f9b77d48a实际main。Godot run39433443585的prepare、serial/parallel/core、Web、Windows、部署jobs成功；verify_public在git fetch整仓库耗尽原8分钟，Python验证未启动，整个workflow cancelled。Documentation39433443537失败：原26检查前12通过，level-design-contracts原60秒timeout60.035，后13未执行。这轮不能签完整CI或正式交付。

优化保原门槛：production_loop.snapshot每次仍全量真实SHA，改流式+最多4线程。8,715,254,451B完整对照原9.232秒/stream8.090/parallel4.469，完整dict与Git顺序相同。原107方法AST不变，新增5真实Git/FS语义测试纳入原runner，112/112通过36.716秒；原31契约文件逐字不变，原60预算内11.711秒通过（旧N本地23.101秒已通过，因此没有宣称复现远端超时）。双端21434项fresh SHA一致。Python最低3.12，file_digest兼容。

verify_public仅稀疏检出stdlib验证脚本，原8分钟、脚本、URL/build/commit和校验保持。独立真实远端N实取约928KB，fetch3.336+checkout1.763秒，文件字节等于N；独立新增5测试通过，整个workflow除4行稀疏配置外等于N。

N原生第一张24段电影通过217.066秒；第二张LP1软件渲染在原native240.030秒超时，无第二图完成证据。原AVI保留本地、完整SHA索引入ZIP。新候选仅movie模式允许最多4个渲染线程并记实际值，headless80/import保持1，90/240预算、60fps/路径/断言不动；静态独审不等于已验证实际提速。新main两部完整影片仍须实录。

新候选完整docs profile、新main全freshCI、API绑定实际CI ZIP原三消费者、公开完整PCK SHA及同源双图影片均待执行。N旧失败、U本地73通过、历史M通过各守原来源；全区美感/HUD、真人设备/FUN和用户最终认可未签。
