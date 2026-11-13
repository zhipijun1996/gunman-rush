# pixelfx 项目适配

上游：https://github.com/patch-gg/pixelfx 。制作工具固定在 `5294518ce7c72e48b6100a744596e0acf57f2826`；更新版本须重新核对许可、导出格式与项目效果，不跟随 main 自动变化。

## 文件职责

- `tools/vfx/pixelfx.py`：创建隔离制作目录、同步项目源稿、调用上游检索／渲染／检查。
- `tools/vfx/effects/`：项目特效可编辑代码；引用上游 core 的相对路径与上游原生效果相同。
- `build/vfx/pixelfx/`：固定版本工具和参考库，可删除并重建；不进入 Godot 导出。
- `build/vfx/previews/`：逐帧图和正常速度媒体。
- 正式资源随具体消费者登记；不把整个上游库、演示人形、画廊和字体装进游戏。

## 使用

在仓库根目录运行：

```sh
python3 tools/vfx/pixelfx.py setup
python3 tools/vfx/pixelfx.py list ice
python3 tools/vfx/pixelfx.py render ice/ice-lance --sheet --no-actor
python3 tools/vfx/pixelfx.py check gunman
```

setup 首次需要 GitHub 网络与 Git；已有精确版本时无需网络。渲染、检索和检查只需 Node。工具不安装全局包，不请求 Patch 登录或发布，不写游戏状态。

上游技能的路径已适配本项目；保留找参考、确定性代码创作、逐帧与正常速度检查、不同方案比较、结束和循环校验。接入规则沿项目真实消费者，不采用默认人形、演示攻击时序或浏览器运行方式。

## 候选选择

| 用途 | 上游参考 | 改编重点 |
| --- | --- | --- |
| 枪口、命中 | projectiles/muzzle-pistol、impacts/hit-spark、impacts/bullet-impact | 分离短亮芯与长烟尾；枪口原点校准；命中方向和材质 |
| 冰弹 | ice/ice-lance、ice/ice-shatter | 分面、高光、冷雾和碎晶；去除冰块演示及延迟碎裂 |
| 共鸣 | arcane/spell-charge、holy/heal | 汇聚／取消／成功释放；移除默认人形，保持实际身体比例 |
| 落地 | impacts/heavy-landing | 脚底锚点、实际速度强度、贴地尘浪 |
| 爆炸、奇点 | explosions/small-explosion、explosions/implosion、shadow/black-hole | 不超过真实作用范围；内收与外爆有不同运动 |
| 拾取、机关 | pickups/collect-burst、pickups/key-glint、lightning/spark-arc | 真实接受与提交，必要提示保持可读 |

## 许可

代码与特效采用 MIT，版权包含 Patch、Hugo Duprez；部分 act 来自 Hollow Crown。保留 [MIT 文本](../LICENSE.pixelfx) 及 [上游 NOTICE](pixelfx-NOTICE.md)。`gallery/fonts` 不在该 MIT 范围，制作与运行资源均不迁入它。复制上游源码或实质派生资源时，在对应素材来源清单中记录路径、SHA、改编及许可。
