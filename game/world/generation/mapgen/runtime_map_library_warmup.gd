class_name RuntimeMapLibraryWarmup
extends Node
## Web file/resource I/O stays on Main. An exclusive worker verifies and
## decodes in-memory DATA with the original SDK; no SceneTree or I/O there.
const CACHE := preload("res://game/world/generation/mapgen/runtime_map_verified_library_cache.gd")
const PRELOADER := preload("res://addons/mapgen/preload_job.gd")
class DataPreloader extends "res://addons/mapgen/preload_job.gd":
	var derived_schema:=""
	var derived_module_sha:=""
	var derived_implementation:=""
	var derived_rows:Array=[]
	var cpu_enabled:=false
	func _derived() -> Dictionary:
		_phase="cpu_ready"
		while not cpu_enabled:
			if not await consume():return {}
		_phase="derived_json"
		if derived_rows.is_empty():cache_status="missing_rebuilt";return {}
		return await _decode_derived(derived_schema,derived_module_sha,derived_implementation,derived_rows)
var _lock:Dictionary={}
var _job:RefCounted
var _worker:RuntimeMapSolveWorker
var _owns:=false
var _started:=0
var _execution_ms:=0.0
var _backend:="threaded_verified_preload"
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(RuntimeMapGenerationJob.LOCK_PATH))
	if value is Dictionary:_lock=value
	else:set_process(false)
func _process(_delta:float) -> void:
	if _lock.is_empty() or CACHE.has_verified(_lock):_release();set_process(false);return
	if not _owns:
		if not CACHE.claim_warmup(_lock,self):return
		_owns=true;_started=Time.get_ticks_usec()
		var data:=DataPreloader.new()
		data._path=str(_lock.module_package.path);data._expected=str(_lock.module_package.sha256)
		# The SDK default _derived() calls ResourceLoader. Resolve its optional
		# immutable constants here, before starting any work on the data thread.
		var path:="res://addons/mapgen/derived_library.gd"
		if ResourceLoader.exists(path):
			var derived:Script=load(path)
			data.derived_schema=derived.SCHEMA;data.derived_module_sha=derived.MODULE_SHA;data.derived_implementation=derived.IMPLEMENTATION;data.derived_rows=derived.ROWS
		_job=data
	if _worker==null:
		# Web FS calls proxy to Main. Finish SDK ZIP I/O here, then move the
		# suspended data-only gate to its exclusive worker before decoding.
		var before:=Time.get_ticks_usec()
		while not _job.is_done():
			_job.advance(1)
			if _job.phase_name()=="cpu_ready":
				(_job as DataPreloader).cpu_enabled=true
				_worker=RuntimeMapSolveWorker.new()
				if not _worker.start(_job):_worker=null;_backend="cooperative_preload"
				break
			if Time.get_ticks_usec()-before>=8000:break
		_execution_ms+=float(Time.get_ticks_usec()-before)/1000.0
	if _worker!=null:
		var state:=_worker.poll()
		if not state.get("done",false):return
		if _worker.finish().is_empty():return
		_execution_ms+=float(state.get("advance_total_ms",0))
	elif not _job.is_done():return
	if CACHE.publish(_lock,_job):
		var metrics:Dictionary={"backend":_backend,"execution_ms":_execution_ms,"wall_ms":float(Time.get_ticks_usec()-_started)/1000.0}
		CACHE.record_warmup(_lock,metrics)
		print("MAPGEN_LIBRARY_WARM "+JSON.stringify(metrics))
	_release();set_process(false)
func _release() -> void:
	if _worker!=null:_worker.close()
	if _job!=null and not _job.is_done():_job.cancel()
	_worker=null;_job=null
	if _owns:CACHE.release_warmup(_lock,self)
	_owns=false
func _exit_tree() -> void:_release()
