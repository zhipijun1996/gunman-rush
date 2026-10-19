# 最终交付限定独审

结论：**CI与部署证据限定接受；公开 GUI 第一轮失败，整体体验仍为 REVISE。** 这是只读 API／原日志／源码绑定审查，没有运行引擎、重跑浏览器或修改生产、文档与质量记录。详细30项核对见 `final-delivery-review.json`。

实际游戏源 `5a9f4bdaf846a635eb2659080d563b865758ab87`，公开构建 `5fd40a31c4be`。试玩地址：https://zhipijun1996.github.io/gunman-rush/?v=5fd40a31c4be。

## 可接受的技术事实

选定 GitHub CI39160856629、attempt1，head为上述游戏源，终态 SUCCESS。prepare、Web、Windows、两lane、core合并、deploy与verify_public均成功；Android明确跳过。完整官方run日志实际取回1,224,395字节；逐stdout核实68个parallel和18个serial检查均唯一、顺序与原profile相同，合计86，并有原严格 same-source/fresh coverage 合并标记。这里没有把未取得的lane ZIP当作已解压复核。

该CI原 `forest-depth-region` 600秒检查与新增air suite均有实际passed日志。森林检查 Running／passed消息相隔约586.179秒，只称stdout时间间隔，不冒充内层原生精确耗时。旧本地600.135秒超时报告及其61条running前缀不改签；后续分组80技术覆盖和此次新CI通过是不同执行。

公开build-info实际为游戏源5a9f、build5fd40、PCK90,357,852字节；CI原公开校验器及本机原校验器成功。第一轮浏览器也读取到完整PCK SHA `5fd40a31c4be5282534775dc3026007f8dbbcfb964f5363c07266b52cb590de1`，五个已加载身份均匹配该source/build。公开校验验证HTML引用、PCK大小和内容哈希前缀，不等于取得GitHub原ZIP。

## 必须分开的失败与未验证项

公开 `public-forest01` 原完整检查终态 **FAILED，完成11/20检查，5个已加载身份，控制台errors为空**。四个模拟触屏入口及暂停恢复已经完成，森林两图实际layout均为v11；进入鼠标平原map1后，原MENU像素文字定位器失败。原错误为 `Actual MENU text not found in original canvas or enlarged HUD pixels`。此处不签20/20，不把它直接归为网络阻断，也不声称已证明游戏MENU本身坏了；根因仍需独立证据。

GitHub Web ZIP下载受proxy403阻断，当前artifact.zip仍0字节。API声明artifact12148549445、199,235,434字节及digest只属服务端元数据，没有独立读到该ZIP，不能签其本机字节／digest或原包72项浏览器复验。publisher原checkpoint仍waiting_ci、ci completed/success、live_verified=false、permission_or_policy；不能称publisher verified。部署成功来自该选定CI，而非把publisher状态改绿。

## 源、影片与文档绑定

2096路径的原影片runtime库存与游戏5a9f实际Git blob／模式逐项匹配，地图1快线1630帧／27.1667秒、地图2快线1860帧／31秒的成功receipt保留；长map2 growth影片原240秒timeout仍为失败。交付MP4实际SHA匹配元数据。不据两部快线片宣称完整growth或Boss全片验收。

当前新增的MENU定位工具修补明确只改 `tools/verify_forest_browser.py`；因此**当前全部2096工具／运行文件并非与原库存完全相同**。游戏目录与project逐字节仍匹配5a9f，原影片及CI绑定的是5a9f中的旧工具源。新浏览器工具的后续复验应单列，不能追认获得原CI验证，也不能覆盖第一轮失败。

提交 `c5d841fdf1596263064c74c82d79557efa3d79b1` 相对5a9f只有四个docs文件。原5a9f PR docs39160851552失败保留，同源push docs通过分列；c5的PR／push docs39162037730／39162032876均实际SUCCESS。该记录修正不等于又执行一次游戏CI。

整体质量记录保持region／in_progress。摆荚真实区域价值、QueenH核心价值、灰盒美术、真人手感趣味听音、实体设备与商业品质均未由本审查认可。若后续public-forest02通过，应另加follow-up并保留此原评审及第一轮原件。
