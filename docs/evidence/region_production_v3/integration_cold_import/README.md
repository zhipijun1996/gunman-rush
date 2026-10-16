# ROOT真实冷导入与专项回归

第一次整合实际失败：新PlainsLandscapeObserver尚未进入冷class cache，ParseError；run_plains_directed_space_tests现在在冻结运行输入前实际editor导入，保留原正反例。第二次原生973/0及174/1成功，但新PNG.import生成导致外层source_changed，外层失败保留。第三次全部四项fresh：directed-space-tests、root-bell-tests、art-art、docs；不是full/gameplay/性能验收。实际日志/收据原字节压缩，archive_index绑定，不改写原状态。
