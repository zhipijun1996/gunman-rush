# 旧港与熔火的制品来源

下文记录 v27 的关卡构图与验证。请在[冻结版本](https://github.com/zhipijun1996/gunman-rush/tree/24e5957206d3e966e7c7a9e98ce4982fb28c2a8b)复现旧房；区域像素母库和角色、机关素材继续供重做使用。

旧港以退水石柱、铜气钟和贝壳残圈标记屋顶、干街与泵房。熔火以黑曜岩牙、裂隙、石坩埚和断链架区分天然岩脊与原矿队留下的设施。房间直接引用两区的正式材质和独立 PNG，可在各自 JSON 中移动或替换部件。[区域原生图](../../world-art-v2/assets/pixel/) · [分区独立物件](../../world-art-v2/assets/pixel/v2/)

旧港守卫与热源守钟者的机体来自同一物件母库。运行下方脚本可以重建两张独立首领贴图。回潮司钟和熔脊蜕壳兽有各自的制作源。[守卫和守钟者](build_wardens.py) · [回潮司钟和蜕壳兽](../../bosses/tide_and_ember/build.py)

```bash
python art/rooms/harbor_ember/build_wardens.py
```
