extends Node3D
## Bello, der Hund: folgt dem Helden, beißt Gegner, kann zu Hause bleiben. Nimmt keinen Schaden.

var legs := []
var wobble := 0.0
var bite_t := 0.0
var bark_t := 3.0
var body: Node3D
var reach := 3.0
var stay := false
var art := "hund"         # "hund" kämpft mit, "esel" trägt nur


func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	if art == "esel":
		legs = Formen.vierbeiner(body, Color(0.5, 0.48, 0.46), Color(0.8, 0.78, 0.74), 1.15)
		for x in [-0.5, 0.5]:
			Formen._m(body, Formen._box(Vector3(0.35, 0.6, 0.9)), Vector3(x, 1.2, 0), Color(0.5, 0.33, 0.18))
	else:
		legs = Formen.vierbeiner(body, Color(0.62, 0.42, 0.22), Color(0.95, 0.9, 0.8), 0.78)
	add_to_group("interact")
	stay = G.p["flags"].get(art + "_bleibt", false)
	var tag = Label3D.new()
	tag.text = "Bello" if art == "hund" else "Fridolin"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 2.0
	tag.font_size = 36
	tag.outline_size = 8
	tag.pixel_size = 0.008
	tag.modulate = Color(1.0, 0.9, 0.7)
	tag.visibility_range_end = 30.0
	add_child(tag)


func usable() -> bool:
	return true

func prompt() -> String:
	return "Bello streicheln" if art == "hund" else "Fridolin (Packesel)"

func interact() -> void:
	if art == "hund":
		Audio.sfx("hund", 1.0, 0.7)
	G.ui.dialog("Bello" if art == "hund" else "Fridolin", "Bello wedelt mit dem Schwanz und stupst deine Hand an." if art == "hund" else "Fridolin trägt dein Gepäck (%d von %d Stück) und sieht dich vorwurfsvoll an." % [G.load_now(), G.capacity()], [
		["Komm mit!" if stay else "Bleib beim Haus.", func():
			stay = not stay
			G.p["flags"][art + "_bleibt"] = stay
			G.say("Er wartet am Haus." if stay else "Er läuft wieder mit.")],
		["Guter Hund.", func():
			G.p["fatigue"] = min(100.0, G.p["fatigue"] + 2.0)]])


func _physics_process(delta: float) -> void:
	var pl = G.player
	if pl == null:
		return
	bite_t -= delta
	var goal: Vector3 = pl.global_position - pl.facing() * (2.2 if art == "hund" else 4.0) + Vector3(-1.4 if art == "hund" else 1.8, 0, 0.6)
	var stop = 1.0
	var target: Node = null
	if stay:
		goal = G.world.places["spielerhaus"] + Vector3(2.5, 0, 1.5)
	else:
		var best = 10.0
		for e in get_tree().get_nodes_in_group("enemy"):
			var d: float = e.global_position.distance_to(pl.global_position)
			if art == "hund" and not e.dead and e.state != "idle" and d < best and e.zone == G.p.get("room", ""):
				best = d
				target = e
		if target:
			goal = target.global_position
			stop = 2.0
		if global_position.distance_to(pl.global_position) > 40.0:
			global_position = pl.global_position + Vector3(-1.5, 0, 1.5)
	var to = goal - global_position
	to.y = 0
	var moving = to.length() > stop
	if moving:
		var dir = to.normalized()
		if G.p.get("room", "") == "" or stay:
			dir = G.world.avoid(global_position, dir)
		global_position += dir * min(9.5 if to.length() > 5.0 else 5.0, to.length() / delta) * delta
		global_position.y = pl.global_position.y if not stay else 0.0
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 10.0)
	elif target and bite_t <= 0.0:
		bite_t = 1.1
		target.take_damage(6.0 + G.p["level"] * 2.5, false)
		body.position.z = 0.5
	body.position.z = lerp(body.position.z, 0.0, 0.2)
	wobble += delta * (14.0 if moving else 0.0)
	for i in legs.size():
		legs[i].rotation.x = sin(wobble + (PI if i % 3 == 0 else 0.0)) * (0.8 if moving else 0.0)
	bark_t -= delta
	if target and bark_t <= 0.0:
		bark_t = randf_range(2.5, 5.0)
		Audio.sfx("hund", randf_range(0.9, 1.1), 0.5)
