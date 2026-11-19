extends Node3D
## Geschoss (Feuerball des Helden oder Knochenzauber der Gegner).

var dir := Vector3.FORWARD
var speed := 26.0
var dmg := 10.0
var crit := false
var from_player := true
var life := 2.2
var color := Color(1.0, 0.5, 0.15)
var arrow := false


func _ready() -> void:
	if arrow:
		# Pfeil: Spitze voraus (im Modell liegt sie bei +Z), etwas größer, damit man ihn fliegen sieht
		var am = G.model("gear/arrow_bow.gltf")
		add_child(am)
		am.scale = Vector3.ONE * 1.5
		am.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP)
		return
	var m = MeshInstance3D.new()
	var s = SphereMesh.new()
	s.radius = 0.28
	s.height = 0.56
	m.mesh = s
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	m.material_override = mat
	add_child(m)
	var l = OmniLight3D.new()
	l.light_color = color
	l.light_energy = 2.5
	l.omni_range = 7.0
	add_child(l)


func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if from_player:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not e.dead and e.global_position.distance_to(global_position - Vector3(0, 1.2, 0)) < 1.4 * e.body.scale.x:
				e.take_damage(dmg, crit)
				_burst()
				return
	elif G.player and not G.player.dead and G.player.global_position.distance_to(global_position - Vector3(0, 1.2, 0)) < 1.2:
		G.player.take_damage(dmg, self)
		_burst()


func _burst() -> void:
	G.world.ring(global_position - Vector3(0, 1.0, 0), 1.6, color)
	queue_free()
