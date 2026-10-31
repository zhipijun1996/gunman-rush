# 实际mirrorlist入口补齐

f57的prepare120520157762虽然安装通过，实际日志仍从Azure获取。其[真实API日志节选](observed-f57-prepare-excerpt.log)显示Get:1 file:/etc/apt/apt-mirrors.txt Mirrorlist144B，而后libcodec2/libdav1d URL仍为HTTPAzure。日志来源为run39984455176/job120520157762，节选不是完整日志；此前把安装通过称作已切源不准确。原两sources仅引用mirror+file，77e没覆盖实际mirrorlist，原报告仍保留其有限边界。

实现7ab4a1bc82be5ff86d5ec94f5784332556d54c47仅将六个目标文件列表追加这个实际观测的第三入口。原sed、套件、priority、arch、GPG、APT参数、全部预算／断言／合流均不变；去这六个路径即可逐字恢复f57两workflow。真实临时三文件用例与原五组通过；[精确Git独审](mirrorlist-7ab4-review.json)限定ACCEPT，官方Actionlint实际两文件通过。没有本机apt或原生重跑。

下一精确head须核实际Get URL为官方HTTPS，不能再把step通过当切换已生效。此处不预填新CI／main／Release成功，游戏运行源与a074Preview不变。
