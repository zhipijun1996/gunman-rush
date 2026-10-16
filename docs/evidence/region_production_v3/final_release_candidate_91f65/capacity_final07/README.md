# final07：八个已授权外部模板的临时容量迁移

精确迁移Linux x86的linux_debug.x86_32/linux_release.x86_32/linux_debug.x86_64/linux_release.x86_64，以及实际Windows主debug模板windows_debug_x86_32.exe/windows_debug_x86_64.exe和web_debug.zip/web_dlink_debug.zip。没有迁移Windows console/ARM64或Web/Windows release模板；运行engine、根cache、repo源码/docs及全部证据均未动，无Godot调用、无森林内容工作。

每份实际文件在无activefd确认后逐SHA/bytes/mode/uid/gid复制至独立/tmp/gunman-v3-toolchain-capacity，再CAS原子换symlink；原逻辑路径与数据保留，未删除数据。实际释放overlay allocated537157632 bytes，完成可用1349652480 bytes（约1.257GiB）。并发free delta在回执另列，不拿回收数冒充后续当前余量。

/tmp是可重建外部工具链临时存储，不是证据存储；本包不含八模板字节。原inode/ctime/type改变，原metadata/SHA/目标和逐项恢复命令在回执。恢复脚本可复制回独立常规文件并还原mode/owner/atime/mtime，但不能恢复原inode/ctime。tmpfs副本保留至恢复或工具链重建。

最小ZIP只含完整迁移脚本、终态原回执及恢复脚本，逐成员CRC/SHA与来源前后SHA验证。progress仅重复终态operations，原件仍在ignored目录；不改旧冻结包。容量修复不签Harness、发布或游戏品质通过。
