class_name PlayerWeaponFeelPreviewV2
extends PlayerWeaponFeelPreview

func _ready() -> void:
	super._ready()
	_motion_status.text="WEAPON V2 / committed enemy hits / ion / black hole / 6s mine fuse"

func _new_weapon_audio() -> PlayerWeaponFeelAudio:
	return PlayerWeaponFeelAudioV2.new()

func _new_weapon_feel() -> PlayerWeaponFeel:
	return PlayerWeaponFeelV2.new()
