extends Node3D
## Kleines Getier, das die Welt belebt: Hühner, Hasen, Enten, Schmetterlinge, Vögel, Glühwürmchen.
## Rein dekorativ, ohne Physik; aus einfachen Formen gebaut.

var kind := "huhn"
var home := Vector3.ZERO
var radius := 8.0
var t := 0.0
var target := Vector3.ZERO
var wait := 0.0
var color := Color.WHITE
var wing_l: Node3D
var wing_r: Node3D
var body: Node3D
var phase := 0.0


func init(k: String, pos: Vector3, r := 8.0, c := Color.WHITE) -> void:
	kind = k
	home = pos
	radius = r
	color = c
	position = pos
	target = pos


func _m(mesh: Mesh, pos: Vector3, col: Color, parent: Node = null, glow := 0.0, flat := false) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = glow
	if flat:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


func _ball(r: float, sc := Vector3.ONE) -> SphereMesh:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s


func _box(v: Vector3) -> BoxMesh:
	var b = BoxMesh.new()
	b.size = v
	return b


func _wing(col: Color, size: Vector2, side: float, parent: Node) -> Node3D:
	var pivot = Node3D.new()
	parent.add_child(pivot)
	var p = PlaneMesh.new()
	p.size = size
	_m(p, Vector3(side * size.x / 2.0, 0, 0), col, pivot, 0.0, true)
	return pivot


func _ready() -> void:
	t = randf() * 20.0
	phase = randf() * TAU
	body = Node3D.new()
	add_child(body)
	match kind:
		"huhn":
			var c = [Color(0.96, 0.95, 0.9), Color(0.72, 0.45, 0.22), Color(0.25, 0.22, 0.2)][randi() % 3]
			_m(_ball(0.3), Vector3(0, 0.38, 0), c, body).scale = Vector3(1, 0.95, 1.3)
			_m(_ball(0.17), Vector3(0, 0.72, 0.3), c, body)
			_m(_box(Vector3(0.08, 0.07, 0.16)), Vector3(0, 0.7, 0.5), Color(1.0, 0.65, 0.1), body)
			_m(_box(Vector3(0.05, 0.12, 0.16)), Vector3(0, 0.9, 0.3), Color(0.9, 0.12, 0.1), body)
			_m(_box(Vector3(0.1, 0.25, 0.1)), Vector3(0, 0.6, -0.4), c.darkened(0.15), body)
			_m(_box(Vector3(0.04, 0.2, 0.04)), Vector3(0.1, 0.1, 0), Color(1.0, 0.65, 0.1), body)
			_m(_box(Vector3(0.04, 0.2, 0.04)), Vector3(-0.1, 0.1, 0), Color(1.0, 0.65, 0.1), body)
		"hase":
			var c = [Color(0.75, 0.62, 0.48), Color(0.9, 0.88, 0.84), Color(0.5, 0.45, 0.42)][randi() % 3]
			_m(_ball(0.28), Vector3(0, 0.3, 0), c, body).scale = Vector3(1, 0.95, 1.4)
			_m(_ball(0.2), Vector3(0, 0.52, 0.34), c, body)
			_m(_box(Vector3(0.07, 0.36, 0.06)), Vector3(0.08, 0.86, 0.3), c, body)
			_m(_box(Vector3(0.07, 0.36, 0.06)), Vector3(-0.08, 0.86, 0.3), c, body)
			_m(_ball(0.1), Vector3(0, 0.36, -0.4), Color(1, 1, 1), body)
		"ente":
			_m(_ball(0.3), Vector3(0, 0.18, 0), Color(0.97, 0.97, 0.95), body).scale = Vector3(1, 0.7, 1.4)
			_m(_ball(0.16), Vector3(0, 0.5, 0.3), Color(0.15, 0.5, 0.3) if randf() < 0.5 else Color(0.97, 0.97, 0.95), body)
			_m(_box(Vector3(0.12, 0.05, 0.18)), Vector3(0, 0.47, 0.5), Color(1.0, 0.7, 0.1), body)
		"schmetterling":
			_m(_box(Vector3(0.03, 0.03, 0.2)), Vector3.ZERO, Color(0.15, 0.12, 0.1), body)
			wing_l = _wing(color, Vector2(0.26, 0.3), -1.0, body)
			wing_r = _wing(color, Vector2(0.26, 0.3), 1.0, body)
		"vogel":
			_m(_box(Vector3(0.18, 0.14, 0.6)), Vector3.ZERO, color, body)
			wing_l = _wing(color.lightened(0.15), Vector2(0.9, 0.4), -1.0, body)
			wing_r = _wing(color.lightened(0.15), Vector2(0.9, 0.4), 1.0, body)
		"gluehwurm":
			_m(_ball(0.07), Vector3.ZERO, Color(0.8, 1.0, 0.45), body, 6.0)
	if kind in ["huhn", "hase", "ente"]:
		for m in find_children("*", "MeshInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		for m in find_children("*", "MeshInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	t += delta
	var pl = G.player if (G.playing and G.player) else null
	if pl and Vector2(pl.global_position.x - home.x, pl.global_position.z - home.z).length() > 120.0:
		return
	match kind:
		"huhn", "hase":
			var sp = 1.6 if kind == "huhn" else 3.5
			if pl and kind == "hase" and pl.global_position.distance_to(global_position) < 9.0:
				# Hasen flüchten vor dem Helden
				var away = global_position - pl.global_position
				away.y = 0
				target = global_position + away.normalized() * 10.0
				sp = 10.0
				wait = 0.0
			var d = target - global_position
			d.y = 0
			if wait > 0.0:
				wait -= delta
				body.position.y = 0.0
				body.rotation.x = max(0.0, sin(t * 6.0)) * 0.5 if kind == "huhn" else 0.0   # picken
			elif d.length() < 0.4:
				wait = randf_range(1.0, 5.0)
				var a = randf() * TAU
				target = home + Vector3(sin(a), 0, cos(a)) * randf() * radius
			else:
				global_position += d.normalized() * sp * delta
				rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), delta * 8.0)
				body.rotation.x = 0.0
				body.position.y = abs(sin(t * (9.0 if kind == "hase" else 14.0))) * (0.45 if kind == "hase" else 0.08)
				if global_position.distance_to(home) > radius * 3.0:
					home = global_position
		"ente":
			var a = t * 0.18 + phase
			var p = home + Vector3(sin(a) * radius, 0, cos(a * 1.3) * radius)
			var dir = p - global_position
			global_position = p
			if dir.length() > 0.0001:
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 4.0)
			body.position.y = sin(t * 2.0) * 0.03
		"schmetterling":
			var p = home + Vector3(sin(t * 0.7 + phase) * radius, 1.2 + sin(t * 1.9 + phase) * 0.6, cos(t * 0.53 + phase * 2.0) * radius)
			var dir = p - global_position
			global_position = p
			rotation.y = atan2(dir.x, dir.z)
			var f = sin(t * 22.0) * 1.1
			wing_l.rotation.z = -f
			wing_r.rotation.z = f
		"vogel":
			var a = t * 0.22 + phase
			var p = home + Vector3(sin(a) * radius, sin(t * 0.4 + phase) * 3.0, cos(a) * radius)
			var dir = p - global_position
			global_position = p
			rotation.y = atan2(dir.x, dir.z)
			var f = sin(t * 7.0) * 0.6
			wing_l.rotation.z = -f
			wing_r.rotation.z = f
		"gluehwurm":
			visible = G.world.night
			if visible:
				global_position = home + Vector3(sin(t * 0.5 + phase) * 2.0, 1.0 + sin(t * 0.9 + phase) * 0.7, cos(t * 0.37 + phase) * 2.0)
