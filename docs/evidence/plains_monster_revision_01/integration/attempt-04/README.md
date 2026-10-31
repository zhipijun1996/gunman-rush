# 第四轮原适用163回归

冻结源0a51b7eca36e6749a9ada8b3aa63cfd76200ee7f，实际29通过、cloud-production-planner-tests失败，后133未执行。不是完整通过。

唯一失败是原历史inventory哈希尚未适配已独审的一换一registry职责分流。后继只在该测试明确固定新项在manifest74/plan85、只出现一次、原历史项只在legacy，并只为历史摘要逆映射这个名称；四个原摘要、原166/91/75及全部其他断言不改。原21项测试后继通过，独审另附。
