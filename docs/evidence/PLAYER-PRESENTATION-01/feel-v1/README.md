# 高落差反馈与运动音效 Development 交付

冻结运行源 `4ed0de042db44902c6d8544d9217b617f7dc3271`，Web build `a814296a70c8`。完整工作线仍in_progress；未合main、未开自动Integration PR。交互／帧资源／消费者边界见[本次合同](../../../worklines/PLAYER-PRESENTATION-01/feel-contract-03.md)。

[真实带声对照短片，约26秒，先原表现后候选](https://raw.githubusercontent.com/zhipijun1996/gunman-rush-previews/d06c828f4bfa1b36fbb3077072959730ef98bf2a/site/deliveries/PLAYER-PRESENTATION-01/4ed0de042db44902c6d8544d9217b617f7dc3271/21175e861ba0/comparison.mp4)已匿名下载完整5833104字节并核SHA；不是只验HTTP状态或假定Pages成功。[本地原片](landing-feel-comparison.mp4)、[下载凭据](public-movie-download.json)。SHA `21175e861ba04ff868d62ae77c200c6f15e84827cc074e1421382dbb00528bd4`。

原Home正常出生，真实走／跳上两层露台，两次约192.0556wu、800wu/s安全落地。第一回自然缓冲恢复；第二回缓冲中立即合法跳跃。无位置、物理、HP、资源、授予或关卡注入。两片各788帧，780采样；14字段零差异，accepted事件除纯表现heavy标记外逐字段相等。前后Camera offset/canvas/muzzle/实际鼠标瞄准一致。每片1583检查、0错误，原始source inventory前后相同且Git干净。

专项：原Underworld607检查／583Motor帧／7状态；新增Home lifecycle668检查覆盖真实高落差、活跃pause、OFF/ON、静音准入、返回原Home、重复HOME DROP及组件单独卸载；旧平原lifecycle19检查。docs检查仍因稀疏历史evidence/archive缺失失败，未删链接。Development计划未知依赖仍保守full；用户指定的受影响完整Integration归总控，此处未执行／未代签。

独立[工程审查](engineering-review.json)限域ACCEPT；[最终运行审查](runtime-review.json)实际读完14字段轨迹、看16张原尺寸电影抽帧，限域确认HUD不晃／采样帧无明显黑边接缝／后摇可立即跳跃取消，整体仍UNVERIFIED。复用land后半接近站立，不能称新精细重落动作；新idle体量／握持／连续全速过渡仍待改进。没有听音、用户或设备验收。

独立可操作包 `build/player_presentation_01/feel-v1/player-feel-preview-a814296a70c8.zip`，166940027字节，SHA `8c23a47a97daa28fcb1fabdab9091cb65c6db2b41e02e6a4f0cb4b7d783f81cc`。实际ZIP解压后用canonical工具重建原完整PCK、逐文件核SHA；Chromium真实Space/A-D、候选开关、重启、原Home、HOME DROP返回通过；真实Space后AudioContext状态running也单独验证。包内 `python3 start_preview.py` 启动本地浏览器，无需Godot。Space跳、A/D走、S下穿平台；x约825跳上两层，走到940按S产生样板落差。

新公网Web未上线：当前包再次被共享900MiB重建容量门槛拒绝，旧入口保留。尝试用GitHub Release提供ZIP下载时上传401；随后该tag及API id均404，未留下可确认的公开发行。未修改容量／删历史／绕过守门；本地包不冒充公网试玩。上一轮tunnel阻塞未重复尝试。

[原始证据ZIP](feel-v1-evidence.zip)及[逐成员SHA索引](feel-v1-evidence-index.json)保存最终电影／trace／source inventory／浏览器截帧、实际交付驱动、导出报告、失败尝试与日志。所有成员重新读回核SHA和CRC；attempts目录包含冻结前失败，不能一概声称来自最终提交。ZIP不含166MB可玩包本体。
