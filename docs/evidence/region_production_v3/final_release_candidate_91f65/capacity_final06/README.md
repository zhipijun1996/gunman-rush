# final06：六个外部工具链模板的临时容量迁移

只迁移授权的android_debug.apk/android_release.apk/linux_debug.arm32/linux_debug.arm64/linux_release.arm32/linux_release.arm64；逐文件确认无activefd，完整SHA/bytes/mode/uid/gid匹配后CAS原子换symlink，原逻辑路径和数据保留。实际回收overlay allocated500285440 bytes，结束可用1266163712 bytes（约1.18GiB）；并发filesystem delta另记回执。

/tmp/gunman-v3-toolchain-capacity位于独立tmpfs，只放可重建外部工具链临时数据，不放证据。engine/Web/Windows/x86模板、根cache、repo源码/docs及全部证据均未动，未调用Godot。不宣称inode/ctime/文件类型原样；每项原metadata、SHA、symlink目标及恢复命令在回执。恢复可重建常规文件及原mode/owner/atime/mtime，但不能恢复原inode/ctime；tmpfs副本保留至恢复或重建工具链。

最小ZIP只含完整迁移脚本、终态实际回执和恢复脚本，不含六模板字节。progress仅重复终态operations，原文件仍在ignored目录。ZIP逐成员CRC/SHA及来源前后SHA已核，原portable包未改。容量修复不签游戏、Harness、发布或品质通过。
