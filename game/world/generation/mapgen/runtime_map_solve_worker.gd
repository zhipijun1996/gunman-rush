class_name RuntimeMapSolveWorker
extends RefCounted
## Exclusive owner of an SDK data job while running. Never accesses SceneTree,
## player, lifetime or UI. Main-thread callers receive copied progress only.
var _thread := Thread.new()
var _mutex := Mutex.new()
var _job: RefCounted
var _cancel_requested := false
var _done := false
var _started := false
var _snapshot: Dictionary = {}
var _result: Dictionary = {}
var _profile: Dictionary = {}
var _error := ""

func start(job: RefCounted) -> bool:
	if _started or job==null:return false
	_job=job
	var result:=_thread.start(_run)
	_started=result==OK
	return _started

func poll() -> Dictionary:
	_mutex.lock()
	var value:=_snapshot.duplicate(true)
	value["done"]=_done
	value["error"]=_error
	_mutex.unlock()
	return value

func finish() -> Dictionary:
	if not poll().get("done",false) or _thread.is_alive():return {}
	_join()
	return {"result":_result,"profile":_profile,"metrics":_snapshot}

func close() -> void:
	_mutex.lock();_cancel_requested=true;_mutex.unlock()
	_join()

func _join() -> void:
	if _started:
		_thread.wait_to_finish()
		_started=false

func _run() -> void:
	var calls:=0
	var total:=0.0
	var maximum:=0.0
	var started:=Time.get_ticks_usec()
	while not _job.is_done():
		_mutex.lock();var cancelled:=_cancel_requested;_mutex.unlock()
		if cancelled:_job.cancel();break
		var before:=Time.get_ticks_usec()
		var step: Dictionary=_job.advance(1)
		var elapsed:=float(Time.get_ticks_usec()-before)/1000.0
		total+=elapsed;maximum=maxf(maximum,elapsed);calls+=1
		if not step.get("ok",false):
			_mutex.lock()
			_error=str(step.get("error","SDK advance failed"))
			_mutex.unlock()
			break
		if calls%64==0:_publish(calls,total,maximum,started)
	_result=_job.result()
	_profile=_job.profile()
	_publish(calls,total,maximum,started)
	_mutex.lock();_done=true;_mutex.unlock()

func _publish(calls: int,total: float,maximum: float,started: int) -> void:
	var progress: Dictionary=_job.progress()
	_mutex.lock()
	_snapshot={"progress":progress,"advance_calls":calls,"advance_total_ms":total,"advance_max_ms":maximum,"worker_wall_ms":float(Time.get_ticks_usec()-started)/1000.0}
	_mutex.unlock()

func _notification(what: int) -> void:
	if what!=NOTIFICATION_PREDELETE:return
	_mutex.lock()
	_cancel_requested=true
	_mutex.unlock()
	if _started:
		_thread.wait_to_finish()
		_started=false
