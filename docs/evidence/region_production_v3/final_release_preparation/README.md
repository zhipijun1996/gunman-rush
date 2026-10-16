# 最终发布前真实准备与失败记录

这不是最终发布通过记录。源码检查点9eef7a8，其后当前工作区尚有明确未提交改动。

- `foundry_prepare24.log`：真实build --count 24 --promote，36开发短语与18连续路线通过。
- `foundry_export_stamp.log`：真实导出依据更新。
- `foundry_refresh_diff.json`：56个文件的实际字段差异；54回放的frame数组未改变，仅依据/manifest hash刷新。
- `ci_9eef_failed.log`：GitHub run38821836985原失败step日志。Web visual-director-tests和core generated-consumers失败；该日志没有给出内层断言根因。原artifact下载403无法取得内层日志，本地重新执行定位，不删除失败或放宽标准。

精确字节和原路径见manifest.json。CI下载失败含短时签名链接的原日志留在忽略build目录，不复制到仓库。
