extends Node3D
## Stachelfalle im Dungeon: fährt im Takt aus und verletzt, wer darauf steht.

var t := 0.0
var spikes: Node3D
var hurt_t := 0.0
var zone := ""


func _ready() -> void:
	t = randf() * 2.7
	var plate = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(3.2, 0.08, 3.2)
	plate.mesh = bm
	var pm = StandardMaterial3D.new()
	pm.albedo_color = Color(0.3, 0.12, 0.1)
	plate.material_override = pm
	plate.position.y = 0.2
	add_child(plate)
	spikes = Node3D.new()
	add_child(spikes)
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.16
	cone.height = 1.2
	var sm = StandardMaterial3D.new()
	sm.albedo_color = Color(0.7, 0.72, 0.78)
	sm.metallic = 0.7
	sm.roughness = 0.35
	cone.material = sm
	for x in 4:
		for z in 4:
			var m = MeshInstance3D.new()
			m.mesh = cone
			m.position = Vector3(-1.2 + x * 0.8, 0.6, -1.2 + z * 0.8)
			spikes.add_child(m)


func _process(delta: float) -> void:
	if G.p.get("room", "") != zone or not G.player:
		return
	t = fmod(t + delta, 2.7)
	var up = t > 1.5
	spikes.scale.y = lerp(spikes.scale.y, 1.0 if up else 0.02, 0.35)
	hurt_t -= delta
	if up and hurt_t <= 0.0 and not G.player.dead:
		var d = G.player.global_position - global_position
		if abs(d.x) < 1.7 and abs(d.z) < 1.7:
			hurt_t = 0.9
			Audio.sfx("falle", 1.0, 0.8)
			G.player.take_damage(14.0, self)
