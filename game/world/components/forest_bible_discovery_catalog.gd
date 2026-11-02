class_name ForestBibleDiscoveryCatalog
extends RefCounted
## Optional, run-local forest evidence. Item effects remain Definition resources.
const IDS := ["voiceless_bell", "root_cache", "old_badge", "spiral_core", "unsent_letter", "branch_ring_map"]
const DEFINITIONS := {
	"voiceless_bell": {"title":"失声的引铃", "object_kind":"buried_bell_plate", "kind":"coin", "amount":10, "text":"半埋的铜铃缺了铃舌，内壁刻着林间邮路的编号。铃带夹着今天的送件单，信使还在寻找这只引铃；铃底的旧邮资尚未取用。枝间的铜环原来曾为送信人引路。", "benefit":"取用旧邮资：本局金币 +10；引铃留在原处。", "return_hint":"从高枝背侧下到宽根，由较低的根洞回到来时的树腹。"},
	"root_cache": {"title":"根脉藏匣", "object_kind":"mushroom_hut_cache", "kind":"heart", "amount":2, "text":"低窗背后的菌灯照着一只干燥木匣，匣内留有折好的绷带。盖内写着：巡林人绕下窗回来时取用，别拆上面的挂索。窗旁的树皮上刻着今天记录新芽的日期。", "benefit":"使用巡林补给：恢复当前生命 2 点，不提高上限；满血时留待回程。", "return_hint":"由另一扇窗回到树腹观察枝，再从低根入口返回营地。"},
	"old_badge": {"title":"荆冠旧徽", "object_kind":"numbered_bridge_badge", "kind":"item", "item":"forest_old_badge", "text":"断桥的编号牌上嵌着一枚旧徽，背面刻着北庭巡林队的名字。徽下放着备用的护身衬片，桥牌箭头指向低处的归路。取用衬片后，旧徽仍留在桥牌上。", "return_hint":"从奖枝后侧下降到下根，再由树腹返回北庭或营地。"},
	"spiral_core": {"title":"螺旋木芯", "object_kind":"spiral_heartwood_cache", "kind":"item", "item":"forest_spiral_core", "text":"根唇上的旧匣装着备用木芯，一圈圈纹路朝上旋转。匣盖说明将它用作枪管衬芯；从这里回望，深根的果实与来时断枝终于连成了一条路。原本嵌在树中的木芯仍与根脉相连。", "return_hint":"沿上方出口穿过异侧根洞，回到原先的主环，再选择高冠或营地。"},
	"unsent_letter": {"title":"未寄出的林间信", "object_kind":"old_mailbag", "kind":"story", "text":"旧邮袋里有封没有封口的信，纸上写着：『庆典日，早上。我把新芽画在背面了，等你从钟院回来，一起看。』信旁树皮也刻着同一个日期，没有另一天的回信。", "benefit":"读到林间来信，记下这一天的等待；信留在邮袋里。", "return_hint":"绕过菌灯小屋，从安静树洞的下口回到熟悉的根湾。"},
	"branch_ring_map": {"title":"钟院枝环图", "object_kind":"broken_crown_observatory", "kind":"story", "text":"观察台的图纸把铜环、吊铃和邮袋落点连在一起。图边写着：枝环用于运送货物，吊铃用于传讯，巡林人由低处洞口返程。脚下那些危险的空路，原本也是人们日常回家的路。", "benefit":"读懂枝环图，记下运输与巡林路线；图纸留在观察台上。", "return_hint":"从冠顶侧枝下到树腹窗口，再沿内洞的安全枝返回下层营地。"}
}

static func definition(id: String) -> Dictionary:
	return DEFINITIONS[id].duplicate(true) if DEFINITIONS.has(id) else {}

static func item(definition_id: String) -> ItemDefinition:
	var value := definition(definition_id)
	if value.get("kind") != "item": return null
	return load("res://resources/items/%s.tres" % value.item) as ItemDefinition

static func benefit_text(definition_id: String) -> String:
	var value := definition(definition_id)
	if value.get("kind") == "item":
		var equipment := item(definition_id)
		return equipment.description if equipment != null else ""
	return str(value.get("benefit", ""))

static func valid_rows(rows: Array) -> bool:
	if rows.is_empty(): return false
	var seen: Dictionary = {}
	var definitions: Dictionary = {}
	for value: Variant in rows:
		if not value is Dictionary: return false
		var row: Dictionary = value
		for key: String in ["id", "definition_id", "area_id", "support_id", "approach_route", "return_route"]:
			if not row.get(key) is String or str(row[key]).is_empty(): return false
		if seen.has(row.id) or definitions.has(row.definition_id) or not DEFINITIONS.has(row.definition_id) or row.approach_route == row.return_route: return false
		if not row.get("position") is Array or row.position.size() != 2: return false
		for number: Variant in row.position:
			if not (number is int or number is float) or not is_finite(float(number)): return false
		if row.has("return_hint") and (not row.return_hint is String or str(row.return_hint).is_empty()): return false
		seen[row.id] = true
		definitions[row.definition_id] = true
	return true
