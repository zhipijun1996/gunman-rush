# 主标题与家园美术包

独立PNG：GUNMAN RUSH工作名字标、固定平原家园背景、3位NPC单帧图集、6件UI图集。全部由image_gen生成，保留源图不做像素处理；AtlasTexture按JSON区域读取。背景不是无缝纹理，不含独立远景层或建筑解锁变体。UI装饰保持比例，九宫格拉伸尚未验证。中文和交互热区由引擎绘制。

接入契约：docs/title_home_ui.md。可操作样板：preview/title_home.html，需HTTP打开。浏览器裁取仅为实时绘制，不产生修改后的源素材。脚底约背景y565；独立地面碰撞必须由代码定义。

NPC为候选身份/单帧，无对话动画。标题透明边缘仍需游戏缩放检查。永久经济、人物名单、解锁门槛、存档和正式Godot接入未实现。

来源：home_background.png = exec-e1b31204-97fe-433c-979b-5ada4d09abc8.png；title_logo.png = exec-fc8f9e6a-aa30-46e1-b0bb-b24d92279344.png。其他图集提示词与来源见相邻文件。
