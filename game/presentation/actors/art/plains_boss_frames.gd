class_name PlainsBossFrames
extends RefCounted
## Pure frame selection. Encounter state, accepted hit age and death own time.
const SHEETS := {
	&"windkeeper_phase1_turn": "res://assets/plains_actors_142/atlases/windkeeper_phase1_turn.tres",
	&"windkeeper_phase2_turn": "res://assets/plains_actors_142/atlases/windkeeper_phase2_turn.tres",
	&"bellstrider_turn": "res://assets/plains_actors_142/atlases/bellstrider_turn.tres",
	&"bellstrider_flow": "res://assets/plains_actors_142/atlases/bellstrider_flow.tres",
	&"bellstrider_lob_flow": "res://assets/plains_actors_142/atlases/bellstrider_lob_flow.tres",
	&"bellstrider_ring_flow": "res://assets/plains_actors_142/atlases/bellstrider_ring_flow.tres",
	&"bellstrider_roll_flow": "res://assets/plains_actors_142/atlases/bellstrider_roll_flow.tres",
	&"windkeeper_phase1_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase1_flow.tres",
	&"windkeeper_phase1_gust_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase1_gust_flow.tres",
	&"windkeeper_phase1_lunge_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase1_lunge_flow.tres",
	&"windkeeper_phase1_platform_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase1_platform_flow.tres",
	&"windkeeper_phase1_seeds_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase1_seeds_flow.tres",
	&"windkeeper_phase1_stomp_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase1_stomp_flow.tres",
	&"windkeeper_phase1_sweep_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase1_sweep_flow.tres",
	&"windkeeper_phase2_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase2_flow.tres",
	&"windkeeper_phase2_gust_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase2_gust_flow.tres",
	&"windkeeper_phase2_lunge_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase2_lunge_flow.tres",
	&"windkeeper_phase2_platform_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase2_platform_flow.tres",
	&"windkeeper_phase2_seeds_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase2_seeds_flow.tres",
	&"windkeeper_phase2_stomp_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase2_stomp_flow.tres",
	&"windkeeper_phase2_sweep_flow": "res://assets/plains_actors_142/atlases/windkeeper_phase2_sweep_flow.tres",
	&"windkeeper_transition_flow": "res://assets/plains_actors_142/atlases/windkeeper_transition_flow.tres",

	&"bellstrider_motion": "res://assets/plains_actors_142/atlases/bellstrider_motion.tres",
	&"windkeeper_phase1_motion": "res://assets/plains_actors_142/atlases/windkeeper_phase1_motion.tres",
	&"windkeeper_phase2_motion": "res://assets/plains_actors_142/atlases/windkeeper_phase2_motion.tres",
	&"bellstrider": "res://assets/plains_actors_142/atlases/bellstrider.tres",
	&"bellstrider_roll": "res://assets/plains_actors_142/atlases/bellstrider_roll.tres",
	&"bellstrider_ring": "res://assets/plains_actors_142/atlases/bellstrider_ring.tres",
	&"bellstrider_lob": "res://assets/plains_actors_142/atlases/bellstrider_lob.tres",
	&"windkeeper_phase1": "res://assets/plains_actors_142/atlases/windkeeper_phase1.tres",
	&"windkeeper_phase1_stomp": "res://assets/plains_actors_142/atlases/windkeeper_phase1_stomp.tres",
	&"windkeeper_phase1_lunge": "res://assets/plains_actors_142/atlases/windkeeper_phase1_lunge.tres",
	&"windkeeper_phase1_sweep": "res://assets/plains_actors_142/atlases/windkeeper_phase1_sweep.tres",
	&"windkeeper_phase1_gust": "res://assets/plains_actors_142/atlases/windkeeper_phase1_gust.tres",
	&"windkeeper_phase1_seeds": "res://assets/plains_actors_142/atlases/windkeeper_phase1_seeds.tres",
	&"windkeeper_phase1_platform": "res://assets/plains_actors_142/atlases/windkeeper_phase1_platform.tres",
	&"windkeeper_phase2": "res://assets/plains_actors_142/atlases/windkeeper_phase2.tres",
	&"windkeeper_phase2_stomp": "res://assets/plains_actors_142/atlases/windkeeper_phase2_stomp.tres",
	&"windkeeper_phase2_lunge": "res://assets/plains_actors_142/atlases/windkeeper_phase2_lunge.tres",
	&"windkeeper_phase2_sweep": "res://assets/plains_actors_142/atlases/windkeeper_phase2_sweep.tres",
	&"windkeeper_phase2_gust": "res://assets/plains_actors_142/atlases/windkeeper_phase2_gust.tres",
	&"windkeeper_phase2_seeds": "res://assets/plains_actors_142/atlases/windkeeper_phase2_seeds.tres",
	&"windkeeper_phase2_platform": "res://assets/plains_actors_142/atlases/windkeeper_phase2_platform.tres",
	&"windkeeper_transition": "res://assets/plains_actors_142/atlases/windkeeper_transition.tres"
}

static func sample(kind: StringName, data: Dictionary, cache: Dictionary) -> Dictionary:
	var mode: StringName = data.get("mode", &"idle")
	var phase := int(data.get("phase", 1))
	var base := String(kind) if kind == &"bellstrider" else "windkeeper_phase%d" % mini(2, phase)
	var sheet := base
	var clip := &"idle"
	var age := float(data.get("state_age", 0.0))
	var duration := maxf(.001, float(data.get("state_duration", 1.0)))
	var progress := clampf(age / duration, 0.0, 1.0)
	var attack := ""
	if kind == &"bellstrider":
		if mode in [&"roll_warning", &"combo_warning", &"roll", &"combo_brake", &"combo_turn", &"phase_transition"]: attack = "roll"
		elif mode in [&"ring_warning", &"rings"]: attack = "ring"
		elif mode in [&"lob_aim", &"lob_lock", &"lob"]: attack = "lob"
		elif mode == &"neck": attack = String(data.get("recovery_from", "roll")).replace("rings", "ring")
	else:
		attack = String(mode).trim_suffix("_warning")
		if attack in ["traverse", "traverse_warning"]: attack = "lunge"
		if mode in [&"recover", &"link"]: attack = String(data.get("recovery_from", "stomp"))
	if SHEETS.has(StringName(base + "_" + attack)):
		sheet = base + "_" + attack
		clip = &"recovery" if mode in [&"recover", &"link", &"neck", &"combo_brake", &"combo_turn"] else &"anticipation" if String(mode).ends_with("warning") or mode in [&"lob_aim", &"lob_lock", &"phase_transition"] else &"attack"
		if mode == &"lob_aim": progress *= .6
		elif mode == &"lob_lock": progress = .6 + progress * .4
		elif mode == &"roll": progress = clampf(age / .32, 0.0, 1.0)
		elif mode == &"rings": progress = clampf(float(data.get("ring_strike_age", 0.0)) / .36, 0.0, 1.0)
	else:
		progress = fposmod(float(data.get("fight_age", 0.0)) / 1.0, 1.0)
		if absf(float(data.get("speed", 0.0))) > 2.0:
			clip = &"move"
			progress = fposmod(float(data.get("travel", 0.0)) / 110.0, 1.0)
	if mode == &"phase_transition" and kind == &"windkeeper" and phase == 2:
		sheet = "windkeeper_transition"
		progress = clampf(age / duration, 0.0, .99999) * 2.0
		clip = &"transition_start" if progress < 1.0 else &"transition_finish"
		progress = fposmod(progress, 1.0)
	var hit_age := float(data.get("bell_hit_age", -1.0))
	# Attack telegraphs remain readable: recoil is played between committed
	# attacks, while accepted hits during attacks retain the flash feedback.
	if hit_age >= 0.0 and hit_age < .24 and mode in [&"observe", &"approach", &"turn", &"recover", &"neck"]:
		sheet = base
		clip = &"hurt"
		progress = hit_age / .24
	if mode == &"dead":
		sheet = base
		clip = &"death"
		progress = clampf(float(data.get("death_age", 0.0)) / maxf(.1, float(data.get("death_duration", 1.8))), 0.0, 1.0)
	if clip in [&"idle", &"move"]: sheet = base + "_motion"
	elif SHEETS.has(StringName(sheet+"_flow")):
		sheet += "_flow"
		# Finish the physical settling movement, then hold the final readable
		# pose for the remainder of the combat recovery window.
		if clip==&"recovery": progress=clampf(age/minf(duration,.72),0,1)
	var facing := -1.0 if float(data.get("direction", 1)) < 0 else 1.0
	if mode in [&"turn", &"combo_turn"]:
		sheet = base + "_turn"
		clip = &"turn"
		progress = clampf(age / duration, 0, 1)
		facing = float(data.get("turn_from", data.get("direction", 1)))
	if cache.get("@family", "") != base:
		cache.clear()
		cache["@family"] = base
	if not cache.has(sheet): cache[sheet] = load(SHEETS[StringName(sheet)])
	var animation: PlainsActorAnimation = cache[sheet]
	return {"animation": animation, "sheet": sheet, "clip": clip, "progress": progress,
		"origin": Vector2(0, 65), "face": facing}

static func core_transform(frame: Dictionary) -> Transform2D:
	var animation: PlainsActorAnimation = frame.animation
	var point := PlainsBossTween.anchor(frame,animation.core_points)
	return Transform2D(0.0, frame.origin + point * Vector2(frame.face, 1.0))

static func muzzle_point(frame: Dictionary) -> Vector2:
	var animation: PlainsActorAnimation = frame.animation
	return frame.origin + PlainsBossTween.anchor(frame,animation.muzzle_points) * Vector2(frame.face, 1.0)

static func draw(canvas: Node2D, frame: Dictionary, tint := Color.WHITE) -> void:
	PlainsBossTween.draw(canvas,frame,tint)
