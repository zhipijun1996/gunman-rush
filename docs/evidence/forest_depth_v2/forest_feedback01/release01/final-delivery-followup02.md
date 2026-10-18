# 公开 GUI 第二轮限定复审

结论：**限定接受20项公开 GUI 检查及技术身份；整体体验仍为 REVISE。** 本复审没有运行引擎或浏览器、修改生产源码／文档／质量记录，也没有覆盖上一份评审。

`public-forest02` 实际原报告passed，完整终态stdout与报告相同；父代理观察进程exit0。本次只读逐项核实 **20项、8个唯一case／身份、16个实际入口与组装事件，控制台errors为空**。涵盖鼠标和模拟DOM触屏的平原／森林各两图入口、暂停和恢复；两种设备下森林两图均实际组装v11、仅授予H、Boss场景／资源正确。24张对应entry／pause／resume PNG存在且有效；这不代签人工像素审美。

8个加载身份都绑定游戏源 `5a9f4bdaf846a635eb2659080d563b865758ab87`、构建 `5fd40a31c4be`、PCK90,357,852字节及完整SHA `5fd40a31c4be5282534775dc3026007f8dbbcfb964f5363c07266b52cb590de1`，与选定SUCCESS CI39160856629及原公开校验一致。

工具变化只是在原文字识别之前增加一个归一化HUD裁剪；删除该片段后与游戏提交中的整个原脚本字节／AST完全一致，原480秒预算、准确文字匹配、从实际像素计算点击、旧fallback和8个case均保留。独立ROI审查实际旧图失败／新图文字中心成功，blank／删除MENU／错误文字／仅MAP1／仅形状五种负例全部拒绝。本复审核验对应结果及源SHA，没有再执行OCR。

第一轮 `public-forest01` 的 **FAILED、11/20、原错误和原报告SHA仍保留**；旧47文件未改由独立ROI审查的before／after结果证明，本复审另外核实原报告、原失败截图SHA及47文件数量。第二轮成功不重签第一轮成功。

当前2096路径库存只有 `tools/verify_forest_browser.py` 与原电影／CI库存不同；游戏目录和project未变。原影片／CI仍绑定5a9f中的旧工具，新ROI工具不追认获得原CI覆盖。

仍未签署：GitHub原ZIP实读及digest、原包72项浏览器检查（未执行）、publisher verified（ZIP仍0字节且live_verified=false／permission_or_policy）、整张地图浏览器探索、自然奖励／跨区GUI、真人设备、摆荚地区价值、QueenH核心价值、灰盒美术、真人手感趣味听音和商业品质。

61项只读核对及原件SHA见 `final-delivery-followup02.json`。上一份 `final-delivery-review.json/md` 与第一轮失败保持不变。
