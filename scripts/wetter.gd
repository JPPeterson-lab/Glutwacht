extends Node
## Wetter, Jahreszeiten und Kalender (Markttage, Feste).
## Das Wetter wechselt alle paar Stunden, die Jahreszeit alle sieben Tage.

const SEASONS := ["Frühling", "Sommer", "Herbst", "Winter"]
const NAMES := {"klar": "klar", "wolkig": "bewölkt", "regen": "Regen", "nebel": "Nebel", "gewitter": "Gewitter", "schnee": "Schnee"}
## Wahrscheinlichkeiten je Jahreszeit
const CHANCE := [
	{"klar": 40, "wolkig": 25, "regen": 22, "nebel": 8, "gewitter": 5},
	{"klar": 55, "wolkig": 20, "regen": 10, "nebel": 2, "gewitter": 13},
	{"klar": 25, "wolkig": 25, "regen": 25, "nebel": 20, "gewitter": 5},
	{"klar": 30, "wolkig": 25, "schnee": 35, "nebel": 10},
]
const TINT := [Vector3(1.0, 1.05, 0.95), Vector3(1.0, 1.0, 1.0), Vector3(1.25, 1.0, 0.7), Vector3(0.9, 0.95, 1.05)]

var world: Node3D
var rain: CPUParticles3D
var snow: CPUParticles3D
var cur := "klar"
var blend := 0.0          # 0 klar, 1 volles Wetter (weicher Übergang)
var flash := 0.0
var thunder_t := 8.0
var snow_cover := 0.0


func _ready() -> void:
	rain = _particles(700, 0.9, Vector3(0, -34, 0), Vector3(0.03, 0.7, 0.03), Color(0.75, 0.82, 0.95, 0.55))
	snow = _particles(500, 5.0, Vector3(0.6, -3.2, 0.3), Vector3(0.09, 0.09, 0.09), Color(1, 1, 1, 0.9))
	G.new_day.connect(_new_day)


func _particles(amount: int, life: float, vel: Vector3, size: Vector3, col: Color) -> CPUParticles3D:
	var ps = CPUParticles3D.new()
	ps.amount = amount
	ps.lifetime = life
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = Vector3(26, 0.5, 26)
	ps.direction = vel.normalized()
	ps.spread = 4.0
	ps.gravity = Vector3.ZERO
	ps.initial_velocity_min = vel.length() * 0.9
	ps.initial_velocity_max = vel.length() * 1.1
	var bm = BoxMesh.new()
	bm.size = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	ps.mesh = bm
	ps.emitting = false
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ps)
	return ps


func season() -> int:
	return int((G.p.get("day", 1) - 1) / 7.0) % 4 if G.playing else 0

func season_day() -> int:
	return (G.p["day"] - 1) % 7 + 1

func is_winter() -> bool:
	return season() == 3

func bad() -> bool:
	return cur in ["regen", "gewitter", "schnee"]

## Sichtweite der Gegner: bei Nebel, Regen und Schnee bemerken sie dich später.
func sight() -> float:
	return {"nebel": 0.55, "regen": 0.8, "gewitter": 0.7, "schnee": 0.75}.get(cur, 1.0)

## Markttag (jeder siebte Tag) oder Fest (erster Tag einer Jahreszeit, außer ganz am Anfang)?
func today() -> String:
	if not G.playing:
		return ""
	if G.p.get("flags", {}).get("hochzeit_day", -1) == G.p["day"]:
		return "Hochzeit"
	if season_day() == 1 and G.p["day"] > 1:
		return ["Frühlingsfest", "Sonnwendfest", "Erntefest", "Winterfeuer"][season()]
	if season_day() == 4:
		return "Markttag"
	return ""

func festive() -> bool:
	var t = today()
	return t != "" and t != "Markttag" and G.hour() >= 17.0 and G.hour() < 23.5

func text() -> String:
	var t = "%s, Tag %d · %s" % [SEASONS[season()], season_day(), NAMES[cur]]
	if today() != "":
		t += " · " + today()
	return t


func _new_day() -> void:
	var t = today()
	if t == "Markttag":
		G.say("Heute ist Markttag in Aschfurt: alle Händler geben 20 % Nachlass.")
	elif t != "":
		G.say("Heute Abend: %s auf dem Dorfplatz von Aschfurt, ab 17 Uhr." % t)
	if season_day() == 1 and G.p["day"] > 1:
		G.say("Es wird %s." % SEASONS[season()])


func _pick() -> void:
	var table: Dictionary = CHANCE[season()]
	var roll = randi() % 100
	for k in table:
		roll -= table[k]
		if roll < 0:
			cur = k
			break
	G.p["wetter"] = cur
	G.p["wetter_bis"] = G.p["day"] * 24.0 + G.p["time"] + randf_range(3.0, 8.0)
	if cur != "klar":
		G.say("Das Wetter schlägt um: %s." % NAMES[cur])


func _process(delta: float) -> void:
	if not G.playing or get_tree().paused:
		return
	if not G.p.has("wetter") or G.p["day"] * 24.0 + G.p["time"] > G.p.get("wetter_bis", 0.0):
		_pick()
	cur = G.p["wetter"]
	if cur == "regen" or cur == "gewitter":
		G.p["flags"]["regen_day"] = G.p["day"]
	if snow_cover == 0.0 and is_winter() and blend == 0.0:
		snow_cover = 1.0
	var outside = G.p.get("room", "") == ""
	blend = move_toward(blend, 0.0 if cur == "klar" else 1.0, delta * 0.25)
	snow_cover = move_toward(snow_cover, 1.0 if is_winter() else 0.0, delta * 0.05)
	var cam = get_viewport().get_camera_3d()
	if cam:
		var above = cam.global_position + Vector3(0, 14, -6)
		rain.global_position = above
		snow.global_position = above
	rain.emitting = outside and (cur == "regen" or cur == "gewitter")
	snow.emitting = (outside and cur == "schnee") or G.p.get("room", "") == "hochwacht"
	flash = max(0.0, flash - delta * 3.0)
	if cur == "gewitter" and outside:
		thunder_t -= delta
		if thunder_t <= 0.0:
			thunder_t = randf_range(7.0, 18.0)
			flash = 1.0
			Audio.sfx("donner", randf_range(0.85, 1.1), 0.9)
	var amb = "tag"
	if world.GEBIETE.has(G.p.get("room", "")): amb = "wind" if G.p["room"] == "hochwacht" else ("wasser" if G.p["room"] == "salzhafen" else ("nacht" if G.is_night() else "tag"))
	elif not outside: amb = "hoehle" if world.dungeons.has(G.p.get("room", "")) else ("wirtshaus" if G.p.get("room", "").ends_with("wirtshaus") else "feuer")
	elif cur == "regen" or cur == "gewitter": amb = "regen"
	elif cur == "schnee" or G.p.get("room", "") == "asche": amb = "wind"
	elif G.is_night(): amb = "nacht"
	Audio.ambience(amb)


## Wird nach der Tageszeit-Beleuchtung aufgerufen und legt das Wetter darüber.
func apply(sun: DirectionalLight3D, env: Environment, sky: ProceduralSkyMaterial) -> void:
	var grey = Color(0.42, 0.45, 0.5)
	var k = blend
	var dim = {"wolkig": 0.25, "regen": 0.45, "nebel": 0.35, "gewitter": 0.65, "schnee": 0.3}.get(cur, 0.0) * k
	sun.light_energy = sun.light_energy * (1.0 - dim) + flash * 2.5
	sky.sky_top_color = sky.sky_top_color.lerp(grey.darkened(0.3), dim * 1.2)
	sky.sky_horizon_color = sky.sky_horizon_color.lerp(grey, dim * 1.2)
	sky.ground_horizon_color = sky.sky_horizon_color
	env.fog_density = env.fog_density + {"nebel": 0.02, "regen": 0.004, "gewitter": 0.006, "schnee": 0.006}.get(cur, 0.0) * k
	env.fog_light_color = env.fog_light_color.lerp(grey, dim)
	if world.ground_mat:
		world.ground_mat.set_shader_parameter("season_tint", TINT[season()])
		world.ground_mat.set_shader_parameter("snow", snow_cover * 0.85)
