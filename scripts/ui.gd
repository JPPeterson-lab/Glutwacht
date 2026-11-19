extends CanvasLayer
## Anzeige im Spiel und alle Fenster (Menü, Charakter, Inventar, Handel, Schmiede, Truhe, Cheats).

const ACCENT := Color(1.0, 0.77, 0.42)
const ATTR_NAMES := {"str": "Stärke", "ges": "Geschick", "int": "Intelligenz", "vit": "Vitalität"}
const ATTR_HINT := {"str": "Schaden für Ritter und Barbar", "ges": "Ausdauer, kritische Treffer, Schaden der Schurkin",
	"int": "Mana, Schaden der Magierin", "vit": "Leben und Schutz"}

var theme: Theme
var hud: Control
var win: Control
var locked := false
var bars := {}
var lbl := {}
var slots := []
var toasts: VBoxContainer
var fader: ColorRect
var fade_label: Label
var fading := false
var ink := false          # dunkle Tinte auf Pergament (in Fenstern) statt heller Schrift (Anzeige)
var parchment: StyleBoxTexture
var wslots := []
var target_box: Control
const MapScript := preload("res://scripts/map.gd")


func _ready() -> void:
	G.ui = self
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme()
	fader = ColorRect.new()
	fader.color = Color(0, 0, 0, 0)
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fader.z_index = 100
	add_child(fader)
	fade_label = Label.new()
	fade_label.theme = theme
	fade_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fade_label.add_theme_font_size_override("font_size", 26)
	fade_label.modulate.a = 0.0
	fader.add_child(fade_label)
	G.toast.connect(_toast)
	G.level_up.connect(func(): Audio.sfx("stufe"))


func _box(color: Color, radius := 4, border := 0, bcolor := ACCENT) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = bcolor
	s.set_content_margin_all(10)
	return s


func _theme() -> void:
	# Holzrahmen, Pergament und Schrift mit Serifen statt glatter Flächen
	theme = Theme.new()
	var serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino", "Palatino Linotype", "Book Antiqua", "URW Palladio L", "TeX Gyre Pagella", "Georgia", "DejaVu Serif", "Times New Roman", "serif"])
	theme.default_font = serif
	theme.default_font_size = 19
	var noise = FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var grad = Gradient.new()
	grad.set_color(0, Color(0.74, 0.62, 0.42))
	grad.set_color(1, Color(0.94, 0.87, 0.68))
	var tex = NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	parchment = StyleBoxTexture.new()
	parchment.texture = tex
	parchment.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	parchment.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	parchment.set_content_margin_all(20)
	var wood = _box(Color(0.19, 0.11, 0.06, 0.94), 5, 3, Color(0.72, 0.55, 0.25))
	wood.shadow_color = Color(0, 0, 0, 0.5)
	wood.shadow_size = 8
	theme.set_stylebox("panel", "PanelContainer", wood)
	var gold = Color(0.72, 0.55, 0.25)
	theme.set_stylebox("normal", "Button", _box(Color(0.36, 0.21, 0.11), 3, 2, Color(0.55, 0.4, 0.18)))
	theme.set_stylebox("hover", "Button", _box(Color(0.5, 0.3, 0.14), 3, 2, Color(0.95, 0.78, 0.4)))
	theme.set_stylebox("pressed", "Button", _box(Color(0.25, 0.14, 0.07), 3, 2, gold))
	theme.set_stylebox("disabled", "Button", _box(Color(0.42, 0.34, 0.25, 0.55), 3, 1, Color(0.4, 0.3, 0.2, 0.5)))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 3, 2, Color(0.95, 0.78, 0.4)))
	theme.set_color("font_color", "Label", Color(0.96, 0.9, 0.76))
	theme.set_color("font_color", "Button", Color(0.98, 0.92, 0.76))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.8))
	theme.set_color("font_disabled_color", "Button", Color(0.8, 0.72, 0.6, 0.7))
	theme.set_color("font_color", "CheckButton", Color(0.22, 0.13, 0.06))
	theme.set_color("font_hover_color", "CheckButton", Color(0.5, 0.12, 0.08))
	theme.set_color("font_pressed_color", "CheckButton", Color(0.5, 0.12, 0.08))
	theme.set_stylebox("normal", "LineEdit", _box(Color(0.97, 0.92, 0.78), 3, 2, Color(0.45, 0.3, 0.15)))
	theme.set_color("font_color", "LineEdit", Color(0.22, 0.13, 0.06))
	var sep = StyleBoxLine.new()
	sep.color = Color(0.45, 0.28, 0.14, 0.7)
	sep.thickness = 2
	theme.set_stylebox("separator", "HSeparator", sep)


# ---------------------------------------------------------------- Anzeige im Spiel

func _bar(color: Color, w: float, h: float) -> ProgressBar:
	var b = ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.1), 5))
	var f = _box(color, 5)
	f.set_content_margin_all(0)
	b.add_theme_stylebox_override("fill", f)
	return b


func _label(text: String, size := 18, color := Color(0.95, 0.92, 0.85)) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if ink:
		# auf Pergament: braune Tinte, Überschriften in Rot, Nebensächliches blasser
		if color == ACCENT: color = Color(0.52, 0.1, 0.06)
		elif color.r > 0.9 and color.g > 0.9: color = Color(0.22, 0.13, 0.06)
		elif abs(color.r - color.g) < 0.05 and abs(color.g - color.b) < 0.05: color = Color(0.45, 0.36, 0.26)
		l.add_theme_color_override("font_color", color)
	else:
		l.add_theme_color_override("font_color", color)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func start_hud() -> void:
	if hud:
		hud.queue_free()
	ink = false
	wslots.clear()
	hud = Control.new()
	hud.theme = theme
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	move_child(fader, -1)
	bars.clear()
	lbl.clear()
	slots.clear()
	# links oben: Werte des Helden
	var p = PanelContainer.new()
	p.position = Vector2(18, 18)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	lbl["name"] = _label("", 18, ACCENT)
	v.add_child(lbl["name"])
	for q in [["hp", Color(0.85, 0.22, 0.25), 13.0], ["mana", Color(0.25, 0.5, 0.95), 9.0], ["stamina", Color(0.45, 0.75, 0.3), 7.0]]:
		bars[q[0]] = _bar(q[1], 300, q[2])
		v.add_child(bars[q[0]])
	var h = HBoxContainer.new()
	v.add_child(h)
	for q in [["hunger", "Sättigung", Color(0.9, 0.6, 0.25)], ["fatigue", "Wachheit", Color(0.6, 0.55, 0.9)]]:
		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 1)
		vb.add_child(_label(q[1], 12, Color(0.8, 0.8, 0.8)))
		bars[q[0]] = _bar(q[2], 144, 6)
		vb.add_child(bars[q[0]])
		h.add_child(vb)
	lbl["state"] = _label("", 13, Color(1.0, 0.5, 0.4))
	v.add_child(lbl["state"])
	# rechts oben: Uhr, Gold, Aufgaben
	var r = PanelContainer.new()
	r.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	r.position = Vector2(-358, 18)
	r.custom_minimum_size = Vector2(340, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(r)
	var rv = VBoxContainer.new()
	r.add_child(rv)
	lbl["clock"] = _label("", 17, ACCENT)
	rv.add_child(lbl["clock"])
	lbl["quest"] = _label("", 15)
	lbl["quest"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl["quest"].custom_minimum_size = Vector2(320, 0)
	rv.add_child(lbl["quest"])
	# unten: Fähigkeiten und Erfahrung
	var b = VBoxContainer.new()
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.position = Vector2(-420, -196)
	b.custom_minimum_size = Vector2(840, 0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(b)
	lbl["prompt"] = _label("", 20, ACCENT)
	lbl["prompt"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(lbl["prompt"])
	var sh = HBoxContainer.new()
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation", 8)
	b.add_child(sh)
	for i in 2:
		var wp = PanelContainer.new()
		wp.custom_minimum_size = Vector2(150, 56)
		wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wl = _label("", 14)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		wp.add_child(wl)
		sh.add_child(wp)
		wslots.append([wp, wl])
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	sh.add_child(gap)
	for i in 3:
		var sp = PanelContainer.new()
		sp.custom_minimum_size = Vector2(164, 56)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sl = _label("", 14)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sp.add_child(sl)
		sh.add_child(sp)
		slots.append([sp, sl])
	bars["xp"] = _bar(ACCENT, 840, 6)
	b.add_child(bars["xp"])
	lbl["xp"] = _label("", 12, Color(0.85, 0.85, 0.85))
	lbl["xp"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(lbl["xp"])
	var keys = _label("WASD Laufen · Maus links Angriff · rechts Block · Leertaste Ausweichen · Q Waffe · T Fackel · E Benutzen · F Essen · R Trank · mittlere Maustaste: Kamera drehen · I Inventar · C Charakter · J Aufgaben · M Karte · H Hilfe", 12, Color(0.8, 0.8, 0.8, 0.75))
	keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	keys.position = Vector2(18, -26)
	hud.add_child(keys)
	# Minikarte unten rechts
	var mp = PanelContainer.new()
	mp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mp.position = Vector2(-222, -246)
	mp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mp)
	var mini = Control.new()
	mini.set_script(MapScript)
	mini.mini = true
	mini.custom_minimum_size = Vector2(184, 184)
	mp.add_child(mini)
	var mh = _label("[M] Karte", 13, Color(0.95, 0.88, 0.7))
	mh.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mh.position = Vector2(-150, -40)
	hud.add_child(mh)
	# Anzeige des anvisierten Gegners oben in der Mitte
	target_box = PanelContainer.new()
	target_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_box.position = Vector2(-210, 92)
	target_box.custom_minimum_size = Vector2(420, 0)
	target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_box.visible = false
	hud.add_child(target_box)
	var tv = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	target_box.add_child(tv)
	lbl["target"] = _label("", 17, ACCENT)
	lbl["target"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(lbl["target"])
	bars["target"] = _bar(Color(0.8, 0.15, 0.12), 400, 14)
	tv.add_child(bars["target"])
	var komp = Control.new()
	komp.set_script(load("res://scripts/kompass.gd"))
	komp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	komp.position = Vector2(-210, 14)
	hud.add_child(komp)
	toasts = VBoxContainer.new()
	toasts.position = Vector2(18, 210)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toasts)


func set_prompt(t: String) -> void:
	if lbl.has("prompt"):
		lbl["prompt"].text = t


func _toast(t: String) -> void:
	if toasts == null or not is_instance_valid(toasts):
		return
	var was = ink
	ink = false
	var l = _label(t, 17)
	ink = was
	toasts.add_child(l)
	if toasts.get_child_count() > 7:
		toasts.get_child(0).queue_free()
	var tw = create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


var _hud_t := 0.0

func _process(_d: float) -> void:
	if not G.playing or hud == null:
		return
	var p: Dictionary = G.p
	hud.visible = not fading
	# Texte und Balken zehnmal pro Sekunde auffrischen, das genügt und spart Rechenzeit
	_hud_t -= _d
	if _hud_t > 0.0:
		return
	_hud_t = 0.1
	lbl["name"].text = "%s · %s · Stufe %d" % [p["name"], G.cls()["name"], p["level"]]
	if p["flags"].has("titel"):
		lbl["name"].text += "\n" + p["flags"]["titel"]
	bars["hp"].max_value = G.max_hp(); bars["hp"].value = p["hp"]
	bars["mana"].max_value = G.max_mana(); bars["mana"].value = p["mana"]
	bars["stamina"].max_value = G.max_stamina(); bars["stamina"].value = p["stamina"]
	bars["hunger"].value = p["hunger"]
	bars["fatigue"].value = p["fatigue"]
	bars["xp"].max_value = G.xp_need(p["level"]); bars["xp"].value = p["xp"]
	lbl["xp"].text = "Erfahrung %d / %d" % [p["xp"], G.xp_need(p["level"])]
	var st = ""
	if p["hunger"] <= 0.0: st += "Du verhungerst!  "
	elif p["hunger"] < 25.0: st += "Hungrig (schwächer)  "
	if p["fatigue"] < 25.0: st += "Übermüdet (langsamer, schwächer)  "
	if p["hunger"] > 75.0 and p["fatigue"] > 75.0: st = "Satt und ausgeruht (+10 % Schaden)"
	if G.load_now() > G.capacity(): st += "Überladen (langsamer)  "
	if p["cheats"]["god"]: st += "  [Gottmodus]"
	lbl["state"].text = st
	lbl["state"].add_theme_color_override("font_color", Color(0.6, 0.95, 0.6) if st.begins_with("Satt") else Color(1.0, 0.5, 0.4))
	lbl["clock"].text = "%s  ·  %d Gold\n%s" % [G.clock_text(), p["gold"], G.world.wetter.text()]
	var qt = ""
	for id in p["quests"]:
		if G.quest_active(id):
			qt += ("◆ " if G.QUESTS[id].get("main", false) else "◇ ") + G.QUESTS[id]["name"] + "\n    " + G.stage_text(id) + "\n"
	lbl["quest"].text = qt.strip_edges()
	for i in 2:
		var id: String = p["slots"][i]
		if id == "":
			wslots[i][1].text = "Slot %d\nleer" % (i + 1)
		else:
			wslots[i][1].text = "%s%s +%d\n%s" % ["[Q] " if i != p["active"] else "", G.WEAPONS[id]["name"], G.wlvl(id),
				("%d Pfeile" % G.count("pfeil")) if id == "bogen" else ("in der Hand" if i == p["active"] else "bereit")]
		wslots[i][0].modulate.a = 1.0 if i == p["active"] else 0.55
	# nächster Gegner im Kampf: Name, Lebensbalken, Zahlen
	var best = null
	var bd = 18.0
	if G.player and not p["inside"]:
		for e in get_tree().get_nodes_in_group("enemy"):
			var d: float = e.global_position.distance_to(G.player.global_position)
			if not e.dead and d < bd and (e.state != "idle" or d < 9.0):
				bd = d
				best = e
	target_box.visible = best != null
	if best:
		lbl["target"].text = "%s  ·  %d / %d" % [best.d["name"], ceil(best.hp), ceil(best.hp_max)]
		bars["target"].max_value = best.hp_max
		bars["target"].value = best.hp
	var sk: Array = G.cls()["skills"]
	for i in 3:
		var s: Dictionary = G.SKILLS[sk[i]]
		var cd: float = G.player.cds[i] if G.player else 0.0
		var t = "[%d] %s" % [i + 1, s["name"]]
		if G.rank(sk[i]) <= 0: t += "\nnicht erlernt"
		elif cd > 0.0: t += "\n%.0f s" % ceil(cd)
		else: t += "\n%d Mana" % s["cost"]
		slots[i][1].text = t
		slots[i][0].modulate.a = 0.45 if (G.rank(sk[i]) <= 0 or cd > 0.0) else 1.0


func _unhandled_input(e: InputEvent) -> void:
	if fading or not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.is_action("ui_cancel"):
		if win and not locked:
			close()
		elif G.playing and not win:
			show_pause()
		get_viewport().set_input_as_handled()
		return
	if not G.playing or locked:
		return
	for q in [["inventar", show_inventory], ["charakter", show_character], ["aufgaben", show_quests], ["cheats", show_cheats], ["karte", show_map], ["hilfe", show_help]]:
		if e.is_action(q[0]):
			var same: bool = win != null and win.get_meta("kind", "") == q[0]
			close()
			if not same:
				q[1].call()
				win.set_meta("kind", q[0])
			get_viewport().set_input_as_handled()
			return
	if e.is_action("schnellspeichern") and not win:
		G.save_game()


# ---------------------------------------------------------------- Fenster

func open(title: String, size := Vector2(780, 0), pause := true, lock := false) -> VBoxContainer:
	close()
	locked = lock
	ink = true
	win = ColorRect.new()
	win.color = Color(0.05, 0.03, 0.0, 0.5 if pause else 0.25)
	win.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.theme = theme
	add_child(win)
	move_child(fader, -1)
	var c = CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.add_child(c)
	var frame = PanelContainer.new()        # Holzrahmen
	var fs = _box(Color(0.24, 0.14, 0.07), 6, 4, Color(0.74, 0.57, 0.26))
	fs.set_content_margin_all(9)
	fs.shadow_color = Color(0, 0, 0, 0.6)
	fs.shadow_size = 18
	frame.add_theme_stylebox_override("panel", fs)
	c.add_child(frame)
	var p = PanelContainer.new()            # Pergament
	p.add_theme_stylebox_override("panel", parchment)
	p.custom_minimum_size = size
	frame.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head = HBoxContainer.new()
	v.add_child(head)
	if title != "":
		head.add_child(pic("flamme", 44))
	var t = _label(title, 25, ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	if title != "" and lock:
		head.add_child(pic("flamme", 44))
	if not lock:
		icon_btn(head, "x", close, false, 46)
	if title != "":
		v.add_child(HSeparator.new())
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(size.x - 20, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 7)
	sc.add_child(body)
	sc.set_meta("body", body)
	win.set_meta("scroll", sc)
	G.ui_open = true
	if pause and G.playing:
		get_tree().paused = true
	_fit.call_deferred(sc, body)
	return body


func _fit(sc: ScrollContainer, body: Control) -> void:
	if is_instance_valid(sc) and is_instance_valid(body):
		sc.custom_minimum_size.y = max(min(body.get_combined_minimum_size().y + 4, 700), sc.get_meta("mindest", 0))


func close() -> void:
	Audio.hush()
	if win:
		win.queue_free()
		win = null
	locked = false
	ink = false
	G.ui_open = false
	if not fading:
		get_tree().paused = false


const ZeichenScript := preload("res://scripts/zeichen.gd")


## Selbst gezeichnetes Symbol (siehe zeichen.gd): als Verzierung ...
func pic(n: String, height: float) -> Control:
	var z = Control.new()
	z.set_script(ZeichenScript)
	z.art = n
	z.knopf = false
	z.custom_minimum_size = Vector2(height * 0.8, height)
	return z


## ... oder als runder Holzknopf (Schließen, Plus, Minus).
func icon_btn(parent: Node, n: String, cb: Callable, disabled := false, px := 44) -> Control:
	var z = Control.new()
	z.set_script(ZeichenScript)
	z.art = n
	z.aus = disabled
	z.custom_minimum_size = Vector2(px, px)
	z.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	z.gedrueckt.connect(func():
		Audio.sfx("klick")
		cb.call())
	parent.add_child(z)
	return z


func btn(parent: Node, text: String, cb: Callable, disabled := false):
	var sym = {"+": "plus", "−": "minus", "✕": "x"}.get(text.strip_edges(), "")
	if sym != "":
		var holder = CenterContainer.new()
		holder.custom_minimum_size = Vector2(60, 0)
		parent.add_child(holder)
		icon_btn(holder, sym, cb, disabled)
		return holder
	var b = Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(func():
		Audio.sfx("klick")
		cb.call())
	parent.add_child(b)
	return b


func row(parent: Node, text: String, btn_text := "", cb := Callable(), disabled := false, color := Color(0.95, 0.92, 0.85)) -> HBoxContainer:
	var h = HBoxContainer.new()
	var l = _label(text, 17, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	h.add_child(l)
	if btn_text != "":
		btn(h, btn_text, cb, disabled).custom_minimum_size = Vector2(130, 0)
	parent.add_child(h)
	return h


func head(parent: Node, text: String) -> void:
	parent.add_child(_label("❧ " + text, 17, ACCENT))


func dialog(title: String, text: String, options: Array) -> void:
	var b = open(title, Vector2(760, 0))
	var l = _label(text, 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(720, 0)
	b.add_child(l)
	b.add_child(HSeparator.new())
	for o in options:
		var cb: Callable = o[1]
		var bt = btn(b, o[0], func():
			close()
			if cb.is_valid():
				cb.call())
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT


func fade(text: String, mid: Callable) -> void:
	if fading:
		return
	close()
	fading = true
	get_tree().paused = true
	fade_label.text = text
	var tw = create_tween()
	tw.tween_property(fader, "color:a", 1.0, 0.5)
	tw.tween_property(fade_label, "modulate:a", 1.0, 0.4)
	await tw.finished
	if mid.is_valid():
		mid.call()
	await get_tree().create_timer(2.4).timeout
	var t2 = create_tween()
	t2.tween_property(fade_label, "modulate:a", 0.0, 0.3)
	t2.tween_property(fader, "color:a", 0.0, 0.6)
	await t2.finished
	fading = false
	get_tree().paused = false


# ---------------------------------------------------------------- Hauptmenü und Erstellung

func show_menu() -> void:
	if hud:
		hud.visible = false
	var b = open("", Vector2(460, 0), false, true)
	var th = HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 14)
	b.add_child(th)
	th.add_child(pic("flamme", 92))
	var t = _label("Glutwacht", 72, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	th.add_child(t)
	th.add_child(pic("flamme", 92))
	var s = _label("Hüter der letzten Flamme", 18)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(s)
	b.add_child(HSeparator.new())
	btn(b, "Neues Spiel", func(): show_slots(true))
	btn(b, "Spiel laden", func(): show_slots(false), not G.has_save())
	btn(b, "Einstellungen", show_settings)
	btn(b, "Hilfe und Chronik", show_help)
	btn(b, "Beenden", func(): get_tree().quit())
	b.add_child(_label("Figuren und Umgebung: KayKit (Kay Lousberg, CC0)", 12, Color(0.7, 0.7, 0.7)))


func show_create(sel := "ritter", pname := "Aldric", extra := {}) -> void:
	var b = open("Charakter erschaffen", Vector2(820, 0), false, true)
	var c: Dictionary = G.CLASSES[sel]
	var name_edit = LineEdit.new()
	name_edit.text = pname
	name_edit.max_length = 16
	name_edit.placeholder_text = "Name"
	b.add_child(name_edit)
	head(b, "Klasse")
	var h = HBoxContainer.new()
	b.add_child(h)
	for k in G.CLASSES:
		var bt = btn(h, G.CLASSES[k]["name"], func(): show_create(k, name_edit.text, {}))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if k == sel:
			bt.add_theme_stylebox_override("normal", _box(Color(0.4, 0.28, 0.14), 8, 1, ACCENT))
	var d = _label("%s\nWaffe: %s · Schutz: %s · Fähigkeiten: %s" % [c["desc"], G.WEAPONS[c["start"][0]]["name"] + " und " + G.WEAPONS[c["start"][1]]["name"], c["guard"],
		", ".join(c["skills"].map(func(s): return G.SKILLS[s]["name"]))], 16)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(780, 0)
	b.add_child(d)
	var used = 0
	for k in extra:
		if not k.begins_with("_"):
			used += extra[k]
	head(b, "Attribute (noch %d Punkte frei)" % (5 - used))
	for k in ATTR_NAMES:
		var h2 = HBoxContainer.new()
		b.add_child(h2)
		var l = _label("%s  %d    %s" % [ATTR_NAMES[k], c["attr"][k] + extra.get(k, 0), ATTR_HINT[k]], 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(l)
		btn(h2, " − ", func():
			extra[k] = extra.get(k, 0) - 1
			show_create(sel, name_edit.text, extra), extra.get(k, 0) <= 0)
		btn(h2, " + ", func():
			extra[k] = extra.get(k, 0) + 1
			show_create(sel, name_edit.text, extra), used >= 5)
	head(b, "Schwierigkeit")
	var sh = HBoxContainer.new()
	b.add_child(sh)
	var ssel: int = extra.get("_schwer", 1)
	for v in 3:
		var sb = btn(sh, G.SCHWER[v].capitalize(), func():
			extra["_schwer"] = v
			show_create(sel, name_edit.text, extra))
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if v == ssel:
			sb.add_theme_stylebox_override("normal", _box(Color(0.55, 0.14, 0.08), 3, 2, Color(0.95, 0.78, 0.4)))
	var vh = HBoxContainer.new()
	var vsel: int = extra.get("_voice", 0)
	if Audio.has_voices():
		head(b, "Stimme im Kampf (Kampfrufe aus einem Stimmenpaket; „Aus“ ist die Voreinstellung)")
		b.add_child(vh)
	for v in (4 if Audio.has_voices() else 0):
		var vb = btn(vh, "Aus" if v == 0 else "Stimme %d" % v, func():
			extra["_voice"] = v
			Audio.voice("attack", v)
			show_create(sel, name_edit.text, extra))
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if v == vsel:
			vb.add_theme_stylebox_override("normal", _box(Color(0.55, 0.14, 0.08), 3, 2, Color(0.95, 0.78, 0.4)))
	b.add_child(HSeparator.new())
	btn(b, "Abenteuer beginnen", func():
		var attr = {}
		for k in ATTR_NAMES:
			attr[k] = c["attr"][k] + extra.get(k, 0)
		var n = name_edit.text.strip_edges()
		G.new_game(n if n != "" else "Namenlos", sel, attr)
		G.p["talents"][c["skills"][0]] = 1
		G.p["voice"] = vsel
		G.p["schwer"] = ssel
		close()
		G.world.start_game()
		dialog("Die Legende der Glutwacht", Texte.LEGENDE, [["Weiter", func():
			dialog("Dein Weg nach Aschfurt", Texte.KLASSEN_GESCHICHTE[sel], [["Weiter", func():
				dialog("Aschfurt", "Du erreichst das Dorf am Rand des Dämmerwaldes. Hauptmann Gernot wartet bei der Wache im Norden des Dorfes, dein Haus steht westlich vom Brunnen.\n\nAuch Hüter müssen essen und schlafen. Die Taste H erklärt alles Weitere, M zeigt die Karte.", [["Los geht's", Callable()]])]])]]))
	btn(b, "Zurück", show_menu)


## Drei Spielstände: Auswahl für ein neues Spiel oder zum Laden.
func show_slots(new_game: bool) -> void:
	var b = open("Neues Spiel: Spielstand wählen" if new_game else "Spiel laden", Vector2(620, 0), G.playing, not G.playing)
	for n in [1, 2, 3]:
		var info = G.slot_info(n)
		btn(b, "Spielstand %d:  %s%s" % [n, info, "  (wird überschrieben)" if new_game and info != "leer" else ""], func():
			if new_game:
				G.slot = n
				show_create()
			elif G.load_game(n):
				close()
				G.world.start_game(), not new_game and info == "leer")
	btn(b, "Zurück", show_menu if not G.playing else show_pause)


var waiting_key := ""

func show_settings() -> void:
	var b = open("Einstellungen", Vector2(760, 0), G.playing, not G.playing)
	var o: Dictionary = G.opt
	head(b, "Bild")
	row(b, "Grafikqualität: %s" % ["Niedrig (für Laptops, kühl)", "Mittel", "Hoch"][int(o["quality"])], "Ändern", func():
		o["quality"] = (int(o["quality"]) + 1) % 3
		_opt_changed())
	var sz: Array = G.SIZES[clamp(int(o["size"]), 0, G.SIZES.size() - 1)]
	row(b, "Fenstergröße: %d × %d" % [sz[0], sz[1]], "Ändern", func():
		o["size"] = (int(o["size"]) + 1) % G.SIZES.size()
		_opt_changed(), o["fullscreen"])
	row(b, "Vollbild: %s" % ("an" if o["fullscreen"] else "aus"), "Umschalten", func():
		o["fullscreen"] = not o["fullscreen"]
		_opt_changed())
	row(b, "Bilder pro Sekunde höchstens: %s  (weniger = kühler und leiser)" % ["30", "45", "60", "unbegrenzt"][int(o["fps"])], "Ändern", func():
		o["fps"] = (int(o["fps"]) + 1) % 4
		_opt_changed())
	row(b, "Bildsynchronisation (VSync): %s" % ("an" if o["vsync"] else "aus"), "Umschalten", func():
		o["vsync"] = not o["vsync"]
		_opt_changed())
	head(b, "Eingabe")
	row(b, "Gamepad: %s" % ("an" if o["pad"] else "aus (nur Tastatur und Maus)"), "Umschalten", func():
		o["pad"] = not o["pad"]
		_opt_changed())
	head(b, "Kampf")
	if G.playing:
		row(b, "Schwierigkeit: %s  (leicht: Gegner schwächer · schwer: Gegner härter und zäher)" % G.SCHWER[int(G.p.get("schwer", 1))], "Ändern", func():
			G.p["schwer"] = (int(G.p.get("schwer", 1)) + 1) % 3
			show_settings())
	row(b, "Zielen: %s" % ("mit der Maus" if o["aim"] else "automatisch auf den nächsten Gegner"), "Umschalten", func():
		o["aim"] = not o["aim"]
		_opt_changed())
	if G.playing and Audio.has_voices():
		row(b, "Kampfrufe des Helden: %s" % ("aus" if int(G.p.get("voice", 0)) == 0 else "Stimme %d" % int(G.p["voice"])), "Ändern", func():
			G.p["voice"] = (int(G.p.get("voice", 0)) + 1) % 4
			Audio.voice("attack")
			show_settings())
	head(b, "Tastenbelegung (anklicken, dann die neue Taste drücken)")
	for a in G.KEY_LABELS:
		row(b, G.KEY_LABELS[a], "…" if waiting_key == a else G.key_name(a), func():
			waiting_key = a
			show_settings())
	btn(b, "Zurück", show_menu if not G.playing else show_pause)


func _opt_changed() -> void:
	G.save_opt()
	G.apply_opt()
	show_settings()


func _input(e: InputEvent) -> void:
	# fängt die nächste Taste für die Tastenbelegung ab
	if waiting_key != "" and e is InputEventKey and e.pressed:
		if e.physical_keycode != KEY_ESCAPE:
			G.rebind(waiting_key, e.physical_keycode)
		waiting_key = ""
		get_viewport().set_input_as_handled()
		show_settings()


func show_pause() -> void:
	var b = open("Pause", Vector2(520, 0))
	btn(b, "Weiterspielen", close)
	btn(b, "Speichern (Spielstand %d)" % G.slot, func(): G.save_game())
	btn(b, "Spielstand laden", func(): show_slots(false))
	btn(b, "Einstellungen", show_settings)
	head(b, "Musiklautstärke")
	var sl = HSlider.new()
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = Audio.music_volume
	sl.value_changed.connect(func(v):
		Audio.set_music_volume(v)
		G.opt["music"] = v
		G.save_opt())
	b.add_child(sl)
	head(b, "Klänge")
	var s2 = HSlider.new()
	s2.max_value = 1.0
	s2.step = 0.05
	s2.value = Audio.sfx_volume
	s2.value_changed.connect(func(v):
		Audio.sfx_volume = v
		G.opt["sfx"] = v
		G.save_opt())
	b.add_child(s2)
	btn(b, "Hilfe und Chronik (H)", show_help)
	btn(b, "Cheats (F1)", show_cheats)
	btn(b, "Zum Hauptmenü (speichert)", func():
		G.save_game()
		G.playing = false
		close()
		G.world.menu_cam.make_current()
		Audio.music("menue")
		show_menu())
	btn(b, "Spiel beenden (speichert)", func():
		G.save_game()
		get_tree().quit())
	var k = _label("Kamera: Q / X drehen, Mausrad zoomen, mittlere Maustaste ziehen · F5 Schnellspeichern · F12 Bildschirmfoto", 13, Color(0.75, 0.75, 0.75))
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(k)


# ---------------------------------------------------------------- Charakter, Inventar, Aufgaben

func show_character() -> void:
	var p: Dictionary = G.p
	var c: Dictionary = G.cls()
	var b = open("%s · %s · Stufe %d" % [p["name"], c["name"], p["level"]], Vector2(860, 0))
	row(b, "Leben %d · Mana %d · Ausdauer %d · Schaden %.0f · Schutz %d %% · Kritisch %d %%" % [G.max_hp(), G.max_mana(), G.max_stamina(),
		G.damage(), int(G.defense() * 100), int(G.crit_chance() * 100)])
	var worn = []
	for part in G.ARMOR:
		if int(p["armor"][part]) > 0:
			worn.append(G.ARMOR[part]["tiers"][int(p["armor"][part]) - 1][0])
	row(b, "Rüstung: " + (", ".join(worn) if not worn.is_empty() else "keine (Hilda verkauft Helm, Brust und Stiefel)"))
	row(b, "%s +%d%s · %s +%d" % [G.weapon()["name"], G.wlvl(), (" mit " + G.RUNES[p["rune"]]["name"]) if p["rune"] != "" else "", c["guard"], p["guard_lvl"]])
	head(b, "Attribute (%d Punkte frei) · im Haus und auf dem Übungsplatz kannst du sie auch trainieren" % p["attr_pts"])
	for k in ATTR_NAMES:
		var need: int = 2 + int(p["attr"][k] / 3.0)
		row(b, "%s  %d    %s    (Training %d/%d)" % [ATTR_NAMES[k], p["attr"][k], ATTR_HINT[k], p["train"][k], need], " + ", func():
			p["attr"][k] += 1
			p["attr_pts"] -= 1
			show_character(), p["attr_pts"] <= 0)
	head(b, "Fähigkeiten (%d Talentpunkte frei)" % p["talent_pts"])
	for id in c["skills"]:
		var s: Dictionary = G.SKILLS[id]
		_talent_row(b, id, "%s  Rang %d/%d    %s (%d Mana, %d s)" % [s["name"], G.rank(id), G.MAX_RANK, s["desc"], s["cost"], s["cd"]])
	var rufe = []
	for o in G.ORTE:
		if G.ruf(o) > 0:
			rufe.append("%s %d" % [G.ORTE[o], G.ruf(o)])
	row(b, "Ruf: " + (", ".join(rufe) if not rufe.is_empty() else "noch keiner (Aufgaben erledigen)") + "    Gepäck: %d von %d" % [G.load_now(), G.capacity()])
	head(b, "Berufe (steigen durch Ausüben)")
	for j in G.JOBS:
		row(b, "%s  Stufe %d    %s" % [G.JOBS[j][0], G.job_lvl(j), G.JOBS[j][1]])
	head(b, "Talente")
	for id in G.PASSIVES:
		_talent_row(b, id, "%s  Rang %d/%d    %s" % [G.PASSIVES[id]["name"], G.rank(id), G.MAX_RANK, G.PASSIVES[id]["desc"]])
	win.set_meta("kind", "charakter")


func _talent_row(b: Node, id: String, text: String) -> void:
	row(b, text, " + ", func():
		G.p["talents"][id] = G.rank(id) + 1
		G.p["talent_pts"] -= 1
		show_character(), G.p["talent_pts"] <= 0 or G.rank(id) >= G.MAX_RANK)


func _item_text(i: String, n: int) -> String:
	var d: Dictionary = G.ITEMS[i]
	var t = "%s × %d" % [d["name"], n]
	if d["type"] == "food": t += "    Sättigung +%d, Leben %+d" % [d["hunger"], d.get("heal", 0)]
	elif d.has("heal"): t += "    Leben +%d" % d["heal"]
	elif d.has("mana"): t += "    Mana +%d" % d["mana"]
	elif d["type"] == "gift": t += "    Geschenk"
	elif d["type"] == "mat": t += "    Material"
	elif d["type"] == "saat": t += "    Saat für den Garten"
	elif d["type"] == "tool": t += "    Licht für die Nacht (Rest der brennenden: %.1f Std.)" % max(0.0, G.p.get("torch_left", 0.0))
	return t


func show_inventory() -> void:
	var b = open("Inventar · %d Gold" % G.p["gold"], Vector2(760, 0))
	head(b, "Waffen (Taste Q wechselt zwischen den beiden Slots)")
	for id in G.p["weapons"]:
		var w: Dictionary = G.WEAPONS[id]
		var where = ""
		if G.p["slots"][0] == id: where = "   [Slot 1]"
		if G.p["slots"][1] == id: where = "   [Slot 2]"
		var h = row(b, "%s +%d%s\n%s Grundschaden %.0f%s" % [w["name"], G.wlvl(id), where, w["desc"], w["base"] + G.wlvl(id) * 3.5, "" if G.proficient(id) else " · ungeübt (25 % weniger)"],
			"Slot 1", func(): _equip(id, 0), G.p["slots"][0] == id)
		btn(h, "Slot 2", func(): _equip(id, 1), G.p["slots"][1] == id).custom_minimum_size = Vector2(90, 0)
	head(b, "Gepäck (%d von %d Stück%s)" % [G.load_now(), G.capacity(), ", überladen: du bist langsamer" if G.load_now() > G.capacity() else ""])
	if G.p["inv"].is_empty():
		row(b, "Dein Gepäck ist leer.")
	for i in G.p["inv"].keys():
		var ty: String = G.ITEMS[i]["type"]
		if ty == "karte":
			row(b, _item_text(i, G.count(i)) + "    zeigt eine Grabstelle", "Lesen", func():
				close()
				G.world.read_map())
		elif ty == "tool":
			row(b, _item_text(i, G.count(i)) + "    Taste T", "Löschen" if G.p.get("torch", false) else "Anzünden", func():
				G.player.torch()
				show_inventory())
		elif ty == "food" or ty == "potion":
			row(b, _item_text(i, G.count(i)), "Essen" if ty == "food" else "Trinken", func():
				G.use_item(i)
				show_inventory())
		else:
			row(b, _item_text(i, G.count(i)))
	win.set_meta("kind", "inventar")


func _equip(id: String, slot: int) -> void:
	var sl: Array = G.p["slots"]
	if sl[1 - slot] == id:
		sl[1 - slot] = sl[slot]
	sl[slot] = id
	if sl[G.p["active"]] == "":
		G.p["active"] = 1 - G.p["active"]
	G.player.refresh_gear()
	G.player.play(G.weapon()["idle"], 1.0, true)
	show_inventory()


## Hilfe-Wiki: Abschnitte als Knöpfe oben, Text darunter.
func show_help(sec := "steuerung") -> void:
	var b = open("Hilfe und Chronik", Vector2(900, 0), G.playing, not G.playing)
	win.get_meta("scroll").set_meta("mindest", 520)
	var flow = HFlowContainer.new()
	b.add_child(flow)
	var all = Texte.WIKI.duplicate()
	all.append(["gegenstaende", "Gegenstände", ""])
	all.append(["waffenliste", "Waffenliste", ""])
	all.append(["chronik", "Die Glutwacht", Texte.LEGENDE])
	all.append(["leute", "Die Leute von Aschfurt", ""])
	all.append(["taten", "Chronik deiner Taten", ""])
	all.append(["lizenzen", "Mitwirkende und Lizenzen", ""])
	var text = ""
	for e in all:
		var bt = btn(flow, e[1], func(): show_help(e[0]))
		if e[0] == sec:
			bt.add_theme_stylebox_override("normal", _box(Color(0.55, 0.14, 0.08), 3, 2, Color(0.95, 0.78, 0.4)))
			text = e[2]
	b.add_child(HSeparator.new())
	if sec == "gegenstaende":
		for i in G.ITEMS:
			var d: Dictionary = G.ITEMS[i]
			var t = d["name"] + ":  " + Texte.ITEM_INFO.get(i, "")
			if d["type"] == "food": t += "  (Sättigung +%d, Leben %+d)" % [d["hunger"], d.get("heal", 0)]
			t += "  ·  Preis %d Gold" % d["price"]
			row(b, t)
	elif sec == "waffenliste":
		for i in G.WEAPONS:
			var w: Dictionary = G.WEAPONS[i]
			row(b, "%s:  %s Grundschaden %.0f, Reichweite %.0f, Attribut %s, Preis %d Gold" % [w["name"], w["desc"], w["base"], w["range"], ATTR_NAMES[w["attr"]], w["price"]])
	elif sec == "lizenzen":
		var t = "Glutwacht: Programmcode, Spieltexte sowie die selbst erzeugte Musik und Klänge stehen unter der MIT-Lizenz.\n\n"
		t += "Figuren, Gebäude, Waffen, Möbel, Natur und Animationen: KayKit von Kay Lousberg (www.kaylousberg.com), CC0 1.0 (gemeinfrei).\n\n"
		t += "Erstellt mit der Godot Engine (godotengine.org/license):\n\n" + Engine.get_license_text() + "\n\nDie Godot Engine enthält Komponenten Dritter:\n"
		for info in Engine.get_copyright_info():
			var lines = []
			for part in info["parts"]:
				for c in part["copyright"]:
					lines.append(c)
				lines.append("Lizenz: " + part["license"])
			t += "\n%s: %s" % [info["name"], "; ".join(lines)]
		t += "\n\nDie vollständigen Lizenztexte stehen unter godotengine.org/license."
		var l = _label(t, 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(850, 0)
		b.add_child(l)
	elif sec == "taten":
		if not G.playing:
			row(b, "Hier steht, was du im Spiel erreicht hast. Starte oder lade ein Spiel.")
		else:
			var f: Dictionary = G.p["flags"]
			var E = load("res://scripts/enemy.gd")
			row(b, "%s, %s, Stufe %d%s · Tag %d · Schwierigkeit %s" % [G.p["name"], G.cls()["name"], G.p["level"], (", " + f["titel"]) if f.has("titel") else "", G.p["day"], G.SCHWER[int(G.p.get("schwer", 1))]])
			var done = 0
			for q in G.p["quests"]:
				if G.quest_done(q): done += 1
			row(b, "Besiegte Gegner: %d · erledigte Aufgaben: %d · gehobene Schätze: %d" % [G.p["kills"], done, int(f.get("schaetze", 0))])
			head(b, "Besiegte Endgegner")
			var bosse = {"boss": "Aschenritter", "mine_boss": "Der Knochenhauer", "gruft_boss": "Gruftfürst Malrik", "turmkeller_boss": "Hauptmann ohne Namen",
				"leuchtturm_boss": "Der Schmugglerkönig", "eishoehle_boss": "Frostgeist", "hort_w": "Wächter des Westhorts", "hort_o": "Wächter des Osthorts", "thron_boss": "Alderan, der Aschenkönig"}
			var nb = 0
			for k in bosse:
				if f.get(k + "_tot", false):
					row(b, "✦ " + bosse[k])
					nb += 1
			if nb == 0: row(b, "noch keiner", "", Callable(), false, Color(0.6, 0.6, 0.6))
			head(b, "Entzündete Glutschalen")
			var lit = []
			for id in G.world.SCHALEN:
				if G.world.schale_lit(id): lit.append(G.world.SCHALEN[id][0])
			row(b, "%d von %d: %s" % [lit.size(), G.world.SCHALEN.size(), ", ".join(lit)])
			head(b, "Besuchte Orte")
			var orte = ["Aschfurt"]
			for id in G.world.BESUCH:
				if f.get("ort_" + id, false): orte.append(G.world.BESUCH[id][0])
			for id in G.world.GEBIETE:
				if f.get("ort_" + id, false): orte.append(G.world.GEBIETE[id][1])
			for id in G.world.dungeons:
				if f.get("ort_" + id, false): orte.append(Dungeon.PLAENE[id]["name"])
			row(b, ", ".join(orte))
			if f.has("ende"):
				head(b, "Das Ende deiner Geschichte")
				row(b, {"a": "Der Hüter am Berg", "b": "Zwölf Flammen", "c": "Der neue Aschenkönig"}[f["ende"]])
	elif sec == "leute":
		var Npc = load("res://scripts/npc.gd")
		for id in Npc.PEOPLE:
			var pd: Dictionary = Npc.PEOPLE[id]
			var known = G.playing and G.npc_data(id).get("bio", false)
			row(b, "%s, %s%s\n%s" % [pd["name"], pd["job"], "  (umwerbbar)" if pd["romance"] else "",
				("„" + Texte.BIO.get(id, "") + "“") if known else "Frag nach: „Erzähl mir von dir“, dann steht die Geschichte hier."])
	else:
		if sec == "chronik" and G.playing:
			text += "\n\nDeine Geschichte: " + Texte.KLASSEN_GESCHICHTE[G.p["cls"]]
		var l = _label(text, 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(850, 0)
		b.add_child(l)
	if not G.playing:
		btn(b, "Zurück", show_menu)
	else:
		win.set_meta("kind", "hilfe")


func show_map() -> void:
	var reg: String = G.p.get("region", "") if G.playing else ""
	var b = open(G.world.GEBIETE[reg][1] if reg != "" else "Aschfurt und Umland", Vector2(700, 0))
	var m = Control.new()
	m.set_script(MapScript)
	m.custom_minimum_size = Vector2(660, 660)
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_child(m)
	var hint = _label("Mausrad: zoomen · Ziehen: verschieben · Pfeil: du · Raute: Aufgabenziel · Kreuz: Gegnerlager · Punkte: Dorfbewohner", 13, Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(hint)
	win.set_meta("kind", "karte")


func show_quests() -> void:
	var b = open("Aufgaben", Vector2(780, 0))
	head(b, "Offen")
	for id in G.p["quests"]:
		if G.quest_active(id):
			var Komp = load("res://scripts/kompass.gd")
			var on: bool = Komp.tracked() == id
			row(b, ("Hauptaufgabe: " if G.QUESTS[id].get("main", false) else "Nebenaufgabe: ") + G.QUESTS[id]["name"] + ("   (Kompass zeigt hierhin)" if on else "") + "\n" + G.stage_text(id),
				"Verfolgen", func():
					G.p["flags"]["verfolgt"] = id
					show_quests(), on)
	head(b, "Erledigt")
	for id in G.p["quests"]:
		if G.quest_done(id):
			row(b, G.QUESTS[id]["name"], "", Callable(), false, Color(0.6, 0.6, 0.6))
	win.set_meta("kind", "aufgaben")


# ---------------------------------------------------------------- Handel, Schmiede, Truhe, Kochen

func show_shop(who: String, stock_in: Array) -> void:
	var o: String = G.ort()
	var stock: Array = stock_in.duplicate()
	if G.ruf() >= 30:       # besondere Waren für angesehene Kunden
		for extra in G.SONDERWAREN.get(o, []):
			if not extra in stock:
				stock.append(extra)
	var b = open("Handel mit %s · %d Gold" % [who, G.p["gold"]], Vector2(840, 0))
	row(b, "Ort: %s · dein Ruf hier: %d (Nachlass %d %%)%s · Gepäck %d von %d%s" % [G.ORTE[o], G.ruf(), int(min(0.2, G.ruf() / 250.0) * 100),
		" · Markttag: 20 % Nachlass" if G.world.wetter.today() == "Markttag" else "", G.load_now(), G.capacity(), "  (überladen!)" if G.load_now() > G.capacity() else ""])
	head(b, "Kaufen")
	for i in stock:
		var d: Dictionary = G.ITEMS[i]
		var n = 10 if i == "pfeil" else 1       # Pfeile im Zehnerbündel
		var cost: int = G.preis(i) * n
		var f: float = G.PREISE.get(o, {}).get(i, 1.0)
		var hint = "  (hier günstig)" if f < 0.85 else ("  (hier teuer)" if f > 1.15 else "")
		row(b, _item_text(i, 1).replace(" × 1", "") + ("  (Bündel mit 10)" if n > 1 else "") + hint, "%d Gold" % cost, func():
			G.add_gold(-cost)
			G.add_item(i, n)
			Audio.sfx("muenze")
			show_shop(who, stock_in), G.p["gold"] < cost)
	head(b, "Verkaufen")
	for i in G.p["inv"].keys():
		var d: Dictionary = G.ITEMS[i]
		if d["type"] == "quest":
			continue
		var pr: int = G.preis(i, true)
		var f: float = G.PREISE.get(o, {}).get(i, 1.0)
		row(b, "%s × %d%s" % [d["name"], G.count(i), "  (bringt hier viel)" if f > 1.15 else ("  (bringt hier wenig)" if f < 0.85 else "")], "+%d Gold" % pr, func():
			G.add_item(i, -1)
			G.add_gold(pr)
			Audio.sfx("muenze")
			show_shop(who, stock_in))


func show_alchemie() -> void:
	var b = open("Elaras Alchemietisch", Vector2(800, 0))
	row(b, "Alchemie Stufe %d: mit jeder Stufe 8 %% Chance auf einen zweiten Trank. Heilkraut wächst wild auf den Wiesen." % G.job_lvl("alchemie"))
	for r in G.ALCHEMIE:
		var need: Dictionary = G.ALCHEMIE[r]
		var ok = true
		var parts = []
		for i in need:
			parts.append("%d %s (%d)" % [need[i], G.ITEMS[i]["name"], G.count(i)])
			if G.count(i) < need[i]:
				ok = false
		row(b, "%s    %s\nZutaten: %s" % [G.ITEMS[r]["name"], Texte.ITEM_INFO.get(r, ""), ", ".join(parts)], "Brauen", func():
			for i in need:
				G.add_item(i, -need[i])
			var twice = randf() < G.job_lvl("alchemie") * 0.08
			G.add_item(r, 2 if twice else 1)
			G.job_xp("alchemie", 2)
			Audio.sfx("zauber")
			G.say("%s gebraut%s" % [G.ITEMS[r]["name"], " (zwei Stück!)" if twice else ""])
			show_alchemie(), not ok)


func _upgrade_cost(lvl: int) -> Array:
	# der Beruf Schmieden senkt den Goldpreis um 3 % je Stufe
	return [int((40 + lvl * 35) * (1.0 - 0.03 * (G.job_lvl("schmieden") - 1))), 1 + int(lvl / 2.0)]


func show_moebel() -> void:
	var b = open("Möbel für dein Haus · %d Gold" % G.p["gold"], Vector2(720, 0))
	for id in G.world.MOEBEL:
		var q: Array = G.world.MOEBEL[id]
		if id == "wiege":
			continue
		var have: bool = G.p["flags"].get("m_" + id, false)
		row(b, q[0] + ("  (steht schon in deinem Haus)" if have else ""), "%d Gold" % q[1], func():
			G.add_gold(-q[1])
			G.p["flags"]["m_" + id] = true
			G.world.update_home()
			Audio.sfx("muenze")
			G.say("%s wird in dein Haus geliefert." % q[0])
			show_moebel(), have or G.p["gold"] < q[1])


func show_smith() -> void:
	var p: Dictionary = G.p
	var c: Dictionary = G.cls()
	var b = open("Hildas Glutschmiede · %d Gold · %d Eisenerz" % [p["gold"], G.count("erz")], Vector2(860, 0))
	head(b, "Verbessern (+3,5 Grundschaden je Stufe, alle drei Stufen ein neues Aussehen)")
	for id in p["weapons"]:
		var lvl: int = G.wlvl(id)
		var nm: String = G.WEAPONS[id]["name"]
		if lvl >= 10:
			row(b, "%s +10 (Meisterstück)" % nm)
			continue
		var cost = _upgrade_cost(lvl)
		row(b, "%s +%d  →  +%d    Kosten: %d Gold, %d Eisenerz" % [nm, lvl, lvl + 1, cost[0], cost[1]], "Verbessern", func():
			G.add_gold(-cost[0])
			G.add_item("erz", -cost[1])
			p["weapons"][id] = lvl + 1
			Audio.sfx("schmiede")
			G.player.refresh_gear()
			G.job_xp("schmieden", 3)
			G.say("%s auf +%d verbessert" % [nm, lvl + 1])
			show_smith(), p["gold"] < cost[0] or G.count("erz") < cost[1])
	var gl: int = p["guard_lvl"]
	if gl >= 10:
		row(b, "%s +10 (Meisterstück)" % c["guard"])
	else:
		var gc = _upgrade_cost(gl)
		row(b, "%s +%d  →  +%d    fängt 4 %% Schaden je Stufe ab    Kosten: %d Gold, %d Eisenerz" % [c["guard"], gl, gl + 1, gc[0], gc[1]], "Verbessern", func():
			G.add_gold(-gc[0])
			G.add_item("erz", -gc[1])
			p["guard_lvl"] = gl + 1
			Audio.sfx("schmiede")
			G.player.refresh_gear()
			show_smith(), p["gold"] < gc[0] or G.count("erz") < gc[1])
	head(b, "Rüstung (jedes Teil in drei Güten: Leder, Eisen, Glutstahl)")
	for part in G.ARMOR:
		var cur: int = int(p["armor"][part])
		var tiers: Array = G.ARMOR[part]["tiers"]
		if cur >= 3:
			row(b, "%s: %s (beste Güte)" % [G.ARMOR[part]["name"], tiers[2][0]])
			continue
		var nx: Array = tiers[cur]
		row(b, "%s: %s  →  %s    Schutz +%d %%" % [G.ARMOR[part]["name"], "nichts" if cur == 0 else tiers[cur - 1][0], nx[0], int(nx[1] * 100)], "%d Gold" % nx[2], func():
			G.add_gold(-nx[2])
			p["armor"][part] = cur + 1
			Audio.sfx("schmiede")
			G.player.refresh_gear()
			G.say("%s angelegt" % nx[0])
			show_smith(), p["gold"] < nx[2])
	head(b, "Waffen kaufen")
	for id in G.WEAPONS:
		if p["weapons"].has(id):
			continue
		var w: Dictionary = G.WEAPONS[id]
		row(b, "%s    %s Grundschaden %.0f%s" % [w["name"], w["desc"], w["base"], "" if G.proficient(id) else " · für deine Klasse ungeübt"], "%d Gold" % w["price"], func():
			G.add_gold(-w["price"])
			p["weapons"][id] = 0
			if p["slots"][1] == "":
				p["slots"][1] = id
			Audio.sfx("muenze")
			G.say("%s gekauft. Im Inventar (I) kannst du sie einem Slot zuweisen." % w["name"])
			show_smith(), p["gold"] < w["price"])
	var best = 0
	for id in p["weapons"]:
		best = max(best, G.wlvl(id))
	head(b, "Runen (ab einer Waffe +5, kostet 1 Glutsplitter und 100 Gold; du hast %d Splitter)" % G.count("splitter"))
	for r in G.RUNES:
		var d: Dictionary = G.RUNES[r]
		row(b, "%s    %s%s" % [d["name"], d["desc"], "    (aktiv)" if p["rune"] == r else ""], "Einsetzen", func():
			G.add_gold(-100)
			G.add_item("splitter", -1)
			p["rune"] = r
			Audio.sfx("schmiede")
			G.player.refresh_gear()
			show_smith(), best < 5 or p["gold"] < 100 or G.count("splitter") < 1 or p["rune"] == r)


func show_chest() -> void:
	var b = open("Truhe in deinem Haus", Vector2(820, 0))
	head(b, "Im Gepäck")
	for i in G.p["inv"].keys():
		row(b, "%s × %d" % [G.ITEMS[i]["name"], G.count(i)], "Einlagern", func():
			G.add_item(i, -1)
			G.add_item(i, 1, "chest")
			show_chest())
	head(b, "In der Truhe")
	if G.p["chest"].is_empty():
		row(b, "Die Truhe ist leer.", "", Callable(), false, Color(0.6, 0.6, 0.6))
	for i in G.p["chest"].keys():
		row(b, "%s × %d" % [G.ITEMS[i]["name"], G.count(i, "chest")], "Nehmen", func():
			G.add_item(i, -1, "chest")
			G.add_item(i, 1)
			show_chest())


func show_cook() -> void:
	var b = open("Kochstelle", Vector2(780, 0))
	for r in G.RECIPES:
		var need: Dictionary = G.RECIPES[r]
		var ok = true
		var parts = []
		for i in need:
			parts.append("%d %s (%d)" % [need[i], G.ITEMS[i]["name"], G.count(i)])
			if G.count(i) < need[i]:
				ok = false
		row(b, "%s    Sättigung +%d, Leben +%d\nZutaten: %s" % [G.ITEMS[r]["name"], G.ITEMS[r]["hunger"], G.ITEMS[r]["heal"], ", ".join(parts)], "Kochen", func():
			for i in need:
				G.add_item(i, -need[i])
			var twice = randf() < G.job_lvl("kochen") * 0.08
			G.add_item(r, 2 if twice else 1)
			G.job_xp("kochen", 2)
			Audio.sfx("essen")
			G.say("%s gekocht%s" % [G.ITEMS[r]["name"], " (doppelte Portion!)" if twice else ""])
			show_cook(), not ok)


# ---------------------------------------------------------------- Cheats

func show_cheats() -> void:
	var b = open("Cheats", Vector2(620, 0))
	var c: Dictionary = G.p["cheats"]
	for q in [["god", "Gottmodus (unverwundbar)"], ["stamina", "Unendlich Ausdauer und Mana"], ["needs", "Kein Hunger, keine Müdigkeit"], ["onehit", "Jeder Schlag besiegt den Gegner"]]:
		var cb = CheckButton.new()
		cb.text = q[1]
		cb.button_pressed = c[q[0]]
		cb.toggled.connect(func(on): c[q[0]] = on)
		b.add_child(cb)
	b.add_child(HSeparator.new())
	btn(b, "+500 Gold", func(): G.add_gold(500))
	btn(b, "+1 Stufe", func(): G.add_xp(G.xp_need(G.p["level"]) - G.p["xp"]))
	btn(b, "Vollständig heilen, satt und ausgeruht", func():
		G.p["hp"] = G.max_hp()
		G.p["mana"] = G.max_mana()
		G.p["hunger"] = 100.0
		G.p["fatigue"] = 100.0)
	btn(b, "+5 Eisenerz, +1 Glutsplitter", func():
		G.add_item("erz", 5)
		G.add_item("splitter"))
	btn(b, "Zeit um 6 Stunden vorstellen", func(): G.advance(6.0, true))
	btn(b, "Haus und Schmiede freischalten", func():
		G.p["flags"]["home"] = true
		G.p["flags"]["smith_free"] = true)
	win.set_meta("kind", "cheats")
