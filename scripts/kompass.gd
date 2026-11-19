extends Control
## Kompass am oberen Bildrand: Der Pfeil zeigt zum Ziel der verfolgten Aufgabe.

var font: Font
var angle := 0.0
var text := ""
var far := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = get_theme_default_font()
	custom_minimum_size = Vector2(420, 62)


var _t := 0.0

func _process(d: float) -> void:
	_t -= d
	if _t > 0.0:
		return
	_t = 0.08
	visible = G.playing and G.player != null and _update()
	if visible:
		queue_redraw()


## Welche Aufgabe wird verfolgt? Die gewählte, sonst die Hauptaufgabe, sonst die erste offene.
static func tracked() -> String:
	var want: String = G.p["flags"].get("verfolgt", "")
	if want != "" and G.quest_active(want):
		return want
	for id in G.p["quests"]:
		if G.quest_active(id) and G.QUESTS[id].get("main", false):
			return id
	for id in G.p["quests"]:
		if G.quest_active(id):
			return id
	return ""


func _update() -> bool:
	var id = tracked()
	if id == "":
		return false
	var w = G.world
	var goal: Vector3 = w.quest_pos(G.stage(id))
	if goal == Vector3.INF:
		return false
	var here: String = G.p.get("region", "")
	var there: String = w.gebiet_von(goal)
	far = here != there
	if far:
		text = "%s: Ziel liegt in %s" % [G.QUESTS[id]["name"], w.GEBIETE[there][1] if there != "" else "Aschfurt und Umland"]
		return true
	# im Haus oder Dungeon zeigt der Pfeil nichts Sinnvolles
	if G.p.get("room", "") != here:
		text = "%s: Ziel liegt draußen" % G.QUESTS[id]["name"]
		far = true
		return true
	var d = goal - G.player.global_position
	d.y = 0
	var yaw: float = G.player.cam_yaw
	var fwd = Vector3(-sin(yaw), 0, -cos(yaw))
	var right = Vector3(cos(yaw), 0, -sin(yaw))
	angle = atan2(d.dot(right), d.dot(fwd))
	text = "%s · %d Schritte" % [G.QUESTS[id]["name"], int(d.length())]
	return true


func _draw() -> void:
	var c = Vector2(size.x / 2.0, 22)
	draw_circle(c, 21.0, Color(0.16, 0.09, 0.04, 0.85))
	draw_arc(c, 21.0, 0, TAU, 40, Color(0.74, 0.57, 0.26), 2.0, true)
	if not far:
		var up = Vector2(sin(angle), -cos(angle))
		var side = Vector2(up.y, -up.x)
		draw_colored_polygon(PackedVector2Array([c + up * 17.0, c - up * 9.0 + side * 8.0, c - up * 3.0, c - up * 9.0 - side * 8.0]), Color(1.0, 0.75, 0.2))
	else:
		draw_circle(c, 5.0, Color(1.0, 0.75, 0.2))
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string_outline(font, Vector2(c.x - w / 2.0, 60), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Color(0.1, 0.05, 0.02, 0.9))
	draw_string(font, Vector2(c.x - w / 2.0, 60), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.98, 0.92, 0.76))
