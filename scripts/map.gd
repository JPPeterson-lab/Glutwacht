extends Control
## Karte: groß im Fenster (Taste M, Mausrad zoomt, Ziehen verschiebt) oder klein als Minikarte.
## Der Hintergrund ist ein echtes Luftbild der Welt, das beim Start einmal aufgenommen wird.

const NAMES := {"wirtshaus": "Wirtshaus", "schmiede": "Schmiede", "markt": "Markt", "studierstube": "Studierstube",
	"wache": "Wache", "spielerhaus": "Dein Haus", "b_wirtshaus": "Gasthaus zum Hecht", "b_steg": "Steg", "tor": "Südtor", "muehle": "Mühle", "teich": "Teich", "holzplatz": "Holzplatz"}
const SPOTS := [["Dämmerwald", Vector3(-120, 0, -60)], ["Alte Mine", Vector3(125, 0, -40)], ["Ruinen", Vector3(30, 0, -170)],
	["Sumpf", Vector3(42, 0, 136)], ["Weidenau", Vector3(250, 0, 178)], ["Bergpass", Vector3(0, 0, -366)], ["Alter Friedhof", Vector3(-300, 0, 60)], ["Wachturm", Vector3(280, 0, -250)], ["Acker", Vector3(64, 0, 50)], ["Aschfurt", Vector3(0, 0, -6)]]
const DARK := Color(0.16, 0.09, 0.04)
const PAPER := Color(0.98, 0.93, 0.78)
var WORLD := 800.0            # Kantenlänge des Luftbilds in Welteinheiten (je Gebiet verschieden)
var origin := Vector3.ZERO    # Mittelpunkt des gezeigten Gebiets
var gebiet := ""
const ORTSNAMEN := {"salz_wirtshaus": "Zum Anker", "salz_steg": "Hafen", "salz_markt": "Fischmarkt", "salz_turm": "Leuchtturm",
	"hoch_wirtshaus": "Berghütte", "hoch_schmiede": "Meisterschmiede", "hoch_pfad": "Bergpfad", "eishoehle": "Eishöhle",
	"dorn_wirtshaus": "Zur goldenen Ähre", "dorn_markt": "Markt", "dorn_kutsche": "Kutsche", "dorn_feld": "Felder"}


func _setup() -> void:
	gebiet = G.p.get("region", "") if G.playing else ""
	if gebiet != "" and G.world.map_texs.has(gebiet):
		origin = G.world.GEBIETE[gebiet][0]
		WORLD = 480.0 if gebiet == "asche" else 400.0
	else:
		gebiet = ""
		origin = Vector3.ZERO
		WORLD = 800.0

var mini := false
var font: Font
var zoom := 1.0
var center := Vector3.ZERO
var t := 0.0
var redraw_t := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if mini else Control.MOUSE_FILTER_STOP
	font = get_theme_default_font()
	_setup()
	if not mini and G.player and G.p.get("room", "") == gebiet:
		zoom = 2.6 if gebiet == "" else 1.6
		center = G.player.global_position - origin
		_clamp()


func _process(d: float) -> void:
	t += d
	redraw_t -= d
	if is_visible_in_tree() and redraw_t <= 0.0:
		redraw_t = 0.2 if mini else 0.03      # die Minikarte muss nicht in jedem Bild neu gezeichnet werden
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if mini:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = min(9.0, zoom * 1.25)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = max(1.0, zoom / 1.25)
		_clamp()
		accept_event()
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var span = WORLD / zoom
		center -= Vector3(e.relative.x, 0, e.relative.y) / size.x * span
		_clamp()
		accept_event()


func _clamp() -> void:
	var lim = (WORLD - WORLD / zoom) / 2.0
	center.x = clamp(center.x, -lim, lim)
	center.z = clamp(center.z, -lim, lim)


func _span() -> float:
	return (130.0 if gebiet == "" else 110.0) if mini else WORLD / zoom


## Wo steht der Held auf der Karte? Im Haus oder Dungeon: an dessen Tür.
func _hero() -> Vector3:
	if G.player == null:
		return origin
	var rm: String = G.p.get("room", "")
	if rm == gebiet:
		return G.player.global_position
	return G.world.places.get(rm, G.world.places.get(G.p.get("room_door", "spielerhaus"), origin))


func _center() -> Vector3:
	if not mini:
		return center
	return _hero() - origin


func w2m(p: Vector3) -> Vector2:
	var c = _center()
	return size / 2.0 + Vector2(p.x - origin.x - c.x, p.z - origin.z - c.z) / _span() * size.x


func _draw() -> void:
	var w = G.world
	if mini:
		_setup()
	var c = _center()
	var span = _span()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.3, 0.2))
	var tex: Texture2D = w.map_tex if gebiet == "" else w.map_texs[gebiet]
	if tex:
		var ts: float = tex.get_width()
		var src = Rect2(((c.x - span / 2.0) / WORLD + 0.5) * ts, ((c.z - span / 2.0) / WORLD + 0.5) * ts, span / WORLD * ts, span / WORLD * ts)
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), src, Color(0.93, 0.86, 0.72))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.6, 0.38, 0.16))      # leichter Pergamentton
	var big = 1.0 if mini else 1.0 + (zoom - 1.0) * 0.12
	# Beschriftung
	if not mini and gebiet == "":
		for q in SPOTS:
			_text(w2m(q[1]), q[0], int(21 * big), Color(1.0, 0.9, 0.6))
		if zoom >= 2.2:
			for key in NAMES:
				if w.places.has(key):
					_text(w2m(w.places[key]) + Vector2(0, -12), NAMES[key], int(13 * big), PAPER)
	elif not mini:
		_text(w2m(origin) + Vector2(0, -26), w.GEBIETE[gebiet][1], int(22 * big), Color(1.0, 0.9, 0.6))
		for key in ORTSNAMEN:
			if w.places.has(key) and w.gebiet_von(w.places[key]) == gebiet:
				_text(w2m(w.places[key]) + Vector2(0, -12), ORTSNAMEN[key], int(13 * big), PAPER)
	# Glutschalen (Flamme, wenn sie brennt) und Dungeon-Eingänge
	for id in w.SCHALEN:
		if w.gebiet_von(w.SCHALEN[id][1]) != gebiet:
			continue
		var fp = w2m(w.SCHALEN[id][1])
		var lit = G.playing and w.schale_lit(id)
		draw_circle(fp, 6.0, DARK)
		draw_circle(fp, 4.5, Color(1.0, 0.6, 0.15) if lit else Color(0.45, 0.45, 0.5))
	for id in w.dungeons:
		if not w.places.has(id) or w.gebiet_von(w.places[id]) != gebiet:
			continue
		var ep = w2m(w.places[id])
		draw_rect(Rect2(ep - Vector2(6, 6), Vector2(12, 12)), DARK)
		draw_rect(Rect2(ep - Vector2(4, 4), Vector2(8, 8)), Color(0.55, 0.35, 0.75))
		if not mini and zoom >= 2.2:
			_text(ep + Vector2(0, 22), Dungeon.PLAENE[id]["name"], int(13 * big), PAPER)
	# Gegnerlager
	if G.playing and gebiet == "" and G.p["flags"].has("schatz"):
		# Grabstelle der Schatzkarte
		var sp = w2m(Vector3(G.p["flags"]["schatz"][0], 0, G.p["flags"]["schatz"][1]))
		for pass_ in [[DARK, 7.0], [Color(1.0, 0.85, 0.3), 3.5]]:
			draw_line(sp - Vector2(9, 9), sp + Vector2(9, 9), pass_[0], pass_[1], true)
			draw_line(sp - Vector2(9, -9), sp + Vector2(9, -9), pass_[0], pass_[1], true)
		if not mini:
			_text(sp + Vector2(0, 26), "Schatz", 14, Color(1.0, 0.9, 0.5))
	for camp in (w.CAMPS if gebiet == "" else {}):
		var cp = w2m(w.CAMPS[camp]["pos"])
		var r = 6.0 if not mini else 5.0
		for pass_ in [[DARK, 5.0], [Color(0.9, 0.15, 0.1), 2.5]]:
			draw_line(cp - Vector2(r, r), cp + Vector2(r, r), pass_[0], pass_[1], true)
			draw_line(cp - Vector2(r, -r), cp + Vector2(r, -r), pass_[0], pass_[1], true)
	if G.playing:
		# Dorfbewohner
		for id in G.npcs:
			var n = G.npcs[id]
			if not is_instance_valid(n) or w.gebiet_von(n.global_position if n.room == "" else w.places[n.room]) != gebiet:
				continue
			var np = w2m(w.places[n.room] if n.room != "" else n.global_position)
			var col = Color(1.0, 0.85, 0.3) if G.p["partner"] != id else Color(1.0, 0.45, 0.65)
			draw_circle(np, 4.5, DARK)
			draw_circle(np, 3.0, col if n.room == "" else col.darkened(0.35))
			if not mini and zoom >= 3.6:
				_text(np + Vector2(0, 18), n.d["name"].replace("Hauptmann ", ""), 12, PAPER)
		# Ziele der offenen Aufgaben (pulsierende Raute)
		for id in G.p["quests"]:
			if G.quest_active(id):
				var qp = w.quest_pos(G.stage(id))
				if qp != Vector3.INF and w.gebiet_von(qp) == gebiet:
					var m = w2m(qp).clamp(Vector2(12, 12), size - Vector2(12, 12))
					var s = 9.0 + sin(t * 4.0) * 2.0
					var pts = PackedVector2Array([m + Vector2(0, -s), m + Vector2(s * 0.8, 0), m + Vector2(0, s), m + Vector2(-s * 0.8, 0)])
					draw_colored_polygon(pts, Color(1.0, 0.75, 0.1) if G.QUESTS[id].get("main", false) else Color(0.95, 0.95, 1.0))
					draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), DARK, 2.0, true)
		# Held
		if G.player:
			var pp = w2m(_hero())
			var a = G.player.body.rotation.y
			var f = Vector2(sin(a), cos(a))
			var side = Vector2(f.y, -f.x)
			var tri = PackedVector2Array([pp + f * 13.0, pp - f * 8.0 + side * 8.0, pp - f * 3.0, pp - f * 8.0 - side * 8.0])
			draw_colored_polygon(tri, Color(0.95, 0.2, 0.15))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), Color.WHITE, 2.0, true)
	# Rand wie eine alte Karte: dunkler Verlauf und Doppellinie
	var edge = 26.0 if not mini else 12.0
	for i in 6:
		var k = edge * (1.0 - i / 6.0)
		draw_rect(Rect2(Vector2(k, k) * 0.0, size), Color(0.25, 0.14, 0.05, 0.0))
		draw_rect(Rect2(0, 0, size.x, k), Color(0.25, 0.14, 0.05, 0.09))
		draw_rect(Rect2(0, size.y - k, size.x, k), Color(0.25, 0.14, 0.05, 0.09))
		draw_rect(Rect2(0, 0, k, size.y), Color(0.25, 0.14, 0.05, 0.09))
		draw_rect(Rect2(size.x - k, 0, k, size.y), Color(0.25, 0.14, 0.05, 0.09))
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), DARK, false, 3.0)
	if not mini:
		draw_rect(Rect2(Vector2(8, 8), size - Vector2(16, 16)), Color(0.85, 0.68, 0.32, 0.9), false, 1.5)
		_compass(Vector2(size.x - 58, 62), 34.0)
	else:
		_text(Vector2(size.x / 2.0, 16), "N", 13, PAPER)


func _compass(c: Vector2, r: float) -> void:
	draw_circle(c, r + 6.0, Color(0.16, 0.09, 0.04, 0.55))
	draw_arc(c, r + 6.0, 0, TAU, 48, Color(0.85, 0.68, 0.32), 2.0, true)
	for i in 4:
		var a = i * PI / 2.0
		var d = Vector2(sin(a), -cos(a))
		var s = Vector2(d.y, -d.x)
		draw_colored_polygon(PackedVector2Array([c + d * r, c + s * r * 0.2, c - s * r * 0.2]), Color(0.9, 0.2, 0.15) if i == 0 else PAPER)
	_text(c + Vector2(0, -r - 10.0), "N", 16, PAPER)


func _text(pos: Vector2, s: String, fs: int, col: Color) -> void:
	pos.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2.0
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0.1, 0.05, 0.02, 0.9))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
