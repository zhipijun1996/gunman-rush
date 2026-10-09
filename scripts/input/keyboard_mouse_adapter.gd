class_name KeyboardMouseAdapter
extends Node

@export var router: InputRouter
var _held: Dictionary = {}
var _blocked_until_release: Dictionary = {}

func _ready() -> void:
	router.cancelled.connect(_cancel)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var code: Key = event.physical_keycode
		if _blocked_until_release.has(code):
			if not event.pressed:
				_blocked_until_release.erase(code)
			return
		_held[code] = event.pressed
		var left := bool(_held.get(KEY_A, false)) or bool(_held.get(KEY_LEFT, false))
		var right := bool(_held.get(KEY_D, false)) or bool(_held.get(KEY_RIGHT, false))
		router.set_move_axis(float(right) - float(left))
		if code == KEY_SPACE and event.pressed:
			router.request_action(&"jump")

func _cancel(_reason: String) -> void:
	for code: Key in _held:
		if _held[code]:
			_blocked_until_release[code] = true
	_held.clear()
