# 森林探索原型公开试玩交付

2026-10-22用户明确：“现在完成了什么，还有什么没有完成？远端到试玩网站了吗？我都是通过试玩网站试玩的”。[原话与范围](user-request.json)仅是交付方式，不签输出品质。上一轮只推源码／给本地包，确未上站；本次按既有快速发布授权复用Web07同包，不重新导出或整套CI。

[试玩入口](https://zhipijun1996.github.io/gunman-rush/?v=e361af714d54)：DEVELOPMENT DEMOS → SELECT REGION → FOREST PLACES MAP 1 / MAP 2。普通THORN_FOREST仍旧v15，新候选显式v18。若在普通森林入口，看到的不是新场所。

运行源263afd4fbdd535df6b4e80b1f4b584a05b55c7ea／build e361af714d54；prepared297bb91ba60364247c115f13500a7cd404d62001只承载原导出，唯一大PCK以原内容寻址chunks运输，原helper重构核完整SHA。发布工作流使用81e4f0ab9535c30437a60262fbe1ad65ed97fd87，不能误记为PCK source。

[Pages run39733962550](https://github.com/zhipijun1996/gunman-rush/actions/runs/39733962550)实际success；[run](deployment-run.json)／[步骤](deployment-jobs.json)／[prepared](prepared.json)／唯一[dispatch](dispatch.json)。[公开完整身份](public-identity.json)：141811380字节PCK与本地完整SHA e361af714d54c94edef2e6035eca0724392a9a08da6acb175f106f5ad3a5fe70一致，HTML/build-info同源。

[公开GUI实际报告](browser-report.json)两图×mouse／模拟DOM touch共4case／12checks通过、errors为空；实际候选组装v18、Boss/H-only、完整标题、暂停恢复及四次PCK身份一致。原CLI／原30秒截图及480秒总预算未改。原PNG、日志、workflow收据与原话在public-proof.zip及[完整成员索引](index.json)，逐成员全字节读回核SHA。

这是公开原型，不是整森林完成。ART_REWORK、完整网状多路／更大模块库／活果渡口／真人8–12和15–20分钟／真实手机／浏览器全路线／整套CI验收仍未完成；旧33超时、旧Web／browser失败与独审均保留，不被部署抵销。没合main。旧12ac原恢复是历史包，不以加旧v参数恢复。
