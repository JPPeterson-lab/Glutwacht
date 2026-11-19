extends Node3D
## Baut die offene Welt auf und steuert Tageszeit, Gegnerlager, Fundstücke und das Zuhause.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const NpcScript := preload("res://scripts/npc.gd")
const UiScript := preload("res://scripts/ui.gd")
const CritterScript := preload("res://scripts/critter.gd")

const S := 8.0                                 # Maßstab der Gebäude
const HOME := Vector3(600, 0, 600)             # Innenraum des eigenen Hauses
const CAMPS := {
	"acker": {"pos": Vector3(64, 0, 50), "power": 0.8, "list": ["diener", "diener", "diener"]},
	"wald1": {"pos": Vector3(-78, 0, -48), "power": 0.9, "list": ["diener", "diener", "diener"]},
	"schrein": {"pos": Vector3(-120, 0, -80), "power": 1.0, "list": ["diener", "diener", "diener", "krieger", "krieger"]},
	"wald2": {"pos": Vector3(-158, 0, -40), "power": 1.1, "list": ["schurke", "schurke", "diener"]},
	"mine": {"pos": Vector3(122, 0, -34), "power": 1.3, "list": ["krieger", "krieger", "diener", "diener", "magier"]},
	"sumpf": {"pos": Vector3(44, 0, 138), "power": 1.4, "list": ["sumpf", "sumpf", "sumpf", "schurke", "magier"]},
	"ruinen": {"pos": Vector3(30, 0, -158), "power": 1.6, "list": ["krieger", "krieger", "krieger", "magier", "magier"]},
	"boss": {"pos": Vector3(30, 0, -182), "power": 1.0, "list": ["boss"]},
	"ufer": {"pos": Vector3(330, 0, 170), "power": 1.5, "list": ["schurke", "schurke", "diener", "diener"]},
	"friedhof": {"pos": Vector3(-300, 0, 60), "power": 1.9, "list": ["krieger", "krieger", "krieger", "magier", "magier", "schurke", "geist", "geist"]},
	"turm": {"pos": Vector3(280, 0, -250), "power": 2.2, "list": ["krieger", "krieger", "krieger", "magier", "magier"]},
	"strasse": {"pos": Vector3(170, 0, 110), "power": 1.2, "list": ["bandit", "bandit", "schuetze"]},
	"heide": {"pos": Vector3(-220, 0, 220), "power": 1.5, "list": ["wolf", "wolf", "wolf", "wolf"]},
	"wolfsbau": {"pos": Vector3(-70, 0, 150), "power": 0.9, "list": ["wolf", "wolf", "wolf"]},
	"raeuberlager": {"pos": Vector3(200, 0, -40), "power": 1.5, "list": ["schlaeger", "bandit", "bandit", "schuetze"]},
	"geisterhain": {"pos": Vector3(-330, 0, -60), "power": 1.8, "list": ["geist", "geist", "geist"]},
	"nordwald": {"pos": Vector3(-200, 0, -280), "power": 1.8, "list": ["wolf", "wolf", "schlaeger", "schuetze"]},
}
const ZONES := [
	[Vector3(0, 0, 11), Vector3(0.5, 0.42, 0.3)],        # Dorfplatz (x, z, Radius)
	[Vector3(-115, -75, 80), Vector3(0.10, 0.24, 0.16)],   # Dämmerwald
	[Vector3(125, -40, 40), Vector3(0.42, 0.41, 0.44)],    # Mine
	[Vector3(30, -170, 52), Vector3(0.34, 0.31, 0.33)],    # Ruinen
	[Vector3(42, 136, 52), Vector3(0.16, 0.26, 0.22)],     # Sumpf
	[Vector3(62, 48, 15), Vector3(0.42, 0.30, 0.18)],      # Acker
	[Vector3(250, 190, 34), Vector3(0.62, 0.55, 0.38)],    # Weidenau (Sand)
	[Vector3(300, 240, 50), Vector3(0.5, 0.5, 0.36)],      # Seeufer
	[Vector3(-300, 60, 46), Vector3(0.24, 0.25, 0.26)],    # alter Friedhof
	[Vector3(280, -250, 40), Vector3(0.4, 0.38, 0.36)],    # Wachturm
]

var places := {}
var sun: DirectionalLight3D
var env: Environment
var sky: ProceduralSkyMaterial
var dyn: Node3D                 # alles, was pro Spielstand neu entsteht
var dead := []
var lamps := []
var night := false
var clouds := []
var hue_mats := {}
var rooms := {}
var bereit := false          # Welt fertig aufgebaut?
var map_texs := {}           # Luftbilder der eigenen Gebiete
var turnier := 0             # laufende Turnierrunde (0 = keines)
var arena := Vector3.ZERO
var schatz_node: Interact
var enc_t := 60.0
var enc_nodes := []
var night_t := 20.0
const TURNIER := [["bandit", "bandit", "bandit"], ["schlaeger", "schuetze", "schuetze"], ["schlaeger", "schlaeger", "bandit", "bandit"], ["turniermeister"]]
const PREISGELD := [60, 120, 200, 400]
const SCHATZ_ORTE := [Vector3(-160, 0, 120), Vector3(190, 0, 40), Vector3(-60, 0, -210), Vector3(120, 0, -150), Vector3(-250, 0, -120), Vector3(330, 0, 60),
	Vector3(-120, 0, 250), Vector3(60, 0, 300), Vector3(-330, 0, 200), Vector3(220, 0, 320), Vector3(350, 0, -150), Vector3(-200, 0, -340)]
const RAETSEL := [["Je mehr du davon machst, desto mehr lässt du hinter dir zurück. Was ist es?", ["Schritte", "Münzen", "Versprechen"]],
	["Ich habe Städte, aber keine Häuser. Wälder, aber keine Bäume. Flüsse, aber kein Wasser. Was bin ich?", ["Eine Karte", "Ein Traum", "Ein Spiegel"]],
	["Was wird nasser, je mehr es trocknet?", ["Ein Handtuch", "Der Regen", "Ein Brunnen"]],
	["Ich fliege ohne Flügel und weine ohne Augen. Was bin ich?", ["Eine Wolke", "Der Wind", "Eine Fledermaus"]],
	["Füttere mich, und ich lebe. Gib mir zu trinken, und ich sterbe. Was bin ich?", ["Feuer", "Ein Fisch", "Die Zeit"]]]
## Orte, die in der Chronik der Taten als besucht gezählt werden
const BESUCH := {"schrein": ["Schrein im Dämmerwald", Vector3(-120, 0, -80)], "mine_ort": ["Alte Mine", Vector3(125, 0, -40)], "ruinen": ["Ruinen", Vector3(30, 0, -170)],
	"sumpf": ["Sumpf", Vector3(42, 0, 136)], "weidenau": ["Weidenau", Vector3(250, 0, 190)], "friedhof": ["Alter Friedhof", Vector3(-300, 0, 60)],
	"turm": ["Wachturm", Vector3(280, 0, -250)], "pass": ["Bergpass", Vector3(0, 0, -372)]}
var room_names := {}
var dorf_spots := {}        # Dorfkürzel -> Orte, zu denen die Bewohner spazieren
## Eigene Gebiete, nur per Reise erreichbar: Mittelpunkt und Name
const GEBIETE := {"asche": [Vector3(0, 0, -1500), "Aschenlande"], "salzhafen": [Vector3(-1200, 0, -3200), "Salzhafen"],
	"hochwacht": [Vector3(0, 0, -3200), "Hochwacht"], "dornfeld": [Vector3(1200, 0, -3200), "Dornfeld"]}
const SCHALE_GEBIET := {"asche": "asche", "salzhafen": "salzhafen", "hochwacht": "hochwacht", "dornfeld": "dornfeld"}
var moebel := {}
var beete := []
## Möbel: Name, Preis, Modell, Platz im Haus, Drehung, Größe
const MOEBEL := {
	"sofa": ["Sofa mit Kissen", 140, "furn/couch_pillows.gltf", Vector3(-1.6, 0.15, 2.9), PI, 1.0],
	"teppich": ["Gestreifter Teppich", 60, "furn/rug_rectangle_stripes_A.gltf", Vector3(-2.6, 0.17, 0.4), 0.0, 1.1],
	"bild": ["Gemälde", 80, "furn/pictureframe_medium.gltf", Vector3(2.9, 2.3, -3.95), 0.0, 1.2],
	"tischchen": ["Beistelltisch", 50, "furn/table_low.gltf", Vector3(-1.6, 0.15, 1.5), 0.0, 1.0],
	"kerzen": ["Kerzenleuchter", 45, "dungeon/candle_triple.glb", Vector3(3.9, 1.15, 1.9), 0.0, 1.0],
	"banner": ["Banner der Glutwacht", 90, "dungeon/banner_yellow.glb", Vector3(-4.6, 0, -4.0), 0.0, 1.0],
	"fass": ["Vorratsfass", 40, "dungeon/barrel_large.glb", Vector3(5.6, 0.15, 0.4), 0.0, 0.9],
	"werkbank": ["Werkbank", 160, "dungeon/table_small.glb", Vector3(5.2, 0.15, 2.6), 0.0, 1.0],
	"wiege": ["Wiege", 0, "dungeon/trunk_medium_A.glb", Vector3(-2.2, 0.15, -2.6), 0.0, 0.8],
}
var wetter: Node
var dungeons := {}          # id -> {"start": Vector3, "gates": [...]}
var dungeon_spawns := []    # [Art, Ort, Lager, Stärke, Dungeon]
var schalen := {}           # id -> Flammenknoten
## Glutschalen: einmal entzündet, kann man zwischen ihnen reisen.
const SCHALEN := {"aschfurt": ["Aschfurt", Vector3(-7, 0, 6)], "schrein": ["Schrein im Dämmerwald", Vector3(-120, 0, -80)],
	"weidenau": ["Weidenau", Vector3(258, 0, 200)], "mine": ["Alte Mine", Vector3(112, 0, -28)], "sumpf": ["Sumpf", Vector3(28, 0, 116)],
	"ruinen": ["Ruinen", Vector3(30, 0, -138)], "friedhof": ["Alter Friedhof", Vector3(-276, 0, 66)], "turm": ["Wachturm", Vector3(266, 0, -232)],
	"pass": ["Bergpass", Vector3(0, 0, -372)], "asche": ["Aschenlande", Vector3(0, 0, -1380)],
	"salzhafen": ["Salzhafen", Vector3(-1190, 0, -3190)], "hochwacht": ["Hochwacht", Vector3(10, 0, -3190)], "dornfeld": ["Dornfeld", Vector3(1210, 0, -3190)]}
const ASCHE := Vector3(0, 0, -1500)
const THRON_TOR := Vector3(0, 0, -1690)
const EINGAENGE := {"mine": Vector3(120, 0, -48), "gruft": Vector3(-300, 0, 41), "turmkeller": Vector3(274, 0, -240)}
var obst := {}             # Hindernisse (Bäume, Pfosten) in einem groben Raster, zum Ausweichen
var grass_chunks := []
var tiere := []            # alle Tiere, werden nur in der Nähe des Helden bewegt
var far_keys := []        # Orte außerhalb von Aschfurt (eigene Wege, keine Vorgärten nach Dorfschema)
var map_tex: Texture2D          # Luftbild der Welt für die Karte
var map_baking := false
var ground_mat: ShaderMaterial
var pickups := []
var ores := []
var menu_cam: Camera3D
var rng := RandomNumberGenerator.new()
var check_t := 0.0
var shrine_fire: Node3D
var args := {}


func _ready() -> void:
	G.world = self
	rng.seed = 20261117
	for a in OS.get_cmdline_user_args():
		var kv = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var ui = CanvasLayer.new()
	ui.set_script(UiScript)
	add_child(ui)
	# Ladebild: Die Welt entsteht in Schritten, damit das Fenster nicht sekundenlang schwarz bleibt.
	var lade = CanvasLayer.new()
	lade.layer = 60
	add_child(lade)
	var bg = ColorRect.new()
	bg.color = Color(0.09, 0.055, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	lade.add_child(bg)
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.theme = ui.theme
	lade.add_child(cc)
	var lv = VBoxContainer.new()
	lv.add_theme_constant_override("separation", 14)
	lv.custom_minimum_size = Vector2(620, 0)
	cc.add_child(lv)
	var th = HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 16)
	lv.add_child(th)
	th.add_child(ui.pic("flamme", 104))
	var lt = Label.new()
	lt.text = "Glutwacht"
	lt.add_theme_font_size_override("font_size", 84)
	lt.add_theme_color_override("font_color", Color(1.0, 0.77, 0.42))
	th.add_child(lt)
	th.add_child(ui.pic("flamme", 104))
	var ls = Label.new()
	ls.text = "Hüter der letzten Flamme"
	ls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ls.add_theme_font_size_override("font_size", 22)
	lv.add_child(ls)
	var lb = ProgressBar.new()
	lb.show_percentage = false
	lb.custom_minimum_size = Vector2(620, 16)
	lb.add_theme_stylebox_override("background", ui._box(Color(1, 1, 1, 0.1), 5))
	var fill = ui._box(Color(1.0, 0.6, 0.2), 5)
	fill.set_content_margin_all(0)
	lb.add_theme_stylebox_override("fill", fill)
	lv.add_child(lb)
	var ll = Label.new()
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.add_theme_font_size_override("font_size", 18)
	ll.add_theme_color_override("font_color", Color(0.85, 0.78, 0.62))
	lv.add_child(ll)
	var steps = [["Der Himmel wird gespannt", _boden], ["Aschfurt wird gebaut", _village], ["Wälder wachsen", _wilds],
		["Weidenau, Friedhof und Wachturm", _outlands], ["Dungeons werden gegraben", _dungeons], ["Asche fällt auf die Aschenlande", _aschenlande],
		["Salzhafen, Hochwacht und Dornfeld", _gebiete], ["Glutschalen werden aufgestellt", _schalen], ["Garten und Stall", _hof],
		["Dein Haus wird eingerichtet", _home_interior], ["Wirtshäuser öffnen", _interiors], ["Tiere ziehen ein", _life],
		["Das Dorf wird wohnlich", _cozy], ["Wege werden getreten", _paths], ["Unterwegs lauert etwas", _unterwegs]]
	for i in steps.size():
		ll.text = steps[i][0] + " ..."
		lb.value = 100.0 * i / steps.size()
		await get_tree().process_frame
		await get_tree().process_frame
		steps[i][1].call()
	ll.text = "Die Karten werden gezeichnet ..."
	lb.value = 97.0
	apply_quality()
	wetter = Node.new()
	wetter.set_script(load("res://scripts/wetter.gd"))
	wetter.world = self
	add_child(wetter)
	dyn = Node3D.new()
	add_child(dyn)
	menu_cam = Camera3D.new()
	menu_cam.fov = 45.0
	menu_cam.far = 1000.0
	add_child(menu_cam)
	menu_cam.make_current()
	bereit = true
	await _render_map()
	lade.queue_free()
	G.new_day.connect(_on_new_day)
	Audio.music("menue")
	if args.has("auto"):
		var c: String = args.get("cls", "ritter")
		G.new_game("Aldric", c, G.CLASSES[c]["attr"])
		G.p["talents"][G.CLASSES[c]["skills"][0]] = 1
		if args.has("slot2"):
			G.p["weapons"][args["slot2"]] = 0
			G.p["slots"][1] = args["slot2"]
			G.p["active"] = 1
		for k in ["home", "smith_free"]:
			if args.has(k): G.p["flags"][k] = true
		if args.has("time"): G.p["time"] = float(args["time"])
		if args.has("wlvl"):
			G.p["weapons"][G.wid()] = int(args["wlvl"])
			G.p["guard_lvl"] = int(args["wlvl"])
		if args.has("pos"):
			var xy: PackedStringArray = args["pos"].split(",")
			G.p["pos"] = [float(xy[0]), 0.5, float(xy[1])]
		start_game()
		if args.has("inside"): enter_room(args["inside"] if rooms.has(args["inside"]) else "spielerhaus")
		if args.has("day"): G.p["day"] = int(args["day"])
		if args.has("wetter"):
			G.p["wetter"] = args["wetter"]
			G.p["wetter_bis"] = 999999.0
		if args.has("asche"):
			G.p["flags"]["hort_w_tot"] = true
			G.p["inside"] = true
			G.p["room"] = "asche"
			var ap: PackedStringArray = args["asche"].split(",")
			G.player.global_position = ASCHE + Vector3(float(ap[0]), 0.4, float(ap[1]))
			G.player.snap_camera()
		if args.has("gebiet"):
			var gq: PackedStringArray = args["gebiet"].split(",")
			_ankommen(gq[0], GEBIETE[gq[0]][0] + Vector3(float(gq[1]), 0, float(gq[2])))
		if args.has("hq"):
			G.opt["quality"] = 2
			G.opt["fps"] = 3
			apply_quality()
		if args.has("gott"):
			G.p["cheats"]["god"] = true
			G.p["cheats"]["onehit"] = true
		if args.has("nah"):
			G.player.cam_dist = 6.0
			G.player.cam_pitch = 0.3
			G.player.cam_yaw = float(args["nah"])
			G.player.set_physics_process(false)
			G.player.play(args.get("anim", "Idle_A"), 1.0, true)
			G.player.anim.seek(float(args.get("seek", "0.3")), true)
			G.player.anim.pause()
			G.player.snap_camera()
			G.ui.hud.visible = false
		if args.has("turnier"):
			_turnier_runde(int(args["turnier"]))
		if args.has("enc"):
			enc_t = 1.0
			night_t = 1.0
		if args.has("dungeon"):
			G.p["torch"] = args.has("fackel")
			G.p["torch_left"] = 6.0
			enter_dungeon(args["dungeon"])
		if args.has("ui"): G.ui.call_deferred("call", "show_" + args["ui"])
	else:
		G.ui.show_menu()
	if args.has("frei"):
		await get_tree().process_frame
		Engine.max_fps = 0
	if args.has("speed"): Engine.time_scale = float(args["speed"])
	if args.has("fight"):
		G.opt["aim"] = false
	if args.has("hund"):
		G.p["flags"]["hund"] = true
		spawn_dog()
	if args.has("talk"):
		await get_tree().create_timer(1.0).timeout
		G.npcs[args["talk"]].interact()
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("wait", "4")), true, false, true).timeout
		if G.playing:
			print("BILDER/S %d" % Engine.get_frames_per_second())
			print("LAST zeichenaufrufe=%d objekte=%d dreiecke=%d prozess=%.1fms physik=%.1fms knoten=%d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
			var nn = 0
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.camp in ["nacht", "begegnung"]: nn += 1
			print("UNTERWEGS nacht/begegnung=%d figuren=%d enc_t=%.1f night_t=%.1f nacht=%s" % [nn, enc_nodes.size(), enc_t, night_t, G.is_night()])
			print("STAND hp=%d kills=%d xp=%d gold=%d zeit=%s inv=%s" % [G.p["hp"], G.p["kills"], G.p["xp"], G.p["gold"], G.clock_text(), G.p["inv"]])
			for id in G.npcs:
				var n = G.npcs[id]
				print("NPC %s: %s raum=%s e=%d h=%d" % [id, n.act, n.room, n.needs["energy"], n.needs["hunger"]])
		get_viewport().get_texture().get_image().save_png(args["shot"])
		get_tree().quit()


# ---------------------------------------------------------------- Bausteine

func put(path: String, pos: Vector3, rot := 0.0, sc := 1.0, parent: Node = null) -> Node3D:
	var n = G.model(path)
	n.position = pos
	n.rotation.y = rot
	n.scale = Vector3.ONE * sc
	(parent if parent else self).add_child(n)
	return n


func solid(pos: Vector3, size: Vector3, rot := 0.0, layer := 1) -> void:
	var b = StaticBody3D.new()
	b.collision_layer = layer
	var s = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	s.shape = box
	b.add_child(s)
	b.position = pos + Vector3(0, size.y / 2.0, 0)
	b.rotation.y = rot
	add_child(b)


## Lenkt eine Laufrichtung sanft an Bäumen und Pfosten vorbei.
func avoid(pos: Vector3, dir: Vector3) -> Vector3:
	var cx = int(floor(pos.x / 8.0))
	var cz = int(floor(pos.z / 8.0))
	var push = Vector3.ZERO
	var perp = Vector3(-dir.z, 0, dir.x)
	for ix in range(cx - 1, cx + 2):
		for iz in range(cz - 1, cz + 2):
			for o in obst.get(Vector2i(ix, iz), []):
				var v = Vector3(o.x - pos.x, 0, o.y - pos.z)
				var dist = v.length()
				var reach = o.z + 2.4
				if dist < reach and dist > 0.01 and v.dot(dir) > -0.2:
					var side = -1.0 if v.dot(perp) > 0.0 else 1.0
					push += perp * side * (1.0 - (dist - o.z) / 2.4) * 1.6
	return (dir + push).normalized() if push != Vector3.ZERO else dir


func pillar(pos: Vector3, radius: float, height := 4.0) -> void:
	if radius < 4.0:
		var key = Vector2i(int(floor(pos.x / 8.0)), int(floor(pos.z / 8.0)))
		if not obst.has(key):
			obst[key] = []
		obst[key].append(Vector3(pos.x, pos.z, radius))
	var b = StaticBody3D.new()
	b.collision_layer = 16      # Kleinkram: nur der Held stößt daran an
	var s = CollisionShape3D.new()
	var c = CylinderShape3D.new()
	c.radius = radius
	c.height = height
	s.shape = c
	b.add_child(s)
	b.position = pos + Vector3(0, height / 2.0, 0)
	add_child(b)


## Stellt ein Modell auf und gibt ihm einen Kollisionskasten nach seiner Größe.
func block(path: String, pos: Vector3, rot := 0.0, sc := 1.0, shrink := 0.8, layer := 16) -> Node3D:
	var n = put(path, pos, rot, sc)
	var m: MeshInstance3D = n if n is MeshInstance3D else n.find_child("*", true, false) as MeshInstance3D
	for c in n.find_children("*", "MeshInstance3D", true, false):
		m = c
		break
	if m:
		var bb = m.get_aabb()
		solid(pos, Vector3(bb.size.x * sc * shrink, bb.size.y * sc, bb.size.z * sc * shrink), rot, layer)
	return n


func thing(pos: Vector3, label: String, action: Callable, reach := 3.6, parent: Node = null) -> Interact:
	var i = Interact.new()
	i.label = label
	i.action = action
	i.reach = reach
	i.position = pos
	(parent if parent else self).add_child(i)
	return i


func lamp(pos: Vector3, color := Color(1.0, 0.62, 0.3), energy := 2.2, rng_ := 14.0, always := false) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_
	add_child(l)
	if not always:
		lamps.append(l)
	return l


func glow_mesh(mesh: Mesh, pos: Vector3, color: Color, energy := 3.0, parent: Node = null) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(m)
	return m


func flat_mesh(mesh: Mesh, pos: Vector3, color: Color, rough := 0.9, parent: Node = null) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	m.material_override = mat
	m.position = pos
	if mesh.get_aabb().get_longest_axis_size() < 1.6:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF       # Kleinteile werfen keinen Schatten
	(parent if parent else self).add_child(m)
	return m


# ---------------------------------------------------------------- Himmel, Licht, Boden

func _environment() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.04
	add_child(sun)
	sky = ProceduralSkyMaterial.new()
	var s = Sky.new()
	s.sky_material = sky
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = s
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_density = 0.0015
	env.fog_aerial_perspective = 0.15
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _daylight(h: float) -> void:
	var f: float = clamp(sin((h - 6.0) / 12.0 * PI) * 1.7 + 0.12, 0.0, 1.0)     # 0 Nacht, 1 Tag
	var dusk: float = clamp(1.0 - abs(f - 0.3) / 0.3, 0.0, 1.0)                 # Dämmerung
	sun.rotation_degrees = Vector3(-lerp(18.0, 62.0, f), -35.0 + (h - 12.0) * 7.0, 0)
	sun.light_energy = lerp(0.28, 1.25, f)
	sun.light_color = Color(0.5, 0.62, 1.0).lerp(Color(1.0, 0.96, 0.88), f).lerp(Color(1.0, 0.6, 0.35), dusk * 0.6)
	var top = Color(0.05, 0.08, 0.2).lerp(Color(0.22, 0.45, 0.85), f).lerp(Color(0.25, 0.2, 0.45), dusk * 0.5)
	var hor = Color(0.12, 0.16, 0.34).lerp(Color(0.66, 0.8, 0.95), f).lerp(Color(1.0, 0.55, 0.3), dusk * 0.7)
	sky.sky_top_color = top
	sky.sky_horizon_color = hor
	sky.ground_horizon_color = hor
	sky.ground_bottom_color = top.darkened(0.4)
	env.ambient_light_energy = lerp(0.75, 0.6, f)
	env.fog_light_color = hor.darkened(0.15)
	env.fog_density = lerp(0.003, 0.0007, f)
	night = f < 0.4
	if wetter and G.playing:
		var rm: String = G.p.get("room", "")
		if dungeons.has(rm):
			# unter der Erde: fast kein Licht, nur Fackeln
			sun.light_energy = 0.02
			env.ambient_light_energy = 0.12
			env.fog_density = 0.012
			env.fog_light_color = Color(0.02, 0.02, 0.03)
			sky.ground_bottom_color = Color(0.01, 0.01, 0.02)
			sky.sky_top_color = Color(0.01, 0.01, 0.02)
			sky.sky_horizon_color = Color(0.02, 0.02, 0.03)
			sky.ground_horizon_color = Color(0.02, 0.02, 0.03)
		elif rm == "asche":
			sun.light_energy = 0.55
			sun.light_color = Color(1.0, 0.6, 0.45)
			env.ambient_light_energy = 0.5
			env.fog_density = 0.011
			env.fog_light_color = Color(0.4, 0.25, 0.2)
			sky.sky_top_color = Color(0.16, 0.1, 0.1)
			sky.sky_horizon_color = Color(0.6, 0.3, 0.2)
			sky.ground_horizon_color = Color(0.6, 0.3, 0.2)
		elif rm == "hochwacht":
			env.fog_density = 0.006
			env.fog_light_color = Color(0.8, 0.85, 0.92)
		elif rm == "":
			wetter.apply(sun, env, sky)
	for l in lamps:
		l.visible = f < 0.45


func _ground() -> void:
	var m = MeshInstance3D.new()
	var pl = PlaneMesh.new()
	pl.size = Vector2(1600, 1600)
	m.mesh = pl
	var sh = Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 zone_pos[10];
uniform vec3 zone_col[10];
uniform sampler2D path_tex : filter_linear, repeat_disable;
uniform vec3 season_tint = vec3(1.0);
uniform float snow = 0.0;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = noise(wp.xz * 0.06) * 0.55 + noise(wp.xz * 0.35) * 0.3 + noise(wp.xz * 1.7) * 0.15;
	vec3 c = mix(vec3(0.16, 0.42, 0.12), vec3(0.42, 0.66, 0.2), n);
	float patch = noise(wp.xz * 0.018 + 7.0);
	c = mix(c, vec3(0.55, 0.68, 0.18), smoothstep(0.62, 0.8, patch) * 0.6);
	c = mix(c, vec3(0.12, 0.5, 0.3), smoothstep(0.3, 0.12, patch) * 0.5);
	for (int i = 0; i < 10; i++) {
		float d = distance(wp.xz, zone_pos[i].xy);
		float w = 1.0 - smoothstep(zone_pos[i].z * 0.55, zone_pos[i].z * (0.95 + n * 0.3), d);
		c = mix(c, zone_col[i] * (0.8 + 0.4 * n), w * 0.9);
	}
	float pv = texture(path_tex, wp.xz / 800.0 + 0.5).r;
	float pw = smoothstep(0.3 + n * 0.15, 0.62 + n * 0.1, pv);
	c = mix(c, vec3(0.62, 0.5, 0.33) * (0.85 + 0.3 * noise(wp.xz * 2.0)), pw * 0.92);
	c *= season_tint;
	c = mix(c, vec3(0.9, 0.93, 0.97), snow * (1.0 - pw * 0.4) * (0.75 + 0.25 * n));
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	ground_mat = mat
	var zp = PackedVector3Array()
	var zc = PackedVector3Array()
	for z in ZONES:
		zp.append(z[0])
		zc.append(z[1])
	mat.set_shader_parameter("zone_pos", zp)
	mat.set_shader_parameter("zone_col", zc)
	m.material_override = mat
	add_child(m)
	var b = StaticBody3D.new()
	var s = CollisionShape3D.new()
	s.shape = WorldBoundaryShape3D.new()
	b.add_child(s)
	add_child(b)
	# Grasbüschel: in Kacheln aufgeteilt, damit nur das Gras in der Nähe gezeichnet wird
	var tuft = CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.07
	tuft.height = 0.4
	tuft.radial_segments = 3
	tuft.rings = 1
	tuft.cap_bottom = false
	var tm = StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.roughness = 1.0
	tuft.material = tm
	var pts = []
	for i in 80000:
		var gp = Vector3(rng.randf_range(-385, 385), 0.2, rng.randf_range(-385, 385))
		var bs = Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)).scaled(Vector3.ONE * rng.randf_range(0.6, 1.4))
		var col = Color(0.25, 0.5, 0.18).lerp(Color(0.5, 0.7, 0.25), rng.randf())
		if i % 23 == 0: col = [Color(0.95, 0.85, 0.3), Color(0.9, 0.4, 0.5), Color(0.85, 0.85, 0.95)][i % 3]
		pts.append([bs, gp, col])
	grass_chunks = _kacheln(pts, tuft)
	# Weltrand: Berge und unsichtbare Wände
	for i in 4:
		var a = i * PI / 2.0
		solid(Vector3(sin(a), 0, cos(a)) * 392.0, Vector3(800, 30, 4), a)
	for i in 100:
		var a = i * TAU / 100.0 + rng.randf() * 0.05
		var r = 404.0 + rng.randf() * 45.0
		put("hex/mountain_%s%s.gltf" % [["A", "B", "C"][i % 3], ["", "_grass", "_grass_trees"][rng.randi() % 3]],
			Vector3(sin(a) * r, -2, cos(a) * r), rng.randf() * TAU, 40.0 + rng.randf() * 30.0)


# ---------------------------------------------------------------- Dorf Aschfurt

func _house(model: String, pos: Vector3, key: String, sc := S, mid := Vector3.ZERO) -> void:
	var to = Vector3(mid.x - pos.x, 0, mid.z - pos.z).normalized()
	var rot = atan2(to.x, to.z)
	var n = block("hex/%s.gltf" % model, pos, rot, sc, 0.78, 1)
	# Die Tür liegt sicher vor der Hauswand: Abstand aus der wirklichen Größe des Modells
	var half = 0.62
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = c.get_aabb()
		half = max(max(abs(bb.position.x), abs(bb.end.x)), max(abs(bb.position.z), abs(bb.end.z)))
		break
	var door = pos + to * (half * sc * 0.94 + 1.3)
	if key != "":
		places[key] = door


func _village() -> void:
	places["brunnen"] = Vector3(0, 0, 0)
	block("hex/building_well_blue.gltf", Vector3.ZERO, 0, S * 0.8, 0.6)
	_house("building_tavern_blue", Vector3(-26, 0, -18), "wirtshaus")
	_house("building_blacksmith_blue", Vector3(24, 0, -16), "schmiede")
	_house("building_market_blue", Vector3(22, 0, 18), "markt")
	_house("building_church_blue", Vector3(-12, 0, 36), "studierstube")
	_house("building_barracks_blue", Vector3(8, 0, -44), "wache")
	_house("building_home_B_blue", Vector3(-42, 0, 16), "spielerhaus")
	_house("building_home_A_red", Vector3(22, 0, -46), "haus_gernot")
	_house("building_home_A_green", Vector3(42, 0, -18), "haus_hilda")
	_house("building_home_B_red", Vector3(-40, 0, -34), "haus_bruno")
	_house("building_home_B_yellow", Vector3(40, 0, 30), "haus_mira")
	_house("building_home_A_blue", Vector3(-28, 0, 40), "haus_elara")
	_house("building_home_A_red", Vector3(-56, 0, -14), "haus_finn")
	_house("building_home_B_red", Vector3(60, 0, 22), "haus_tomas")
	_house("building_windmill_blue", Vector3(78, 0, 34), "", 10.0)
	_house("building_tower_A_blue", Vector3(-4, 0, -56), "", 9.0)
	_house("building_home_A_yellow", Vector3(-68, 0, 6), "haus_odo")
	_house("building_home_B_green", Vector3(-62, 0, 34), "haus_lina")
	_house("building_home_A_green", Vector3(16, 0, 56), "haus_karl")
	_house("building_home_B_yellow", Vector3(66, 0, 4), "haus_bertha")
	_house("building_home_A_yellow", Vector3(56, 0, -36), "haus_jorik")
	_house("building_tower_A_red", Vector3(-10, 0, 64), "", 8.0)
	places["tor"] = Vector3(0, 0, 60)
	places["muehle"] = Vector3(70, 0, 30)
	places["holzplatz"] = Vector3(-60, 0, -30)
	places["steinbruch"] = Vector3(32, 0, -7)
	places["waldrand"] = Vector3(-62, 0, -40)
	places["acker_rand"] = Vector3(52, 0, 42)
	places["teich"] = Vector3(-43, 0, 47)
	# Teich
	var pond = CylinderMesh.new()
	pond.top_radius = 9.0
	pond.bottom_radius = 9.0
	pond.height = 0.1
	var pm = flat_mesh(pond, Vector3(-50, 0.03, 54), Color(0.16, 0.36, 0.52), 0.1)
	pm.material_override.metallic = 0.4
	for i in 7:
		put("hex/water%s.gltf" % ["lily_A", "lily_B", "plant_A", "plant_B"][i % 4], Vector3(-50 + rng.randf_range(-6, 6), 0.08, 54 + rng.randf_range(-6, 6)), rng.randf() * TAU, 7.0)
	# Kleinkram
	var props = [["barrel", -20, -8], ["barrel", -21.5, -9], ["crate_A_big", -18, -12], ["weaponrack", 20, -8], ["crate_B_big", 26, 12],
		["sack", 17, 13], ["crate_long_A", 18, 10], ["wheelbarrow", 48, 36], ["sack", 58, 30], ["bucket_water", 2.5, 2], ["flag_blue", 3, -38],
		["tent", -58, -34], ["barrel", 12, -40], ["crate_open", 15, 22], ["pallet", 28, -10], ["resource_stone", 30, -12]]
	for q in props:
		block("hex/%s.gltf" % q[0], Vector3(q[1], 0, q[2]), rng.randf() * TAU, S * 0.9, 0.7)
	for i in 36:
		var a = i * TAU / 36.0
		if i % 12 != 0:
			put("hex/fence_wood_straight.gltf", Vector3(64 + sin(a) * 14.0, 0, 50 + cos(a) * 14.0), a + PI / 2.0, 2.2)
	for i in 40:
		put("food/food_ingredient_%s.gltf" % ["carrot", "lettuce", "potato"][i % 3], Vector3(56 + (i % 8) * 2.2, 0.05, 43 + int(i / 8.0) * 3.0), rng.randf() * TAU, 0.8)
	put("res/Wood_Log_Stack.gltf", Vector3(-61, 0, -28), 0.4, 1.4)
	put("res/Wood_Planks_Stack_Medium.gltf", Vector3(-63, 0, -33), 1.2, 1.4)
	put("res/Iron_Bars_Stack_Small.gltf", Vector3(27, 0.0, -8.5), 0.5, 1.5)
	put("res/Stone_Chunks_Large.gltf", Vector3(31, 0, -9), 0.2, 1.3)
	for i in 30:
		var a = rng.randf() * TAU
		var r = rng.randf_range(20.0, 62.0)
		forest(BUSHES[i % BUSHES.size()], Vector3(sin(a) * r, 0, cos(a) * r) + Vector3(rng.randf_range(-2, 2), 0, 0), rng.randf_range(0.8, 1.3))
	for q in [[-14, -26], [10, 24], [-30, 2], [34, 4], [-6, -22], [8, -24], [-22, 26], [46, 10], [-50, 2], [28, 38]]:
		forest(TREES[rng.randi() % 8], Vector3(q[0], 0, q[1]), rng.randf_range(1.6, 2.2), true)
		pillar(Vector3(q[0], 0, q[1]), 0.5, 6.0)
	# Laternen
	for q in [[4, 3], [-18, -10], [18, -9], [16, 12], [-34, 14], [-8, 28], [6, -36], [36, -12], [34, 26], [-48, -14]]:
		var p = Vector3(q[0], 0, q[1])
		flat_mesh(_cyl(0.12, 3.2), p + Vector3(0, 1.6, 0), Color(0.25, 0.2, 0.16))
		flat_mesh(_box(Vector3(0.9, 0.1, 0.1)), p + Vector3(0.4, 3.15, 0), Color(0.25, 0.2, 0.16))
		put("tools3d/lantern.gltf", p + Vector3(0.8, 2.1, 0), 0.0, 0.9)
		glow_mesh(_sphere(0.16), p + Vector3(0.8, 2.5, 0), Color(1.0, 0.75, 0.4), 3.0)
		lamp(p + Vector3(0.8, 2.6, 0))
	# Anschlagbrett
	var bp = Vector3(6, 0, 6)
	flat_mesh(_box(Vector3(0.2, 2.6, 0.2)), bp + Vector3(-1.1, 1.3, 0), Color(0.3, 0.22, 0.15))
	flat_mesh(_box(Vector3(0.2, 2.6, 0.2)), bp + Vector3(1.1, 1.3, 0), Color(0.3, 0.22, 0.15))
	flat_mesh(_box(Vector3(2.6, 1.5, 0.12)), bp + Vector3(0, 2.0, 0), Color(0.45, 0.33, 0.2))
	flat_mesh(_box(Vector3(0.7, 0.9, 0.02)), bp + Vector3(-0.5, 2.0, 0.08), Color(0.92, 0.88, 0.75))
	flat_mesh(_box(Vector3(0.6, 0.7, 0.02)), bp + Vector3(0.55, 2.1, 0.08), Color(0.88, 0.85, 0.7))
	solid(bp, Vector3(2.6, 3, 0.4), 0.0, 16)
	thing(bp + Vector3(0, 0, 1), "Anschlagbrett lesen", _board)
	# Haustür und Übungsplatz
	var door: Vector3 = places["spielerhaus"]
	var di = thing(door, "", func():
		if G.p["flags"].get("home", false):
			enter_home()
		else:
			G.say("Das Haus steht leer und ist verschlossen. Hauptmann Gernot verwaltet den Schlüssel."))
	di.label_fn = func(): return "Dein Haus betreten" if G.p["flags"].get("home", false) else "Leeres Haus (verschlossen)"
	var yard = Vector3(-34, 0, 30)
	flat_mesh(_cyl(0.18, 2.6), yard + Vector3(0, 1.3, 0), Color(0.4, 0.28, 0.18))
	flat_mesh(_box(Vector3(1.8, 0.2, 0.2)), yard + Vector3(0, 1.9, 0), Color(0.4, 0.28, 0.18))
	flat_mesh(_sphere(0.42), yard + Vector3(0, 2.75, 0), Color(0.75, 0.65, 0.45))
	flat_mesh(_cyl(0.45, 1.1), yard + Vector3(0, 1.5, 0), Color(0.75, 0.65, 0.45))
	pillar(yard, 0.5)
	_train_spot(yard, "An der Übungspuppe trainieren (Stärke)", "str")
	block("hex/target.gltf", yard + Vector3(6, 0, 0), -0.6, 9.0, 0.6)
	_train_spot(yard + Vector3(6, 0, 0), "Auf die Zielscheibe üben (Geschick)", "ges")
	block("hex/resource_stone.gltf", yard + Vector3(-6, 0, 1), 0.4, 9.0, 0.7)
	_train_spot(yard + Vector3(-6, 0, 1), "Steine stemmen (Vitalität)", "vit")


func _train_spot(pos: Vector3, label: String, attr: String) -> void:
	var i = thing(pos, label, func(): train(attr), 4.0)
	i.condition = func(): return G.p["flags"].get("home", false)


func _board() -> void:
	if not G.event("use", "brett").is_empty():
		return
	if G.quest_available("b1"):
		G.ui.dialog("Anschlagbrett", G.QUESTS["b1"]["intro"], [
			["Auftrag annehmen", func(): G.start_quest("b1")], ["Weitergehen", Callable()]])
	else:
		G.ui.dialog("Anschlagbrett", "Der Aushang der Dorfwache hängt noch. " + G.stage_text("b1"), [["Weitergehen", Callable()]])


## Orte weit draußen: Fischerdorf Weidenau am See, alter Friedhof, Wachturm.
func _outlands() -> void:
	# ---- Weidenau
	var m = Vector3(250, 0, 190)
	places["b_brunnen"] = m
	block("hex/building_well_blue.gltf", m, 0, S * 0.7, 0.6)
	_house("building_tavern_blue", m + Vector3(-20, 0, -12), "b_wirtshaus", S, m)
	_house("building_home_A_green", m + Vector3(18, 0, -16), "haus_walda", S, m)
	_house("building_home_B_yellow", m + Vector3(-18, 0, 16), "haus_ivo", S, m)
	_house("building_home_A_red", m + Vector3(4, 0, -26), "haus_selma", S, m)
	places["b_steg"] = Vector3(279, 0, 213)
	places["b_ufer"] = Vector3(262, 0, 222)
	far_keys = ["b_brunnen", "b_wirtshaus", "haus_walda", "haus_ivo", "haus_selma", "b_steg", "b_ufer"]
	dorf_spots["b"] = ["b_brunnen", "b_steg", "b_ufer"]
	var lake = Vector3(306, 0, 244)
	var lm = CylinderMesh.new()
	lm.top_radius = 40.0
	lm.bottom_radius = 40.0
	lm.height = 0.1
	lm.radial_segments = 48
	var water = flat_mesh(lm, lake + Vector3(0, 0.04, 0), Color(0.14, 0.38, 0.55), 0.08)
	water.material_override.metallic = 0.5
	pillar(lake, 38.5, 4.0)
	# Steg, Boote, Netze
	var dir = (lake - places["b_steg"]).normalized()
	for i in 6:
		var pp = places["b_steg"] + dir * (1.5 + i * 2.2)
		flat_mesh(_box(Vector3(2.6, 0.2, 2.3)), pp + Vector3(0, 0.45, 0), Color(0.46, 0.33, 0.2)).rotation.y = atan2(dir.x, dir.z)
		if i % 2 == 0:
			flat_mesh(_cyl(0.12, 1.4), pp + Vector3(dir.z, 0, -dir.x) * 1.2 + Vector3(0, 0.3, 0), Color(0.3, 0.22, 0.14))
	for q in [[0.6, 0.9, Color(0.55, 0.25, 0.2)], [-0.5, 0.75, Color(0.25, 0.4, 0.55)], [1.5, 0.82, Color(0.5, 0.42, 0.25)]]:
		var bp = lake + Vector3(sin(q[0] + 3.6), 0, cos(q[0] + 3.6)) * 40.0 * q[1]
		var boat = Node3D.new()
		boat.position = bp + Vector3(0, 0.25, 0)
		boat.rotation.y = q[0] * 2.0
		add_child(boat)
		flat_mesh(_box(Vector3(1.4, 0.5, 4.2)), Vector3.ZERO, q[2], 0.9, boat)
		flat_mesh(_box(Vector3(1.0, 0.3, 3.4)), Vector3(0, 0.2, 0), q[2].darkened(0.4), 0.9, boat)
		flat_mesh(_box(Vector3(1.3, 0.08, 0.3)), Vector3(0, 0.3, 0.4), Color(0.6, 0.45, 0.28), 0.9, boat)
	for i in 14:
		var a = rng.randf() * TAU
		put("hex/water%s.gltf" % ["lily_A", "lily_B", "plant_A", "plant_B", "plant_C"][i % 5], lake + Vector3(sin(a), 0, cos(a)) * rng.randf_range(20, 38) + Vector3(0, 0.1, 0), rng.randf() * TAU, 8.0)
	for k in 6:
		critter("ente", lake + Vector3(rng.randf_range(-16, 16), 0.1, rng.randf_range(-16, 16)), rng.randf_range(3.0, 9.0))
	for q in [[-6, 8, "barrel_large"], [8, 6, "crates_stacked"], [-10, -4, "box_large"]]:
		put("dungeon/%s.glb" % q[2], m + Vector3(q[0], 0, q[1]), rng.randf() * TAU, 0.9)
	put("tools3d/rope_bundle_A.gltf", places["b_ufer"] + Vector3(2, 0, 1), 0.4, 1.4)
	put("res/Wood_Planks_Stack_Medium.gltf", places["b_ufer"] + Vector3(-3, 0, 2), 1.0, 1.3)
	for i in 3:      # Trockengestelle für Netze
		var np = places["b_ufer"] + Vector3(-6 + i * 4.5, 0, -4)
		for sx in [-1.2, 1.2]:
			flat_mesh(_cyl(0.07, 2.4), np + Vector3(sx, 1.2, 0), Color(0.4, 0.28, 0.18))
		flat_mesh(_box(Vector3(2.4, 1.5, 0.04)), np + Vector3(0, 1.5, 0), Color(0.75, 0.72, 0.6, 1.0))
	seat(m + Vector3(5, 0, 5), -2.4)
	seat(places["b_ufer"] + Vector3(4, 0, -2), 0.6)
	for i in 5:
		var a = i * TAU / 5.0
		var lp = m + Vector3(sin(a), 0, cos(a)) * 11.0
		flat_mesh(_cyl(0.12, 3.2), lp + Vector3(0, 1.6, 0), Color(0.25, 0.2, 0.16))
		put("tools3d/lantern.gltf", lp + Vector3(0, 3.1, 0), 0.0, 0.9)
		lamp(lp + Vector3(0, 3.4, 0))
	for i in 14:
		var a = rng.randf() * TAU
		var rr = rng.randf_range(16.0, 34.0)
		var tp = m + Vector3(sin(a) * rr, 0, cos(a) * rr)
		var okay = tp.distance_to(lake) > 44.0
		for key in far_keys:
			if places[key].distance_to(tp) < 8.0:
				okay = false
		if okay:
			forest(TREES[rng.randi() % 8], tp, rng.randf_range(1.8, 2.6), true)
			pillar(tp, 0.6, 6.0)
	for i in 30:
		var a = rng.randf() * TAU
		var rr = rng.randf_range(8.0, 34.0)
		forest(BUSHES[i % BUSHES.size()], m + Vector3(sin(a) * rr, 0, cos(a) * rr), rng.randf_range(0.7, 1.2))
	for q in [places["b_steg"] + dir * 12.0, places["b_ufer"] + Vector3(0, 0, 6)]:
		thing(q, "Im See angeln", func():
			G.player.play("Fishing_Cast", 1.0, true)
			fade("Der See liegt still. Du wirfst die Leine aus.", func():
				G.advance(1.0)
				G.job_xp("angeln", 2)
				if randf() < 0.7 + G.job_lvl("angeln") * 0.03:
					var nf = 1 + (1 if randf() < 0.4 + G.job_lvl("angeln") * 0.05 else 0)
					G.add_item("fisch", nf)
					G.say("%d Fisch gefangen. Der See ist großzügiger als der Dorfteich." % nf)
				else:
					G.say("Nichts. Der Hecht lacht dich aus.")
				G.changed.emit()), 3.2)
	for k in 5:
		critter("huhn", m + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(4, 12)), 6.0)

	# ---- Alter Friedhof im Westen
	var f = Vector3(-300, 0, 60)
	for i in 28:
		var gp = f + Vector3(-18 + (i % 7) * 6.0 + rng.randf_range(-0.8, 0.8), 0, -12 + int(i / 7.0) * 8.0 + rng.randf_range(-0.8, 0.8))
		if i % 5 == 2:
			continue
		var st = flat_mesh(_box(Vector3(1.0, rng.randf_range(1.1, 1.8), 0.25)), gp + Vector3(0, 0.7, 0), Color(0.45, 0.46, 0.5))
		st.rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.15, 0.15))
		flat_mesh(_box(Vector3(1.2, 0.12, 2.2)), gp + Vector3(0, 0.06, 1.3), Color(0.3, 0.27, 0.24))
	for i in 16:
		var a = i * TAU / 16.0
		if i % 8 != 0:
			put("hex/fence_stone_straight.gltf", f + Vector3(sin(a) * 30.0, 0, cos(a) * 30.0), a + PI / 2.0, 5.0)
	for i in 14:
		var a = rng.randf() * TAU
		_tree(f + Vector3(sin(a), 0, cos(a)) * rng.randf_range(24.0, 44.0), true)
	for q in [[0, -22, 0.0], [-4, -22, 0.0], [4, -22, 0.0]]:
		put("dungeon/%s.glb" % ("wall_arched" if q[0] == 0 else "wall"), f + Vector3(q[0], 0, q[1]), q[2])
	solid(f + Vector3(0, 0, -22), Vector3(12, 4, 1))
	put("dungeon/pillar_decorated.glb", f + Vector3(-7, 0, -20))
	put("dungeon/pillar_decorated.glb", f + Vector3(7, 0, -20))
	lamp(f + Vector3(0, 3, -18), Color(0.4, 1.0, 0.6), 2.2, 20.0, true)
	glow_mesh(_sphere(0.35), f + Vector3(0, 2.6, -20.5), Color(0.4, 1.0, 0.6), 3.0)

	# ---- Wachturm im Nordosten
	var t = Vector3(280, 0, -250)
	block("hex/building_tower_B_blue.gltf", t, 0.4, 11.0, 0.7, 1)
	block("hex/building_destroyed.gltf", t + Vector3(-16, 0, 6), 1.0, 9.0, 0.75, 1)
	for i in 8:
		var a = i * TAU / 8.0
		if i % 3 != 0:
			put("dungeon/%s.glb" % ["wall_broken", "wall"][i % 2], t + Vector3(sin(a) * 22.0, 0, cos(a) * 22.0), a + PI)
			solid(t + Vector3(sin(a) * 22.0, 0, cos(a) * 22.0), Vector3(4, 4, 1), a + PI)
	put("dungeon/banner_red.glb", t + Vector3(6, 0, 6), 0.4, 1.3)
	lamp(t + Vector3(0, 6, 8), Color(1.0, 0.5, 0.2), 2.4, 22.0)
	for i in 6:
		forest(["Rock_1_K", "Rock_3_L", "Rock_2_G"][i % 3], t + Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30)), rng.randf_range(0.8, 1.3))


func _box(size: Vector3) -> BoxMesh:
	var b = BoxMesh.new()
	b.size = size
	return b

func _cyl(r: float, h: float, top := -1.0) -> CylinderMesh:
	var c = CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if top < 0.0 else top
	c.height = h
	return c

func _sphere(r: float) -> SphereMesh:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


# ---------------------------------------------------------------- Wildnis

func _free(p: Vector3) -> bool:
	# hält Plätze frei, an denen nichts wachsen soll
	if Vector2(p.x, p.z).length() < 70.0 and Vector2(p.x, p.z).length() > 0.0:
		if Vector2(p.x, p.z).length() < 66.0: return false
	if abs(p.x) > 386.0 or abs(p.z) > 386.0: return false
	for c in [[-120, -80, 16], [125, -40, 26], [30, -170, 36], [64, 50, 18], [44, 138, 16], [78, 34, 12], [250, 190, 34], [300, 240, 40], [-300, 60, 30], [280, -250, 26]]:
		if Vector2(p.x - c[0], p.z - c[1]).length() < c[2]: return false
	return true


const TREES := ["Tree_1_A", "Tree_1_B", "Tree_1_C", "Tree_2_A", "Tree_2_B", "Tree_2_C", "Tree_2_D", "Tree_2_E", "Tree_3_A", "Tree_3_B", "Tree_3_C", "Tree_4_A", "Tree_4_B", "Tree_4_C"]
const BARE := ["Tree_Bare_1_A", "Tree_Bare_1_B", "Tree_Bare_1_C", "Tree_Bare_2_A", "Tree_Bare_2_B", "Tree_Bare_2_C"]
const BUSHES := ["Bush_1_C", "Bush_1_E", "Bush_1_G", "Bush_2_B", "Bush_2_D", "Bush_2_F", "Bush_3_A", "Bush_3_C", "Bush_4_B", "Bush_4_D", "Bush_4_F"]
const ROCKS := ["Rock_1_A", "Rock_1_C", "Rock_1_E", "Rock_2_A", "Rock_2_C", "Rock_3_A", "Rock_3_C", "Rock_3_E", "Rock_1_G", "Rock_3_F"]


func forest(n: String, p: Vector3, sc := 1.0, fade := false) -> Node3D:
	var t = put("forest/%s_Color1.gltf" % n, p, rng.randf() * TAU, sc)
	for m in t.find_children("*", "MeshInstance3D", true, false):
		m.visibility_range_end = 150.0       # weit entfernte Bäume, Büsche und Felsen gar nicht erst zeichnen
	if fade:
		for m in t.find_children("*", "MeshInstance3D", true, false):
			# Bäume dicht vor der Kamera ausblenden, damit sie den Helden nicht verdecken
			m.visibility_range_begin = 13.0
			m.visibility_range_begin_margin = 4.0
			m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return t


func _tree(p: Vector3, bare := false) -> void:
	var sc = rng.randf_range(1.5, 2.5)
	var t = forest((BARE if bare else TREES)[rng.randi() % (BARE.size() if bare else TREES.size())], p, sc, true)
	if not bare:
		var mystic = Vector2(p.x + 115.0, p.z + 75.0).length() < 85.0      # Dämmerwald
		var roll = rng.randf()
		if mystic and roll < 0.5:
			_hue(t, 0.4, 0.85)          # im Dämmerwald nur ein dunkleres, kühleres Grün
	pillar(p, 0.28 * sc, 6.0)


## Färbt das Laub eines Baumes um (Herbstrot, Gelb, Blütenrosa, im Dämmerwald Blau und Violett).
func _hue(tree: Node3D, hue: float, sat: float) -> void:
	for m in tree.find_children("*", "MeshInstance3D", true, false):
		var key = "%.2f" % hue
		if not hue_mats.has(key):
			var base = m.get_active_material(0)
			if not (base is BaseMaterial3D):
				return
			var sh = Shader.new()
			sh.code = """
shader_type spatial;
uniform sampler2D tex : source_color;
uniform float hue = 0.08;
uniform float sat = 1.0;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec3 h = rgb2hsv(texture(tex, UV).rgb);
	if (h.x > 0.17 && h.x < 0.5 && h.y > 0.2) { h.x = hue; h.y = clamp(h.y * sat, 0.0, 1.0); h.z = clamp(h.z * 0.8, 0.0, 1.0); }
	ALBEDO = hsv2rgb(h);
	ROUGHNESS = 0.9;
}
"""
			var mat = ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("tex", base.albedo_texture)
			mat.set_shader_parameter("hue", hue)
			mat.set_shader_parameter("sat", sat)
			hue_mats[key] = mat
		m.material_override = hue_mats[key]


func critter(kind: String, pos: Vector3, radius := 8.0, color := Color.WHITE) -> void:
	var c = Node3D.new()
	c.set_script(CritterScript)
	c.init(kind, pos, radius, color)
	add_child(c)
	tiere.append(c)


## Verteilt viele kleine Netze (Gras, Blumen) auf Kacheln von 64 × 64. Jede Kachel wird nur gezeichnet,
## wenn die Kamera in der Nähe ist. pts: Liste aus [Basis, Ort, Farbe].
func _kacheln(pts: Array, mesh: Mesh) -> Array:
	var cells := {}
	for q in pts:
		var key = Vector2i(int(floor(q[1].x / 64.0)), int(floor(q[1].z / 64.0)))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(q)
	var out = []
	for key in cells:
		var mid = Vector3(key.x * 64.0 + 32.0, 0, key.y * 64.0 + 32.0)
		var list: Array = cells[key]
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, Transform3D(list[i][0], list[i][1] - mid))
			mm.set_instance_color(i, list[i][2])
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = mid
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 115.0
		mmi.visibility_range_end_margin = 10.0
		add_child(mmi)
		out.append(mmi)
	return out


func smoke(pos: Vector3, color := Color(0.85, 0.85, 0.88, 0.55), amount := 14, size := 0.9) -> void:
	var ps = CPUParticles3D.new()
	ps.position = pos
	ps.amount = amount
	ps.lifetime = 5.0
	ps.direction = Vector3(0.25, 1, 0.1)
	ps.spread = 12.0
	ps.gravity = Vector3.ZERO
	ps.initial_velocity_min = 1.0
	ps.initial_velocity_max = 1.8
	ps.scale_amount_min = size * 0.6
	ps.scale_amount_max = size * 1.4
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	ps.mesh = sm
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	ps.color_ramp = g
	add_child(ps)


## Farbe und Leben: Blumen, Wimpel, Fahnen, Wolken, Tiere, Rauch, Werkstätten.
func _life() -> void:
	var bright = [Color(1.0, 0.25, 0.3), Color(1.0, 0.8, 0.15), Color(0.95, 0.45, 0.85), Color(0.45, 0.55, 1.0), Color(1.0, 0.55, 0.15), Color(0.98, 0.98, 1.0), Color(0.7, 0.4, 1.0)]
	# Blumenwiesen
	var head = SphereMesh.new()
	head.radius = 0.11
	head.height = 0.14
	head.radial_segments = 5
	head.rings = 2
	var hm = StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.roughness = 0.8
	head.material = hm
	var fl_pts = []
	var fl_max = 24000
	var idx = 0
	var patches = []
	while idx < fl_max:
		var c = Vector3(rng.randf_range(-375, 375), 0, rng.randf_range(-375, 375))
		var pr = rng.randf_range(5.0, 13.0)
		var c1 = bright[rng.randi() % bright.size()]
		var c2 = bright[rng.randi() % bright.size()]
		patches.append([c, c1])
		for k in int(pr * 11.0):
			if idx >= fl_max:
				break
			var a = rng.randf() * TAU
			var d = sqrt(rng.randf()) * pr
			var bs = Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.7, 1.5))
			var fp = c + Vector3(sin(a) * d, rng.randf_range(0.3, 0.5), cos(a) * d)
			if Vector2(fp.x, fp.z).length() < 78.0 or fp.distance_to(Vector3(250, 0, 190)) < 48.0:
				fp = Vector3(0, -50, 0)        # in den Dörfern keine Blumenteppiche
			if fp.y > -10.0:
				fl_pts.append([bs, fp, (c1 if rng.randf() < 0.7 else c2).lerp(Color.WHITE, rng.randf() * 0.15)])
			idx += 1
	_kacheln(fl_pts, head)
	# Schmetterlinge über einem Teil der Wiesen, Hasen daneben
	for i in patches.size():
		if i % 3 == 0:
			for k in 3:
				critter("schmetterling", patches[i][0] + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)), rng.randf_range(2.5, 5.0), patches[(i + k) % patches.size()][1])
		if i % 7 == 1 and Vector2(patches[i][0].x, patches[i][0].z).length() > 50.0:
			for k in 2:
				critter("hase", patches[i][0] + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), 9.0)
	# Hühner im Dorf, Enten auf dem Teich, Vögel am Himmel, Glühwürmchen
	for q in [[52, 30], [-34, 6], [30, 24], [-20, 30], [10, -30], [58, 10]]:
		for k in 4:
			critter("huhn", Vector3(q[0] + rng.randf_range(-3, 3), 0, q[1] + rng.randf_range(-3, 3)), 6.0)
	for k in 5:
		critter("ente", Vector3(-50, 0.08, 54), rng.randf_range(2.0, 6.5))
	for k in 22:
		critter("vogel", Vector3(rng.randf_range(-160, 160), rng.randf_range(24, 40), rng.randf_range(-160, 160)), rng.randf_range(18, 60),
			[Color(0.2, 0.2, 0.25), Color(0.9, 0.9, 0.95), Color(0.75, 0.3, 0.2), Color(0.25, 0.4, 0.7)][k % 4])
	for k in 150:
		var gp = Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-70, 70)) if k < 70 else Vector3(-115 + rng.randf_range(-70, 70), 0, -75 + rng.randf_range(-70, 70))
		critter("gluehwurm", gp)
	# Wolken
	for k in 30:
		var cl = put("hex/cloud_%s.gltf" % ("big" if k % 2 == 0 else "small"), Vector3(rng.randf_range(-450, 450), rng.randf_range(60, 85), rng.randf_range(-450, 450)), rng.randf() * TAU, rng.randf_range(22, 40))
		for m in cl.find_children("*", "MeshInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clouds.append(cl)
	# Fahnen und Wimpelketten im Dorf
	var cols = ["red", "yellow", "green", "blue"]
	var fl = [[-22, -8], [20, -6], [18, 10], [-6, 28], [4, -36], [-36, 12], [2, 56], [-4, 56], [36, 28], [-34, -28], [64, 26], [-58, -10]]
	for i in fl.size():
		put("hex/flag_%s.gltf" % cols[i % 4], Vector3(fl[i][0], 0, fl[i][1]), rng.randf() * TAU, 11.0)
	var posts = [Vector3(4, 0, 3), Vector3(-18, 0, -10), Vector3(18, 0, -9), Vector3(16, 0, 12), Vector3(-8, 0, 28)]
	var tri = PrismMesh.new()
	tri.size = Vector3(0.5, 0.6, 0.04)
	for i in posts.size() - 1:
		for seg in [[posts[0], posts[i + 1]]]:
			var n = int(seg[0].distance_to(seg[1]) / 0.9)
			for k in range(1, n):
				var f = float(k) / n
				var pp = seg[0].lerp(seg[1], f) + Vector3(0, 3.1 - sin(f * PI) * 0.9, 0)
				var pen = flat_mesh(tri, pp, bright[k % bright.size()])
				pen.rotation = Vector3(PI, atan2(seg[1].x - seg[0].x, seg[1].z - seg[0].z) + PI / 2.0, 0)
				pen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Marktstände mit bunten Dächern
	for i in 4:
		var sp = Vector3(8 + i * 3.6, 0, 20 + (i % 2) * 1.0)
		flat_mesh(_box(Vector3(2.6, 1.0, 1.4)), sp + Vector3(0, 0.5, 0), Color(0.5, 0.36, 0.22))
		for cx in [-1.2, 1.2]:
			flat_mesh(_cyl(0.07, 2.6), sp + Vector3(cx, 1.3, -0.6), Color(0.35, 0.25, 0.16))
		for st in 5:
			flat_mesh(_box(Vector3(0.56, 0.08, 1.9)), sp + Vector3(-1.12 + st * 0.56, 2.65, 0), bright[i % bright.size()] if st % 2 == 0 else Color(0.97, 0.95, 0.9)).rotation.x = 0.22
		solid(sp, Vector3(2.6, 1.0, 1.4), 0.0, 16)
		put("food/%s.gltf" % ["crate_carrots", "crate_cheese", "crate_potatoes", "food_ingredient_tomato"][i], sp + Vector3(0, 1.0, 0), 0.0, 0.7)
	# Blumenbeete an den Häusern
	for key in places:
		if not key.begins_with("haus_") and key != "spielerhaus":
			continue
		for side in [-1.0, 1.0]:
			var bp = places[key] + Vector3(side * 2.2, 0, 0).rotated(Vector3.UP, atan2(-places[key].x, -places[key].z))
			flat_mesh(_box(Vector3(1.6, 0.35, 0.7)), bp + Vector3(0, 0.17, 0), Color(0.42, 0.3, 0.2))
			for k in 6:
				flat_mesh(_sphere(0.17), bp + Vector3(-0.6 + k * 0.24, 0.5 + (k % 2) * 0.08, rng.randf_range(-0.15, 0.15)), bright[(k + int(bp.x)) % bright.size()])
	# Rauch aus Schornsteinen, Feuerstelle auf dem Dorfplatz
	for key in ["wirtshaus", "schmiede", "haus_mira", "haus_tomas", "haus_odo", "spielerhaus"]:
		var hp: Vector3 = places[key]
		smoke(hp - Vector3(hp.x, 0, hp.z).normalized() * -5.5 + Vector3(0, 8.5, 0))
	var fp = Vector3(-7, 0, 6)
	for k in 7:
		forest("Rock_1_A", fp + Vector3(sin(k * 0.9) * 1.1, 0, cos(k * 0.9) * 1.1), 0.7)
	put("res/Wood_Log_Stack.gltf", fp, 0.3, 0.45)
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.45
	cone.height = 1.3
	glow_mesh(cone, fp + Vector3(0, 1.1, 0), Color(1.0, 0.5, 0.12), 4.0)
	lamp(fp + Vector3(0, 1.6, 0), Color(1.0, 0.55, 0.2), 2.6, 16.0, true)
	smoke(fp + Vector3(0, 1.6, 0), Color(1.0, 0.6, 0.2, 0.8), 10, 0.25)
	pillar(fp, 1.3, 1.5)
	# Werkstätten
	block("tools3d/anvil.gltf", Vector3(20, 0, -7), 0.4, 1.3, 0.8)
	block("tools3d/grindstone.gltf", Vector3(16, 0, -11), 1.1, 1.0, 0.8)
	put("tools3d/bucket_metal.gltf", Vector3(22, 0, -5), 0.0, 1.1)
	put("tools3d/tongs.gltf", Vector3(20.6, 1.05, -7), 1.4, 1.0).rotation.x = PI / 2.0
	block("furn/table_medium.gltf", Vector3(3, 0, -40), 0.2, 1.0, 0.8)
	put("tools3d/map.gltf", Vector3(3, 1.0, -40), 0.2, 1.0)
	put("tools3d/lantern.gltf", Vector3(3.9, 1.0, -40.4), 0.0, 0.7)
	forest("Rock_3_L", Vector3(34, 0, -5), 1.0)
	forest("Rock_1_K", Vector3(36, 0, -8), 0.8)
	put("res/Stone_Chunks_Large.gltf", Vector3(33, 0, -9.5), 0.6, 1.4)
	put("tools3d/rope_bundle_A.gltf", Vector3(-45, 0, 45), 0.5, 1.2)
	put("res/Wood_Log_Stack.gltf", Vector3(-57, 0, -27), 1.2, 1.3)
	put("tools3d/saw.gltf", Vector3(-57, 1.9, -27), 0.3, 1.2)


func _wilds() -> void:
	var n = 0
	while n < 230:       # Dämmerwald, dicht
		var a = rng.randf() * TAU
		var r = sqrt(rng.randf()) * 84.0
		var p = Vector3(-115 + sin(a) * r, 0, -75 + cos(a) * r)
		if _free(p):
			_tree(p)
		n += 1
	n = 0
	while n < 800:       # übrige Welt, lichter
		var p = Vector3(rng.randf_range(-382, 382), 0, rng.randf_range(-382, 382))
		if _free(p):
			_tree(p)
		n += 1
	for i in 340:
		var p = Vector3(rng.randf_range(-382, 382), 0, rng.randf_range(-382, 382))
		if Vector2(p.x, p.z).length() > 40.0:
			forest(ROCKS[i % ROCKS.size()], p, rng.randf_range(0.9, 1.8))
	for i in 950:
		var p = Vector3(rng.randf_range(-382, 382), 0, rng.randf_range(-382, 382))
		if Vector2(p.x, p.z).length() > 44.0:
			forest(BUSHES[i % BUSHES.size()], p, rng.randf_range(0.9, 1.6))
	for c in [Vector3(30, 0, -170), Vector3(42, 0, 136)]:
		for i in 26:
			var a = rng.randf() * TAU
			var r = rng.randf_range(18.0, 50.0)
			_tree(c + Vector3(sin(a) * r, 0, cos(a) * r), true)
	for i in 34:
		var a = rng.randf() * TAU
		var r = rng.randf_range(250.0, 378.0)
		var p = Vector3(sin(a) * r, -0.5, cos(a) * r)
		if _free(p) and p.distance_to(Vector3(270, 0, 210)) > 110.0 and p.distance_to(Vector3(-300, 0, 60)) > 80.0 and p.distance_to(Vector3(280, 0, -250)) > 80.0:
			put("hex/hill_single_%s.gltf" % ["A", "B", "C"][i % 3], p, rng.randf() * TAU, rng.randf_range(10.0, 16.0))

	# Schrein im Dämmerwald
	var sp = Vector3(-120, 0, -80)
	flat_mesh(_cyl(9.0, 0.3, 8.6), sp + Vector3(0, 0.15, 0), Color(0.42, 0.42, 0.48))
	for i in 7:
		var a = i * TAU / 7.0 + 0.3
		var pp = sp + Vector3(sin(a) * 8.0, 0, cos(a) * 8.0)
		put("dungeon/%s.glb" % ("pillar_decorated" if i % 2 == 0 else "pillar"), pp, a, 1.0 if i != 3 else 0.6)
		pillar(pp, 0.8)
		glow_mesh(_box(Vector3(0.12, 0.9, 0.12)), pp + Vector3(-sin(a) * 0.8, 2.0, -cos(a) * 0.8), Color(0.3, 0.85, 1.0), 2.5)
	flat_mesh(_cyl(0.7, 1.2, 1.3), sp + Vector3(0, 0.9, 0), Color(0.5, 0.5, 0.56))
	pillar(sp, 1.3, 2.0)
	lamp(sp + Vector3(0, 3, 0), Color(0.3, 0.8, 1.0), 1.2, 16.0, true)
	shrine_fire = Node3D.new()
	shrine_fire.position = sp + Vector3(0, 1.6, 0)
	add_child(shrine_fire)
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.7
	cone.height = 1.8
	glow_mesh(cone, Vector3(0, 0.8, 0), Color(1.0, 0.5, 0.12), 5.0, shrine_fire)
	var fl = OmniLight3D.new()
	fl.light_color = Color(1.0, 0.55, 0.2)
	fl.light_energy = 6.0
	fl.omni_range = 26.0
	fl.position.y = 1.5
	shrine_fire.add_child(fl)
	shrine_fire.visible = false
	var gi = thing(sp + Vector3(0, 0, 1.8), "Die Glutschale entzünden", func():
		G.event("use", "glutschale")
		G.p["flags"]["glut"] = true
		Audio.sfx("stufe")
		ring(sp, 9.0, Color(1.0, 0.6, 0.2))
		G.say("Die Glut erwacht. Wärme breitet sich über den Wald aus."), 4.5)
	gi.condition = func(): return G.stage("m1").get("key", "") == "glutschale"
	for i in 8:
		var a = rng.randf() * TAU
		var r = rng.randf_range(20.0, 70.0)
		_pickup(Vector3(-115 + sin(a) * r, 0, -75 + cos(a) * r), "blume")

	# Alte Mine
	var mp = Vector3(125, 0, -40)
	block("hex/building_mine_blue.gltf", mp + Vector3(8, 0, -10), -0.6, 12.0, 0.75, 1)
	for q in [["crate_A_big", -6, 4], ["barrel", -8, 2], ["wheelbarrow", 2, 8], ["resource_stone", 10, 6], ["ladder", -2, -8]]:
		block("hex/%s.gltf" % q[0], mp + Vector3(q[1], 0, q[2]), rng.randf() * TAU, 8.0, 0.7)
	for i in 7:
		var a = i * TAU / 7.0
		var op = mp + Vector3(sin(a) * rng.randf_range(10, 22), 0, cos(a) * rng.randf_range(10, 22))
		var node = forest(["Rock_1_K", "Rock_3_L", "Rock_2_G"][i % 3], op, 0.9)
		var gl = put("res/Iron_Nuggets.gltf", op + Vector3(1.6, 0, 0.8).rotated(Vector3.UP, a), a, 1.6)
		pillar(op, 1.5, 3.0)
		var oi = thing(op, "Eisenerz abbauen", Callable(), 4.2)
		oi.action = func():
			G.add_item("erz")
			G.player.play("Pickaxe", 1.3, true)
			G.player.busy = 0.9
			Audio.sfx("schmiede")
			G.say("Eisenerz abgebaut")
			G.p["fatigue"] = max(0.0, G.p["fatigue"] - 1.5)
			gl.visible = false
			oi.set_meta("leer", true)
		oi.condition = func(): return not oi.get_meta("leer", false)
		ores.append([oi, gl])
		node.name = "Erz%d" % i
	lamp(mp + Vector3(0, 4, 0), Color(1.0, 0.6, 0.3), 2.0, 18.0)

	# Ruinen im Norden
	var rp = Vector3(30, 0, -170)
	for q in [[-14, 6, 0.3], [12, 10, 2.0], [-18, -14, 4.0], [18, -10, 1.0]]:
		block("hex/building_destroyed.gltf", rp + Vector3(q[0], 0, q[1]), q[2], 9.0, 0.75, 1)
	for i in 12:
		var a = i * TAU / 12.0
		var pp = rp + Vector3(sin(a) * 26.0, 0, cos(a) * 26.0)
		if i % 4 == 0:
			continue
		put("dungeon/%s.glb" % ["wall_broken", "wall", "wall_arched"][i % 3], pp, a + PI, 1.0)
		solid(pp, Vector3(4, 4, 1), a + PI)
	for i in 6:
		var pp = rp + Vector3(rng.randf_range(-16, 16), 0, rng.randf_range(-24, 4))
		put("dungeon/%s.glb" % ["rubble_large", "rubble_half", "column"][i % 3], pp, rng.randf() * TAU, 1.2)
	flat_mesh(_cyl(7.0, 0.25), rp + Vector3(0, 0.12, -12), Color(0.25, 0.22, 0.25))
	lamp(rp + Vector3(0, 4, -12), Color(1.0, 0.35, 0.15), 3.0, 24.0, true)
	put("dungeon/sword_shield.glb", rp + Vector3(0, 0, 14), 0, 1.6)

	# Sumpf im Süden
	var wp = Vector3(42, 0, 136)
	for i in 9:
		var c = CylinderMesh.new()
		var r = rng.randf_range(5.0, 11.0)
		c.top_radius = r
		c.bottom_radius = r
		c.height = 0.08
		var pp = wp + Vector3(rng.randf_range(-36, 36), 0.03, rng.randf_range(-36, 36))
		flat_mesh(c, pp, Color(0.1, 0.2, 0.18), 0.15).material_override.metallic = 0.5
		for k in 4:
			put("hex/waterplant_%s.gltf" % ["A", "B", "C"][k % 3], pp + Vector3(rng.randf_range(-r, r), 0.05, rng.randf_range(-r, r)), rng.randf() * TAU, 9.0)
	var kp = wp + Vector3(6, 0, 10)
	var crate = put("hex/crate_long_A.gltf", kp, 0.7, 9.0)
	put("hex/wheelbarrow.gltf", kp + Vector3(3, 0, 1), 2.0, 9.0)
	var ci = thing(kp, "Finns Lieferung bergen", func():
		G.add_item("lieferung")
		G.event("use", "lieferung")
		crate.visible = false, 4.0)
	ci.condition = func(): return G.stage("s4").get("key", "") == "lieferung"

	# Wildgemüse und Schatzkisten
	var kinds = ["karotte", "kartoffel", "zwiebel", "tomate", "salat", "kraut", "kraut"]
	var k = 0
	while k < 130:
		var p = Vector3(rng.randf_range(-340, 340), 0, rng.randf_range(-340, 340))
		if Vector2(p.x, p.z).length() > 46.0 and _free(p):
			_pickup(p, kinds[k % kinds.size()])
			k += 1
	var chests = [[-306, 44, 160, "splitter"], [286, -262, 220, "splitter"], [340, 150, 110, "kette"], [-240, 240, 120, "festmahl"], [-180, -300, 140, "erz"], [360, -40, 90, "buch"], [-360, -150, 100, "heiltrank"], [-96, -20, 60, "heiltrank"], [-150, -110, 90, "kette"], [150, -70, 80, "erz"], [90, 110, 70, "buch"], [-60, 150, 60, "manatrank"],
		[10, -200, 150, "splitter"], [180, 60, 70, "festmahl"], [-200, 30, 80, "erz"]]
	for i in chests.size():
		var c: Array = chests[i]
		var cp = Vector3(c[0], 0, c[1])
		var ch = put("dungeon/chest.glb", cp, rng.randf() * TAU, 1.0)
		solid(cp, Vector3(1.6, 1, 1.6), 0.0, 16)
		var key = "kiste%d" % i
		var it = thing(cp, "Schatzkiste öffnen", Callable(), 3.6)
		it.action = func():
			G.p["looted"][key] = true
			G.add_gold(c[2])
			G.add_item(c[3])
			Audio.sfx("muenze")
			var lid = ch.find_child("chest_lid", true, false)
			if lid: lid.rotation.x = -1.1
			G.say("Schatzkiste: +%d Gold, %s" % [c[2], G.ITEMS[c[3]]["name"]])
		it.condition = func(): return G.playing and not G.p["looted"].get(key, false)


func _pickup(pos: Vector3, item: String) -> void:
	var d: Dictionary = G.ITEMS[item]
	var holder = Node3D.new()
	holder.position = pos
	add_child(holder)
	if d.has("model"):
		put("food/%s.gltf" % d["model"], Vector3(0, 0.1, 0), rng.randf() * TAU, 1.0, holder)
		glow_mesh(_sphere(0.1), Vector3(0, 1.3, 0), Color(1.0, 0.9, 0.5), 1.5, holder)
	else:
		flat_mesh(_cyl(0.05, 0.7), Vector3(0, 0.35, 0), Color(0.2, 0.45, 0.2), 0.9, holder)
		glow_mesh(_sphere(0.24), Vector3(0, 0.8, 0), Color(1.0, 0.45, 0.2) if item != "kraut" else Color(0.4, 0.95, 0.5), 2.2 if item != "kraut" else 0.8, holder)
	var i = thing(Vector3.ZERO, d["name"] + " aufsammeln", Callable(), 3.0, holder)
	i.action = func():
		G.add_item(item)
		Audio.sfx("aufheben")
		G.say("%s gefunden" % d["name"])
		holder.visible = false
	pickups.append(holder)


# ---------------------------------------------------------------- Zuhause

## Legt einen Innenraum an (Boden, Wände, Licht, Ausgang) und gibt seinen Mittelpunkt zurück.
## Die Räume liegen weit außerhalb der Karte; Türen im Dorf führen hinein.
func room(id: String, cols: int, rows: int, floor := "floor_wood_large") -> Vector3:
	var o = Vector3(600.0 + rooms.size() * 150.0, 0, 600)
	var w = cols * 4.0
	var dd = rows * 4.0
	flat_mesh(_box(Vector3(80, 0.2, 80)), o + Vector3(0, -0.12, 0), Color(0.04, 0.04, 0.06))
	solid(o + Vector3(0, -1, 0), Vector3(80, 1, 80))
	for x in cols:
		for z in rows:
			put("dungeon/%s.glb" % floor, o + Vector3(-w / 2.0 + 2.0 + x * 4.0, 0, -dd / 2.0 + 2.0 + z * 4.0))
		put("dungeon/%s.glb" % ("wall_window_open" if x == int(cols / 2.0) else "wall"), o + Vector3(-w / 2.0 + 2.0 + x * 4.0, 0, -dd / 2.0 - 0.5))
	for z in rows:
		put("dungeon/wall.glb", o + Vector3(-w / 2.0 - 0.5, 0, -dd / 2.0 + 2.0 + z * 4.0), PI / 2.0)
		put("dungeon/wall.glb", o + Vector3(w / 2.0 + 0.5, 0, -dd / 2.0 + 2.0 + z * 4.0), PI / 2.0)
	solid(o + Vector3(0, 0, -dd / 2.0 - 0.5), Vector3(w + 1.0, 4, 1))
	solid(o + Vector3(-w / 2.0 - 0.5, 0, 0), Vector3(1, 4, dd + 1.0))
	solid(o + Vector3(w / 2.0 + 0.5, 0, 0), Vector3(1, 4, dd + 1.0))
	solid(o + Vector3(0, 0, dd / 2.0 + 0.6), Vector3(w + 1.0, 4, 0.4))
	lamp(o + Vector3(0, 3.2, -dd / 2.0 + 1.5), Color(1.0, 0.68, 0.38), 2.6, 14.0, true)
	lamp(o + Vector3(0, 3.6, dd / 2.0 + 1.5), Color(1.0, 0.85, 0.7), 1.5, 16.0, true)
	put("dungeon/torch_mounted.glb", o + Vector3(-w / 2.0 + 1.0, 2.2, -dd / 2.0))
	put("dungeon/torch_mounted.glb", o + Vector3(w / 2.0 - 1.0, 2.2, -dd / 2.0))
	thing(o + Vector3(0, 0, dd / 2.0 - 0.6), "Hinausgehen", exit_room, 2.6)
	rooms[id] = {"o": o, "cols": cols, "rows": rows, "spots": {}}
	return o


## Grafikqualität aus den Einstellungen: 0 niedrig, 1 mittel, 2 hoch.
func apply_quality() -> void:
	if sun == null:
		return
	var q: int = int(G.opt["quality"])
	sun.shadow_enabled = q >= 1
	sun.directional_shadow_max_distance = 110.0 if q == 2 else 70.0
	env.ssao_enabled = q == 2
	env.glow_enabled = q >= 1
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X][q]
	# auf hochauflösenden Bildschirmen (Retina) die 3D-Ansicht kleiner rechnen und hochskalieren
	var hidpi = DisplayServer.screen_get_scale() > 1.5
	var sc3: float = ([0.4, 0.5, 0.75] if hidpi else [0.7, 1.0, 1.0])[q]
	get_viewport().scaling_3d_scale = sc3
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if sc3 < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	if hidpi and q < 2:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q == 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	for g in grass_chunks:
		g.visible = q >= 1
		g.multimesh.visible_instance_count = -1 if q == 2 else int(g.multimesh.instance_count / 2.0)


func fire(pos: Vector3, size := 1.0) -> void:
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.4 * size
	cone.height = 1.1 * size
	glow_mesh(cone, pos + Vector3(0, 0.55 * size, 0), Color(1.0, 0.5, 0.12), 4.0)
	lamp(pos + Vector3(0, 1.2, 0), Color(1.0, 0.55, 0.2), 2.4 * size, 12.0, true)


func seat(pos: Vector3, rot := 0.0) -> void:
	# einfache Holzbank
	var n = Node3D.new()
	n.position = pos
	n.rotation.y = rot
	add_child(n)
	flat_mesh(_box(Vector3(2.4, 0.14, 0.7)), Vector3(0, 0.7, 0), Color(0.5, 0.34, 0.2), 0.9, n)
	flat_mesh(_box(Vector3(2.4, 0.6, 0.12)), Vector3(0, 1.15, -0.32), Color(0.46, 0.31, 0.18), 0.9, n)
	for x in [-1.0, 1.0]:
		flat_mesh(_box(Vector3(0.14, 0.7, 0.6)), Vector3(x, 0.35, 0), Color(0.36, 0.24, 0.14), 0.9, n)
	solid(pos, Vector3(2.4, 0.8, 0.7), rot, 16)
	thing(pos + Vector3(0, 0, 0.9).rotated(Vector3.UP, rot), "Auf die Bank setzen", func():
		G.player.play("Sit_Chair_Idle", 1.0, true)
		fade("Du setzt dich, schaust dem Treiben zu und kommst zur Ruhe.", func():
			G.advance(0.5, true)
			G.p["fatigue"] = min(100.0, G.p["fatigue"] + 5.0)
			G.p["stamina"] = G.max_stamina()
			G.changed.emit()), 2.4)


func _home_interior() -> void:
	var o = room("spielerhaus", 3, 2)
	put("furn/rug_rectangle_A.gltf", o + Vector3(0, 0.16, 0.5), 0, 1.3)
	block("furn/bed_double_A.gltf", o + Vector3(-4.2, 0.15, -2.2), 0, 1.0, 0.9)
	block("dungeon/chest.glb", o + Vector3(-1.2, 0.15, -3.3), 0, 1.0, 0.9)
	block("food/stove_single.gltf", o + Vector3(4.6, 0.15, -3.0), 0, 1.0, 0.9)
	put("food/pot_A_stew.gltf", o + Vector3(4.6, 1.35, -3.0))
	block("furn/shelf_B_large_decorated.gltf", o + Vector3(1.6, 0.15, -3.6), 0, 1.0, 0.9)
	block("furn/table_medium.gltf", o + Vector3(3.2, 0.15, 1.6), 0, 1.0, 0.8)
	put("furn/chair_A_wood.gltf", o + Vector3(1.6, 0.15, 1.6), PI / 2.0)
	put("dungeon/plate_food_A.glb", o + Vector3(3.2, 1.15, 1.9))
	put("furn/armchair.gltf", o + Vector3(-4.6, 0.15, 2.4), PI / 2.0)
	put("furn/lamp_table.gltf", o + Vector3(3.2, 1.15, 1.2))
	put("dungeon/banner_red.glb", o + Vector3(4.0, 0, -4.0))
	put("furn/pictureframe_large_A.gltf", o + Vector3(-2.6, 2.2, -3.95))
	put("dungeon/sword_shield.glb", o + Vector3(-5.6, 0.15, 0.2), PI / 2.0)
	put("tools3d/journal_open.gltf", o + Vector3(1.6, 1.25, -3.0), 0.3)
	lamp(o + Vector3(3.2, 2.2, 1.6), Color(1.0, 0.75, 0.5), 2.0, 10.0, true)
	rooms["spielerhaus"]["spots"] = {"bed": [o + Vector3(-3.6, 0.85, -2.2), 0.0], "guests": [[o + Vector3(0.5, 0.2, 1.6), PI / 2.0], [o + Vector3(3.6, 0.2, -1.4), PI]]}
	thing(o + Vector3(-4.2, 0, -0.6), "Schlafen", func():
		G.ui.dialog("Bett", "Wie lange möchtest du schlafen?", [
			["Bis zum Morgen", func(): sleep_scene("Du schläfst tief und fest in deinem eigenen Bett.", 1.0)],
			["Zwei Stunden ausruhen", func(): fade("Du ruhst dich zwei Stunden aus.", func(): G.sleep(2.0, 1.0))],
			["Doch nicht", Callable()]]), 2.6)
	thing(o + Vector3(-1.2, 0, -2.2), "Truhe öffnen", func(): G.ui.show_chest(), 2.4)
	thing(o + Vector3(4.6, 0, -1.6), "Kochen", func(): G.ui.show_cook(), 2.4)
	thing(o + Vector3(1.6, 0, -2.4), "In den Büchern studieren (Intelligenz)", func(): train("int"), 2.2)
	thing(o + Vector3(-4.2, 0, 2.4), "Im Sessel ausruhen", func():
		G.player.play("Sit_Chair_Idle", 1.0, true)
		fade("Du sinkst in den Sessel und döst eine Stunde am Feuer.", func(): G.sleep(1.0, 0.7)), 2.2)
	thing(o + Vector3(2.4, 0, 2.6), "Am Tisch essen", func():
		var f = G.best_food()
		if f == "":
			G.say("Du hast nichts zu essen im Gepäck. In der Truhe vielleicht?")
		elif G.use_item(f):
			# in Ruhe am eigenen Tisch schmeckt es besser
			G.p["hunger"] = min(100.0, G.p["hunger"] + 8.0)
			G.heal(10.0)
			G.say("In Ruhe am eigenen Tisch gegessen (+8 Sättigung, +10 Leben)"), 2.2)
	thing(o + Vector3(-4.6, 0, 0.2), "Waffenständer (Waffen und Slots)", func(): G.ui.show_inventory(), 2.2)
	thing(o + Vector3(0.4, 0, -3.0), "Ins Tagebuch schreiben (speichern)", func(): G.save_game(), 2.0)
	# Möbel, die man im Krämerladen kaufen kann (erscheinen an festen Plätzen)
	for id in MOEBEL:
		var q: Array = MOEBEL[id]
		var n = put(q[2], o + q[3], q[4], q[5])
		n.visible = false
		moebel[id] = n
	thing(o + MOEBEL["werkbank"][3] + Vector3(0, 0, 1.4), "Werkbank: Pfeile bauen (1 Holz + 1 Eisenerz)", func():
		if G.count("holz") < 1 or G.count("erz") < 1:
			G.say("Dafür brauchst du 1 Holz und 1 Eisenerz.")
		else:
			G.add_item("holz", -1)
			G.add_item("erz", -1)
			var n = 10 + G.job_lvl("schmieden") * 2
			G.add_item("pfeil", n)
			G.job_xp("schmieden", 2)
			Audio.sfx("holz")
			G.say("%d Pfeile gebaut" % n), 2.2).condition = func(): return G.p["flags"].get("m_werkbank", false)
	thing(o + MOEBEL["wiege"][3] + Vector3(0.9, 0, 0.6), "Nach dem Kind sehen", func():
		G.p["fatigue"] = min(100.0, G.p["fatigue"] + 3.0)
		G.say("Es schläft, eine kleine Faust um deinen Finger. Dafür hütest du die Glut."), 2.0).condition = func(): return G.p["flags"].get("m_wiege", false)


func _interiors() -> void:
	# ---- Wirtshaus
	var o = room("wirtshaus", 4, 3)
	block("dungeon/table_long.glb", o + Vector3(-3.5, 0.15, -2.6), PI / 2.0, 1.0, 0.9)       # Tresen quer
	put("dungeon/shelves.glb", o + Vector3(-3.5, 0.15, -5.6))
	put("dungeon/keg_decorated.glb", o + Vector3(-7.0, 0.15, -5.0))
	put("dungeon/keg.glb", o + Vector3(-7.0, 0.15, -3.2))
	put("dungeon/barrel_small_stack.glb", o + Vector3(0.6, 0.15, -5.2))
	for q in [[-4.6, -2.6, "bottle_A_green"], [-3.6, -2.7, "bottle_B_green"], [-2.6, -2.5, "bottle_A_brown"]]:
		put("dungeon/%s.glb" % q[2], o + Vector3(q[0], 1.15, q[1]))
	put("food/food_stew.gltf", o + Vector3(-1.9, 1.15, -2.6), 0, 0.6)
	var guests = []
	for q in [[3.0, -1.5], [4.5, 3.0], [-3.5, 2.8], [0.5, 2.0]]:
		var tp = o + Vector3(q[0], 0.15, q[1])
		block("dungeon/table_medium.glb", tp, 0, 1.0, 0.8)
		put("dungeon/chair.glb", tp + Vector3(-1.9, 0, 0), PI / 2.0)
		put("dungeon/stool.glb", tp + Vector3(1.9, 0, 0))
		put("dungeon/%s.glb" % ["plate_food_A", "plate_food_B", "candle_lit", "plate_food_A"][guests.size() % 4], tp + Vector3(0, 1.0, 0))
		guests.append([tp + Vector3(-1.9, 0.2, 1.0), 1.2])
		guests.append([tp + Vector3(1.9, 0.2, 1.0), -1.2])
		thing(tp + Vector3(0, 0, 1.4), "Am Tisch Platz nehmen", func():
			G.player.play("Sit_Chair_Idle", 1.0, true)
			fade("Du setzt dich, hörst den Gesprächen zu und wärmst dich am Feuer.", func():
				G.advance(0.5, true)
				G.p["fatigue"] = min(100.0, G.p["fatigue"] + 6.0)
				G.changed.emit()), 2.0)
	flat_mesh(_box(Vector3(1.2, 2.4, 3.0)), o + Vector3(7.6, 1.2, 0.5), Color(0.38, 0.36, 0.38))
	flat_mesh(_box(Vector3(0.5, 1.4, 1.8)), o + Vector3(7.2, 0.7, 0.5), Color(0.08, 0.06, 0.06))
	fire(o + Vector3(7.0, 0.1, 0.5), 1.1)
	block("dungeon/bed_decorated.glb", o + Vector3(6.0, 0.15, -4.4), 0, 1.0, 0.9)
	put("dungeon/banner_blue.glb", o + Vector3(2.5, 0, -6.0))
	put("furn/rug_oval_B.gltf", o + Vector3(1.0, 0.16, 0.5), 0, 1.6)
	var sitze = []
	for q in [[3.0, -1.5], [4.5, 3.0], [-3.5, 2.8], [0.5, 2.0]]:
		sitze.append([o + Vector3(q[0] - 1.9, 0.2, q[1]), PI / 2.0])
	rooms["wirtshaus"]["spots"] = {"work": [o + Vector3(-3.5, 0.2, -4.4), 0.0], "guests": guests, "sitze": sitze}
	thing(o + Vector3(-3.5, 0, -0.8), "Am Tresen bestellen", func():
		if G.npcs.has("bruno") and G.npcs["bruno"].room == "wirtshaus":
			G.npcs["bruno"].interact()
		else:
			G.ui.dialog("Tresen", "Bruno ist gerade nicht da. Auf dem Tresen steht eine Schale für die Münzen.", [
				["Selbst bedienen", func(): G.ui.show_shop("dem Wirtshaus", NpcScript.STOCK["bruno"])], ["Lieber warten", Callable()]]), 2.4)
	thing(o + Vector3(-6.0, 0, -4.0), "Einen Krug Met zapfen (8 Gold)", func():
		if G.p["gold"] < 8:
			G.say("Dafür reicht dein Gold nicht.")
		else:
			G.add_gold(-8)
			G.add_item("met")
			Audio.sfx("muenze")
			G.say("Ein Krug Met. Trinken oder verschenken?"), 2.2)
	thing(o + Vector3(6.0, 0, -2.8), "Gästebett mieten (10 Gold)", func():
		if G.p["gold"] < 10:
			G.say("Ohne Münzen kein Bett.")
		else:
			G.add_gold(-10)
			sleep_scene("Du schläfst im Gästebett des Wirtshauses.", 0.85), 2.4)

	# ---- Schmiede
	o = room("schmiede", 3, 2, "floor_tile_large")
	flat_mesh(_box(Vector3(2.6, 1.2, 2.2)), o + Vector3(-4.4, 0.6, -2.8), Color(0.36, 0.34, 0.36))
	flat_mesh(_box(Vector3(1.6, 2.6, 1.2)), o + Vector3(-4.4, 2.4, -3.3), Color(0.3, 0.28, 0.3))
	fire(o + Vector3(-4.4, 1.2, -2.6), 0.9)
	solid(o + Vector3(-4.4, 0, -2.8), Vector3(2.6, 1.4, 2.2), 0.0, 16)
	block("tools3d/anvil.gltf", o + Vector3(-0.5, 0.15, -0.8), 0.3, 1.4, 0.8)
	block("tools3d/grindstone.gltf", o + Vector3(4.0, 0.15, -2.6), 0.0, 1.0, 0.8)
	block("dungeon/table_medium.glb", o + Vector3(1.8, 0.15, -3.2), 0, 1.0, 0.8)
	put("tools3d/hammer.gltf", o + Vector3(1.4, 1.05, -3.2), 0.6).rotation.x = PI / 2.0
	put("tools3d/tongs.gltf", o + Vector3(2.2, 1.05, -3.0), 1.2).rotation.x = PI / 2.0
	put("tools3d/blueprint_stacked.gltf", o + Vector3(1.8, 1.02, -3.5))
	put("dungeon/sword_shield.glb", o + Vector3(5.5, 0.15, 0.5), -PI / 2.0)
	put("dungeon/sword_shield.glb", o + Vector3(5.5, 0.15, 2.2), -PI / 2.0)
	put("res/Iron_Bars_Stack_Small.gltf", o + Vector3(-5.0, 0.15, 1.5), 0.4, 1.5)
	put("tools3d/bucket_metal.gltf", o + Vector3(-2.4, 0.15, -2.4))
	for i in 4:
		put("waffen/%s.gltf" % ["sword_B", "axe_A", "hammer_A", "spear_A"][i], o + Vector3(-1.5 + i * 1.0, 1.9, -4.0), 0).rotation.z = PI
	rooms["schmiede"]["spots"] = {"work": [o + Vector3(-0.5, 0.2, -2.0), 0.0], "guests": [[o + Vector3(2.5, 0.2, 1.0), 0.5]]}
	thing(o + Vector3(-0.5, 0, 0.4), "Am Amboss: Schmieden und Waffen kaufen", func():
		if G.p["flags"].get("smith_free", false):
			G.ui.show_smith()
		else:
			G.say("Hilda lässt dich erst an den Amboss, wenn du ihr das Erz gebracht hast (Aufgabe „Stahl und Glut“)."), 2.4)
	thing(o + Vector3(4.0, 0, -1.0), "Waffe am Schleifstein schärfen", func():
		if G.p["flags"].get("scharf_day", 0) == G.p["day"]:
			G.say("Die Klinge ist heute schon scharf.")
		else:
			G.p["flags"]["scharf_day"] = G.p["day"]
			Audio.sfx("schmiede", 1.5)
			G.say("Frisch geschärft: +10 % Schaden bis morgen früh"), 2.4)

	# ---- Krämerladen am Markt
	o = room("markt", 3, 2)
	block("dungeon/table_long.glb", o + Vector3(0, 0.15, -1.2), PI / 2.0, 1.0, 0.9)
	put("dungeon/shelves.glb", o + Vector3(-3.0, 0.15, -3.6))
	put("dungeon/shelf_large.glb", o + Vector3(2.5, 0.15, -3.6))
	put("dungeon/coin_stack_medium.glb", o + Vector3(1.4, 1.15, -1.2))
	put("dungeon/bottle_A_green.glb", o + Vector3(-1.2, 1.15, -1.1))
	put("dungeon/bottle_C_green.glb", o + Vector3(-0.6, 1.15, -1.3))
	for i in 3:
		put("food/%s.gltf" % ["crate_carrots", "crate_cheese", "crate_potatoes"][i], o + Vector3(-5.0 + i * 1.4, 0.15, 1.5), 0.2 * i, 0.9)
	put("dungeon/barrel_large.glb", o + Vector3(5.0, 0.15, 1.0))
	put("dungeon/crates_stacked.glb", o + Vector3(4.8, 0.15, -2.5))
	put("furn/rug_rectangle_B.gltf", o + Vector3(0, 0.16, 1.5), 0, 1.2)
	rooms["markt"]["spots"] = {"guests": [[o + Vector3(0, 0.2, -2.9), 0.0], [o + Vector3(-2.5, 0.2, 1.5), 1.0]]}
	thing(o + Vector3(0, 0, 0.6), "Waren ansehen (Handel)", func(): G.ui.show_shop("dem Krämerladen", NpcScript.STOCK["mira"]), 2.4)
	thing(o + Vector3(4.2, 0, -1.4), "Möbel für dein Haus ansehen", func(): G.ui.show_moebel(), 2.4)

	# ---- Studierstube
	o = room("studierstube", 3, 2)
	for i in 3:
		block("furn/shelf_B_large_decorated.gltf", o + Vector3(-4.0 + i * 2.6, 0.15, -3.6), 0, 1.0, 0.9)
	block("furn/table_medium.gltf", o + Vector3(1.0, 0.15, 0.6), 0, 1.0, 0.8)
	put("tools3d/journal_open.gltf", o + Vector3(1.0, 1.15, 0.6), 0.2)
	put("tools3d/map_rolled.gltf", o + Vector3(1.8, 1.15, 0.9), 0.8)
	put("dungeon/candle_triple.glb", o + Vector3(0.2, 1.15, 0.3))
	put("furn/chair_A_wood.gltf", o + Vector3(1.0, 0.15, -0.6))
	put("furn/armchair.gltf", o + Vector3(-4.6, 0.15, 1.8), PI / 2.0)
	put("furn/rug_oval_A.gltf", o + Vector3(-1.5, 0.16, 1.2), 0, 1.4)
	put("furn/book_set.gltf", o + Vector3(4.6, 0.15, 1.5))
	glow_mesh(_sphere(0.3), o + Vector3(4.8, 1.6, -2.6), Color(0.4, 0.8, 1.0), 2.0)
	flat_mesh(_cyl(0.25, 1.3), o + Vector3(4.8, 0.65, -2.6), Color(0.35, 0.33, 0.4))
	rooms["studierstube"]["spots"] = {"work": [o + Vector3(1.0, 0.2, -0.8), 0.0], "guests": [[o + Vector3(-3.0, 0.2, 1.5), 1.0]]}
	var lore = ["Vom Ersten Hüter: „Als die Welt noch in Asche lag, trug Alderan die Glut vom Berg herab. Zwölf Schalen ließ er errichten, und solange eine brennt, schläft die Asche.“",
		"Über den Aschenschlaf: „Wen die Asche berührt, der vergisst zuerst seinen Namen, dann sein Gesicht. Was bleibt, sind Knochen, die noch marschieren.“",
		"Randnotiz in Elaras Handschrift: „Die Glutblumen wachsen nur, wo eine Schale einmal brannte. Sie erinnern sich für uns.“",
		"Aus der Dorfchronik: „Aschfurt hieß einst Glutfurt. Den Namen änderte man im Jahr, als die dritte Schale erlosch.“"]
	thing(o + Vector3(-1.4, 0, -2.2), "In alten Schriften lesen", func():
		var first = G.p["flags"].get("lese_day", 0) != G.p["day"]
		G.p["flags"]["lese_day"] = G.p["day"]
		G.ui.dialog("Alte Schriften", lore[(G.p["day"] + G.p["kills"]) % lore.size()] + ("\n\n(Du lernst etwas dazu: +15 Erfahrung)" if first else ""), [["Zuklappen", func():
			if first: G.add_xp(15)]]), 2.4)
	block("dungeon/table_small.glb", o + Vector3(-4.6, 0.15, -1.2), 0, 1.0, 0.8)
	put("dungeon/bottle_A_green.glb", o + Vector3(-4.8, 1.0, -1.2))
	put("dungeon/bottle_B_green.glb", o + Vector3(-4.3, 1.0, -1.0))
	put("dungeon/bottle_A_brown.glb", o + Vector3(-4.5, 1.0, -1.5))
	thing(o + Vector3(-4.6, 0, 0.0), "Alchemietisch: Tränke brauen", func(): G.ui.show_alchemie(), 2.2)
	thing(o + Vector3(4.2, 0, -1.6), "Den Glutkristall berühren", func():
		G.p["mana"] = G.max_mana()
		Audio.sfx("zauber")
		G.say("Dein Mana ist wieder aufgefüllt."), 2.2)

	# ---- Wache
	o = room("wache", 3, 2, "floor_tile_large")
	block("dungeon/bed_decorated.glb", o + Vector3(-4.6, 0.15, -2.6), 0, 1.0, 0.9)
	block("dungeon/bed_decorated.glb", o + Vector3(-2.2, 0.15, -2.6), 0, 1.0, 0.9)
	block("dungeon/table_medium.glb", o + Vector3(2.5, 0.15, 0.0), 0, 1.0, 0.8)
	put("tools3d/map.gltf", o + Vector3(2.5, 1.02, 0.0), 0.1)
	put("tools3d/lantern.gltf", o + Vector3(3.3, 1.02, -0.4), 0, 0.7)
	put("dungeon/sword_shield.glb", o + Vector3(1.5, 0.15, -3.8))
	put("dungeon/sword_shield.glb", o + Vector3(3.6, 0.15, -3.8))
	put("dungeon/banner_red.glb", o + Vector3(5.2, 0, -4.0))
	put("dungeon/trunk_large_A.glb", o + Vector3(5.0, 0.15, 2.0), -PI / 2.0)
	put("dungeon/barrel_large.glb", o + Vector3(-5.2, 0.15, 2.2))
	rooms["wache"]["spots"] = {"guests": [[o + Vector3(1.0, 0.2, 1.4), 0.6]]}
	thing(o + Vector3(2.5, 0, 1.4), "Die Karte der Wache studieren", func(): G.ui.show_map(), 2.4)
	thing(o + Vector3(5.0, 0, 0.8), "Vorratskiste der Wache", func():
		if G.p["flags"].get("wache_day", 0) == G.p["day"]:
			G.say("Für heute hast du deine Ration schon geholt.")
		else:
			G.p["flags"]["wache_day"] = G.p["day"]
			G.add_item("brot")
			G.add_item("heiltrank")
			G.say("Tagesration der Glutwacht: Brot und ein Heiltrank"), 2.4)

	# ---- Gasthaus zum Hecht in Weidenau
	o = room("b_wirtshaus", 3, 2)
	block("dungeon/table_long.glb", o + Vector3(-2.5, 0.15, -1.8), PI / 2.0, 1.0, 0.9)        # Tresen quer
	put("dungeon/keg_decorated.glb", o + Vector3(-5.2, 0.15, -3.0))
	put("dungeon/shelves.glb", o + Vector3(1.4, 0.15, -3.7))
	put("dungeon/bottle_A_green.glb", o + Vector3(-3.4, 1.15, -1.8))
	put("food/food_dinner.gltf", o + Vector3(-1.6, 1.15, -1.8), 0, 0.5)
	var bg = []
	for q in [[3.0, -1.0], [3.0, 2.2], [-3.2, 2.0]]:
		var tp = o + Vector3(q[0], 0.15, q[1])
		block("dungeon/table_medium.glb", tp, 0, 1.0, 0.8)
		put("dungeon/stool.glb", tp + Vector3(-1.8, 0, 0))
		put("dungeon/stool.glb", tp + Vector3(1.8, 0, 0))
		bg.append([tp + Vector3(-1.8, 0.2, 1.0), 1.2])
	block("dungeon/bed_decorated.glb", o + Vector3(4.6, 0.15, -2.8), 0, 1.0, 0.9)
	put("tools3d/rope_bundle_A.gltf", o + Vector3(5.2, 0.15, 1.8))
	put("dungeon/banner_green.glb", o + Vector3(1.2, 0, -4.0))
	fire(o + Vector3(-5.4, 0.1, 1.6), 0.9)
	rooms["b_wirtshaus"]["spots"] = {"work": [o + Vector3(-2.5, 0.2, -3.5), 0.0], "guests": bg}
	thing(o + Vector3(-2.5, 0, -0.1), "Am Tresen bestellen", func():
		if G.npcs.has("walda") and G.npcs["walda"].room == "b_wirtshaus":
			G.npcs["walda"].interact()
		else:
			G.ui.show_shop("dem Gasthaus zum Hecht", NpcScript.STOCK["walda"]), 2.4)
	thing(o + Vector3(4.6, 0, -1.2), "Gästebett mieten (10 Gold)", func():
		if G.p["gold"] < 10:
			G.say("Ohne Münzen kein Bett.")
		else:
			G.add_gold(-10)
			sleep_scene("Du schläfst im Gasthaus zum Hecht. Draußen plätschert der See.", 0.85), 2.4)

	# ---- Wohnhäuser der Dorfbewohner
	var n = 0
	for id in NpcScript.PEOPLE:
		var key = "haus_" + id
		if not places.has(key):
			continue
		o = room(key, 2, 2)
		var single = n % 2 == 0
		block("furn/bed_single_%s.gltf" % ("A" if n % 4 < 2 else "B"), o + Vector3(-2.6, 0.15, -2.0), 0, 1.0, 0.9)
		block("furn/table_small.gltf" if single else "furn/table_medium.gltf", o + Vector3(1.8, 0.15, 0.8), 0, 1.0, 0.8)
		put("furn/chair_%s_wood.gltf" % ("A" if single else "B"), o + Vector3(0.5, 0.15, 0.8), PI / 2.0)
		block("furn/%s.gltf" % ["cabinet_medium_decorated", "shelf_A_big", "cabinet_small_decorated", "shelf_B_large_decorated"][n % 4], o + Vector3(1.6, 0.15, -3.5), 0, 1.0, 0.9)
		put("furn/%s.gltf" % ["rug_oval_A", "rug_rectangle_stripes_A", "rug_rectangle_B", "rug_oval_B"][n % 4], o + Vector3(0, 0.16, 0.6), 0, 1.0)
		put("dungeon/%s.glb" % ["candle_lit", "plate_food_B", "candle_triple", "plate_food_A"][n % 4], o + Vector3(1.8, 1.0, 0.8))
		put("furn/pictureframe_medium.gltf", o + Vector3(-0.8, 2.2, -3.95))
		put("dungeon/%s.glb" % ["banner_green", "banner_yellow", "banner_blue", "banner_red"][n % 4], o + Vector3(3.2, 0, -4.0))
		put("dungeon/trunk_medium_A.glb", o + Vector3(-3.2, 0.15, 1.8), PI / 2.0)
		rooms[key]["spots"] = {"bed": [o + Vector3(-2.6, 0.85, -2.0), 0.0], "guests": [[o + Vector3(0.6, 0.2, 2.0), 0.4], [o + Vector3(1.8, 0.2, -1.2), PI]]}
		n += 1

	# ---- Türen im Dorf
	var names = {"wirtshaus": "Wirtshaus", "schmiede": "Schmiede", "markt": "Krämerladen", "studierstube": "Studierstube", "wache": "Wache", "b_wirtshaus": "Gasthaus zum Hecht"}
	for id in rooms:
		if id == "spielerhaus":
			continue
		var label = names.get(id, room_names.get(id, ""))
		if label == "":
			label = "Haus von " + NpcScript.PEOPLE[id.trim_prefix("haus_")]["name"].replace("Hauptmann ", "")
		thing(places[id], label + " betreten", func(): enter_room(id), 3.0)


func enter_room(id: String) -> void:
	var rd: Dictionary = rooms[id]
	G.p["inside"] = true
	G.p["room"] = id
	G.p["room_door"] = id
	G.player.global_position = rd["o"] + Vector3(0, 0.4, rd["rows"] * 2.0 - 2.0)
	G.player.body.rotation.y = PI
	G.player.cam_yaw = 0.0
	G.player.cam_dist = 12.0 + rd["cols"] * 1.2
	G.player.snap_camera()
	Audio.sfx("tuer")


func exit_room() -> void:
	var id: String = G.p.get("room", "spielerhaus")
	if id == "thron":        # der Aschenthron führt zurück in die Aschenlande, nicht nach draußen
		G.p["room"] = "asche"
		G.player.global_position = THRON_TOR + Vector3(0, 0.4, 4.0)
		G.player.snap_camera()
		Audio.sfx("tuer")
		return
	var gebiet: String = G.p.get("region", "")
	G.p["inside"] = gebiet != ""
	G.p["room"] = gebiet
	var mid: Vector3 = GEBIETE[gebiet][0] if gebiet != "" else Vector3.ZERO
	G.player.global_position = places[id] + Vector3(0, 0.4, 0) + Vector3(mid.x - places[id].x, 0, mid.z - places[id].z).normalized() * 1.5
	G.player.cam_dist = 19.0
	G.player.snap_camera()
	Audio.sfx("klick")


# ---------------------------------------------------------------- Dungeons und Glutschalen

func _dungeons() -> void:
	var n = 0
	for id in EINGAENGE:
		dungeons[id] = {}
		Dungeon.build(self, id, Vector3(-200.0 + n * 220.0, 0, 1500.0))
		places[id] = EINGAENGE[id]
		far_keys.append(id)
		var ep: Vector3 = EINGAENGE[id]
		put("dungeon/wall_doorway.glb", ep + Vector3(0, 0, -1.2))
		put("dungeon/stairs.glb", ep + Vector3(0, -3.2, 2.5), PI) if ResourceLoader.exists("res://assets/dungeon/stairs.glb") else null
		lamp(ep + Vector3(0, 3, 1), Color(1.0, 0.5, 0.25), 2.0, 12.0, true)
		var nm: String = Dungeon.PLAENE[id]["name"]
		thing(ep + Vector3(0, 0, 1.2), "%s betreten (Dungeon, Fackel empfohlen)" % nm, func(): enter_dungeon(id), 3.4)
		n += 1


func enter_dungeon(id: String) -> void:
	G.p["flags"]["ort_" + id] = true
	G.p["inside"] = true
	G.p["room"] = id
	G.p["room_door"] = id
	G.player.global_position = dungeons[id]["start"] + Vector3(1.2, 0.4, 1.2)
	G.player.cam_dist = 17.0
	G.player.snap_camera()
	Audio.sfx("tuer")
	G.say(Dungeon.PLAENE[id]["name"] + ". Es ist stockfinster." + ("" if G.p.get("torch", false) else " Taste T zündet eine Fackel an."))


func open_gate(g: Node, instant := false) -> void:
	g.collision_layer = 0
	if instant:
		g.position.y = -2.4
	else:
		create_tween().tween_property(g, "position:y", -2.4, 1.6)


# ---------------------------------------------------------------- Weitere Dörfer auf eigenen Karten

## Legt den Boden, die Grenzen und die Landschaft eines Gebiets an.
func _land(c: Vector3, ground: Color, n_trees: int, bare := false) -> void:
	var g = flat_mesh(_box(Vector3(380, 0.1, 380)), c, ground, 1.0)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		var a = i * PI / 2.0
		solid(c + Vector3(sin(a), 0, cos(a)) * 182.0, Vector3(380, 30, 4), a)
	for i in 30:
		var a = i * TAU / 30.0
		put("hex/mountain_%s%s.gltf" % [["A", "B", "C"][i % 3], ["", "_grass"][i % 2] if not bare else ""], c + Vector3(sin(a), 0, cos(a)) * rng.randf_range(192, 220) + Vector3(0, -2, 0), rng.randf() * TAU, rng.randf_range(32, 52))
	var k = 0
	while k < n_trees:
		var p = c + Vector3(rng.randf_range(-172, 172), 0, rng.randf_range(-172, 172))
		if p.distance_to(c) > 46.0:
			_tree(p, bare and k % 3 == 0)
		k += 1
	for i in 70:
		var p = c + Vector3(rng.randf_range(-172, 172), 0, rng.randf_range(-172, 172))
		if p.distance_to(c) > 30.0:
			forest(ROCKS[i % ROCKS.size()] if i % 2 == 0 else BUSHES[i % BUSHES.size()], p, rng.randf_range(0.9, 1.8))


## Baut ein Dorf: Brunnen, Wirtshaus, Wohnhäuser, Laternen, Bänke, Wege.
func _dorf(pre: String, m: Vector3, inn_name: String, keeper: String, homes: Array, weg := Color(0.6, 0.5, 0.34)) -> void:
	var keys = [pre + "_brunnen", pre + "_wirtshaus"]
	places[pre + "_brunnen"] = m
	block("hex/building_well_blue.gltf", m, 0, S * 0.7, 0.6)
	_house("building_tavern_blue", m + Vector3(-22, 0, -14), pre + "_wirtshaus", S, m)
	room_names[pre + "_wirtshaus"] = inn_name
	var models = ["building_home_A_red", "building_home_B_yellow", "building_home_A_green", "building_home_B_red", "building_home_A_yellow"]
	for i in homes.size():
		var a = 0.6 + i * TAU / (homes.size() + 1.5)
		_house(models[i % models.size()], m + Vector3(sin(a) * 27.0, 0, cos(a) * 27.0), "haus_" + homes[i], S, m)
		keys.append("haus_" + homes[i])
	for key in keys:
		if key == pre + "_brunnen":
			continue
		# Weg vom Brunnen zur Tür
		var d: Vector3 = places[key] - m
		var strip = flat_mesh(_box(Vector3(3.0, 0.06, d.length())), m + d / 2.0 + Vector3(0, 0.06, 0), weg, 1.0)
		strip.rotation.y = atan2(d.x, d.z)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 6:
		var a = i * TAU / 6.0 + 0.3
		var lp = m + Vector3(sin(a), 0, cos(a)) * 12.0
		flat_mesh(_cyl(0.12, 3.2), lp + Vector3(0, 1.6, 0), Color(0.25, 0.2, 0.16))
		put("tools3d/lantern.gltf", lp + Vector3(0, 3.1, 0), 0.0, 0.9)
		pillar(lp, 0.2, 3.0)
		if i % 2 == 0:
			lamp(lp + Vector3(0, 3.4, 0))
	seat(m + Vector3(5, 0, 5), -2.4)
	seat(m + Vector3(-5, 0, 6), 2.4)
	for i in 10:
		var a = rng.randf() * TAU
		var tp = m + Vector3(sin(a), 0, cos(a)) * rng.randf_range(34.0, 44.0)
		forest(TREES[rng.randi() % 8], tp, rng.randf_range(1.8, 2.6), true)
		pillar(tp, 0.6, 6.0)
	for k in 4:
		critter("huhn", m + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(6, 14)), 6.0)
	_inn(pre + "_wirtshaus", keeper, inn_name)
	for key in keys:
		far_keys.append(key)
	dorf_spots[pre] = [pre + "_brunnen"]


## Richtet ein Wirtshaus ein (Tresen, Tische, Kamin, Gästebett).
func _inn(key: String, keeper: String, title: String) -> void:
	var o = room(key, 3, 2)
	block("dungeon/table_long.glb", o + Vector3(-2.5, 0.15, -1.8), PI / 2.0, 1.0, 0.9)        # Tresen quer
	put("dungeon/keg_decorated.glb", o + Vector3(-5.2, 0.15, -3.0))
	put("dungeon/shelves.glb", o + Vector3(1.4, 0.15, -3.7))
	put("dungeon/bottle_A_green.glb", o + Vector3(-3.4, 1.15, -1.8))
	put("dungeon/plate_food_A.glb", o + Vector3(-1.6, 1.15, -1.8))
	var bg = []
	var sitze = []
	for q in [[3.0, -1.0], [3.0, 2.2], [-3.2, 2.0]]:
		var tp = o + Vector3(q[0], 0.15, q[1])
		block("dungeon/table_medium.glb", tp, 0, 1.0, 0.8)
		put("dungeon/chair.glb", tp + Vector3(-1.8, 0, 0), PI / 2.0)
		put("dungeon/stool.glb", tp + Vector3(1.8, 0, 0))
		bg.append([tp + Vector3(1.8, 0.2, 1.0), -1.2])
		sitze.append([tp + Vector3(-1.8, 0.2, 0), PI / 2.0])
	block("dungeon/bed_decorated.glb", o + Vector3(4.6, 0.15, -2.8), 0, 1.0, 0.9)
	put("dungeon/banner_blue.glb", o + Vector3(1.2, 0, -4.0))
	put("furn/rug_oval_A.gltf", o + Vector3(0, 0.16, 1.0), 0, 1.4)
	fire(o + Vector3(-5.4, 0.1, 1.6), 0.9)
	rooms[key]["spots"] = {"work": [o + Vector3(-2.5, 0.2, -3.5), 0.0], "guests": bg, "sitze": sitze}
	thing(o + Vector3(-2.5, 0, -0.1), "Am Tresen bestellen", func():
		if G.npcs.has(keeper) and G.npcs[keeper].room == key:
			G.npcs[keeper].interact()
		else:
			G.ui.show_shop(title, NpcScript.STOCK[keeper]), 2.4)
	thing(o + Vector3(4.6, 0, -1.2), "Gästebett mieten (10 Gold)", func():
		if G.p["gold"] < 10:
			G.say("Ohne Münzen kein Bett.")
		else:
			G.add_gold(-10)
			sleep_scene("Du schläfst im Gästezimmer von „%s“." % title, 0.85), 2.4)


func _hoehle(id: String, n: int, entrance: Vector3) -> void:
	dungeons[id] = {}
	Dungeon.build(self, id, Vector3(-200.0 + n * 220.0, 0, 1800.0))
	places[id] = entrance
	far_keys.append(id)
	put("dungeon/wall_doorway.glb", entrance + Vector3(0, 0, -1.2))
	lamp(entrance + Vector3(0, 3, 1), Color(1.0, 0.5, 0.25), 2.0, 12.0, true)
	thing(entrance + Vector3(0, 0, 1.2), "%s betreten (Dungeon, Fackel empfohlen)" % Dungeon.PLAENE[id]["name"], func(): enter_dungeon(id), 3.4)


func _lager(zone: String, camp: String, pos: Vector3, list: Array, power: float) -> void:
	for k in list:
		dungeon_spawns.append([k, pos + Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-7, 7)), camp, power, zone])


func _gebiete() -> void:
	# ============ Salzhafen: Hafenstadt am Meer
	var sc: Vector3 = GEBIETE["salzhafen"][0]
	_land(sc, Color(0.56, 0.6, 0.36), 110)
	_dorf("salz", sc + Vector3(0, 0, -14), "Zum Anker", "greta", ["greta", "marek", "nele", "ole"], Color(0.72, 0.66, 0.48))
	var sea = flat_mesh(_box(Vector3(380, 0.1, 150)), sc + Vector3(0, 0.08, 135), Color(0.12, 0.36, 0.56), 0.08)
	sea.material_override.metallic = 0.5
	solid(sc + Vector3(0, 0, 64), Vector3(380, 6, 2))
	flat_mesh(_box(Vector3(380, 0.08, 14)), sc + Vector3(0, 0.07, 55), Color(0.82, 0.76, 0.56), 1.0)     # Strand
	places["salz_steg"] = sc + Vector3(12, 0, 50)
	places["salz_markt"] = sc + Vector3(24, 0, 10)
	places["salz_turm"] = sc + Vector3(-112, 0, 36)
	for i in 9:
		flat_mesh(_box(Vector3(3.4, 0.25, 2.4)), places["salz_steg"] + Vector3(0, 0.5, 4.0 + i * 2.4), Color(0.46, 0.33, 0.2))
	var ship = Node3D.new()
	ship.position = places["salz_steg"] + Vector3(6.5, 0.3, 22)
	add_child(ship)
	flat_mesh(_box(Vector3(5.0, 2.0, 16.0)), Vector3(0, 0.6, 0), Color(0.42, 0.26, 0.14), 0.9, ship)
	flat_mesh(_box(Vector3(4.0, 0.3, 14.0)), Vector3(0, 1.7, 0), Color(0.6, 0.45, 0.28), 0.9, ship)
	flat_mesh(_cyl(0.25, 12.0), Vector3(0, 7.5, 0), Color(0.36, 0.25, 0.15), 0.9, ship)
	flat_mesh(_box(Vector3(6.0, 6.0, 0.15)), Vector3(0, 8.5, 0.4), Color(0.92, 0.9, 0.82), 0.9, ship)
	thing(places["salz_steg"] + Vector3(0, 0, 20), "", func():
		var cost = 0 if G.p["flags"].get("schiff_frei", false) else 15
		reise("", places["b_steg"], "Die Möwe legt ab. Salzhafen wird kleiner, der See von Weidenau kommt in Sicht.", cost), 4.0).label_fn = func(): return "Mit dem Schiff nach Weidenau%s" % ("" if G.p["flags"].get("schiff_frei", false) else " (15 Gold)")
	for i in 5:       # Fischmarkt
		var sp = places["salz_markt"] + Vector3(i * 3.6 - 6, 0, 3)
		flat_mesh(_box(Vector3(2.6, 1.0, 1.4)), sp + Vector3(0, 0.5, 0), Color(0.5, 0.36, 0.22))
		for st in 5:
			flat_mesh(_box(Vector3(0.56, 0.08, 1.9)), sp + Vector3(-1.12 + st * 0.56, 2.65, 0), Color(0.2, 0.45, 0.7) if st % 2 == 0 else Color(0.97, 0.95, 0.9)).rotation.x = 0.22
		for cx in [-1.2, 1.2]:
			flat_mesh(_cyl(0.07, 2.6), sp + Vector3(cx, 1.3, -0.6), Color(0.35, 0.25, 0.16))
		solid(sp, Vector3(2.6, 1.0, 1.4), 0.0, 16)
	for q in [["barrel_large", 16, 44], ["crates_stacked", 6, 46], ["box_large", 18, 40], ["barrel_large", -4, 44]]:
		put("dungeon/%s.glb" % q[0], sc + Vector3(q[1], 0, q[2]), rng.randf() * TAU, 0.9)
	block("hex/building_tower_A_blue.gltf", places["salz_turm"] + Vector3(0, 0, -8), 0, 16.0, 0.6, 1)
	glow_mesh(_sphere(1.2), places["salz_turm"] + Vector3(0, 26, -8), Color(1.0, 0.85, 0.4), 1.0)
	_hoehle("leuchtturm", 0, places["salz_turm"] + Vector3(0, 0, 2))
	for k in 6:
		critter("ente", sc + Vector3(rng.randf_range(-40, 60), 0.12, 80), rng.randf_range(4.0, 10.0))
	for k in 10:
		critter("vogel", sc + Vector3(rng.randf_range(-100, 100), rng.randf_range(20, 34), rng.randf_range(20, 120)), rng.randf_range(16, 40), Color(0.95, 0.95, 0.98))
	_lager("salzhafen", "salz_strand", sc + Vector3(110, 0, 36), ["bandit", "bandit", "schuetze", "schlaeger", "bandit"], 1.7)
	_lager("salzhafen", "salz_wald", sc + Vector3(-70, 0, -110), ["bandit", "bandit", "schuetze"], 1.6)
	_lager("salzhafen", "salz_wald", sc + Vector3(90, 0, -100), ["wolf", "wolf", "wolf"], 1.5)
	dorf_spots["salz"] = ["salz_brunnen", "salz_steg", "salz_markt"]
	far_keys.append_array(["salz_steg", "salz_markt", "salz_turm"])

	# ============ Hochwacht: Bergdorf im Schnee
	var hc: Vector3 = GEBIETE["hochwacht"][0]
	_land(hc, Color(0.9, 0.92, 0.96), 150, true)
	_dorf("hoch", hc, "Berghütte", "sigrun", ["sigrun", "bjarne", "torvald", "ylva"], Color(0.62, 0.62, 0.66))
	places["hoch_schmiede"] = hc + Vector3(24, 0, 12)
	places["hoch_alm"] = hc + Vector3(-40, 0, 44)
	places["hoch_pfad"] = hc + Vector3(0, 0, 160)
	block("tools3d/anvil.gltf", places["hoch_schmiede"] + Vector3(2, 0, 0), 0.4, 1.4, 0.8)
	block("tools3d/grindstone.gltf", places["hoch_schmiede"] + Vector3(-3, 0, 2), 1.1, 1.0, 0.8)
	flat_mesh(_box(Vector3(2.6, 1.2, 2.2)), places["hoch_schmiede"] + Vector3(4, 0.6, -4), Color(0.36, 0.34, 0.36))
	fire(places["hoch_schmiede"] + Vector3(4, 1.2, -4), 0.9)
	put("res/Iron_Bars_Stack_Small.gltf", places["hoch_schmiede"] + Vector3(-2, 0, -3), 0.4, 1.5)
	for i in 4:
		put("waffen/%s.gltf" % ["sword_D", "axe_C", "hammer_C", "halberd"][i], places["hoch_schmiede"] + Vector3(-1.5 + i * 1.1, 1.2, -5.5), 0)
	thing(places["hoch_schmiede"] + Vector3(2, 0, 1.6), "Bjarnes Amboss: schmieden und Waffen kaufen", func(): G.ui.show_smith(), 2.6)
	for i in 30:
		forest(["Rock_1_K", "Rock_3_L", "Rock_2_G", "Rock_1_M"][i % 4], hc + Vector3(rng.randf_range(-165, 165), 0, rng.randf_range(-165, 165)).normalized() * rng.randf_range(60, 170), rng.randf_range(0.8, 1.6))
	thing(places["hoch_pfad"], "Den Bergpfad hinab zum Wachturm", func():
		reise("", Vector3(270, 0, -226), "Du steigst den Bergpfad hinab. Der Schnee wird Geröll, das Geröll wird Gras, und unter dir taucht der Wachturm auf."), 4.0)
	flat_mesh(_cyl(0.1, 3.0), places["hoch_pfad"] + Vector3(2, 1.5, 0), Color(0.36, 0.25, 0.15))
	flat_mesh(_box(Vector3(1.8, 0.4, 0.08)), places["hoch_pfad"] + Vector3(2, 2.6, 0), Color(0.55, 0.4, 0.24))
	_hoehle("eishoehle", 1, hc + Vector3(-124, 0, -104))
	for i in 10:
		glow_mesh(_box(Vector3(0.5, rng.randf_range(1.5, 3.5), 0.5)), hc + Vector3(-124 + rng.randf_range(-9, 9), 1.2, -110 + rng.randf_range(-6, 2)), Color(0.6, 0.85, 1.0), 0.8)
	_lager("hochwacht", "hoch_wolf", hc + Vector3(94, 0, -80), ["wolf", "wolf", "wolf", "wolf"], 1.8)
	_lager("hochwacht", "hoch_wolf", hc + Vector3(-84, 0, 70), ["wolf", "wolf", "wolf"], 1.8)
	_lager("hochwacht", "hoch_geist", hc + Vector3(110, 0, 96), ["geist", "geist", "geist"], 1.9)
	dorf_spots["hoch"] = ["hoch_brunnen", "hoch_schmiede", "hoch_alm"]
	far_keys.append_array(["hoch_schmiede", "hoch_alm", "hoch_pfad"])

	# ============ Dornfeld: Bauern- und Marktdorf in der Ebene
	var dc: Vector3 = GEBIETE["dornfeld"][0]
	_land(dc, Color(0.62, 0.62, 0.3), 60)
	_dorf("dorn", dc, "Zur goldenen Ähre", "konrad", ["konrad", "rosalind", "hedda", "veit"], Color(0.7, 0.6, 0.4))
	places["dorn_markt"] = dc + Vector3(22, 0, 16)
	places["dorn_feld"] = dc + Vector3(-52, 0, 30)
	places["dorn_kutsche"] = dc + Vector3(0, 0, 62)
	var bright = [Color(1.0, 0.3, 0.3), Color(1.0, 0.8, 0.2), Color(0.95, 0.5, 0.85), Color(0.5, 0.6, 1.0), Color(0.3, 0.7, 0.4), Color(0.98, 0.98, 1.0)]
	for i in 8:       # großer Markt in zwei Reihen
		var sp = places["dorn_markt"] + Vector3((i % 4) * 3.8 - 6, 0, 3 + int(i / 4.0) * 6.0)
		flat_mesh(_box(Vector3(2.6, 1.0, 1.4)), sp + Vector3(0, 0.5, 0), Color(0.5, 0.36, 0.22))
		for st in 5:
			flat_mesh(_box(Vector3(0.56, 0.08, 1.9)), sp + Vector3(-1.12 + st * 0.56, 2.65, 0), bright[i % bright.size()] if st % 2 == 0 else Color(0.97, 0.95, 0.9)).rotation.x = 0.22
		for cx in [-1.2, 1.2]:
			flat_mesh(_cyl(0.07, 2.6), sp + Vector3(cx, 1.3, -0.6), Color(0.35, 0.25, 0.16))
		put("food/%s.gltf" % ["crate_carrots", "crate_cheese", "crate_potatoes", "food_ingredient_tomato"][i % 4], sp + Vector3(0, 1.0, 0), 0.0, 0.7)
		solid(sp, Vector3(2.6, 1.0, 1.4), 0.0, 16)
	for i in 14:      # Blumenstand von Rosalind
		flat_mesh(_sphere(0.2), places["dorn_markt"] + Vector3(-9 + (i % 7) * 0.5, 1.2 + (i % 2) * 0.15, -2 + int(i / 7.0) * 0.6), bright[i % bright.size()])
	flat_mesh(_box(Vector3(4.0, 1.0, 1.6)), places["dorn_markt"] + Vector3(-7.5, 0.5, -1.7), Color(0.5, 0.36, 0.22))
	for fx in 4:      # Felder
		var fo = dc + Vector3(-90 + fx * 22, 0, 26)
		flat_mesh(_box(Vector3(18, 0.08, 40)), fo + Vector3(0, 0.07, 0), Color(0.42, 0.3, 0.18) if fx % 2 == 0 else Color(0.8, 0.7, 0.3), 1.0)
		if fx % 2 == 0:
			for i in 24:
				put("food/food_ingredient_%s.gltf" % ["carrot", "lettuce", "potato"][fx % 3], fo + Vector3(-6 + (i % 4) * 4.0, 0.08, -17 + int(i / 4.0) * 6.6), rng.randf() * TAU, 0.8)
	_house("building_windmill_blue", dc + Vector3(64, 0, -52), "", 11.0, dc)
	_house("building_grain", dc + Vector3(-66, 0, -30), "", 9.0, dc) if ResourceLoader.exists("res://assets/hex/building_grain.gltf") else null
	# Turnierplatz (noch ohne Turnier)
	var ar = dc + Vector3(-72, 0, -64)
	flat_mesh(_cyl(16.0, 0.1), ar + Vector3(0, 0.07, 0), Color(0.72, 0.62, 0.4), 1.0)
	for i in 28:
		var a = i * TAU / 28.0
		if i % 14 != 0:
			put("hex/fence_wood_straight.gltf", ar + Vector3(sin(a), 0, cos(a)) * 16.5, a + PI / 2.0, 3.2)
	for i in 4:
		put("hex/flag_%s.gltf" % ["red", "yellow", "green", "blue"][i], ar + Vector3(sin(i * PI / 2.0 + 0.4), 0, cos(i * PI / 2.0 + 0.4)) * 18.5, 0, 12.0)
	arena = ar
	var ti = thing(ar + Vector3(0, 0, 18), "", func():
		if turnier > 0:
			G.say("Das Turnier läuft: Runde %d von 4." % turnier)
		elif G.p["flags"].get("turnier_day", 0) == G.p["day"]:
			G.say("Für heute ist das Turnier vorbei. Morgen wieder.")
		else:
			G.ui.dialog("Turnier von Dornfeld", "Vier Runden, jede schwerer als die letzte. Preisgeld: 60, 120, 200 und 400 Gold. Wer den Turniermeister schlägt, trägt den Titel „Meister von Dornfeld“.\nStartgeld: 30 Gold. Wer fällt, scheidet aus und behält, was er bis dahin gewonnen hat.", [
				["Antreten (30 Gold)", func():
					if G.p["gold"] < 30:
						G.say("Dir fehlt das Startgeld.")
					else:
						G.add_gold(-30)
						G.p["flags"]["turnier_day"] = G.p["day"]
						_turnier_runde(1)],
				["Lieber zusehen", Callable()]]), 3.4)
	ti.label_fn = func(): return "Am Turnier teilnehmen" if turnier == 0 else "Turnier läuft"
	# Kutsche
	var kp: Vector3 = places["dorn_kutsche"] + Vector3(4, 0, 0)
	flat_mesh(_box(Vector3(2.6, 1.6, 4.4)), kp + Vector3(0, 1.6, 0), Color(0.5, 0.3, 0.18))
	flat_mesh(_box(Vector3(2.8, 0.2, 4.6)), kp + Vector3(0, 2.5, 0), Color(0.3, 0.2, 0.12))
	for q in [[-1.4, 1.4], [1.4, 1.4], [-1.4, -1.4], [1.4, -1.4]]:
		var wheel = flat_mesh(_cyl(0.8, 0.2), kp + Vector3(q[0], 0.8, q[1]), Color(0.25, 0.17, 0.1))
		wheel.rotation.z = PI / 2.0
	solid(kp, Vector3(2.8, 2.6, 4.6), 0.0, 16)
	thing(places["dorn_kutsche"], "Mit der Kutsche nach Aschfurt (10 Gold)", func():
		reise("", places["tor"], "Die Kutsche rumpelt über die Feldwege nach Norden, bis das Südtor von Aschfurt auftaucht.", 10), 3.6)
	_lager("dornfeld", "dorn_raeuber", dc + Vector3(124, 0, 60), ["schlaeger", "bandit", "bandit", "schuetze", "bandit"], 1.8)
	_lager("dornfeld", "dorn_raeuber", dc + Vector3(-126, 0, 96), ["bandit", "bandit", "bandit", "schuetze"], 1.7)
	_lager("dornfeld", "dorn_wolf", dc + Vector3(110, 0, -110), ["wolf", "wolf", "wolf"], 1.6)
	dorf_spots["dorn"] = ["dorn_brunnen", "dorn_markt", "dorn_feld", "dorn_kutsche"]
	far_keys.append_array(["dorn_markt", "dorn_feld", "dorn_kutsche"])

	# ============ Abfahrtsorte im Umland von Aschfurt
	thing(places["b_steg"] + Vector3(-3, 0, 2), "Mit dem Schiff nach Salzhafen (15 Gold)", func():
		reise("salzhafen", places["salz_steg"], "Kapitän Marek löst die Leinen. Der See öffnet sich zum Fluss, der Fluss zum Meer, und am Abend riechst du Salz und Teer.", 15, "b_steg"), 3.4)
	var cart: Vector3 = places["tor"] + Vector3(7, 0, 4)
	flat_mesh(_box(Vector3(2.6, 1.6, 4.4)), cart + Vector3(0, 1.6, 0), Color(0.5, 0.3, 0.18))
	flat_mesh(_box(Vector3(2.8, 0.2, 4.6)), cart + Vector3(0, 2.5, 0), Color(0.3, 0.2, 0.12))
	for q in [[-1.4, 1.4], [1.4, 1.4], [-1.4, -1.4], [1.4, -1.4]]:
		var wheel = flat_mesh(_cyl(0.8, 0.2), cart + Vector3(q[0], 0.8, q[1]), Color(0.25, 0.17, 0.1))
		wheel.rotation.z = PI / 2.0
	solid(cart, Vector3(2.8, 2.6, 4.6), 0.0, 16)
	thing(cart + Vector3(-2.6, 0, 0), "Mit der Kutsche nach Dornfeld (10 Gold)", func():
		reise("dornfeld", places["dorn_kutsche"], "Veit schnalzt mit der Zunge, die Gäule ziehen an. Stundenlang nur Felder, dann die Dächer von Dornfeld.", 10, "tor"), 3.4)
	thing(Vector3(292, 0, -262), "Den Bergpfad nach Hochwacht hinaufsteigen", func():
		reise("hochwacht", places["hoch_pfad"] + Vector3(0, 0, -6), "Der Pfad windet sich hinter dem Wachturm in die Felsen. Nach Stunden knirscht Schnee unter deinen Stiefeln, und über dir rauchen die Schornsteine von Hochwacht.", 0, "turmkeller"), 4.0)
	flat_mesh(_cyl(0.1, 3.0), Vector3(294, 1.5, -262), Color(0.36, 0.25, 0.15))
	flat_mesh(_box(Vector3(1.8, 0.4, 0.08)), Vector3(294, 2.6, -262), Color(0.55, 0.4, 0.24))


# ---------------------------------------------------------------- Akt II und III: die Aschenlande

func _aschenlande() -> void:
	var A = ASCHE
	places["pass"] = SCHALEN["pass"][1]
	far_keys.append("pass")
	# Boden, Grenzen, Berge
	var ground = flat_mesh(_box(Vector3(460, 0.1, 460)), A + Vector3(0, 0.0, 0), Color(0.3, 0.28, 0.28), 1.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		var a = i * PI / 2.0
		solid(A + Vector3(sin(a), 0, cos(a)) * 222.0, Vector3(460, 30, 4), a)
	for i in 34:
		var a = i * TAU / 34.0
		put("hex/mountain_%s.gltf" % ["A", "B", "C"][i % 3], A + Vector3(sin(a), 0, cos(a)) * rng.randf_range(232, 262) + Vector3(0, -2, 0), rng.randf() * TAU, rng.randf_range(34, 56))
	for i in 150:
		var p = A + Vector3(rng.randf_range(-210, 210), 0, rng.randf_range(-210, 210))
		if p.distance_to(SCHALEN["asche"][1]) > 14.0:
			forest(BARE[i % BARE.size()], p, rng.randf_range(1.6, 2.8))
	for i in 110:
		forest(ROCKS[i % ROCKS.size()], A + Vector3(rng.randf_range(-210, 210), 0, rng.randf_range(-210, 210)), rng.randf_range(1.0, 2.6))
	for i in 40:      # glühende Risse im Boden
		var lp = A + Vector3(rng.randf_range(-200, 200), 0.08, rng.randf_range(-200, 200))
		var crack = glow_mesh(_box(Vector3(rng.randf_range(3, 9), 0.05, 0.35)), lp, Color(1.0, 0.35, 0.08), 3.0)
		crack.rotation.y = rng.randf() * TAU
	for i in 70:
		glow_mesh(_sphere(0.08), A + Vector3(rng.randf_range(-200, 200), rng.randf_range(0.5, 3.0), rng.randf_range(-200, 200)), Color(1.0, 0.5, 0.15), 4.0)
	# Aschentor am Bergpass (in der normalen Welt)
	var pp: Vector3 = SCHALEN["pass"][1] + Vector3(0, 0, -10)
	put("dungeon/wall_arched.glb", pp, 0, 2.0)
	put("dungeon/pillar_decorated.glb", pp + Vector3(-7, 0, 1), 0, 1.6)
	put("dungeon/pillar_decorated.glb", pp + Vector3(7, 0, 1), 0, 1.6)
	glow_mesh(_box(Vector3(5.0, 6.0, 0.2)), pp + Vector3(0, 3.2, 0.6), Color(0.9, 0.25, 0.1), 2.5)
	lamp(pp + Vector3(0, 4, 3), Color(1.0, 0.35, 0.15), 3.0, 22.0, true)
	var tor = thing(pp + Vector3(0, 0, 3.0), "Durch das Aschentor gehen", func():
		G.event("use", "aschentor")
		_travel("pass", "asche"), 4.0)
	tor.condition = func(): return G.playing and (G.quest_active("m4") or G.quest_done("m4"))
	var zu = thing(pp + Vector3(0, 0, 3.0), "Das Aschentor ist versiegelt", func():
		G.say("Das Tor öffnet sich nur einem Hüter, der den ersten Glutsplitter errungen hat (Hauptaufgabe)."), 4.0)
	zu.condition = func(): return G.playing and not (G.quest_active("m4") or G.quest_done("m4"))
	# Gegner
	for q in [[-60, 60, ["geist", "geist", "geist"]], [70, 70, ["krieger", "krieger", "magier"]], [-140, -20, ["geist", "geist", "krieger", "krieger"]],
		[120, -60, ["geist", "geist", "geist", "magier"]], [0, -90, ["krieger", "krieger", "krieger", "magier", "geist"]], [-40, -150, ["geist", "geist", "geist", "geist"]]]:
		for k in q[2]:
			dungeon_spawns.append([k, A + Vector3(q[0] + rng.randf_range(-6, 6), 0, q[1] + rng.randf_range(-6, 6)), "asche", 2.4, "asche"])
	# Einsiedlerin Verena nahe der Ankunft
	var v = Actor.new()
	v.position = SCHALEN["asche"][1] + Vector3(9, 0, 4)
	add_child(v)
	v.collision_layer = 8
	v.collision_mask = 1
	v.setup("chars2/Mage.glb")
	v.gear({"r": "staff"})
	v.play("Idle_A")
	v.body.rotation.y = -1.0
	put("hex/tent.gltf", v.position + Vector3(4, 0, -3), 0.6, 9.0)
	fire(v.position + Vector3(-2.5, 0, 1.5), 0.9)
	thing(v.position, "Mit der Einsiedlerin Verena sprechen", func():
		G.ui.dialog("Verena, Einsiedlerin", "Ein Lebender. Hier. Ich war Hüterin, die Neunte, und bin geblieben, als die anderen flohen oder fielen. Im Westen und im Osten liegen die Horte, jeder mit einem Splitter und einem Wächter. Im Norden sitzt er auf seinem Thron: Alderan, der die Glut einst vom Berg trug. Er hat sie nie hergeben wollen. Das ist die ganze traurige Wahrheit über den Aschenkönig.", [
			["Was rätst du mir?", func(): G.ui.dialog("Verena", "Entscheide an jedem Hort selbst, was mit dem Splitter geschieht. Nimm ihn, und du bist stärker. Lass ihn in der Schale, und das Land ist es. Alderan hat immer genommen.", [["Ich verstehe.", Callable()]])],
			["Hast du Vorräte?", func(): G.ui.show_shop("Verena", ["heiltrank", "manatrank", "fackel", "pfeil", "braten"])],
			["Leb wohl.", Callable()]])
		Audio.babble(true, 0.95, 200), 3.6)
	# Horte
	_hort("hort_w", A + Vector3(-150, 0, -90), "Westhort")
	_hort("hort_o", A + Vector3(150, 0, 50), "Osthort")
	# Aschenthron
	dungeons["thron"] = {}
	Dungeon.build(self, "thron", Vector3(600.0, 0, 1500.0))
	put("dungeon/wall_doorway.glb", THRON_TOR, 0, 2.0)
	put("dungeon/pillar_decorated.glb", THRON_TOR + Vector3(-7, 0, 2), 0, 1.8)
	put("dungeon/pillar_decorated.glb", THRON_TOR + Vector3(7, 0, 2), 0, 1.8)
	lamp(THRON_TOR + Vector3(0, 5, 4), Color(1.0, 0.25, 0.1), 4.0, 26.0, true)
	var ti = thing(THRON_TOR + Vector3(0, 0, 4.0), "", func():
		if G.p["flags"].has("d1") and G.p["flags"].has("d2"):
			enter_dungeon("thron")
		else:
			G.say("Das Tor reagiert nicht. Erst wenn über beide Splitter entschieden ist, öffnet sich der Thron."), 4.5)
	ti.label_fn = func(): return "Den Aschenthron betreten"
	# die erste Glut hinter dem Aschenkönig
	for q in dungeon_spawns:
		if q[0] == "aschenkoenig":
			var gp: Vector3 = q[1] + Vector3(0, 0, -3.0)
			glow_mesh(_sphere(0.7), gp + Vector3(0, 1.6, 0), Color(1.0, 0.6, 0.2), 6.0)
			flat_mesh(_cyl(1.0, 1.2, 0.7), gp + Vector3(0, 0.6, 0), Color(0.3, 0.28, 0.3))
			lamp(gp + Vector3(0, 3, 0), Color(1.0, 0.6, 0.25), 4.0, 22.0, true)
			var ei = thing(gp + Vector3(0, 0, 2.0), "Vor die erste Glut treten", _ending, 3.6)
			ei.condition = func(): return G.playing and G.p["flags"].get("thron_boss_tot", false) and not G.p["flags"].has("ende")


func _hort(id: String, pos: Vector3, title: String) -> void:
	flat_mesh(_cyl(10.0, 0.3, 9.6), pos + Vector3(0, 0.15, 0), Color(0.36, 0.34, 0.36))
	for i in 6:
		var a = i * TAU / 6.0
		put("dungeon/pillar.glb", pos + Vector3(sin(a), 0, cos(a)) * 9.0, a)
		pillar(pos + Vector3(sin(a), 0, cos(a)) * 9.0, 0.8)
	flat_mesh(_cyl(1.2, 1.4, 0.8), pos + Vector3(0, 0.7, 0), Color(0.42, 0.4, 0.44))
	pillar(pos, 1.3, 2.0)
	var glow = glow_mesh(_sphere(0.35), pos + Vector3(0, 1.9, 0), Color(1.0, 0.55, 0.2), 6.0)
	lamp(pos + Vector3(0, 3.5, 0), Color(1.0, 0.45, 0.2), 2.5, 20.0, true)
	dungeon_spawns.append(["aschenwaechter", pos + Vector3(0, 0, 6), id, 1.0, "asche"])
	if id == "hort_o":
		var ghost = Node3D.new()
		ghost.position = pos + Vector3(3.5, 0, -2)
		add_child(ghost)
		Formen.aschengeist(ghost)
	var it = thing(pos + Vector3(0, 0, 2.2), "", func():
		if id == "hort_w":
			G.ui.dialog(title, "In der erloschenen Schale liegt der Glutsplitter des Westens und pulsiert wie ein kleines Herz. Du könntest ihn nehmen. Oder du legst die Hand auf den Stein und gibst ihm zurück, was ihm gehört.", [
				["Den Splitter nehmen (+2 Glutsplitter)", func():
					G.p["flags"]["d1"] = "nehmen"
					G.add_item("splitter", 2)
					glow.visible = false
					G.event("use", "hort_w")],
				["Die Schale neu entzünden und den Splitter in ihr lassen", func():
					G.p["flags"]["d1"] = "lassen"
					G.p["flags"]["schale_west"] = true
					ring(pos, 10.0, Color(1.0, 0.6, 0.2))
					Audio.sfx("stufe")
					G.add_xp(400)
					G.say("Die Schale des Westens brennt. Wärme kriecht über die Asche, und zwischen den Rissen zeigt sich das erste Grün.")
					G.event("use", "hort_w")]])
		else:
			G.ui.dialog("Isolde, die letzte Hüterin", "„Du hast meinen Wächter erschlagen. Gut. Er war einmal mein Mann. Ich bin Isolde, die Zwölfte, an diesen Stein gebunden, damit der Splitter nicht verlischt. Löse mich, und ich gehe, wohin die Glut geht. Oder binde mich fester und nimm, was von meiner Kraft übrig ist. Alderan hätte nicht gezögert.“", [
				["Isolde erlösen (dauerhaft +2 Vitalität)", func():
					G.p["flags"]["d2"] = "erloest"
					G.p["attr"]["vit"] += 2
					Audio.sfx("zauber")
					G.say("Isolde lächelt, zum ersten Mal seit hundert Jahren, und ist fort. Etwas von ihrer Ruhe bleibt bei dir.")
					G.event("use", "hort_o")],
				["Isolde binden und ihre Kraft nehmen (dauerhaft +12 % Schaden, +2 Glutsplitter)", func():
					G.p["flags"]["d2"] = "gebunden"
					G.add_item("splitter", 2)
					Audio.sfx("geist")
					G.say("Der Geist schreit nicht. Er sieht dich nur an. Die Kraft ist kalt, und sie gehorcht.")
					G.event("use", "hort_o")]]), 3.4)
	it.label_fn = func(): return "Glutsplitter des Westens" if id == "hort_w" else "Mit dem Geist der Hüterin sprechen"
	it.condition = func(): return G.playing and G.p["flags"].get(id + "_tot", false) and not G.p["flags"].has("d1" if id == "hort_w" else "d2")


## Das Ende: drei Wege, abhängig von früheren Entscheidungen.
func _ending() -> void:
	var lit = 0
	for id in SCHALEN:
		if schale_lit(id):
			lit += 1
	var can_b: bool = G.p["flags"].get("d1", "") == "lassen" or lit >= 6
	var o = [
		["Die Glut auf den Berg zurücktragen und dort wachen", func(): _epilog("a")],
		["Alle zwölf Schalen neu entzünden" + ("" if can_b else "  (dafür hättest du den Westhort entzünden oder sechs Schalen zum Brennen bringen müssen)"), func():
			if can_b: _epilog("b")
			else: _ending()],
		["Die Glut selbst behalten", func(): _epilog("c")]]
	G.ui.dialog("Die erste Glut", "Alderan liegt zu deinen Füßen, endlich nur noch Asche. Hinter dem Thron schwebt, was er hundert Jahre lang umklammert hielt: die erste Glut, klein wie eine Faust, warm wie ein Sommer.

„Nimm sie“, sagt das, was von seiner Stimme übrig ist. „Jeder nimmt sie am Ende.“", o)


func _epilog(wahl: String) -> void:
	G.p["flags"]["ende"] = wahl
	var t = ""
	match wahl:
		"a":
			t = "Du trägst die Glut den Berg hinauf, dorthin, wo Alderan sie einst fand, und setzt dich zu ihr. Unten im Tal werden die Nächte milder. Niemand weiß genau, warum. Man erzählt von einem Licht am Gipfel und nennt es den Hüter am Berg."
		"b":
			t = "Du teilst die Glut. Ein Funke für jede Schale, zwölf Wege, zwölf Feuer. Als das letzte brennt, zieht ein warmer Wind durch die Aschenlande, und wo er weht, steht am Morgen Gras.

Zwölf Flammen. Die Glutwacht hat wieder einen Namen, und er ist deiner."
			for id in SCHALEN:
				if id != "schrein" and id != "aschfurt":
					G.p["flags"]["schale_" + id] = true
			G.p["flags"]["glut"] = true
			_update_schalen()
		"c":
			t = "Du schließt die Hand um die Glut. Sie brennt nicht. Sie gehorcht. Kraft fährt in dich wie ein zweiter Herzschlag (+3 auf alle Attribute, +20 % Schaden).

In Aschfurt grüßt man dich fortan sehr höflich und sieht dir nicht in die Augen. Alderan hat genau so angefangen."
			for k in G.p["attr"]:
				G.p["attr"][k] += 3
	if G.p["partner"] != "":
		var pn: String = NpcScript.PEOPLE[G.p["partner"]]["name"]
		t += "

" + {"a": "%s steigt jeden Sommer zu dir hinauf und bleibt jedes Jahr ein wenig länger.", "b": "%s steht neben dir, als die zwölfte Schale aufflammt, und sagt nur: „Na endlich.“", "c": "%s bleibt bei dir. Aber die Kerze am Bett lässt %s seither brennen."}[wahl].replace("%s", pn)
	if G.p["flags"].get("d2", "") == "erloest":
		t += "

Manchmal, wenn eine Schale im Wind flackert, meinst du Isoldes Lachen zu hören."
	elif G.p["flags"].get("d2", "") == "gebunden":
		t += "

Isolde ist noch immer an ihren Stein gebunden. Sie wartet. Sie hat Zeit."
	if G.p["flags"].get("hund", false):
		t += "

Bello hat von alldem nichts verstanden und ist sehr zufrieden."
	G.event("use", "entscheidung")
	fade(t, func():
		G.p["inside"] = false
		G.p["room"] = ""
		G.player.global_position = Vector3(0, 0.4, 8)
		G.player.snap_camera()
		G.changed.emit()
		G.say("Ende der Geschichte. Du kannst weiterspielen, solange du magst."))


func schale_lit(id: String) -> bool:
	if id == "aschfurt":
		return true
	if id == "schrein":
		return G.p["flags"].get("glut", false)
	if id == "pass":
		return G.p["flags"].get("schale_pass", false)
	return G.p["flags"].get("schale_" + id, false)


func _update_schalen() -> void:
	for id in schalen:
		schalen[id].visible = schale_lit(id)


func _schalen() -> void:
	for id in SCHALEN:
		var pos: Vector3 = SCHALEN[id][1]
		if id != "aschfurt" and id != "schrein":
			flat_mesh(_cyl(0.9, 0.5, 1.1), pos + Vector3(0, 0.25, 0), Color(0.4, 0.4, 0.45))
			flat_mesh(_cyl(0.5, 1.0, 0.35), pos + Vector3(0, 0.9, 0), Color(0.46, 0.46, 0.52))
			flat_mesh(_cyl(1.1, 0.35, 0.7), pos + Vector3(0, 1.55, 0), Color(0.5, 0.5, 0.56))
			pillar(pos, 1.0, 2.0)
			var fl = Node3D.new()
			fl.position = pos + Vector3(0, 1.7, 0)
			add_child(fl)
			var cone = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.6
			cone.height = 1.5
			glow_mesh(cone, Vector3(0, 0.7, 0), Color(1.0, 0.5, 0.12), 5.0, fl)
			var l = OmniLight3D.new()
			l.light_color = Color(1.0, 0.55, 0.2)
			l.light_energy = 4.0
			l.omni_range = 18.0
			l.position.y = 1.2
			fl.add_child(l)
			fl.visible = false
			schalen[id] = fl
		var it = thing(pos + Vector3(0, 0, 1.9), "", func(): _use_schale(id), 3.4)
		it.label_fn = func(): return "Durch die Glut reisen" if schale_lit(id) else "Glutschale entzünden"
		it.condition = func(): return G.playing and (id != "schrein" or schale_lit(id))


func _use_schale(id: String) -> void:
	if not schale_lit(id):
		G.p["flags"]["schale_" + id] = true
		_update_schalen()
		Audio.sfx("stufe")
		ring(SCHALEN[id][1], 7.0, Color(1.0, 0.6, 0.2))
		G.add_xp(40)
		G.say("Die Glutschale von %s brennt. Von hier aus kannst du nun reisen." % SCHALEN[id][0])
		return
	var o = []
	for other in SCHALEN:
		if other != id and schale_lit(other):
			o.append(["Nach %s" % SCHALEN[other][0], func(): _travel(id, other)])
	if o.is_empty():
		G.say("Noch brennt keine andere Glutschale. Entzünde weitere, um zu reisen.")
		return
	o.append(["Hierbleiben", Callable()])
	G.ui.dialog("Glutschale von " + SCHALEN[id][0], "Die Flamme kennt jede ihrer Schwestern. Wohin soll sie dich tragen?", o)


func _travel(from: String, to: String) -> void:
	Audio.sfx("reise")
	fade("Du trittst in die Glut. Für einen Atemzug bist du überall zugleich.", func():
		_ankommen(SCHALE_GEBIET.get(to, ""), SCHALEN[to][1] + Vector3(0, 0, 3.0))
		G.advance(1.0)
		G.changed.emit())


func _ankommen(gebiet: String, pos: Vector3) -> void:
	if gebiet != "":
		G.p["flags"]["ort_" + gebiet] = true
	G.p["region"] = gebiet
	G.p["room"] = gebiet
	G.p["inside"] = gebiet != ""
	G.player.global_position = pos + Vector3(0, 0.4, 0)
	G.player.cam_dist = 19.0
	G.player.snap_camera()


## Reise mit Schiff, Kutsche oder zu Fuß in ein anderes Gebiet ("" = Umland von Aschfurt).
func reise(gebiet: String, pos: Vector3, text: String, cost := 0, door := "") -> void:
	if G.p["gold"] < cost:
		G.say("Dafür fehlen dir %d Gold." % (cost - G.p["gold"]))
		return
	G.add_gold(-cost)
	fade(text, func():
		if door != "":
			G.p["room_door"] = door
		_ankommen(gebiet, pos)
		G.advance(3.0)
		if gebiet != "":
			G.say("%s. Entzünde hier die Glutschale, dann kannst du künftig durch die Glut reisen." % GEBIETE[gebiet][1])
		G.changed.emit())


func update_home() -> void:
	for id in moebel:
		moebel[id].visible = G.playing and G.p["flags"].get("m_" + id, false)
	for i in beete.size():
		_beet_look(i)


# ---------------------------------------------------------------- Garten und Stall

func _hof() -> void:
	var door: Vector3 = places["spielerhaus"]
	var out = Vector3(-door.x, 0, -door.z).normalized()
	var side = Vector3(out.z, 0, -out.x)
	var g = Vector3(-50, 0, 22)       # zwischen deinem Haus und dem Teich
	flat_mesh(_box(Vector3(8.4, 0.12, 6.4)), g + Vector3(0, 0.05, 0), Color(0.32, 0.22, 0.13))
	for i in 6:
		var bp = g + Vector3(-2.7 + (i % 3) * 2.7, 0, -1.5 + int(i / 3.0) * 3.0)
		flat_mesh(_box(Vector3(2.2, 0.25, 2.4)), bp + Vector3(0, 0.12, 0), Color(0.25, 0.16, 0.1))
		var holder = Node3D.new()
		holder.position = bp + Vector3(0, 0.25, 0)
		add_child(holder)
		beete.append(holder)
		var it = thing(bp, "", func(): _beet(i), 2.2)
		it.label_fn = func():
			var b = G.p["garten"][i]
			if b == null: return "Beet bepflanzen"
			return ("%s ernten" % G.ITEMS[b["crop"]]["name"]) if b["wachstum"] >= 2 else ("%s wächst noch" % G.ITEMS[b["crop"]]["name"])
		it.condition = func(): return G.playing
	# Hühnerstall
	var st = g + Vector3(-9, 0, 0)
	flat_mesh(_box(Vector3(3.0, 1.8, 2.4)), st + Vector3(0, 0.9, 0), Color(0.5, 0.36, 0.22))
	var roof = PrismMesh.new()
	roof.size = Vector3(3.4, 1.2, 2.8)
	flat_mesh(roof, st + Vector3(0, 2.4, 0), Color(0.55, 0.2, 0.15))
	flat_mesh(_box(Vector3(0.7, 0.9, 0.1)), st + Vector3(0, 0.45, 1.22), Color(0.1, 0.07, 0.05))
	solid(st, Vector3(3.0, 1.8, 2.4), 0.0, 16)
	var ci = thing(st + Vector3(0, 0, 2.0), "", func():
		var n: int = int(G.p["flags"].get("eier", 0))
		if int(G.p["flags"].get("huhn", 0)) <= 0:
			G.say("Der Stall ist leer. Bauer Tomas verkauft Hühner.")
		elif n <= 0:
			G.say("Noch keine Eier. Die Hühner legen jeden Morgen.")
		else:
			G.p["flags"]["eier"] = 0
			G.add_item("ei", n)
			Audio.sfx("huhn")
			G.say("%d Eier eingesammelt" % n), 2.6)
	ci.label_fn = func(): return "Hühnerstall (%d Hühner, %d Eier)" % [int(G.p["flags"].get("huhn", 0)), int(G.p["flags"].get("eier", 0))]
	ci.condition = func(): return G.playing
	for k in 3:
		critter("huhn", st + Vector3(rng.randf_range(-2, 2), 0, 3.0), 4.0)
	# Holz hacken am Holzplatz
	thing(places["holzplatz"] + Vector3(3, 0, 2), "Holz hacken (1 Stunde)", func():
		if G.p["fatigue"] < 12.0:
			G.say("Du bist zu müde zum Holzhacken.")
			return
		G.player.play("Chopping", 1.0, true)
		Audio.sfx("holz")
		fade("Du hackst eine Stunde lang Holz. Odo nickt anerkennend.", func():
			G.advance(1.0)
			G.p["fatigue"] = max(0.0, G.p["fatigue"] - 6.0)
			var n = 2 + int(G.job_lvl("holz") / 2.0)
			G.add_item("holz", n)
			G.job_xp("holz", 2)
			G.say("%d Holz gehackt" % n)
			G.changed.emit()), 3.0)
	# Mitfeiern am Dorffeuer
	var fi = thing(Vector3(-7, 0, 4.2), "", func():
		var t: String = wetter.today()
		G.p["flags"]["fest_day"] = G.p["day"]
		Audio.sfx("fest")
		var text = "Du feierst mit dem ganzen Dorf. Bruno schenkt aus, Bertha erzählt, was niemand wissen sollte, und jemand spielt Laute."
		if t == "Hochzeit" and G.p["partner"] != "":
			var pn: String = NpcScript.PEOPLE[G.p["partner"]]["name"]
			text = "Ganz Aschfurt steht im Kreis um das Feuer. Hauptmann Gernot spricht die alten Worte der Glutwacht, %s nimmt deine Hand.\n\nVon heute an hütet ihr die Glut gemeinsam. Das Dorf schenkt euch 100 Gold für den Hausstand." % pn
			G.npc_data(G.p["partner"])["married_day"] = G.p["day"]
		fade(text, func():
			for id in G.npcs:
				if G.npcs[id].act == "fest":
					G.npc_data(id)["aff"] = min(100.0, G.npc_data(id)["aff"] + 3.0)
			if t == "Hochzeit":
				G.add_gold(100)
			G.add_item("festmahl")
			G.p["hunger"] = 100.0
			G.advance(2.0, true)
			G.changed.emit()), 3.0)
	fi.label_fn = func(): return "%s mitfeiern" % wetter.today()
	fi.condition = func(): return G.playing and wetter.festive() and G.p["flags"].get("fest_day", 0) != G.p["day"]


func _beet(i: int) -> void:
	var b = G.p["garten"][i]
	if b == null:
		var o = []
		for it in G.p["inv"]:
			if G.ITEMS[it]["type"] == "saat":
				o.append(["%s (%d)" % [G.ITEMS[it]["name"], G.count(it)], func():
					G.add_item(it, -1)
					G.p["garten"][i] = {"crop": G.ITEMS[it]["crop"], "wachstum": 0}
					_beet_look(i)
					G.say("Gepflanzt. In zwei Tagen kannst du ernten, bei Regen schneller.")])
		if o.is_empty():
			G.say("Du hast keine Saat. Mira im Krämerladen verkauft welche.")
			return
		o.append(["Nichts pflanzen", Callable()])
		G.ui.dialog("Beet", "Was möchtest du pflanzen?", o)
	elif b["wachstum"] >= 2:
		G.add_item(b["crop"], 3)
		G.p["garten"][i] = null
		_beet_look(i)
		Audio.sfx("aufheben")
		G.say("3 %s geerntet" % G.ITEMS[b["crop"]]["name"])
	else:
		G.say("Das braucht noch Zeit. Im Winter wächst nichts, Regen hilft.")


func _beet_look(i: int) -> void:
	for c in beete[i].get_children():
		c.queue_free()
	if not G.playing:
		return
	var b = G.p["garten"][i]
	if b == null:
		return
	if b["wachstum"] >= 2:
		for k in 4:
			put("food/%s.gltf" % G.ITEMS[b["crop"]]["model"], Vector3(-0.5 + (k % 2) * 1.0, 0.05, -0.5 + int(k / 2.0) * 1.0), k * 1.3, 0.8, beete[i])
	else:
		for k in 4:
			flat_mesh(_cyl(0.05, 0.3 + b["wachstum"] * 0.25, 0.0), Vector3(-0.5 + (k % 2) * 1.0, 0.2, -0.5 + int(k / 2.0) * 1.0), Color(0.3, 0.65, 0.25), 0.9, beete[i])


func enter_home() -> void:
	enter_room("spielerhaus")


func exit_home() -> void:
	exit_room()


## Nimmt die Welt einmal senkrecht von oben auf; das Bild ist der Hintergrund der Karte.
func _render_map() -> void:
	map_baking = true
	_daylight(12.5)
	for cl in clouds:
		cl.visible = false
	map_tex = await _bake(Vector3.ZERO, 800.0, 2048)
	for id in GEBIETE:
		map_texs[id] = await _bake(GEBIETE[id][0], 480.0 if id == "asche" else 400.0, 1024)
	for cl in clouds:
		cl.visible = true
	map_baking = false


## Nimmt einen Ausschnitt der Welt senkrecht von oben auf (Luftbild für die Karte).
func _bake(center: Vector3, size: float, res: int) -> ImageTexture:
	var vp = SubViewport.new()
	vp.size = Vector2i(res, res)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	cam.far = 900.0
	cam.position = center + Vector3(0, 400, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.4, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
	e.adjustment_enabled = true
	e.adjustment_saturation = 0.8
	e.adjustment_brightness = 0.9
	cam.environment = e
	vp.add_child(cam)
	add_child(vp)
	for i in 3:
		await RenderingServer.frame_post_draw
	var tex = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	return tex


## In welchem Gebiet liegt ein Punkt? ("" = Umland von Aschfurt)
func gebiet_von(pos: Vector3) -> String:
	for id in GEBIETE:
		if abs(pos.x - GEBIETE[id][0].x) < 260.0 and abs(pos.z - GEBIETE[id][0].z) < 260.0:
			return id
	return ""


## Wo liegt das Ziel eines Aufgabenschritts? (für die Karte)
func quest_pos(s: Dictionary) -> Vector3:
	if s.is_empty():
		return Vector3.INF
	var fixed = {"mine_boss": EINGAENGE["mine"], "gruft_boss": EINGAENGE["gruft"], "turmkeller_boss": EINGAENGE["turmkeller"], "friedhof": Vector3(-300, 0, 60),
		"turm": Vector3(280, 0, -250), "pass": Vector3(0, 0, -372), "aschentor": Vector3(0, 0, -380), "hort_w": ASCHE + Vector3(-150, 0, -90), "hort_o": ASCHE + Vector3(150, 0, 50),
		"thron_boss": THRON_TOR, "entscheidung": THRON_TOR, "leuchtturm_boss": places.get("leuchtturm", Vector3.INF), "eishoehle_boss": places.get("eishoehle", Vector3.INF),
		"salz_strand": GEBIETE["salzhafen"][0] + Vector3(110, 0, 36), "hoch_wolf": GEBIETE["hochwacht"][0] + Vector3(94, 0, -80), "dorn_raeuber": GEBIETE["dornfeld"][0] + Vector3(124, 0, 60),
		"ufer": Vector3(330, 0, 170), "schrein": Vector3(-120, 0, -80), "glutschale": Vector3(-120, 0, -80), "ruinen": Vector3(30, 0, -170), "boss": Vector3(30, 0, -182),
		"acker": Vector3(64, 0, 50), "lieferung": Vector3(48, 0, 146), "brett": Vector3(6, 0, 6)}
	if s["t"] in ["talk", "bring"] and G.npcs.has(s["key"]):
		var n = G.npcs[s["key"]]
		return places[n.room] if n.room != "" else n.global_position
	return fixed.get(s["key"], Vector3.INF)


## Wege vom Brunnen zu den Häusern und hinaus in die Welt (werden in den Boden gezeichnet).
func _paths() -> void:
	var segs = []
	var hub = Vector3.ZERO
	for key in places:
		if key in ["brunnen", "steinbruch", "teich", "holzplatz", "acker_rand", "waldrand", "muehle"] or key in far_keys:
			continue
		var p: Vector3 = places[key]
		# erst zur Ringstraße, dann zum Brunnen
		var ring = Vector3(p.x, 0, p.z).normalized() * min(Vector2(p.x, p.z).length(), 16.0)
		segs.append([p, ring])
		segs.append([ring, hub])
	var wm: Vector3 = places["b_brunnen"]
	for key in far_keys:
		if key != "b_brunnen" and key != "b_ufer":
			segs.append([places[key], wm])
	for q in [[places["acker_rand"], Vector3(110, 0, 70)], [Vector3(110, 0, 70), Vector3(170, 0, 120)], [Vector3(170, 0, 120), wm],
		[places["waldrand"], Vector3(-150, 0, 0)], [Vector3(-150, 0, 0), Vector3(-230, 0, 40)], [Vector3(-230, 0, 40), Vector3(-290, 0, 58)],
		[Vector3(118, 0, -36), Vector3(190, 0, -130)], [Vector3(190, 0, -130), Vector3(270, 0, -240)]]:
		segs.append(q)
	for q in [[places["tor"], Vector3(4, 0, 112)], [Vector3(4, 0, 112), Vector3(40, 0, 128)], [Vector3(-16, 0, -10), places["waldrand"]], [places["waldrand"], Vector3(-112, 0, -74)],
		[Vector3(16, 0, -8), Vector3(70, 0, -26)], [Vector3(70, 0, -26), Vector3(118, 0, -36)], [places["wache"], Vector3(26, 0, -100)], [Vector3(26, 0, -100), Vector3(30, 0, -150)],
		[Vector3(14, 0, 8), places["acker_rand"]], [places["acker_rand"], places["muehle"]], [Vector3(-12, 0, 10), places["teich"]]]:
		segs.append(q)
	# Die Wege werden einmal in ein Bild gestempelt; der Boden liest es als Textur.
	var img = Image.create(1024, 1024, false, Image.FORMAT_L8)
	img.fill(Color.BLACK)
	for sg in segs:
		var a: Vector3 = sg[0]
		var b: Vector3 = sg[1]
		var steps = int(a.distance_to(b) / 0.8) + 1
		for i in steps + 1:
			var q = a.lerp(b, float(i) / steps)
			var cx = int((q.x / 800.0 + 0.5) * 1024.0)
			var cy = int((q.z / 800.0 + 0.5) * 1024.0)
			for dx in range(-4, 5):
				for dy in range(-4, 5):
					var x = cx + dx
					var y = cy + dy
					if x < 0 or y < 0 or x > 1023 or y > 1023:
						continue
					var v = clamp(1.3 - sqrt(dx * dx + dy * dy) / 2.9, 0.0, 1.0)
					if v > img.get_pixel(x, y).r:
						img.set_pixel(x, y, Color(v, v, v))
	ground_mat.set_shader_parameter("path_tex", ImageTexture.create_from_image(img))
	# Wegweiser
	for q in [[Vector3(112, 0, 74), "Wegweiser an der Seestraße", "Nach Südosten: Weidenau am See, Gasthaus zum Hecht.\nNach Westen: Aschfurt."],
		[Vector3(-152, 0, 4), "Wegweiser an der Weststraße", "Nach Westen: der alte Friedhof. Die Toten dort ruhen nicht.\nNach Osten: Aschfurt."],
		[Vector3(186, 0, -124), "Wegweiser am Bergpfad", "Nach Nordosten: der verlassene Wachturm.\nNach Südwesten: die alte Mine."],
		[Vector3(3, 0, 62), "Wegweiser am Südtor", "Nach Süden: der Sumpf. Finn warnt vor Skelett-Schurken.\nNach Norden: Dorfplatz, Wirtshaus, Schmiede."],
		[Vector3(-58, 0, -42), "Wegweiser am Waldrand", "Nach Nordwesten: Dämmerwald und der Schrein der Glutwacht.\nNach Osten: Aschfurt."],
		[Vector3(66, 0, -22), "Wegweiser an der Oststraße", "Nach Osten: die alte Mine (Eisenerz).\nNach Westen: Aschfurt."],
		[Vector3(12, 0, -62), "Wegweiser an der Nordstraße", "Nach Norden: die Ruinen. Nur für erfahrene Hüter!\nNach Süden: Wache und Dorfplatz."]]:
		var sp: Vector3 = q[0]
		flat_mesh(_cyl(0.1, 3.0), sp + Vector3(0, 1.5, 0), Color(0.36, 0.25, 0.15))
		flat_mesh(_box(Vector3(1.6, 0.4, 0.08)), sp + Vector3(0.5, 2.6, 0), Color(0.55, 0.4, 0.24)).rotation.y = 0.3
		flat_mesh(_box(Vector3(1.6, 0.4, 0.08)), sp + Vector3(-0.5, 2.1, 0), Color(0.5, 0.36, 0.22)).rotation.y = -0.4
		pillar(sp, 0.2, 3.0)
		thing(sp, "Wegweiser lesen", func(): G.ui.dialog(q[1], q[2], [["Weitergehen", Callable()]]), 3.0)


## Macht das Dorf wohnlich: Gärten, Zäune, Bänke, Bäume, Wäscheleinen, Fässer, Blumenkübel.
func _cozy() -> void:
	var bright = [Color(1.0, 0.3, 0.3), Color(1.0, 0.8, 0.2), Color(0.95, 0.5, 0.85), Color(0.5, 0.6, 1.0), Color(0.98, 0.98, 1.0)]
	var k = 0
	for key in places:
		if not (key.begins_with("haus_") or key == "spielerhaus") or key in far_keys:
			continue
		var door: Vector3 = places[key]
		var out = Vector3(-door.x, 0, -door.z).normalized()       # Richtung Dorfmitte
		var side = Vector3(out.z, 0, -out.x)
		var house = door - out * 5.0
		# Vorgarten mit niedrigem Zaun, Beeten und einem Baum
		var g = house + side * 8.5
		for i in 4:
			var a = i * PI / 2.0
			for j in 3:
				if i == 0 and j == 1:
					continue
				put("hex/fence_wood_straight.gltf", g + Vector3(sin(a), 0, cos(a)) * 3.8 + Vector3(cos(a), 0, -sin(a)) * (-2.5 + j * 2.5), a + PI / 2.0, 2.2)
		for i in 6:
			put("food/food_ingredient_%s.gltf" % ["carrot", "lettuce", "tomato", "potato"][(i + k) % 4], g + Vector3(-2.2 + (i % 3) * 2.2, 0.05, -1.2 + int(i / 3.0) * 2.4), rng.randf() * TAU, 0.7)
		for i in 9:
			flat_mesh(_sphere(0.16), g + Vector3(rng.randf_range(-3.2, 3.2), 0.35, rng.randf_range(-3.2, 3.2)), bright[(i + k) % bright.size()])
		forest(["Tree_2_A", "Tree_2_C", "Tree_1_B", "Tree_2_E", "Tree_1_A"][k % 5], house - side * 7.5 - out * 1.0, rng.randf_range(2.0, 2.7), true)
		pillar(house - side * 7.5 - out * 1.0, 0.6, 6.0)
		# vor der Tür: Bank, Fass, Blumenkübel, Laterne
		if k % 2 == 0:
			seat(door + side * 3.6 - out * 1.2, atan2(out.x, out.z))
		put("dungeon/%s.glb" % ["barrel_large", "box_large", "crates_stacked"][k % 3], door - side * 3.4 - out * 1.6, rng.randf() * TAU, 0.8)
		for sgn in [-1.0, 1.0]:
			var pot = door + side * sgn * 1.5 - out * 0.4
			flat_mesh(_cyl(0.32, 0.5, 0.4), pot + Vector3(0, 0.25, 0), Color(0.6, 0.35, 0.22))
			forest(["Bush_1_C", "Bush_1_E", "Bush_2_B"][k % 3], pot + Vector3(0, 0.45, 0), 0.5)
			flat_mesh(_sphere(0.14), pot + Vector3(0.1, 0.95, 0.05), bright[(k + int(sgn)) % bright.size()])
		# Wäscheleine
		if k % 3 == 1:
			var l1 = house - side * 3.0 - out * 7.0
			var l2 = l1 + side * 6.0
			for lp in [l1, l2]:
				flat_mesh(_cyl(0.07, 2.4), lp + Vector3(0, 1.2, 0), Color(0.4, 0.28, 0.18))
			flat_mesh(_box(Vector3(0.03, 0.03, 6.0)), (l1 + l2) / 2.0 + Vector3(0, 2.3, 0), Color(0.85, 0.82, 0.7)).rotation.y = atan2(side.x, side.z)
			for i in 4:
				var cl = flat_mesh(_box(Vector3(0.04, 0.9, 0.8)), l1.lerp(l2, 0.2 + i * 0.2) + Vector3(0, 1.85, 0), bright[(i + k) % bright.size()].lerp(Color.WHITE, 0.35))
				cl.rotation.y = atan2(side.x, side.z)
		k += 1
	# Dorfplatz: Bänke um den Brunnen, Bäume, Pflaster aus kleinen Steinen
	for i in 4:
		var a = i * PI / 2.0 + PI / 4.0
		seat(Vector3(sin(a), 0, cos(a)) * 7.0, a + PI)
	for i in 26:
		var a = rng.randf() * TAU
		var rr = rng.randf_range(24.0, 64.0)
		var tp = Vector3(sin(a) * rr, 0, cos(a) * rr)
		var free = true
		for key in places:
			if places[key].distance_to(tp) < 9.0:
				free = false
		if free:
			var t = forest(TREES[rng.randi() % 8], tp, rng.randf_range(1.9, 2.8), true)
			pillar(tp, 0.6, 6.0)
	for i in 70:
		var a = rng.randf() * TAU
		var rr = rng.randf_range(10.0, 66.0)
		forest(BUSHES[i % BUSHES.size()], Vector3(sin(a) * rr, 0, cos(a) * rr), rng.randf_range(0.7, 1.3))
	for i in 60:
		var a = rng.randf() * TAU
		var rr = rng.randf_range(3.5, 13.0)
		forest(["Rock_1_A", "Rock_2_A", "Rock_3_A"][i % 3], Vector3(sin(a) * rr, -0.12, cos(a) * rr), rng.randf_range(0.5, 0.9))
	# Dinge zum Benutzen im Freien
	var wi = thing(Vector3(0, 0, 3.4), "Aus dem Brunnen trinken", func():
		G.heal(8.0)
		G.p["stamina"] = G.max_stamina()
		G.player.play("Use_Item", 1.0, true)
		G.player.busy = 0.8
		Audio.sfx("essen", 1.4, 0.5)
		G.say("Kühles Wasser. Das tut gut."), 2.6)
	thing(Vector3(-7, 0, 7.8), "Am Feuer braten und kochen", func(): G.ui.show_cook(), 2.4)
	for q in [Vector3(-44, 0, 46.5), Vector3(-58, 0, 49)]:
		flat_mesh(_box(Vector3(2.6, 0.2, 3.4)), q + Vector3(0, 0.25, 2.0), Color(0.45, 0.32, 0.2))
		thing(q, "Angeln", func():
			if G.p["fatigue"] < 10.0:
				G.say("Du bist zu müde zum Angeln.")
				return
			G.player.play("Fishing_Cast", 1.0, true)
			fade("Du wirfst die Leine aus und wartest. Die Enten schauen zu.", func():
				G.advance(1.0)
				G.job_xp("angeln", 2)
				if randf() < 0.55 + G.job_lvl("angeln") * 0.04:
					var nfish = 1 + (1 if randf() < 0.2 + G.job_lvl("angeln") * 0.06 else 0)
					G.add_item("fisch", nfish)
					G.say("%d Fisch gefangen! Am Feuer oder am Herd wird Bratfisch daraus." % nfish)
				else:
					G.say("Heute beißt nichts an.")
				G.changed.emit()), 3.0)


func train(attr: String) -> void:
	if G.p["fatigue"] < 15.0:
		G.say("Du bist zu müde zum Trainieren. Schlaf erst einmal.")
		return
	if G.p["hunger"] < 10.0:
		G.say("Mit leerem Magen trainiert es sich nicht. Iss etwas.")
		return
	var names = {"str": "Stärke", "ges": "Geschick", "int": "Intelligenz", "vit": "Vitalität"}
	fade("Du trainierst eine Stunde lang.", func():
		G.advance(1.0)
		G.p["fatigue"] = max(0.0, G.p["fatigue"] - 6.0)
		G.p["hunger"] = max(0.0, G.p["hunger"] - 3.0)
		G.p["train"][attr] += 1
		var need: int = 2 + int(G.p["attr"][attr] / 3.0)
		if G.p["train"][attr] >= need:
			G.p["train"][attr] = 0
			G.p["attr"][attr] += 1
			Audio.sfx("stufe")
			G.say("%s steigt auf %d!" % [names[attr], G.p["attr"][attr]])
		else:
			G.say("%s-Training: %d von %d Einheiten" % [names[attr], G.p["train"][attr], need])
		G.add_xp(8)
		G.changed.emit())


# ---------------------------------------------------------------- Spielablauf

func start_game() -> void:
	for c in dyn.get_children():
		c.queue_free()
	dead.clear()
	G.npcs.clear()
	G.p["inside"] = false
	G.p["room"] = ""
	var pl = CharacterBody3D.new()
	pl.set_script(PlayerScript)
	var pp: Array = G.p["pos"]
	pl.position = Vector3(pp[0], 0.5, pp[2])
	dyn.add_child(pl)
	G.player = pl
	pl.snap_camera.call_deferred()
	for id in NpcScript.PEOPLE:
		var n = CharacterBody3D.new()
		n.set_script(NpcScript)
		n.init(id, places[NpcScript.PEOPLE[id]["work"]] + Vector3(rng.randf_range(-3, 3), 0.3, rng.randf_range(-3, 3)))
		dyn.add_child(n)
		G.npcs[id] = n
		if G.p["partner"] == id:
			n.tag.modulate = Color(1.0, 0.6, 0.75)
	for camp in CAMPS:
		if camp == "boss" and G.p["flags"].get("boss_tot", false):
			continue
		for k in CAMPS[camp]["list"]:
			_spawn(k, CAMPS[camp]["pos"] + Vector3(rng.randf_range(-7, 7), 0.3, rng.randf_range(-7, 7)), camp, CAMPS[camp]["power"])
	for q in dungeon_spawns:
		if not G.p["flags"].get(q[2] + "_tot", false):
			_spawn(q[0], q[1] + Vector3(0, 0.3, 0), q[2], q[3], q[4])
	for id in dungeons:
		for g in dungeons[id].get("gates", []):
			g.position.y = 2.2
			g.collision_layer = 1
			if G.p["flags"].get("tor_" + id, false):
				open_gate(g, true)
	_update_schalen()
	update_home()
	if G.p["flags"].get("hund", false):
		spawn_dog()
	if G.p["flags"].get("esel", false):
		spawn_dog("esel")
	turnier = 0
	enc_nodes.clear()
	_update_schatz()
	if G.p["flags"].get("begleitet", "") != "" and G.npcs.has(G.p["flags"]["begleitet"]):
		G.npcs[G.p["flags"]["begleitet"]].following = true
	shrine_fire.visible = G.p["flags"].get("glut", false)
	for h in pickups:
		h.visible = true
	G.playing = true
	get_tree().paused = false
	G.ui.start_hud()
	G.changed.emit()
	G.quest_changed.emit()


func _spawn(kind: String, pos: Vector3, camp: String, power: float, zone := "") -> void:
	var e = CharacterBody3D.new()
	e.set_script(EnemyScript)
	e.init(kind, pos, camp, power)
	e.zone = zone
	if camp in ["nacht", "begegnung", "turnier"]:
		e.state = "chase"        # diese Gegner kommen von sich aus auf den Helden zu
	dyn.add_child(e)


func spawn_dog(art := "hund") -> void:
	var dog = Node3D.new()
	dog.set_script(load("res://scripts/begleiter.gd"))
	dog.art = art
	dog.position = G.player.position + Vector3(2, 0, 2)
	dyn.add_child(dog)


# ---------------------------------------------------------------- Turnier, Schatzsuche, Begegnungen, Nachtgegner

func _turnier_runde(n: int) -> void:
	turnier = n
	G.say("Turnier, Runde %d von 4!" % n)
	Audio.sfx("stufe", 0.8)
	var list: Array = TURNIER[n - 1]
	for i in list.size():
		var a = i * TAU / list.size() + 0.5
		_spawn(list[i], arena + Vector3(sin(a), 0, cos(a)) * 11.0 + Vector3(0, 0.3, 0), "turnier", 1.5 + n * 0.12, "dornfeld")


func _turnier_ende(sieg: bool) -> void:
	if turnier == 0:
		return
	turnier = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.camp == "turnier":
			e.queue_free()
	if sieg:
		G.p["flags"]["titel"] = "Meister von Dornfeld"
		G.add_ruf("dornfeld", 25)
		G.add_xp(600)
		G.say("Du hast das Turnier gewonnen! Ab heute nennt man dich „Meister von Dornfeld“.")


## Schatzkarte lesen: markiert eine Grabstelle auf der Karte.
func read_map() -> void:
	if G.p["flags"].has("schatz"):
		G.say("Du folgst schon einer Schatzkarte. Das Kreuz steht auf deiner Karte (M).")
		return
	var sp: Vector3 = SCHATZ_ORTE[(int(G.p["flags"].get("schaetze", 0)) * 5 + G.p["day"]) % SCHATZ_ORTE.size()]
	G.add_item("schatzkarte", -1)
	G.p["flags"]["schatz"] = [sp.x, sp.z]
	_update_schatz()
	G.say("Die Karte zeigt eine Stelle im Umland von Aschfurt. Ein Kreuz steht jetzt auf deiner Karte (M).")


func _update_schatz() -> void:
	if schatz_node and G.p["flags"].has("schatz"):
		schatz_node.position = Vector3(G.p["flags"]["schatz"][0], 0, G.p["flags"]["schatz"][1])


func _graben() -> void:
	if G.count("schaufel") <= 0:
		G.say("Hier ist die Stelle. Aber ohne Schaufel kommst du nicht weit (Krämerladen).")
		return
	G.player.play("Digging", 1.0, true)
	fade("Du gräbst. Nach einer halben Stunde stößt die Schaufel auf Holz.", func():
		G.advance(0.5)
		var gold = 150 + randi() % 200
		var item: String = ["splitter", "kette", "heiltrank", "erz", "staerketrank"].pick_random()
		G.add_gold(gold)
		G.add_item(item, 1 if item in ["splitter", "kette"] else 3)
		G.p["flags"].erase("schatz")
		G.p["flags"]["schaetze"] = int(G.p["flags"].get("schaetze", 0)) + 1
		Audio.sfx("muenze")
		G.say("Schatz gehoben: +%d Gold, %s" % [gold, G.ITEMS[item]["name"]])
		G.changed.emit())


func _unterwegs() -> void:
	schatz_node = thing(Vector3(0, -100, 0), "Hier nach dem Schatz graben", _graben, 4.0)
	schatz_node.condition = func(): return G.playing and G.p["flags"].has("schatz")
	flat_mesh(_box(Vector3(1.2, 0.05, 0.25)), Vector3(0, 0.08, 0), Color(0.5, 0.1, 0.08), 0.9, schatz_node).rotation.y = 0.78
	flat_mesh(_box(Vector3(1.2, 0.05, 0.25)), Vector3(0, 0.08, 0), Color(0.5, 0.1, 0.08), 0.9, schatz_node).rotation.y = -0.78


func _figur(model: String, pos: Vector3, set := {}) -> Actor:
	var a = Actor.new()
	a.position = pos
	dyn.add_child(a)
	a.collision_layer = 8
	a.collision_mask = 1
	a.setup("chars2/%s.glb" % model)
	a.gear(set)
	a.play("Idle_A")
	if G.player:
		var d = G.player.global_position - pos
		a.body.rotation.y = atan2(d.x, d.z)
	enc_nodes.append(a)
	return a


func _enc_ende(a: Node) -> void:
	enc_nodes.erase(a)
	if is_instance_valid(a):
		a.queue_free()


## Zufallsbegegnungen abseits der Dörfer und Nachtgegner.
func _unterwegs_tick(pp: Vector3, fight: bool) -> void:
	var wild = Vector2(pp.x, pp.z).length() > 95.0 and pp.distance_to(Vector3(250, 0, 190)) > 70.0 and abs(pp.x) < 360.0 and abs(pp.z) < 360.0
	# Aufräumen: Begegnungen verschwinden, wenn man weit weg ist
	for a in enc_nodes.duplicate():
		if not is_instance_valid(a) or a.global_position.distance_to(pp) > 130.0:
			_enc_ende(a)
	# Nachtgegner lösen sich am Morgen auf
	if not G.is_night():
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.camp == "nacht" and not e.dead:
				ring(e.global_position, 2.0, Color(0.6, 0.6, 0.9))
				e.queue_free()
	elif wild and not fight:
		night_t -= 0.6
		if night_t <= 0.0:
			night_t = randf_range(45.0, 90.0)
			var n = 0
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.camp == "nacht":
					n += 1
			if n < 4:
				var a = randf() * TAU
				var kind = "schattenwolf" if randf() < 0.6 else "irrlicht"
				for i in 2:
					_spawn(kind, pp + Vector3(sin(a + i * 0.3), 0, cos(a + i * 0.3)) * 30.0 + Vector3(0, 0.3, 0), "nacht", 1.1 + G.p["level"] * 0.07)
				G.say("Etwas bewegt sich in der Dunkelheit." if kind == "schattenwolf" else "Blasse Lichter tanzen zwischen den Bäumen.")
	if not wild or fight or not enc_nodes.is_empty():
		return
	enc_t -= 0.6
	if enc_t > 0.0:
		return
	enc_t = randf_range(120.0, 240.0)
	var spot = pp + G.player.facing() * 24.0
	spot.y = 0.3
	match randi() % 3:
		0:      # überfallener Händler
			var h = _figur("Mage", spot, {})
			h.set_part("Mage_Hat", false)
			put("hex/wheelbarrow.gltf", Vector3(2.5, 0, 1.0), 0.8, 8.0, h)
			for i in 3:
				_spawn(["bandit", "bandit", "schuetze"][i], spot + Vector3(sin(i * 2.1), 0, cos(i * 2.1)) * 6.0, "begegnung", 1.0 + G.p["level"] * 0.07)
			G.say("Hilferufe! Ein Händler wird überfallen.")
			var it = thing(Vector3.ZERO, "Mit dem geretteten Händler sprechen", Callable(), 3.6, h)
			it.action = func():
				var gold = 60 + G.p["level"] * 10
				Audio.babble(true, 1.0, 120)
				G.ui.dialog("Fahrender Händler", "Die hätten mir alles genommen! Hier, das ist das Mindeste. Und wenn du etwas brauchst: Für dich mache ich heute Sonderpreise.", [
					["Danke. (+%d Gold)" % gold, func():
						G.add_gold(gold)
						G.add_ruf(G.ort(), 6)
						_enc_ende(h)],
					["Zeig mir deine Waren.", func():
						G.add_gold(gold)
						G.add_ruf(G.ort(), 6)
						G.ui.show_shop("dem fahrenden Händler", ["heiltrank", "manatrank", "fackel", "pfeil", "braten", "schatzkarte"])
						_enc_ende(h)]])
			it.condition = func():
				for e in get_tree().get_nodes_in_group("enemy"):
					if e.camp == "begegnung" and not e.dead and e.global_position.distance_to(h.global_position) < 40.0:
						return false
				return true
		1:      # verirrter Wanderer
			var w = _figur("Ranger", spot, {})
			thing(Vector3.ZERO, "Mit dem Wanderer sprechen", func():
				Audio.babble(false, 1.05, 120)
				var o = []
				var f = G.best_food()
				if f != "":
					o.append(["Ihm %s geben und den Weg zeigen" % G.ITEMS[f]["name"], func():
						G.add_item(f, -1)
						G.add_gold(45)
						G.add_ruf(G.ort(), 8)
						G.add_xp(30)
						G.say("Der Wanderer drückt dir dankbar 45 Gold in die Hand.")
						_enc_ende(w)])
				o.append(["Nur den Weg zeigen", func():
					G.add_xp(20)
					G.add_ruf(G.ort(), 3)
					_enc_ende(w)])
				o.append(["Weitergehen", Callable()])
				G.ui.dialog("Verirrter Wanderer", "Den Göttern sei Dank, ein Mensch! Ich laufe seit zwei Tagen im Kreis und habe seit gestern nichts gegessen. Wo geht es ins nächste Dorf?", o), 3.6, w)
		2:      # Fremder mit Rätsel
			var fr = _figur("Rogue_Hooded", spot, {})
			var q: Array = RAETSEL.pick_random()
			thing(Vector3.ZERO, "Den Fremden ansprechen", func():
				Audio.babble(false, 0.8, 160)
				var answers: Array = q[1].duplicate()
				answers.shuffle()
				var o = []
				for ans in answers:
					o.append([ans, func():
						if ans == q[1][0]:
							var got = "splitter" if randf() < 0.25 else ""
							G.add_gold(90)
							if got != "": G.add_item(got)
							G.add_xp(60)
							Audio.sfx("aufgabe")
							G.say("„Klug.“ Der Fremde wirft dir einen Beutel zu: +90 Gold%s" % (", 1 Glutsplitter" if got != "" else ""))
						else:
							G.say("„Falsch.“ Der Fremde zieht die Kapuze tiefer und geht.")
						_enc_ende(fr)])
				o.append(["Ich habe keine Zeit für Rätsel.", Callable()])
				G.ui.dialog("Ein Fremder", "Bleib stehen, Hüter. Eine Frage, eine Antwort, ein Lohn.\n\n" + q[0], o), 3.6, fr)


func enemy_died(e: Node) -> void:
	if not e.d.get("chef", false) and not e.camp in ["turnier", "nacht", "begegnung"]:
		dead.append({"kind": e.kind, "pos": e.home, "camp": e.camp, "power": e.power, "zone": e.zone, "day": G.p["day"] + 2})


func _on_new_day() -> void:
	var keep = []
	for d in dead:
		if d["day"] <= G.p["day"]:
			_spawn(d["kind"], d["pos"], d["camp"], d["power"], d.get("zone", ""))
		else:
			keep.append(d)
	dead = keep
	if not wetter.is_winter():       # im Winter wächst draußen nichts nach
		for h in pickups:
			h.visible = true
	# Garten wächst (nicht im Winter, bei Regen doppelt), Hühner legen
	for i in G.p["garten"].size():
		var b = G.p["garten"][i]
		if b != null and not wetter.is_winter():
			b["wachstum"] = int(b["wachstum"]) + (2 if G.p["flags"].get("regen_day", -1) == G.p["day"] - 1 else 1)
	G.p["flags"]["eier"] = int(G.p["flags"].get("eier", 0)) + int(G.p["flags"].get("huhn", 0))
	if G.p["flags"].get("kind_day", 99999) <= G.p["day"] and not G.p["flags"].get("m_wiege", false):
		G.p["flags"]["m_wiege"] = true
		G.say("Zu Hause steht seit heute eine Wiege. Ihr habt ein Kind bekommen.")
	update_home()
	for o in ores:
		o[0].set_meta("leer", false)
		o[1].visible = true
	G.say("Ein neuer Tag bricht an: Tag %d" % G.p["day"])


func player_died() -> void:
	await get_tree().create_timer(2.2).timeout
	fade("Dir wird schwarz vor Augen.\n\nJemand hat dich gefunden und nach Aschfurt getragen. Ein Teil deines Goldes fehlt.", func():
		G.add_gold(-int(G.p["gold"] * 0.1))
		_turnier_ende(false)
		G.p["hp"] = G.max_hp() * 0.5
		G.p["hunger"] = max(G.p["hunger"], 30.0)
		G.p["fatigue"] = max(G.p["fatigue"], 30.0)
		G.p["inside"] = false
		G.p["room"] = ""
		G.p["region"] = ""
		G.player.global_position = places["spielerhaus" if G.p["flags"].get("home", false) else "wirtshaus"] + Vector3(0, 0.4, 0)
		G.player.revive()
		G.player.snap_camera()
		G.advance(3.0, true)
		for e in get_tree().get_nodes_in_group("enemy"):
			e.state = "return"
		G.changed.emit())


func sleep_scene(text: String, quality := 1.0) -> void:
	fade(text, func():
		G.sleep(G.sleep_until_morning(), quality)
		G.save_game())


func fade(text: String, mid: Callable) -> void:
	G.ui.fade(text, mid)


func _boden() -> void:
	_environment()
	_ground()


func _process(delta: float) -> void:
	if not bereit:
		return
	_daylight(12.5 if map_baking else (G.hour() if G.playing else 18.6))
	if shrine_fire.visible:
		shrine_fire.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.08)
	for cl in clouds:
		cl.position.x += delta * 1.6
		if cl.position.x > 460.0:
			cl.position.x = -460.0
	if not G.playing:
		var t = Time.get_ticks_msec() * 0.00006
		menu_cam.global_position = Vector3(sin(t) * 62.0, 26.0, cos(t) * 62.0)
		menu_cam.look_at(Vector3(0, 3, 0))
		return
	if Input.is_action_just_pressed("bild"):
		get_viewport().get_texture().get_image().save_png("user://bild_%d.png" % Time.get_unix_time_from_system())
		G.say("Bildschirmfoto gespeichert")
	if args.has("fight"):       # Testlauf: klickt die Angriffstaste im Takt
		if Engine.get_physics_frames() % 24 == 0: Input.action_press("angriff")
		elif Engine.get_physics_frames() % 24 == 3: Input.action_release("angriff")
	check_t -= delta
	if check_t > 0.0 or G.player == null:
		return
	check_t = 0.6
	var pp: Vector3 = G.player.global_position
	if not G.p["inside"]:
		if pp.distance_to(Vector3(-120, 0, -80)) < 26.0: G.event("reach", "schrein")
		if pp.distance_to(Vector3(30, 0, -165)) < 34.0: G.event("reach", "ruinen")
		if pp.distance_to(Vector3(0, 0, -372)) < 30.0: G.event("reach", "pass")
	var fight = false
	var turnier_alive = 0
	var here: String = G.p.get("room", "")
	for c in tiere:
		# Tiere weit weg oder in anderen Gebieten ruhen
		var near_c: bool = abs(c.home.x - pp.x) + abs(c.home.z - pp.z) < 130.0
		if c.is_processing() != near_c:
			c.set_process(near_c)
	for id in G.npcs:
		# Dorfbewohner leben überall weiter, aber ihre Figur wird nur in der Nähe animiert
		var n = G.npcs[id]
		var near_n: bool = abs(n.global_position.x - pp.x) + abs(n.global_position.z - pp.z) < 150.0
		if n.anim.active != near_n:
			n.anim.active = near_n
			n.body.visible = near_n
	for e in get_tree().get_nodes_in_group("enemy"):
		var near_e: bool = e.zone == here and abs(e.global_position.x - pp.x) + abs(e.global_position.z - pp.z) < 160.0
		if e.is_physics_processing() != near_e:
			e.set_physics_process(near_e)
			e.visible = near_e
			if e.anim:
				e.anim.active = near_e      # ferne Gegner bewegen auch ihr Skelett nicht
		if e.camp == "turnier" and not e.dead:
			turnier_alive += 1
		if e.state != "idle" and e.state != "return" and e.global_position.distance_to(pp) < 30.0:
			fight = true
	if turnier > 0 and turnier_alive == 0:
		var won = turnier
		G.add_gold(PREISGELD[won - 1])
		Audio.sfx("fest")
		G.say("Runde %d gewonnen: +%d Gold" % [won, PREISGELD[won - 1]])
		if won >= TURNIER.size():
			_turnier_ende(true)
		else:
			_turnier_runde(won + 1)
	if G.p.get("room", "") == "":
		for id in BESUCH:
			if not G.p["flags"].get("ort_" + id, false) and pp.distance_to(BESUCH[id][1]) < 40.0:
				G.p["flags"]["ort_" + id] = true
				G.say("Neuer Ort entdeckt: " + BESUCH[id][0])
		_unterwegs_tick(pp, fight)
	var rm: String = G.p.get("room", "")
	if fight:
		Audio.music("kampf")
	elif dungeons.has(rm):
		Audio.music("dungeon")
	elif rm == "asche":
		Audio.music("asche")
	elif GEBIETE.has(rm):
		Audio.music("nacht" if G.is_night() else ("dorf" if pp.distance_to(GEBIETE[rm][0]) < 60.0 else "wildnis"))
	elif rm != "":
		Audio.music("haus")
	elif G.is_night():
		Audio.music("nacht")
	elif Vector2(pp.x, pp.z).length() < 75.0 or pp.distance_to(Vector3(250, 0, 190)) < 50.0:
		Audio.music("dorf")
	else:
		Audio.music("wildnis")


# ---------------------------------------------------------------- Effekte

func popup(pos: Vector3, text: String, color: Color) -> void:
	var l = Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 72
	l.outline_size = 16
	l.pixel_size = 0.011
	l.modulate = color
	add_child(l)
	l.global_position = pos
	var tw = create_tween().set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(0, 2.2, 0), 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)


func ring(pos: Vector3, radius: float, color: Color) -> void:
	var m = MeshInstance3D.new()
	var t = TorusMesh.new()
	t.inner_radius = 0.86
	t.outer_radius = 1.0
	m.mesh = t
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	add_child(m)
	m.global_position = pos + Vector3(0, 0.3, 0)
	m.scale = Vector3(0.3, 0.6, 0.3)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(radius, 0.6, radius), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(m.queue_free)


func beam(a: Vector3, b: Vector3, color: Color) -> void:
	var m = glow_mesh(_box(Vector3(0.12, 0.12, a.distance_to(b))), (a + b) / 2.0, color, 6.0)
	m.look_at_from_position((a + b) / 2.0, b)
	var tw = create_tween()
	tw.tween_interval(0.18)
	tw.tween_callback(m.queue_free)
