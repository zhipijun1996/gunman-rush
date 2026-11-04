class_name RuntimeMapLibraryWarmup
extends Node
## Title/Home preloads the existing verified library. Never generates a map or
## snapshots player abilities; departure projects the actual live controller.
const CACHE := preload("res://game/world/generation/mapgen/runtime_map_verified_library_cache.gd")
const PRELOADER := preload("res://addons/mapgen/preload_job.gd")
var _lock: Dictionary={}
var _job: RefCounted
var _owns := false
var _started := 0
var _execution_ms := 0.0
var _backend := "cooperative_preload"
var budget_usec:=2000
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(RuntimeMapGenerationJob.LOCK_PATH))
	if not value is Dictionary: set_process(false);return
	_lock=value
func _process(_delta: float) -> void:
	if _lock.is_empty() or CACHE.has_verified(_lock):
		if _owns: CACHE.release_warmup(_lock,self)
		_job=null;_owns=false
		set_process(false)
		return
	if not _owns:
		if not CACHE.claim_warmup(_lock,self): return
		_owns=true
		_started=Time.get_ticks_usec()
		_job=PRELOADER.create(str(_lock.module_package.path),str(_lock.module_package.sha256))
	var metrics: Dictionary={}
	# The SDK preloader uses ResourceLoader for its optional derived script.
	# Keep resource I/O on the scene thread; only the pure solver is threaded.
	var before:=Time.get_ticks_usec()
	while not _job.is_done():
		_job.advance(1)
		if Time.get_ticks_usec()-before>=budget_usec: break
	_execution_ms+=float(Time.get_ticks_usec()-before)/1000.0
	if not _job.is_done(): return
	if CACHE.publish(_lock,_job):
		metrics["backend"]=_backend
		metrics["execution_ms"]=_execution_ms
		metrics["wall_ms"]=float(Time.get_ticks_usec()-_started)/1000.0
		CACHE.record_warmup(_lock,metrics)
		print("MAPGEN_LIBRARY_WARM "+JSON.stringify({"backend":_backend,"wall_ms":metrics.wall_ms}))
	CACHE.release_warmup(_lock,self)
	_owns=false
	_job=null
	set_process(false)
func _exit_tree() -> void:
	if _owns: CACHE.release_warmup(_lock,self)
	_job=null
