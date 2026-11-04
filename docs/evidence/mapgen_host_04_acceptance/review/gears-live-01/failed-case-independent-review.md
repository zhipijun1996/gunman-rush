# 新gears原人工流程：真实300秒失败，不补签

结论 **BLOCK / FAILED**。原112c driver、原单case300秒在WAIT3超时，实际300.489174668秒，exit1；normal source/producer afterguards未执行，served-after未完成。原报告SHA `324b08570e20141d303db03455db82fcb1c7ac04eb5d65869eda9aeb858345f3` 保持不改。后来预算外custody只能是附件，不能补回预算内PASS。历史默认209流程是另一项已获用户允许复用的历史认可，不代替本case。

独立审者 `/root/death_event_audit` 确实用7次 `functions.view_image(detail=original)` 看了7张本次原PNG。首图显示930007 conformance ferry-gears受控加载切片，玩家在入口苔藓平台，第一ferry及锯轮可见；四个运动图显示第一ferry位置改变、saw上下运动。后期第二ferry只有顶/右边缘小片，静态危带未完整视觉呈现；没有完整路线或乘坐证明。before-escape图仍是同一受控场景。最后Title图确实显示完整菜单、开始游戏高亮及seed930007/buildf547fc79，但这次Title审查未能成为预算内第三检查点。

原程序只消费ACK1 observe、ACK2 escape。我实际看Title后，在收到程序已超时通知前，按仍显示waiting3的旧report写了ACK3文件。这是审者的迟到写入，**未被已结束driver消费**；不得将passed=true字段当第三个预算内ACK。该原文件与 `late-ack-03-disclosure.json` 一并保留，未删除或伪装成及时确认。原raw的operator_visual_review只有1/2。

按原截图epoch到实际被消费ACK的时间：入口图至ACK1约41.267秒，before-escape至ACK2约119.916秒，共约161.184秒。它们包括模型/工具/真实审图及记录开销，不是纯游戏CPU。真实生成已PASS；本次终止点为WAIT3总预算耗尽，不能改称SDK求解失败或通过新增独立case修补本aggregate。

在失败前，原driver已经核到新d37原生69来源：930007输出43/55/43，原deee指纹、host6f1/mapc652及spawn474,974；新PCK实际f547fc79/218926492B，明确不同于丢失的旧512c包。真实22条同模块时钟样本跨10.5source秒/10.71749wall秒；两ferry及saw都运动。实际ESC、audio released/lifetime inactive/stage detached，清理早于Title返回日志成立。context/browser正常关闭；它们是分项事实，不能提升为整段PASS。无手机/FPS、骑乘、连续路线、整图/敌人奖励Boss或零资源泄漏认可。

持久归档 `../../gears-live-01-failed-original300.tar.gz`，5,654,558B，SHA `41157c07f1dd443551d7dc3e527ec0669a831e68fa77644e58c1e8ff0f79c97c`。本审者独立读tar全部28个regular成员，SHA/size逐项与原members.json一致；其中原report仍为324b...。7PNG亦在本目录分别gzip保存，原SHA保留于原报告。原ACK1/2/迟到3、失败与所有说明都持久保存。

Root另行授权的v2只可将人工等待移到明确分开的自动捕获＋离线7图strict join；必须保持原非人工审核断言、动作、观察量、7图、300秒和全部正常guards。新run需其自己的7张新原图实际查看，不得复用这次旧图或把本次FAILED改绿。这里尚未审签v2工具或新执行结果。
