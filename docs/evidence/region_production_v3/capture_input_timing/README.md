# 可见采集输入运输：真实受控复现与独立审查

仅修测试运输层，原 Router、Controller、Motor、资源与策略保持不变。实际 `frame_post_draw` 边界之后创建新的原 API 请求；不刷新、重发或改写已有请求时间戳。

`owner/` 保留第一次时序安排错误而真实失败的 fixture、修正 fixture 后的三项实际运行及原冻结 SHA。`independent/` 是不同审查者独立执行的真实 111 帧观测：旧边界请求过期、新边界请求接受，以及新请求故意延迟后仍过期；观察包含事件对齐和源码守卫。完整原始来源和 SHA 见 `archive_index.json`。日志中的旧绝对路径是原始观察，不改写为便携路径。

范围 ACCEPT 仅对应测试运输层受控复现和最小实现。不是完整正式路线、全动作、正常速度电影、目标设备性能或玩家认可。旧录像没有请求年龄，不能倒推认证其失败皆为 TTL。现有旧影片和旧 cohort 不得作为新 driver 的同源对照。

独审后仅修正一处注释：观测到的是 frame_post_draw 信号边界，不能保证 MovieWriter 编码或其他订阅者已经结束。`comment_only.diff` 和 `comment_addendum.json` 绑定新 SHA；旧冻结和旧独审 SHA 原样保留，没有再次执行 Godot，没有追加原生 PASS。完整电影由父任务使用新冻结源码另行执行。
