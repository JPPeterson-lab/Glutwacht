class_name Actor
extends CharacterBody3D
## Gemeinsame Basis für Held, Dorfbewohner und Gegner: Modell, Animation, Drehung.

const LOOPS := ["Idle", "Idle_B", "Idle_Combat", "Running_A", "Running_B", "Walking_A", "Walking_B", "Walking_C",
	"Walking_D_Skeletons", "2H_Melee_Idle", "Blocking", "Sit_Chair_Idle", "Sit_Floor_Idle", "Lie_Idle", "Unarmed_Idle",
	"Spellcasting", "2H_Melee_Attack_Spinning", "Idle_A", "Melee_2H_Idle", "Melee_Blocking", "Melee_Unarmed_Idle",
	"Ranged_Bow_Idle", "Ranged_Bow_Aiming_Idle", "Ranged_Magic_Spellcasting", "Hammering", "Digging", "Chopping", "Pickaxing",
	"Sawing", "Working_A", "Working_B", "Working_C", "Fishing_Idle", "Push_Ups", "Sit_Ups", "Holding_A", "Sneaking"]
## Die 2.0-Figuren haben keine eigenen Animationen; sie bekommen die aus dem KayKit-Animationspaket.
const ANIM_FILES := ["General", "MovementBasic", "MovementAdvanced", "CombatMelee", "CombatRanged", "Simulation", "Tools"]
## alte Namen (Figuren 1.0, Skelette) -> Namen im Animationspaket
const ALIAS := {"Idle": "Idle_A", "Cheer": "Cheering", "2H_Melee_Idle": "Melee_2H_Idle", "Block": "Melee_Block",
	"Blocking": "Melee_Blocking", "Block_Hit": "Melee_Block_Hit", "Block_Attack": "Melee_Block_Attack",
	"Spellcast_Shoot": "Ranged_Magic_Shoot", "Spellcast_Raise": "Ranged_Magic_Raise", "Spellcast_Long": "Ranged_Magic_Spellcasting_Long",
	"Spellcasting": "Ranged_Magic_Spellcasting", "Unarmed_Idle": "Melee_Unarmed_Idle"}
static var shared_lib: AnimationLibrary = null
var gear_nodes := []

var body: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var cur := ""
var _flash: StandardMaterial3D


func setup(path: String, model_scale := 1.0, radius := 0.55, height := 2.3) -> void:
	body = G.model(path)
	body.scale = Vector3.ONE * model_scale
	add_child(body)
	anim = body.find_child("AnimationPlayer", true, false)
	skel = body.find_child("Skeleton3D", true, false)
	if anim == null:
		anim = AnimationPlayer.new()
		body.add_child(anim)
		anim.add_animation_library("", _library())
	elif anim:
		for n in LOOPS:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var shape = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = radius * model_scale
	cap.height = height * model_scale
	shape.shape = cap
	shape.position.y = cap.height / 2.0
	add_child(shape)
	_flash = StandardMaterial3D.new()
	_flash.albedo_color = Color(1, 1, 1, 0.75)
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


static func _library() -> AnimationLibrary:
	if shared_lib == null:
		shared_lib = AnimationLibrary.new()
		for f in ANIM_FILES:
			var scene = load("res://assets/anim/Rig_Medium_%s.glb" % f).instantiate()
			var ap: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
			for n in ap.get_animation_list():
				if n == "T-Pose" or shared_lib.has_animation(n):
					continue
				var a: Animation = ap.get_animation(n)
				if n in LOOPS:
					a.loop_mode = Animation.LOOP_LINEAR
				shared_lib.add_animation(n, a)
			scene.free()
	return shared_lib


func _name(n: String) -> String:
	if anim.has_animation(n):
		return n
	if ALIAS.has(n) and anim.has_animation(ALIAS[n]):
		return ALIAS[n]
	# z. B. "1H_Melee_Attack_Chop" -> "Melee_1H_Attack_Chop"
	var parts = n.split("_")
	if parts.size() > 2 and parts[1] == "Melee":
		var alt = "Melee_" + parts[0] + "_" + "_".join(parts.slice(2))
		if anim.has_animation(alt):
			return alt
	return ""


func play(n: String, speed := 1.0, force := false, blend := 0.15) -> void:
	if anim == null:
		return
	n = _name(n)
	if n == "":
		return
	if n == cur and not force and anim.is_playing():
		anim.speed_scale = speed
		return
	cur = n
	if force:
		anim.stop()
	anim.play(n, blend, speed)


func anim_length(n: String) -> float:
	if anim and _name(n) != "":
		return anim.get_animation(_name(n)).length
	return 0.8


## Gibt der Figur Waffen in die Hände: {"r": "sword_1handed", "l": "shield_round"}
func gear(set: Dictionary) -> void:
	for g in gear_nodes:
		if is_instance_valid(g):
			g.queue_free()
	gear_nodes.clear()
	for side in set:
		var a = BoneAttachment3D.new()
		a.bone_name = "handslot." + side
		skel.add_child(a)
		if set[side] == "rute":       # Angelrute aus einfachen Formen
			var rod = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.015
			cm.bottom_radius = 0.04
			cm.height = 3.2
			rod.mesh = cm
			var rm = StandardMaterial3D.new()
			rm.albedo_color = Color(0.45, 0.3, 0.18)
			rod.material_override = rm
			rod.position = Vector3(0, 1.3, 0)
			a.add_child(rod)
		else:
			var m = G.model(("%s.gltf" if "/" in set[side] else "gear/%s.gltf") % set[side])
			# Bögen richtig herum halten: Sehne zum Schützen, Bogenrücken zum Ziel
			if "bow" in set[side]:
				if set[side].begins_with("waffen/"):
					m.rotation.y = -PI / 2.0
				else:
					m.rotation.z = PI
			a.add_child(m)
		gear_nodes.append(a)


## Zeigt in den Händen nur die genannten Teile (Waffen, Schilde).
func show_only(names: Array) -> void:
	if skel == null:
		return
	for slot in ["handslot_l", "handslot_r"]:
		var s = skel.find_child(slot, false, false)
		if s:
			for c in s.get_children():
				c.visible = c.name in names


func set_part(n: String, on: bool) -> void:
	var c = body.find_child(n, true, false)
	if c:
		c.visible = on


func attach(bone: String, node: Node3D) -> void:
	var a = BoneAttachment3D.new()
	a.bone_name = bone
	skel.add_child(a)
	a.add_child(node)


func face(dir: Vector3, delta: float, rate := 12.0) -> void:
	if dir.length_squared() < 0.0001:
		return
	body.rotation.y = lerp_angle(body.rotation.y, atan2(dir.x, dir.z), clamp(delta * rate, 0.0, 1.0))


func facing() -> Vector3:
	return Vector3(sin(body.rotation.y), 0, cos(body.rotation.y))


func flash(color := Color(1, 1, 1, 0.75)) -> void:
	_flash.albedo_color = color
	for m in body.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = _flash
	await get_tree().create_timer(0.09).timeout
	if is_instance_valid(self):
		for m in body.find_children("*", "MeshInstance3D", true, false):
			m.material_overlay = m.get_meta("ov") if m.has_meta("ov") else null       # Rüstungsfarbe bleibt erhalten


func tint(color: Color) -> void:
	# dauerhafte Einfärbung (z. B. eingefroren); Color(0,0,0,0) hebt sie auf
	var mat: StandardMaterial3D = null
	if color.a > 0.0:
		mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for m in body.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = mat


func flat_dist(to: Vector3) -> float:
	return Vector2(to.x - global_position.x, to.z - global_position.z).length()


func flat_dir(to: Vector3) -> Vector3:
	var d = Vector3(to.x - global_position.x, 0, to.z - global_position.z)
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO
