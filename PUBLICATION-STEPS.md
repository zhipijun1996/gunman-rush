# 固定地图主游戏试玩发布准备

状态：仅准备，未推送、未 dispatch、未上线。此目录是完整主游戏的新 Pages 根；独立 gunman-rush-previews 仓库完全未动。
三个旧主站诊断路径 audio-before、perf-04、perf-actions 将明确显示归档告示；原元数据位于各自 archived-build-info.json，原包与分块仍在不可变提交 153e8a3105fbc1fd42b89d52a4b42d934098ee06。
没有在这些归档路径放置 build-info.json，现有 prepared workflow 因而不会重建旧 PCK。

游戏源码：d643cc98f8c383a29731f701aa10fe479d296154
构建：4ea38dda9616
完整 PCK：index.4ea38dda9616.pck / 230191872 bytes / SHA-256 4ea38dda961623a684e85730f3f182737adda75056db9c3f749f23502bbe81cb
完整原导出 report、worker、引擎与许可证保持字节一致；仅运输目录不含 raw PCK，部署时由原内容寻址 chunks 重建。
本准备器验证原 export 报告、精确 HEAD、地图场景在 PCK 中、复制字节和完整 PCK SHA；这些检查不替代实际菜单/玩法/Web GUI、设备或完整 CI 验证。

## root 后续步骤（尚未执行）

先确认 publication-receipt.json 的 prepared_only 状态及展开后容量；不要把 queued workflow 当发布成功。
以下在新独立 Git 目录创建无父提交的 prepared 支线；它不合入主游戏 main。

```sh
git -C /workspace/gunman-rush/build/mapgen_main/prepared-4ea38dda9616 init --initial-branch deploy/mapgen930001-d643cc98f8c3
git -C /workspace/gunman-rush/build/mapgen_main/prepared-4ea38dda9616 add .
git -C /workspace/gunman-rush/build/mapgen_main/prepared-4ea38dda9616 commit -m 'Prepare integrated fixed-map 930001 playtest'
git -C /workspace/gunman-rush/build/mapgen_main/prepared-4ea38dda9616 remote add origin https://github.com/zhipijun1996/gunman-rush.git
git -C /workspace/gunman-rush/build/mapgen_main/prepared-4ea38dda9616 push --set-upstream origin HEAD:refs/heads/deploy/mapgen930001-d643cc98f8c3
MAPGEN_PREPARED_COMMIT=$(git -C /workspace/gunman-rush/build/mapgen_main/prepared-4ea38dda9616 rev-parse HEAD)
gh workflow run deploy-prepared-playtest.yml --repo zhipijun1996/gunman-rush --ref feature/mapgen-delivery-930001 -f prepared_ref="$MAPGEN_PREPARED_COMMIT"
```

dispatch 的 source ref 必须已推送并仍包含本次精确源码及现有 deployment helper；发布前再次核对，不合 main、不 force push。
等待实际 workflow 成功后检查公开 https://zhipijun1996.github.io/gunman-rush/build-info.json 的 source_commit/build_id；下载完整 https://zhipijun1996.github.io/gunman-rush/index.4ea38dda9616.pck，逐字节核对上面的长度与 SHA-256。
随后用实际浏览器从标题进入 Home，点击普通出发，确认地图930001、唯一玩家、奖励/暂停/回家。原生、浏览器、人工设备与完整连续通关结果分别记录。
再访问三个归档路径，确认明确归档文字、元数据与不可变 Git 链接；检查隔离预览站已有入口仍可访问。
