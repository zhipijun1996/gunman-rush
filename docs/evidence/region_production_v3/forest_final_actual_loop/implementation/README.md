# 实际短请求森林首阶段

唯一启动目标“制作荆棘森林。”经现有自动 route 提取 S2/H、单武器及森林身份，九个完整地区生产包保留 pending。本实施者复用原真实技术切片，未重写或修改游戏代码。

本次真正执行 `python3 tools/run_forest_h_slice_tests.py --output-dir build/forest_h_slice/final_actual_20261015T222434Z`；外层 shared flock、真实 Godot binary、LP/OMP=1，环境与命令见 `native_environment.json`。实际 positive 185 assertions、169 physics ticks、exit0；两真实删锚点/未授H负例各480 ticks、exit1，均被验收拒绝，完整原日志/capture/receipt/summary在 native/。三进程实际正常Controller/Router/Motor，未经位置/速度/资源注入。H仅开发初始化授予，单PulseLv1，全身体停稳与连续返回。未包含射击、敌人、动态目标、完整森林或最终美术。

本地原生证据原路径为 `build/forest_h_slice/final_actual_20261015T222434Z`，便携 native/ 是逐字节复制，原 receipt 内路径及调用不改写；质量记录 region_proof 在本活动树绑定原运行文件。后续源码改变或其他机器路径不能冒称这些 receipt 是当前实际运行，须重新执行。源码基线 b5b9be26357906333bdf53990a93935e5dbfd7e5，runtime delta 空；source inventory 780 文件，双 tracked UID SHA 前后不变。

Python实际检查：contracts30、routing16、region-context10。首次 contracts 因 sparse 历史fixture缺失3 errors，第二次因历史record的间接evidence缺失1 failure；两次原失败完整保留。随后仅从本 HEAD Git blob 精确物化历史证据闭包，第三次contracts30通过，没有降低断言或重签历史事实。预检只检测所选入口的显式inputs，不能覆盖测试内部任意record→evidence依赖，此限制真实暴露，不能称系统对任意稀疏树已完备。

原 V3-FOREST-STARTUP-01 两轮 REJECT 保留且不修改。本新任务只使用父明确重新分配的未创建名额；新原生证明不改写旧失败。G0/G1为隔离技术首阶段，G2-G5、独立审查、真人、实体设备、性能、正式森林开放/进度H授予仍未验；实施者仅 ready_for_review，不能给自己 ACCEPT。

## 真实退出缺陷（未修、未豁免）

本次 positive/两个负例日志分别报告105/99/96 ObjectDB instances、各63 resources、PagedAllocator及7 DummyTexture RID退出泄漏。原生完整动作/资源连续性断言及原有CLI成功条件通过，不代表退出生命周期/内存清理通过。没有Script/Parse错误。未更改现有runner、测试阈值或忽略这些日志；原文在native各capture.log。该缺陷交独立工程审查，不在本G0/G1技术片签完整生命周期或性能。
