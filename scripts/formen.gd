class_name Formen
extends RefCounted
## Baut einfache Tiere und Wesen aus Grundformen (für Gegner und Begleiter ohne eigenes Modell).

static func _m(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, glow := 0.0, alpha := 1.0) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	mat.roughness = 0.9
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = glow
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


static func _box(v: Vector3) -> BoxMesh:
	var b = BoxMesh.new()
	b.size = v
	return b


static func _ball(r: float) -> SphereMesh:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 5
	return s


## Vierbeiner (Wolf oder Hund). Gibt die vier Beine zurück, damit sie beim Laufen schwingen können.
static func vierbeiner(parent: Node3D, fell: Color, bauch: Color, s := 1.0) -> Array:
	_m(parent, _box(Vector3(0.6, 0.6, 1.5) * s), Vector3(0, 0.95, 0) * s, fell)
	_m(parent, _box(Vector3(0.5, 0.25, 1.3) * s), Vector3(0, 0.7, 0) * s, bauch)
	_m(parent, _box(Vector3(0.55, 0.55, 0.6) * s), Vector3(0, 1.3, 0.9) * s, fell)
	_m(parent, _box(Vector3(0.3, 0.28, 0.45) * s), Vector3(0, 1.2, 1.35) * s, bauch)
	_m(parent, _box(Vector3(0.12, 0.1, 0.1) * s), Vector3(0, 1.27, 1.58) * s, Color(0.08, 0.06, 0.06))
	for x in [-0.18, 0.18]:
		_m(parent, _box(Vector3(0.14, 0.3, 0.1) * s), Vector3(x, 1.7, 0.85) * s, fell.darkened(0.2))
		_m(parent, _ball(0.05 * s), Vector3(x * 0.8, 1.4, 1.2) * s, Color(1.0, 0.85, 0.3), 2.0)
	var tail = _m(parent, _box(Vector3(0.16, 0.16, 0.7) * s), Vector3(0, 1.2, -1.0) * s, fell.darkened(0.15))
	tail.rotation.x = 0.6
	var legs = []
	for q in [[-0.22, 0.5], [0.22, 0.5], [-0.22, -0.5], [0.22, -0.5]]:
		var pivot = Node3D.new()
		pivot.position = Vector3(q[0], 0.7, q[1]) * s
		parent.add_child(pivot)
		_m(pivot, _box(Vector3(0.18, 0.7, 0.18) * s), Vector3(0, -0.35, 0) * s, fell.darkened(0.1))
		legs.append(pivot)
	return legs


## Sumpfkriecher: ein glibberiger Klumpen mit Augen.
static func sumpfwesen(parent: Node3D) -> void:
	var b = _m(parent, _ball(0.9), Vector3(0, 0.7, 0), Color(0.22, 0.38, 0.2))
	b.scale = Vector3(1.2, 0.85, 1.3)
	_m(parent, _ball(0.55), Vector3(0, 1.3, 0.5), Color(0.26, 0.44, 0.22))
	for x in [-0.25, 0.25]:
		_m(parent, _ball(0.14), Vector3(x, 1.5, 0.95), Color(0.95, 0.9, 0.3), 2.5)
	for i in 5:
		_m(parent, _ball(0.22), Vector3(sin(i * 1.3) * 0.9, 0.5 + (i % 2) * 0.5, cos(i * 1.3) * 0.9), Color(0.16, 0.3, 0.16))


## Aschengeist: schwebende, glimmende Gestalt.
static func aschengeist(parent: Node3D) -> void:
	var c = CylinderMesh.new()
	c.top_radius = 0.45
	c.bottom_radius = 0.1
	c.height = 1.8
	_m(parent, c, Vector3(0, 1.3, 0), Color(0.75, 0.72, 0.7), 0.6, 0.55)
	_m(parent, _ball(0.42), Vector3(0, 2.4, 0), Color(0.85, 0.82, 0.8), 0.8, 0.7)
	for x in [-0.15, 0.15]:
		_m(parent, _ball(0.08), Vector3(x, 2.45, 0.36), Color(1.0, 0.4, 0.1), 5.0)
	for x in [-0.6, 0.6]:
		var a = _m(parent, _box(Vector3(0.16, 0.9, 0.16)), Vector3(x, 1.7, 0.2), Color(0.75, 0.72, 0.7), 0.6, 0.5)
		a.rotation.z = -x * 0.6
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.45, 0.2)
	l.light_energy = 1.2
	l.omni_range = 6.0
	l.position.y = 2.0
	parent.add_child(l)
