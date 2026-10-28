# 当前冲锋怪连续性核对

任务 `ENEMY-CONTINUITY-01`；生产源 `45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`，附标准／模板的docs-only工作树修改。观察者与文档作者同为`/root`，这是self_review，独立审查仍unverified。没有重画、修复游戏或改配置，不构成before／after改善对照。

## 实际执行和观看范围

原producer `tools/capture_enemy_feedback_01_remains.py`以`--chain underworld --expect-remains`实跑，完整[报告](underworld/report.json)为passed、source_stable=true；[原始trace](underworld/after.json)1560行游戏记录、6次弹体HP提交、2次死亡。实际[影片](underworld/after.mp4)为1280×720、60fps、1568视频帧、约26.133秒，带48kHz双声道音轨。游戏frame与视频frame分别标注，不能因数量接近直接等同物理tick。

这是原两物种显式fixture：固定初始位置与地形、真实InputRouter射击和弹体、实际原AI／伤害，AirFocus关闭，镜头zoom2.5。前13秒为charger，后13秒为diver作原producer覆盖；本卡重点只审charger。不是自然探索路线、普通正式镜头或实体设备；没有改变玩家／敌人中途坐标或注入HP。

实际打开了原活体charger.png、underworld_charger.png及以下解码图：

- [全片抽帧](inspection/overview.jpg)：30个明确视频帧，覆盖两case及终态长尾。
- [第一次受伤退出](inspection/hurt-exit-a.png)：视频90–101连续帧，1×裁区。
- [第二次受伤退出](inspection/hurt-exit-b.png)：视频140–151连续帧，1×裁区。
- [移动与预警](inspection/movement.png)：标明的12帧，1×裁区。

另看了视频135的完整1280×720画面。未在播放器完整播放／实际试听音轨，不签正常速度整体流畅或听感；连续相邻帧只用于定位已能看见的局部结构问题。裁区是审查附件，原始游戏视频像素不改。

## 发现与完成标准对照

| ID／性质 | 实际观察 | 判定、最小后续与复验出口 |
| --- | --- | --- |
| CHR-VIS-01／像素事实与专业判断 | 两次H退出的视频94→95、143→144：圆厚的受伤身体立即切回较低／棱角明显的live身体；背顶装置、壳轮廓、肢体与细节分区发生离散变化。不是靠位置或bbox相等能关闭的反例 | E03／E05在本次charger正式表现链局部failed；不把它称用户审美拒绝。art-director先统一live／hurt／death身体母版，animation-vfx再处理回到当前相位的退出。新源须复看相同事件及两处进入／退出，不通过更多粒子掩盖 |
| CHR-COV-01／覆盖缺口 | charger游戏记录前780行只出现idle／telegraph／recovery，没有attack状态；本次两次非致死发生在恢复与idle附近 | E02／E04／E09完整攻击链仍unverified。不能从此fixture认定冲锋行为坏了，也不能称已验攻击动作／攻击中受伤；另取满足实际激活谓词的正式遭遇 |
| CHR-COV-02／源码事实与局部画面 | 实际Underworld live是同一charger位图加镜像／Transform；移动样本主要表现身体平移与状态压伸，未呈现父类旧绘制的独立步态 | E04完整运动表达仍待设计／正常速度评价。程序方法允许，不因「没有多张图」自动判失败；须明确步态／重量／转向目标并实看最终身体，不能拿父类代码代签 |
| CHR-COV-03／范围限制 | 原始EnemyPresentation链、自然正式遭遇、普通镜头、小屏、不同背景、慢时、连续命中叠加、攻击中受伤、当前源用户／设备未在本片完成 | 对应项目unverified，不扩展为整怪／整区完成；原历史证据保留其源 |

## 已获得的局部技术事实

charger的接受伤害事件在游戏frame59／124／182，HP为2／1／0；trace中受伤索引0–3均实际出现，terminal后remains索引4–7出现，frame212记录settled=true，最后210游戏记录保持可见稳定终态。记录有一次暂停70–84；其保持检查由原producer执行。本片只证明该fixture及表现链，不验证所有支撑／保存与正式战斗。

原native458／0、support199／0、corpse-save72／0、corpse-snapshot147／0均本轮fresh、退出0；日志在[checks](checks/)。保存72继承原strict检查，本轮不再把旧66／1当当前失败。上述原生／headless结果不代替当前正式GUI、完整美术动作、声音或用户／设备。

## 结论与下一制作范围

当前状态为「局部技术通过，身体／受伤退出失败，完整动作和正式体验未验」，不能done。先以同一物种身份统一live／H／D及脚／附件锚，关闭CHR-VIS-01；再补完整移动与冲锋攻击表达及实际攻击中受伤案例，最终回正式遭遇复验。当前请求为标准与核对，本轮不擅自扩成美术重绘或玩法重构。
