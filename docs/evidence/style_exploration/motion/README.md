# 六组真实移动镜头

运行源32200d04fe233bda16cf50f678aabee51a9715e5，Godot4.7.2 / software OpenGL / DISPLAY:99 / LP_NUM_THREADS=2。

真实场景实例化后没有写player/camera位置；前60渲染帧静止让左限位稳定，再按实际frame_post_draw边界生成新的移动/跳跃意图，保留Router原TTL。每段驱动480渲染帧，真实accepted jump/Motor步数/actor_epoch及camera实际screen center记在JSON；这只是正常速度移动展示，不冒称完整主路或上层通关（完整路线另有runtime_v2）。

6个原生过程均exit0，源码tools/capture_style_motion.gd，原AVI保留于build/style_exploration/motion。MP4为ffmpeg libx264 CRF24原分辨率60fps编码，去掉Dummy-driver的静音音轨；完整声音未验。ffprobe记录实际流时长/帧数；source/index原绝对执行路径保留，portable_index提供相对目录映射。

每段sequence.png为实际MP4每0.5秒一帧，共16帧；抽帧审查范围不冒充听过全音轨或实体设备操作。所有clip/source/hash/原生日志可追溯。

追加第7段为独审指出最弱静态读图seed911的Underworld森林移动样本。六主片及追加片均没有走到脚本反向条件，不能称片中已回程；真实完整往返只引用runtime_v2。固定FPS影片用于正常速度观看，不代表软件GPU或实体设备达到60fps。
