# PR141 / Codex Cloud 美术素材导入说明

当前PR引入制作Skill和接入脚本，**不能由文本提交证明二进制资产已经上传**。验证实际素材目录前不得说16区PNG/47 TileSet已进入PR。

待导入的主包名称：`godot-room-art-cloud.zip`，SHA-256应通过附件自带的 `bundle-manifest.json` 核对（zip文件本身的哈希也可在交接中记录）。该包在 ChatGPT 本轮资料库已生成，必须作为附件提供给 Codex Cloud，或由有文件访问的环境直接上传。不要假设其他会话可以访问这段对话的临时sandbox地址。

## 收到附件后的动作

1. 在目标PR分支工作树调用 `python3 tools/art/import_room_art_bundle.py /path/to/godot-room-art-cloud.zip --dry-run` 检查清单。
2. 确认不会覆盖已有文件后以 `--apply` 导入 `art/world-art-v2/` 及必要恢复工具；Skill已在本PR，不用把ZIP内旧版Skill覆盖当前规则。
3. 按包内 `ROOM-ART-START.md` 恢复本地依赖并准备独立Godot对照样例；项目主工程的Godot版本/相机/碰撞不变。
4. 与项目真正使用地形的消费者对齐，优先为正式平原一间房做材质、景深和灯光实拼。保留样例与正式内容的区分，勿直接用样例 FixedWorld 替换。
5. 运行相关最小检查并保存 **Godot 实际画面**；无显示服务时记录未完成的视觉检查。将导入后的文件/版本/哈希/许可记录到当前目录；再判断是否适合合并PR。

源图包只有在需要重烘焙时才导入：`godot-room-art-cloud-sources-terrain-backgrounds.zip` 和 `godot-room-art-cloud-sources-props-depth.zip`。来源说明和 Asouris Underworld 署名必须保留；不能重新标成CC0。

## 现有项目的权威分工

`docs/bible/visual_bible.md` 与区域 Bible 管视觉规则，`godot-recoil-level-design` 管玩法与碰撞，`godot-room-art` 管美术制作和区域外观。旧Canvas样例不是正式Godot渲染；16区新增素材与v2平原/森林背景目前为候选。
