# 同次实际7角色输入的无损运输包

coverage-inputs-f6.tar.gz包含13个原普通文件（两profile、两组四件、三个共享provider/source/validation），逐member SHA与原输入完全相同；完整source向量原JSON在包内，避免在PR重复展开7.5MB。archive-custody.json给全部原SHA。没有改写原profile/指纹或生产者协议。

先解包到新空目录，再按原producer调用该目录内default-profile.json或gears-profile.json；--inputs同解包目录、--zip110用本仓resources/mapgen/module-pack-1.1.0.zip，--out用不存在新目录。原已锁map-edit PR78工作树应用本工作线map-edit-producer/candidate.patch。此包/提取器只用于开发，不进入PCK。
