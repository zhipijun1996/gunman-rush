class_name PlayableWorldAudio
extends Node
## One score and environmental bed for the lifetime of the playable shell.
## The region comes from v27. Replacing a room does not reconstruct the voices.
const WIND := "res://assets/audio/ambience_v1/plains_a.ogg"
const BIRDS := "res://assets/audio/ambience_v1/forest_a.ogg"
const BEDS := {
	"version":"audio-ambience-v1",
	"regions":{
		"wind":{"profiles":{"A":{"bed":WIND,"gain_db":0.0}}},
		"woods":{"profiles":{"A":{"bed":BIRDS,"gain_db":0.0}}},
		"draft":{"profiles":{"A":{"bed":WIND,"gain_db":-10.0}}}
	}
}
# [exploration score, regional bed]. Full track names and source credits
# live alongside the original user-supplied audio files.
const REGION := {
	"P":[&"plains","wind"], "A":[&"plains","wind"], "Y":[&"plains","wind"],
	"I":[&"plains","wind"], "V":[&"plains","wind"], "G":[&"plains","draft"],
	"F":[&"forest","woods"], "S":[&"forest","woods"], "T":[&"forest","draft"],
	"C":[&"forest","draft"], "E":[&"forest","draft"], "K":[&"forest","draft"],
	"M":[&"forest","draft"], "N":[&"forest","draft"], "R":[&"forest","draft"],
	"Z":[&"forest","draft"],
}
const SAFE_ROOMS := ["P08","G12","G_IN01","N_IN01","R_IN01","T_IN01"]
var music := GameMusic.new()
var ambience := GameAmbience.new()
var session: OrdinaryRoomSession
var host: WorldGameHost
var exploration: StringName = &"home"
var battle: StringName = &"plains_boss"
var page: StringName = &"title"

static func mount(owner_shell: Node) -> PlayableWorldAudio:
	var audio := PlayableWorldAudio.new()
	audio.name="WorldAudio"
	owner_shell.add_child(audio)
	owner_shell.connect(&"world_started",audio._world_started)
	owner_shell.connect(&"world_closed",audio.show_title)
	owner_shell.connect(&"page_changed",audio._page_changed)
	audio._page_changed(StringName(owner_shell.get("page")))
	var existing := owner_shell.get("world") as WorldGameHost
	if is_instance_valid(existing): audio._world_started(existing)
	return audio

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(music)
	add_child(ambience)
	# User volume belongs to the Master bus; these voices retain their authored mix.
	ambience.session_volume=1.0
	if not ambience.configure(BEDS): push_error("Playable ambience beds unavailable")
	show_title()

func _world_started(world: WorldGameHost) -> void:
	if not is_instance_valid(world): return
	if host!=world:
		_detach_host()
		host=world
		host.room_changed.connect(_room_changed)
	if is_instance_valid(host.active): enter_room(host.active)

func _room_changed(_id: String) -> void:
	if is_instance_valid(host) and is_instance_valid(host.active): enter_room(host.active)

func _page_changed(next: StringName) -> void:
	page=next
	if page==&"title": show_title()

func _detach_host() -> void:
	if is_instance_valid(host) and host.room_changed.is_connected(_room_changed):
		host.room_changed.disconnect(_room_changed)
	host=null

func show_title() -> void:
	_detach_host()
	session=null
	exploration=&"home"
	music.set_menu_paused(false)
	music.request_track(exploration)
	ambience.clear()

func enter_room(room: OrdinaryRoomSession) -> void:
	if not is_instance_valid(room) or room.content_context.is_empty(): return
	var region: String=room.content_context.room.region
	if not REGION.has(region):
		push_error("Unknown playable audio region: "+region)
		return
	session=room
	var choice: Array=REGION[region]
	exploration=choice[0]
	battle=&"forest_boss" if exploration==&"forest" else &"plains_boss"
	var bed: String=choice[1]
	if room.room.room_id in SAFE_ROOMS:
		exploration=&"home"
		bed="draft" if room.room.room_id!="P08" else "wind"
	ambience.select_region(bed,"A",self,room.player)
	_update_score()

func _process(_delta: float) -> void:
	music.set_menu_paused(is_instance_valid(session) and (get_tree().paused or page not in [&"play",&""]))
	if not get_tree().paused and is_instance_valid(session): _update_score()

func _update_score() -> void:
	for fight: WorldRoomEncounter in session.encounters:
		if fight.encounter.kind in ["main_boss","optional_boss","elite"] and fight.battle_active():
			music.request_track(battle)
			return
	music.request_track(exploration)

func _exit_tree() -> void:
	_detach_host()
