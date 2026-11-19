extends Control
## Selbst gezeichnete Symbole für die Menüs: runde Holzknöpfe (Schließen, Plus, Minus)
## und das Wappen der Glutwacht (Flamme in der Schale). Alles Vektorzeichnung, in jeder Größe scharf.

signal gedrueckt

var art := "x"            # x, plus, minus, flamme
var knopf := true         # anklickbar, mit Holzscheibe
var aus := false          # ausgegraut
var _hover := false
var _down := false

const GOLD := Color(0.78, 0.6, 0.27)
const HOLZ := Color(0.36, 0.21, 0.11)
const HELL := Color(0.98, 0.92, 0.76)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if knopf else Control.MOUSE_FILTER_IGNORE
	if knopf:
		mouse_entered.connect(func():
			_hover = true
			queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			_down = false
			queue_redraw())


func _gui_input(e: InputEvent) -> void:
	if not knopf or aus:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
		elif _down:
			_down = false
			gedrueckt.emit()
		queue_redraw()
		accept_event()


func _draw() -> void:
	var c = size / 2.0
	var r = min(size.x, size.y) / 2.0 - 1.0
	if art == "flamme":
		_flamme(c, r)
		return
	var a = 0.4 if aus else 1.0
	var wood = HOLZ.lightened(0.18) if _hover and not aus else HOLZ
	if _down:
		wood = HOLZ.darkened(0.25)
	draw_circle(c + Vector2(0, 2), r, Color(0, 0, 0, 0.35 * a))
	draw_circle(c, r, Color(wood.r, wood.g, wood.b, a))
	draw_arc(c, r - 1.5, 0, TAU, 48, Color(GOLD.r, GOLD.g, GOLD.b, a), 2.5, true)
	draw_arc(c, r - 5.0, 0, TAU, 48, Color(0.2, 0.11, 0.05, 0.6 * a), 1.0, true)
	var col = Color(HELL.r, HELL.g, HELL.b, a)
	var k = r * 0.42
	var w = max(3.0, r * 0.2)
	match art:
		"x":
			draw_line(c - Vector2(k, k), c + Vector2(k, k), col, w, true)
			draw_line(c - Vector2(k, -k), c + Vector2(k, -k), col, w, true)
		"plus":
			draw_line(c - Vector2(k * 1.15, 0), c + Vector2(k * 1.15, 0), col, w, true)
			draw_line(c - Vector2(0, k * 1.15), c + Vector2(0, k * 1.15), col, w, true)
		"minus":
			draw_line(c - Vector2(k * 1.15, 0), c + Vector2(k * 1.15, 0), col, w, true)


## Wappen: eine Flamme über der Glutschale.
func _flamme(c: Vector2, r: float) -> void:
	var outer = PackedVector2Array()
	var inner = PackedVector2Array()
	for i in 33:
		var t = i / 32.0 * TAU
		# Tropfenform, oben spitz und leicht geschwungen
		var rad = (0.62 + 0.38 * cos(t)) * (0.9 + 0.1 * sin(t * 3.0))
		var p = Vector2(sin(t) * rad * 0.62 + sin(t * 0.5) * 0.06 * (1.0 - cos(t)), -cos(t) * 0.0)
		var y = -(cos(t) * 0.5 + 0.5)        # 0 unten, -1 oben
		p = Vector2(sin(t) * (1.0 - pow(-y, 1.6)) * 0.56 + 0.1 * sin(-y * 3.0) * -y, y * 1.5 + 0.45)
		outer.append(c + p * r)
		inner.append(c + Vector2(p.x * 0.5, p.y * 0.62 + 0.2) * r)
	draw_colored_polygon(outer, Color(0.95, 0.42, 0.1))
	draw_colored_polygon(inner, Color(1.0, 0.82, 0.3))
	# Schale
	var bowl = PackedVector2Array([c + Vector2(-0.62, 0.45) * r, c + Vector2(0.62, 0.45) * r, c + Vector2(0.4, 0.82) * r, c + Vector2(-0.4, 0.82) * r])
	draw_colored_polygon(bowl, Color(0.42, 0.3, 0.2))
	draw_line(c + Vector2(-0.66, 0.45) * r, c + Vector2(0.66, 0.45) * r, GOLD, max(2.0, r * 0.07), true)
	draw_line(c + Vector2(-0.3, 0.9) * r, c + Vector2(0.3, 0.9) * r, GOLD, max(2.0, r * 0.07), true)
