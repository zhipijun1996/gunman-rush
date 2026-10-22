class_name PlayerWeaponFeelProfile
extends Resource
@export_range(0,0.7) var trail_opacity := .42
@export_range(0,1) var accent_opacity := .65
@export_range(4,48) var transient_cap := 32
@export_range(0.05,0.3) var contact_seconds := .16
@export_range(9,24) var shot_attenuation := 12.0
@export_range(18,30) var sustained_attenuation := 24.0

func valid() -> bool:
	return is_finite(trail_opacity) and trail_opacity>=0 and trail_opacity<=.7 and is_finite(accent_opacity) and accent_opacity>=0 and accent_opacity<=1 and transient_cap>=4 and transient_cap<=48 and is_finite(contact_seconds) and contact_seconds>=.05 and contact_seconds<=.3 and is_finite(shot_attenuation) and shot_attenuation>=9 and shot_attenuation<=24 and is_finite(sustained_attenuation) and sustained_attenuation>=18 and sustained_attenuation<=30
