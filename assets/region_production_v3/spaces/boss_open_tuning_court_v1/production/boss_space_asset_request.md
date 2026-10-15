# Boss前庭/战场：原创静默调律遗址（准备规格，未图生）

真实来源：boss_space_geometry.json 是原10root×两图20份正式capture；当前 assembler/module/camera/Boss源码核对。不是凭空固定900/1280，也不代表新Boss实战已采集。两图共用1120宽 arena module，完整solid floor为local[0,600,1120,80]，其余三块20厚为one-way战斗台，不能给其补石根。module入口y582，worldoffset由真实prep+[200,-582]得到；map2 baseline floor[5620,18,1120,80]，实际额外foundation[5640,98,1100,238]。combat bounds是[5720,-332,920,350]；其他Seed随prep上下移动，按module身份定位，不按此坐标特判。

提议一个完整可复用family：原创破损双侧机械调律架/有自身基础的后壁，中心巨大天然开口。整体body1040×310world（1120floor两端留40；350combat高减40），最大370高只作为待审备选。地基完整包络宽≤1040，anchor为module local[560,603]，全体depth0/no mirror。两端低石砌基座应可信落在实际solid floor上，不能落在one-way上；uniform scale，不裁地基。左右石木铜结构各不超过约180宽，中心至少680宽留白，不画拱门上的可站横梁、台阶、门框金色交互轮廓或第二个大型钟盘/风车。不是将clock母版重复放大。

中央与近地战斗通道保持透明/低频：module localx220..900、y250..600属于主要actor/telegraph负空间；最下y600的standing line优先，建筑source可以有自己的根坡但不可跨真实可走前景制造假踏板。侧端结构可在actor后方，但不能以高饱和金环/红灯抢功能铃与危险。map1钟足兽贴地长冲刺、map2风守者包含远程弹体/上台/风区：map2风区可覆盖整个arena宽、floor-280..floor+70；两者不是同一种战斗。艺术不能把“静默中心”画满铜齿细节。

正式CameraRig在1280×720、zoom1.60时视域800×450world，非整张1120arena同时可见。镜头跟actor/真实route_focus，deadzone42/72、lookahead48、actor安全边48；不能为了展示完整资产改相机。进入先见左侧遗构→中央Boss负空间→追逐/回望再见右端。需要实战开始/冲刺极端/风区阶段/最左最右与上下台连续片，不以一帧全景宣称覆盖。真实全世界camera clamp由Manifest world_bounds上下各扩180，需随Seed读，不能用一张屏幕贴图冒独立远层。

只提1call独立task候选，原图完整透明手绘，保留真实prompt/原source/alpha实测/锚/来源许可未知项。consumer拟由PlainsSemanticLandscape读取arena模块/real static foundation，独立表现不改Boss玩法。生产前root确认预算；静态至少三观看窗+实际Boss动态审查才准入，失败只停此族。
