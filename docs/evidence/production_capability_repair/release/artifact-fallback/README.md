# 发布归档恢复通道

`publish_playtest.py --resume --artifact-zip /path/to/artifact.zip`在原run与checkpoint上恢复，不创建第二个dispatch。仍先由GitHub API验证repo/ref/SHA/run/attempt、deploy_web/verify_public成功、唯一未过期Web artifact及其run/source；本地ZIP不是这些门槛的替代。

ZIP恢复要求API提供精确SHA256 digest；本地归档全SHA一致后，安全流读唯一build-info和真实PCK，检查source、pack实际大小与全SHA前12位build_id。不会解压任意路径；拒绝非规范路径、重复成员/metadata、缺digest、错ZIP/错source/错pack。归档2GiB、PCK1GiB、4096成员、metadata64KiB均有明确界限。读取验证时间记录为local_artifact_validation，checkpoint保存归档与PCK全SHA及artifact ID。原gh download 403仍作为权限错误一次终止，只有显式输入ZIP才使用恢复通道；不接受单独metadata JSON。

真实旧V3原件：API `../old-web-artifact-api.json`、授权下载的 `/workspace/scratch/pr69-old-web-artifact.zip`。实际校验ZIP189345058B、SHA与artifact12023882984 API digest精确匹配；PCK85319244B、SHA `8c8eb15dcba39018e5361916965104eecfcf3b3533d41eaa20fc6ccd54379c21`，source为`50fb10c749871cb555f24fab84b3f539abde49fb`。工具归档验证耗时0.254秒，原件见actual-old-archive-verified.json。相同真实ZIP配错digest与错source也实际拒绝，见actual-old-archive-negatives.json。

**这只证明旧远端归档字节已验证。原run38846504655失败且未部署；旧远端build8c8eb15dcba3与旧本地42cd不是同一产物，不能借签。**

`tests.log`为13项隔离测试：保留原10项发布恢复反例，新增实际CLI 403→显式ZIP→resume成功（fake gh/local HTTP，零dispatch且download仍仅一次）、归档流读正例，以及错ZIP/digest/source、重复info、错pack大小/hash、路径穿越负例。fixtures/保存CLI原始transcript/API模拟调用/checkpoint；明确不是真实远端部署。本轮真实新版本仍需主集成者对准确新run/API artifact/ZIP执行该恢复并复核公开metadata。

独立复核：`build/production_repair/independent/publisher-archive-tests.log`实际3个新增测试（含7组坏例/真实CLI恢复）通过；`publisher-actual-old-archive.json`独立流验真实旧ZIP、API digest和PCK通过，工程scope ACCEPT。完整13项最终入口10.514秒通过。独审不签旧失败run已部署，也不签本轮新版本发布。
