# 分块PCK交付边界抽审

只读审查运行源 `32200d04fe233bda16cf50f678aabee51a9715e5` 的 `.github/workflows/deploy-prepared-playtest.yml` 和 `tools/style_exploration_delivery.py`；逐文件与提交一致，见 `delivery_source_fingerprints.json`。未改生产、未导出、未发布，也未重复大型浏览器检查。

**ACCEPT：当前受控prepared bundle的PCK字节重建工程路径。** workflow按github.sha单独checkout精确helper，再checkout传入prepared_ref；重建命令位于upload-pages-artifact之前，未使用continue-on-error或吞异常分支。helper只需Python标准库即可在稀疏checkout执行。

helper要求PCK basename和格式、完整SHA/build_id前缀、正整数量/1GiB界限；每chunk要求不超过512KiB、64hex SHA、唯一内容寻址URL，resolve后路径必须留在bundle。gzip输出只读取size+1以检测超长，逐块明文SHA/长度与最终累计SHA/长度吻合后才原子replace完整PCK。失败清理partial并重新抛异常；已有完整PCK也核对大小与SHA，不静默接受旧包。

本代理实际构造4个小fixture，见 `delivery_boundary_recheck.json`：正确chunk还原字节一致；chunk文件symlink指向bundle之外被拒；压缩长度正确但内容坏的gzip抛BadGzipFile；两个失败均无完整目标且partial已清。以上异常使CLI退出非0，正常GitHub步骤依赖会阻止后续上传/部署。

**非阻断观察 IR-D01**：PCK名称仅验证`index.<12hex>.pck`格式，没有同时要求名称里的12hex等于build_id。我构造全0文件名前缀但manifest/数据SHA正确的样本被接受，完整内容仍严格正确。本次实际bundle命名匹配，故不影响本次字节正确性；若以后把helper作为通用发布schema校验器，可加该跨字段一致断言并保留负例。这不是路径逃逸或错误数据可绕过SHA的发现，本次不要求重开冻结运行源。

已阅读作者 `delivery/chunk_reassembly_tests.json`，其中228真实chunk、已有整包、独立helper及6坏例均有结果；该记录明确candidate，并标早期source_commit，不能冒充本代理复跑最终公开大包。最终公开完整PCK的SHA和源身份由根任务发布证据另核。本抽审不证明任意外部manifest可信、不验完整release或目标设备性能，不代替实际浏览器加载。

## IR-D01工具加固复验

作者随后在PR工具中新增`pack_name == "index." + str(build_id) + ".pck"`的跨字段检查。独立重新加载当前helper并运行原有微型样本：正确完整包继续通过，之前全0命名样本现在在写入前抛`ValueError: Pack filename differs from build ID`。见 `delivery_hardening_recheck.json`，新helper SHA为`582a88b0438753b04d771a479aa4d13f923b4387938252f09428773375391a43`。已读作者针对实际最终PCK的同坏例记录`delivery/helper_filename_hardening.json`，未把它冒称本代理复跑119MB。

**IR-D01已修复（PR工具范围ACCEPT）**。已部署运行PCK和源身份仍为原冻结B，没有因工具两行加固被重建或改签。旧反例和旧helper边界记录继续保留。
