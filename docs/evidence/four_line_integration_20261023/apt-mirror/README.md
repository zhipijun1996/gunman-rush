# Ubuntu依赖下载路径修复

88a08的[实际Artifact身份](failure-identity.json)及[安装原日志](media-install.log)确认：parallel通道尚未进原生检查，Azure镜像下载缓慢，原五分钟安装预算触发。serial单独仍在运行，后续状态以Actions为准，不能借此签整个游戏通过。此前8ca6同类超时亦保留。

实现77eca16a4170643301e105b25bfaed55135837f1只在两workflow的六处原apt update前，把两个原源文件中精确Azure URI改为Ubuntu官方HTTPS。原suite/components/Signed-By/GPG、APT参数、五分钟与其他预算、profile、断言和合流规则全部保留。[原备选审查](independent-review.json)与[精确Git采纳审查](adoption-77eca16-review.json)均限定ACCEPT；旧REPORT记录的是当时备选状态，不改写原件。原5组与独立8组真实临时源文件用例通过；未运行本机sudo apt。实际采纳两workflow的官方Actionlint1.7.7通过，见[收据](canonical-actionlint.json)。

下一精确head的镜像可用性、CI与main/Release仍待实际结果，不把工作区网络probe签成GitHub性能。游戏运行源和a074开发Preview一致，无需重导出；本补丁未采纳Git存在性或批处理原型。
