from pathlib import Path
import hashlib,json,subprocess
R=Path('/workspace/gunman-rush-refactor');E=Path('/workspace/refactor-evidence/combat-perf-deploy-01/root-rig');paths=['game/enemies/presentation/plains_revision_pose.gd','game/enemies/presentation/plains_revision_flora.gd','tests/plains_revision_deform_equivalence_runner.gd']
before={p:(R/p).read_text() for p in paths}
for p,s in before.items():
 q=E/'original'/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_text(s)
(E/'baseline.json').write_text(json.dumps({'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'files':{p:hashlib.sha256(s.encode()).hexdigest() for p,s in before.items()}},indent=2)+'\n')
p=paths[0];s=before[p];needle='static func prepare(values: Dictionary) -> PlainsRevisionPose:'
fields='''# Root geometry is local to this prepared snapshot, never shared across poses.
# Flora fills it lazily and recomputes for a different valid body size. Vector2
# fields preserve the existing single-precision intermediate coordinates.
var root_geometry_ready := false
var root_geometry_size := Vector2.ZERO
var root_base: Vector2
var root_elbow: Vector2
var root_crown: Vector2
var root_destination: Vector2
var root_bent: Vector2
var root_hanger: Vector2
var root_moved_hanger: Vector2
var root_moved_leaf: Vector2
var root_lower_angle: float
var root_upper_angle: float
var root_crown_angle: float
var root_droop: float
var root_swing: float
var root_bell_angle: float
var root_leaf_angle: float

'''
assert s.count(needle)==1;(R/p).write_text(s.replace(needle,fields+needle))
p=paths[1];s=before[p];begin=s.index('static func _root_bell(');finish=s.index('# Two connected rigid stem bones',begin);old=s[begin:finish]
new='''static func _root_bell(point: Vector2, uv: Vector2, size: Vector2, pose: PlainsRevisionPose, weights: PlainsRevisionWeights) -> Vector2:
	_prepare_root_geometry(size, pose)
	var main_stem := weights.main_stem
	var upper_stem := weights.upper_stem
	var bell := weights.bell
	var leaf := weights.leaf
	var p := point
	if pose.dead:
		var droop := pose.root_droop
		var crown := pose.root_crown
		var destination := pose.root_destination
		var stem := _carry_stem(point,uv.y,pose)
		# The lower root remains fixed; both stem bones deliver their real
		# moving endpoint to the crown. Nothing rotates about the old arch.
		var lower_angle := pose.root_lower_angle
		var upper_angle := pose.root_upper_angle
		var crown_angle := pose.root_crown_angle
		var crown_body := destination+(point-crown).rotated(crown_angle)
		var upper_weight := weights.upper_weight
		p = stem.lerp(crown_body,upper_weight)
		# Bell orientation remains hanging under gravity while its hanger is
		# transported down. Its actual clapper/rim reaches the floor at d=.72.
		var hanger := pose.root_hanger
		var moved_hanger := pose.root_moved_hanger
		var swing := pose.root_swing
		var bell_pose := moved_hanger+(point-hanger).rotated(swing)
		# Include the copper mouth and clapper down to their actual alpha rim.
		# The live crown mask fades at y=.46 and cannot carry these lower pixels.
		var dead_bell := weights.dead_bell
		p = p.lerp(bell_pose,dead_bell)
		# Leaf attachments follow the appropriate stem segment, then their
		# blades yield independently. They no longer hold a raised canopy.
		var hinge_uv := Vector2(0.43,0.40) if uv.y<0.47 else Vector2(0.46,0.62)
		if uv.y<0.17: hinge_uv=Vector2(0.62,0.17)
		var top_left := weights.top_left
		var top_right := weights.top_right
		if top_left>0.3: hinge_uv=Vector2(0.43,0.34)
		elif top_right>0.3: hinge_uv=Vector2(0.62,0.17)
		var hinge := _pivot(hinge_uv,size)
		var moved_hinge := _carry_stem(hinge,hinge_uv.y,pose)
		if hinge_uv.y<0.32: moved_hinge=destination+(hinge-crown).rotated(crown_angle)
		var attached_angle := upper_angle if hinge_uv.y<0.55 else lower_angle
		var leaf_angle := (-0.98 if uv.x<0.46 else 0.80)*droop
		if top_left>0.3: leaf_angle=-2.1*droop
		elif top_right>0.3: leaf_angle=1.2*droop
		var leaf_pose := moved_hinge+(point-hinge).rotated(attached_angle*(1.0-droop)+leaf_angle)
		var leaf_mask := maxf(leaf,maxf(top_left,top_right))*(1.0-dead_bell)
		return p.lerp(leaf_pose,leaf_mask)

	p = _joint_at(p, pose.root_base, pose.root_lower_angle, main_stem)
	p = _joint_at(p,pose.root_elbow,pose.root_upper_angle,upper_stem)
	# Child hinges are transported by the two flexible stem segments. Bell and
	# leaf motion are then delayed about those actual carried attachments.
	p = _joint_at(p,pose.root_moved_hanger,pose.root_bell_angle,bell)
	p.y -= size.y * 0.035 * pose.load * bell
	p = _joint_at(p,pose.root_moved_leaf,(1.0 if uv.x>.5 else -1.0)*pose.root_leaf_angle,leaf)
	return p

# Same expressions and Vector2 operations as the former per-vertex calculation.
# Only size/pose terms move here; point/UV/weights remain in the single consumer.
static func _prepare_root_geometry(size: Vector2, pose: PlainsRevisionPose) -> void:
	if pose.root_geometry_ready and pose.root_geometry_size == size: return
	if pose.dead:
		var d := pose.death
		var fold := _window(0.03,0.72,d)
		var droop := _window(0.58,1.00,d)
		var root := _pivot(Vector2(0.43,0.90),size)
		var elbow := _pivot(Vector2(0.43,0.55),size)
		var crown := _pivot(Vector2(0.61,0.17),size)
		var destination := crown.lerp(_pivot(Vector2(0.55,0.58),size),fold)
		var bent := _fold_elbow(root,elbow,crown,destination)
		var lower_angle := (bent-root).angle()-(elbow-root).angle()
		var upper_angle := (destination-bent).angle()-(crown-elbow).angle()
		var crown_angle := upper_angle*(1.0-fold)
		var hanger := _pivot(Vector2(0.72,0.20),size)
		var moved_hanger := destination+(hanger-crown).rotated(crown_angle)
		var swing_progress := _window(0.72,1.00,d)
		var swing := sin(swing_progress*TAU*1.25)*(1.0-swing_progress)*0.11
		pose.root_base = root
		pose.root_elbow = elbow
		pose.root_crown = crown
		pose.root_destination = destination
		pose.root_bent = bent
		pose.root_lower_angle = lower_angle
		pose.root_upper_angle = upper_angle
		pose.root_crown_angle = crown_angle
		pose.root_droop = droop
		pose.root_hanger = hanger
		pose.root_moved_hanger = moved_hanger
		pose.root_swing = swing
	else:
		var load := pose.load
		var strike := pose.strike
		var recovery := pose.recovery
		var hurt := pose.hurt
		var breath := pose.root_stem_sin * 0.018
		var hurt_rebound := pose.root_hurt_sin * hurt * 0.17
		var quiet := pose.flora_quiet
		var live_lower_angle := breath*quiet-.19*load+.25*strike+hurt_rebound
		var live_upper_angle := .015*pose.root_upper_sin*quiet-.10*load+.19*strike+.05*recovery+hurt_rebound*.6
		var moved_elbow := _joint(_pivot(Vector2(.50,.68),size),Vector2(.50,.94),size,live_lower_angle,1.0)
		var live_hanger := _joint(_pivot(Vector2(.70,.20),size),Vector2(.50,.94),size,live_lower_angle,1.0)
		live_hanger = _joint_at(live_hanger,moved_elbow,live_upper_angle,1.0)
		var bell_lag := (.044*pose.root_bell_sin-breath*.5)*quiet
		var leaf_lag := pose.recovery_return_sin * recovery * 0.09
		var moved_leaf := _joint(_pivot(Vector2(.50,.58),size),Vector2(.50,.94),size,live_lower_angle,1.0)
		moved_leaf = _joint_at(moved_leaf,moved_elbow,live_upper_angle,1.0-_window(.45,.72,.58))
		pose.root_base = _pivot(Vector2(0.50, 0.94), size)
		pose.root_lower_angle = live_lower_angle
		pose.root_upper_angle = live_upper_angle
		pose.root_elbow = moved_elbow
		pose.root_moved_hanger = live_hanger
		pose.root_moved_leaf = moved_leaf
		pose.root_bell_angle = -.17*load+.39*strike-.07*recovery+.13*hurt+bell_lag
		pose.root_leaf_angle = .09*load-.15*strike+leaf_lag+.058*pose.root_leaf_sin*quiet
	pose.root_geometry_size = size
	pose.root_geometry_ready = true

'''
s=s[:begin]+new+s[finish:]
oldcarry='''static func _carry_stem(point:Vector2, uv_y:float, root:Vector2, elbow:Vector2, tip:Vector2, bent:Vector2, target:Vector2)->Vector2:
	var lower_angle := (bent-root).angle()-(elbow-root).angle()
	var upper_angle := (target-bent).angle()-(tip-elbow).angle()
	var lower := root+(point-root).rotated(lower_angle)
	var upper := bent+(point-elbow).rotated(upper_angle)'''
newcarry='''static func _carry_stem(point:Vector2, uv_y:float, pose:PlainsRevisionPose)->Vector2:
	var lower := pose.root_base+(point-pose.root_base).rotated(pose.root_lower_angle)
	var upper := pose.root_bent+(point-pose.root_elbow).rotated(pose.root_upper_angle)'''
assert s.count(oldcarry)==1;s=s.replace(oldcarry,newcarry);(R/p).write_text(s)
p=paths[2];s=before[p];test='''func _root_geometry_cases() -> void:
	# Reuse one prepared pose across UVs, points and changing body dimensions.
	# Compare the real public/prepared consumers to the immutable old algorithm,
	# not to the new cached fields. Returning to size A must rebuild after size B.
	var poses: Array[Dictionary] = [{}, _base_pose()]
	for progress: float in [0.0, .13, .16, .72, 1.0]:
		var value := _base_pose()
		value.merge({"dead":true, "death":progress}, true)
		poses.append(value)
	var uvs := _arbitrary_uvs()
	uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2(.43,.17), Vector2(.46,.47), Vector2(.5,.55), Vector2(.62,.34)]))
	for values: Dictionary in poses:
		var prepared := PlainsRevisionPose.prepare(values)
		for size: Vector2 in [Vector2(49.5,60), Vector2(37.125,83.5), Vector2(101,19.25), Vector2(49.5,60)]:
			var actual := PackedVector2Array()
			var direct := PackedVector2Array()
			var expected := PackedVector2Array()
			for uv: Vector2 in uvs:
				for offset: Vector2 in [Vector2.ZERO, Vector2(.127,-.219)]:
					var point := Vector2(-size.x*.5,-size.y)+uv*size+offset
					var weights := PlainsRevisionWeights.new(uv, &"root_bell")
					actual.append(PlainsRevisionFlora.deform_prepared(point,uv,size,prepared,&"root_bell",weights))
					direct.append(PlainsRevisionFlora.deform(point,uv,size,values,&"root_bell"))
					expected.append(FloraOracle.deform(point,uv,size,values,&"root_bell"))
			compared_vertices += expected.size()
			_check(actual.to_byte_array()==expected.to_byte_array(), "Root Bell reused prepared pose/different size exact oracle")
			_check(direct.to_byte_array()==expected.to_byte_array(), "Root Bell public standalone/different size exact oracle")
		# Invalid dimensions still return before preparing geometry; a later valid
		# call on this same object must remain identical to the original result.
		var point := Vector2(1.25,-2.5)
		var uv := Vector2(.43,.17)
		var weights := PlainsRevisionWeights.new(uv, &"root_bell")
		for size: Vector2 in [Vector2.ZERO, Vector2(-1,60), Vector2(INF,60), Vector2(49.5,60)]:
			var actual := PlainsRevisionFlora.deform_prepared(point,uv,size,prepared,&"root_bell",weights)
			var expected := FloraOracle.deform(point,uv,size,values,&"root_bell")
			compared_vertices += 1
			_check(PackedVector2Array([actual]).to_byte_array()==PackedVector2Array([expected]).to_byte_array(), "Root Bell warm prepared invalid-size/restore contract")

'''
assert s.count('func _run() -> void:')==1;s=s.replace('func _run() -> void:',test+'func _run() -> void:').replace('\t_oscillation_cases()\n','\t_oscillation_cases()\n\t_root_geometry_cases()\n');(R/p).write_text(s)
