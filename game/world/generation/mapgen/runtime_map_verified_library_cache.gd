extends RefCounted
## Process-local, source-internal verified DATA cache, never a job/result cache.
## No archive getter or reset-on-exit API: only original SDK JOB.create sees it.
## Cache access is main-thread only; background jobs own their private SDK state.
const PRELOAD_JOB := preload("res://addons/mapgen/preload_job.gd")
const ARCHIVE := preload("res://addons/mapgen/module_archive.gd")
const JOB := preload("res://addons/mapgen/generation_job.gd")
static var _libraries: Dictionary = {}
static var _receipts: Dictionary = {}
static var _warmers: Dictionary = {}

static func claim_warmup(lock: Dictionary, owner: Node) -> bool:
	if has_verified(lock) or is_warming(lock): return false
	_warmers[cache_key(lock)]=weakref(owner)
	return true

static func is_warming(lock: Dictionary) -> bool:
	var owner: WeakRef=_warmers.get(cache_key(lock))
	return owner!=null and is_instance_valid(owner.get_ref()) and not owner.get_ref().is_queued_for_deletion()

static func release_warmup(lock: Dictionary, owner: Node) -> void:
	var ref: WeakRef=_warmers.get(cache_key(lock))
	if ref!=null and ref.get_ref()==owner: _warmers.erase(cache_key(lock))

static func record_warmup(lock: Dictionary, metrics: Dictionary) -> void:
	if has_verified(lock): _receipts[cache_key(lock)]["warmup"]=metrics.duplicate(true)

static func cache_key(lock: Dictionary) -> String:
	var package: Dictionary = lock.get("module_package",{})
	var archive: Dictionary = lock.get("archive",{})
	return JSON.stringify([package.get("sha256"),package.get("version"),lock.get("implementation"),lock.get("algorithm"),lock.get("version"),archive.get("sha256"),lock.get("release_head"),lock.get("source_commit")])

static func has_verified(lock: Dictionary) -> bool:
	return _libraries.has(cache_key(lock))

static func receipt(lock: Dictionary) -> Dictionary:
	# Metadata only; no source JSON, raw bytes, archive, PreparedLibrary or JOB.
	return _receipts.get(cache_key(lock),{}).duplicate(true)

static func publish(lock: Dictionary, preloader: Variant) -> bool:
	if not preloader is PRELOAD_JOB or not preloader.is_done(): return false
	var result: Dictionary = preloader.result()
	if result.get("status")!="PASS" or not result.get("library") is ARCHIVE: return false
	var library: Variant = result.library
	var package: Dictionary = lock.get("module_package",{})
	if library.sha256!=package.get("sha256") or library.version!=package.get("version"): return false
	var key := cache_key(lock)
	if _libraries.has(key): return true
	# The SDK's PreparedLibrary has request-local state, but aliases source JSON.
	# Audited mutation sites deep-copy before changing ports/routes/content. Freeze
	# only archive DATA so an accidental source write cannot poison later jobs.
	var started := Time.get_ticks_usec()
	_freeze(library._json)
	library._files.make_read_only() # PackedByteArray values use copy-on-write.
	var frozen_ms := float(Time.get_ticks_usec()-started)/1000.0
	_receipts[key] = {"key":key,"module_sha256":library.sha256,"module_version":library.version,"sdk_version":lock.version,"checked_files":result.get("checked_files",0),"source_json_read_only":library._json.is_read_only(),"source_files_read_only":library._files.is_read_only(),"freeze_execution_ms":frozen_ms,"scope":"verified library only; process-local; each SDK job owns request/config/RNG/cancellation/result"}
	_libraries[key] = library # Publish only after complete verification and freeze.
	return true

static func create_job(lock: Dictionary, request: Dictionary, config: Dictionary) -> Variant:
	var key := cache_key(lock)
	if not _libraries.has(key): return null
	return JOB.create(request,_libraries[key],config)

static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		if value.is_read_only(): return
		for child: Variant in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		if value.is_read_only(): return
		for child: Variant in value: _freeze(child)
		value.make_read_only()

static func capacity_filter(lock: Dictionary,ids: Array,maximum_jumps: int,maximum_air_shots: int) -> Dictionary:
	var library: RefCounted=_libraries.get(cache_key(lock))
	if library==null:return {"ok":false,"ids":[],"excluded":{}}
	var catalog: Dictionary=library._view_json("catalog.json").value
	var included: Array=[];var excluded: Dictionary={}
	for entry: Dictionary in catalog.modules:
		if entry.id not in ids:continue
		var content: Dictionary=library._view_json(str(entry.compiled)).value
		# Fixture capacity is a conservative qualification floor, not a player
		# grant or a claim that a lower-capacity route has been disproven.
		var qualification: Dictionary=content.get("original_tuning_profile",{}).get("effectiveTuning",{})
		var jumps:=int(qualification.get("max_jumps",0));var shots:=int(qualification.get("max_air_shots",0))
		if maximum_jumps<jumps or maximum_air_shots<shots:excluded[str(entry.id)]={"qualified_jumps":jumps,"qualified_air_shots":shots}
		else:included.append(str(entry.id))
	return {"ok":true,"ids":included,"excluded":excluded}
