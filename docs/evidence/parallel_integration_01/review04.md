# PARALLEL-INTEGRATION-01 预检性能与证据恢复补审04

结论：**限定 ACCEPT**，只接受本次纯词法性能修复和有界恢复复核，**不接受原硬链接去重决策**，不签新CI／公网发布／内容品质。当前工作树两文件SHA见JSON，最终修复提交绑定待补。

两处优化仅替换POSIX路径部件前缀判定、已abspath归一化路径的relative身份派生。没有resolve，不掩盖祖先symlink；Windows保留原pathlib分支与大小写规则。字典仍仅为每次函数调用内的词法结果，每次实际file_state仍做is_symlink／stat／is_file／open和read。原107测试方法、60秒预算保持，新增祖先目录symlink后恢复、同task再fresh预检断言。

审查者独立运行原SelectedInputPreflightTests共21项，3.220秒全部通过（含新增真实祖先symlink与恢复）；独立96组POSIX根／外部同名前缀／相对／..／双斜线／空格大小写路径组合，旧新parents及relative身份全等。没有执行引擎／全套件。Windows仅源码保留／代数审查，不冒实际Windows测试。

完整CI02 ZIP SHA93e807...核实，原report确为60.040秒timeout、exit_code null、缺OK，失败保留。full39230314758状态原件为terminal cancelled，不签部署。作者单次实预检profile2.03854→0.70764秒、前后输出digest完全相同，paired记录源SHA等于当前6e113...源码；原完整profile107／128.315秒与112次预检109.609秒是带仪器开销数据，不能当原CLI或放宽阈值依据。完整原CLI结果另列，不由本专项签新CI。

证据保管发生真实失败：原硬链接把可复用输出与历史两原件连在同inode，后续写入覆盖历史字节。此次恢复不能追认该去重安全。独立核对custody ZIP全部10个清单成员size／SHA；两原始ZIP逐字节等于提交Git对象；各自member与两恢复文件逐字节相同（历史56f5...），当前／保留新raw均为b472...且与两历史文件合计四独立inode。作者1870路径全审与212mutable断开报告保留，只读验收其元数据与原件；本审没有重hash全部5GB，不声称未来任意历史目录可安全重写。

源SHA、检查范围、实际CI失败、custody原始／恢复凭据见同名JSON。新冻结提交／完整CI、公网浏览器、设备及真人体验仍待。
