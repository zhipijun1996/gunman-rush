# 最终容量收口：final05便携补充包（限定环境修复）

本补充包独立于此前冻结的 final_portable_preparation，不改写旧归档。只保存final05的15份实际审计、回执与审计/恢复脚本，逐成员CRC/SHA与来源前后SHA一致。两个progress文件仅重复终态operation，因此不重复打包，原件留在原目录。

1. 明确passed的autonomy run_zxlpc7gu只有嵌套.godot被清理：656个派生文件逐SHA/metadata/CAS后删除，回收97820672 allocated bytes。工程source/原PNG及run JSON/log/receipt前后SHA相同，重建命令在原回执。Root根缓存与当时活动spatial工程未动。
2. Root明确授权的26份旧终态encounter capture仅做逐字节一致硬链接去重：112656384 allocated bytes；13个旧run全部20066文件前后路径与SHA一致。原mtime/mode/owner及恢复脚本保留，inode/ctime/nlink和部分mtime/atime发生变化，不宣称metadata原样或原inode/ctime可恢复。活动iagykdbc不在授权集合，也未扫描处理新范围。
3. 为防overlay写满，四个明确未用的外部工具链归档逐SHA复制至独立/tmp tmpfs，再在原路径CAS原子换symlink，回收618864640 overlay allocated bytes。四个逻辑路径及内容SHA/mode/uid/gid保留；Web/Windows模板和运行引擎完全未动。目标为/tmp/gunman-v3-toolchain-capacity，是可重建工具链临时存储，**不是证据存储**；本包只收审计路径/哈希/恢复命令，不含四个归档字节。没有迁移任何证据、源码或媒体到/tmp。恢复命令可将归档独立复制回原路径，但不能恢复原inode/ctime。

final05三项实际回收allocated总829341696 bytes；并发写入下filesystem free delta另列各回执，不拿回收计数冒充当前free。工具链迁移结束实测可用855506944 bytes。最早final04的620257280 bytes去重及零旧cache删除已在旧冻结包中，本包不重复归集或改变旧回执。

本次没有调用Godot，没有修改repo源码/docs、原reports/log或任何失败原件。容量/便携打包不代表Harness/商业美术/设备/发布通过。Root后续统一复制到docs并补真实最终结果。
