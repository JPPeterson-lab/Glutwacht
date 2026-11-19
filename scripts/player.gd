extends Actor
## Der Held: Bewegung, Kamera, Kampf, Fähigkeiten, Benutzen.

const PROJECTILE := preload("res://scripts/projectile.gd")

var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := 0.74
var hold_t := 0.0
var charged := false
var pad := false           # zuletzt mit dem Gamepad gespielt?
var cam_dist := 19.0
var busy := 0.0
var combo := 0
var cds := [0.0, 0.0, 0.0]
var iframes := 0.0
var blocking := false
var dead := false
var roll_dir := Vector3.ZERO
var roll_t := 0.0
var pending: Callable
var pending_t := 0.0
var step_t := 0.0
var focus: Node = null     # nächstes benutzbares Objekt
var rune_light: OmniLight3D
var lantern: OmniLight3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 16
	var c: Dictionary = G.cls()
	setup("chars2/%s.glb" % c["model"])
	refresh_gear()
	lantern = OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.72, 0.4)
	lantern.omni_range = 20.0
	lantern.shadow_enabled = true
	lantern.position = Vector3(0, 3.2, 0.5)
	lantern.light_energy = 0.0
	add_child(lantern)
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.far = 280.0
	get_parent().add_child.call_deferred(cam)
	cam.make_current.call_deferred()
	play(G.weapon()["idle"])


func refresh_gear() -> void:
	var w: Dictionary = G.weapon()
	var set := {}
	# sichtbare Ausbaustufen: alle drei Verbesserungen ein neues Modell
	var tier: int = int(G.wlvl() / 3.0)
	for side in w["tiers"]:
		var lst: Array = w["tiers"][side]
		set[side] = lst[min(tier, lst.size() - 1)]
	if w.get("shield", false):
		set["l"] = ["gear/shield_round", "waffen/shield_A", "waffen/shield_B", "waffen/shield_C"][min(int(G.p["guard_lvl"] / 3.0), 3)]
	if G.p.get("torch", false) and G.wid() != "bogen":
		set["l"] = "tools3d/torch"       # brennende Fackel in der linken Hand
	gear(set)
	# Rüstung: Helm, Brust und Stiefel färben die passenden Körperteile (Leder, Eisen, Glutstahl)
	for m in body.find_children("*", "MeshInstance3D", true, false):
		var n: String = m.name
		var part = ""
		if n.contains("Head") or n.contains("Helmet") or n.contains("Hat") or n.contains("Hood"): part = "helm"
		elif n.contains("Leg"): part = "stiefel"
		elif n.contains("Body") or n.contains("Arm"): part = "brust"
		var t: int = int(G.p["armor"].get(part, 0)) if part != "" else 0
		var ov: StandardMaterial3D = null
		if t > 0:
			ov = StandardMaterial3D.new()
			ov.albedo_color = G.ARMOR_COLOR[t]
			ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ov.metallic = 0.6 if t >= 2 else 0.0
			ov.roughness = 0.5
			if t == 3:
				ov.emission_enabled = true
				ov.emission = Color(1.0, 0.35, 0.1)
				ov.emission_energy_multiplier = 0.5
		m.set_meta("ov", ov)
		m.material_overlay = ov
	if rune_light == null:
		rune_light = OmniLight3D.new()
		rune_light.omni_range = 5.0
		rune_light.position = Vector3(0, 1.6, 0)
		add_child(rune_light)
	rune_light.visible = G.p["rune"] != ""
	if G.p["rune"] != "":
		rune_light.light_color = G.RUNES[G.p["rune"]]["color"]
		rune_light.light_energy = 1.5


func _input(e: InputEvent) -> void:
	# Kamera: mittlere Maustaste (oder Alt + linke) gedrückt halten und ziehen dreht und neigt, Mausrad zoomt
	if e is InputEventJoypadButton or (e is InputEventJoypadMotion and abs(e.axis_value) > 0.5):
		pad = true
	elif e is InputEventMouseButton or e is InputEventKey:
		pad = false
	if G.ui_open or get_tree().paused:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = max(7.0, cam_dist - 1.2)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = min(34.0, cam_dist + 1.2)
	if e is InputEventMouseMotion:
		var turning = Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or (Input.is_key_pressed(KEY_ALT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
		if turning:
			cam_yaw -= e.relative.x * 0.007
			cam_pitch = clamp(cam_pitch + e.relative.y * 0.004, 0.35, 1.3)


func _physics_process(delta: float) -> void:
	_camera(delta)
	if dead:
		velocity = Vector3(0, velocity.y - 24.0 * delta, 0)
		move_and_slide()
		return
	var c: Dictionary = G.cls()
	var st: Dictionary = G.p
	busy = max(0.0, busy - delta)
	iframes = max(0.0, iframes - delta)
	for i in 3:
		cds[i] = max(0.0, cds[i] - delta)
	if pending_t > 0.0:
		pending_t -= delta
		if pending_t <= 0.0 and pending.is_valid():
			pending.call()

	if Input.is_action_pressed("kamera_l"): cam_yaw += delta * 1.8
	if Input.is_action_pressed("kamera_r"): cam_yaw -= delta * 1.8

	var iv = Input.get_vector("links", "rechts", "vor", "zurueck")
	var dir = (Vector3(iv.x, 0, iv.y)).rotated(Vector3.UP, cam_yaw)
	var sprint = Input.is_action_pressed("sprint") and st["stamina"] > 1.0 and dir.length() > 0.1
	blocking = Input.is_action_pressed("block") and busy <= 0.0 and roll_t <= 0.0
	var sp: float = G.speed() * (1.55 if sprint else 1.0)

	if roll_t > 0.0:
		roll_t -= delta
		velocity.x = roll_dir.x * 15.0
		velocity.z = roll_dir.z * 15.0
	elif busy > 0.0 or blocking:
		velocity.x = move_toward(velocity.x, dir.x * sp * 0.25, delta * 60.0)
		velocity.z = move_toward(velocity.z, dir.z * sp * 0.25, delta * 60.0)
	else:
		velocity.x = move_toward(velocity.x, dir.x * sp, delta * 70.0)
		velocity.z = move_toward(velocity.z, dir.z * sp, delta * 70.0)
		face(dir, delta)
		if dir.length() > 0.1:
			play("Running_A", 1.35 if sprint else 1.0)
			step_t -= delta * (1.5 if sprint else 1.0)
			if step_t <= 0.0:
				step_t = 0.34
				Audio.sfx("schritt", 1.0, 0.35)
		else:
			play(G.weapon()["idle"])
	if blocking and roll_t <= 0.0:
		play("Blocking")
	velocity.y = velocity.y - 24.0 * delta if not is_on_floor() else -1.0
	move_and_slide()

	if sprint:
		st["stamina"] = max(0.0, st["stamina"] - delta * 14.0)
	elif not blocking:
		st["stamina"] = min(G.max_stamina(), st["stamina"] + delta * 16.0 * (0.5 if st["fatigue"] < 25.0 else 1.0))

	if busy <= 0.0 and roll_t <= 0.0:
		if Input.is_action_just_pressed("ausweichen") and st["stamina"] >= 22.0:
			st["stamina"] -= 22.0
			roll_dir = dir.normalized() if dir.length() > 0.1 else facing()
			roll_t = 0.32
			iframes = 0.42
			busy = 0.36
			body.rotation.y = atan2(roll_dir.x, roll_dir.z)
			play("Dodge_Forward", 1.6, true)
			Audio.voice("jump")
			Audio.sfx("schlag", 1.3, 0.4)
		elif Input.is_action_just_pressed("angriff") and not blocking:
			_attack(false)
		elif Input.is_action_just_released("angriff") and hold_t >= 0.55 and not blocking:
			_attack(true)        # lange gehalten: schwerer Angriff
		else:
			for i in 3:
				if Input.is_action_just_pressed("skill%d" % (i + 1)):
					_skill(i)
	# Angriffstaste halten lädt einen schweren Angriff auf
	if Input.is_action_pressed("angriff") and not blocking:
		hold_t += delta
		if hold_t >= 0.55 and not charged:
			charged = true
			G.world.ring(global_position, 1.6, Color(1.0, 0.85, 0.3))
			Audio.sfx("klick", 0.7)
	else:
		hold_t = 0.0
		charged = false
	if Input.is_action_just_pressed("waffe"):
		swap()
	if Input.is_action_just_pressed("fackel"):
		torch()
	if G.p.get("torch", false):
		G.p["torch_left"] = G.p.get("torch_left", 0.0) - delta / G.HOUR_SECONDS
		if G.p["torch_left"] <= 0.0:
			if G.count("fackel") > 0:
				G.add_item("fackel", -1)
				G.p["torch_left"] = 6.0
				G.say("Die Fackel ist heruntergebrannt, du zündest eine neue an.")
			else:
				G.p["torch"] = false
				refresh_gear()
				G.say("Deine letzte Fackel ist erloschen.")
	if Input.is_action_just_pressed("essen"):
		var f = G.best_food()
		if f == "":
			G.say("Du hast nichts zu essen dabei.")
		else:
			G.use_item(f)
	if Input.is_action_just_pressed("trank"):
		if not G.use_item("heiltrank"):
			G.say("Kein Heiltrank im Gepäck.")
	_focus()
	if focus and Input.is_action_just_pressed("benutzen") and busy <= 0.0:
		velocity = Vector3.ZERO
		focus.interact()


func _camera(delta: float) -> void:
	if cam == null or not cam.is_inside_tree():
		return
	var pitch = cam_pitch
	var target = global_position + Vector3(0, 1.6, 0)
	var off = Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * cam_dist
	cam.global_position = cam.global_position.lerp(target + off, clamp(delta * 10.0, 0.0, 1.0))
	cam.look_at(target)
	lantern.light_energy = lerp(lantern.light_energy, (2.4 + sin(Time.get_ticks_msec() * 0.02) * 0.25) if G.p.get("torch", false) else 0.0, 0.2)


func snap_camera() -> void:
	if cam and cam.is_inside_tree():
		_camera(1.0)


func _focus() -> void:
	var best: Node = null
	var bd = 99.0
	for n in get_tree().get_nodes_in_group("interact"):
		if not n.is_visible_in_tree() or not n.usable():
			continue
		var d: float = flat_dist(n.global_position)
		if d < n.reach and d < bd and abs(n.global_position.y - global_position.y) < 6.0:
			bd = d
			best = n
	focus = best
	if G.ui:
		G.ui.set_prompt(("[E]  " + best.prompt()) if best else "")


func enemies_in(radius: float, origin := Vector3.INF) -> Array:
	var o: Vector3 = global_position if origin == Vector3.INF else origin
	var out = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.dead and Vector2(e.global_position.x - o.x, e.global_position.z - o.z).length() < radius + 0.5 * e.body.scale.x:
			out.append(e)
	out.sort_custom(func(a, b): return a.global_position.distance_squared_to(o) < b.global_position.distance_squared_to(o))
	return out


func _roll_damage(mult: float) -> Array:
	var crit = randf() < G.crit_chance()
	var d: float = G.damage() * mult * randf_range(0.9, 1.1) * (1.8 if crit else 1.0)
	if G.p["cheats"]["onehit"]:
		d = 99999.0
	return [d, crit]


func _strike(e: Node, mult: float, stun := 0.0) -> void:
	var r = _roll_damage(mult)
	if int(G.p["flags"].get("gift_n", 0)) > 0:       # Waffengift
		G.p["flags"]["gift_n"] = int(G.p["flags"]["gift_n"]) - 1
		r[0] *= 1.35
	if G.p["rune"] == "frost" and randf() < 0.2:
		stun = max(stun, 1.5)
	e.take_damage(r[0], r[1], stun)


func torch() -> void:
	if G.p.get("torch", false):
		G.p["torch"] = false
		G.say("Fackel gelöscht (Rest: %.1f Stunden)" % max(0.0, G.p.get("torch_left", 0.0)))
	else:
		if G.p.get("torch_left", 0.0) <= 0.0:
			if G.count("fackel") <= 0:
				G.say("Du hast keine Fackel. Mira im Krämerladen verkauft welche.")
				return
			G.add_item("fackel", -1)
			G.p["torch_left"] = 6.0
		G.p["torch"] = true
		Audio.sfx("zauber", 1.6, 0.4)
		G.say("Fackel entzündet" + (" (am Gürtel, der Bogen braucht beide Hände)" if G.wid() == "bogen" else ""))
	refresh_gear()


func block_factor() -> float:
	var w: Dictionary = G.weapon()
	if w.get("shield", false):
		return 0.85 if G.p["cls"] == "ritter" else 0.7
	return G.cls()["block"]


func swap() -> void:
	if busy > 0.0:
		return
	var before = G.wid()
	G.swap_weapon()
	if G.wid() != before:
		refresh_gear()
		busy = 0.25
		combo = 0
		Audio.sfx("block", 1.4, 0.4)
		G.say("Waffe: %s +%d%s" % [G.weapon()["name"], G.wlvl(), "" if G.proficient() else " (ungeübt, 25 % weniger Schaden)"])


## Richtung vom Helden zum Mauszeiger auf dem Boden.
func mouse_dir() -> Vector3:
	var mp = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(mp)
	var d = cam.project_ray_normal(mp)
	if abs(d.y) < 0.001:
		return facing()
	var hit = from + d * ((global_position.y + 1.0 - from.y) / d.y)
	var v = flat_dir(hit)
	return v if v != Vector3.ZERO else facing()


func _attack(heavy: bool) -> void:
	var c: Dictionary = G.weapon()
	if heavy and G.p["stamina"] < 18.0:
		heavy = false
	if c.get("shot", "") == "pfeil" and G.count("pfeil") <= 0:
		G.say("Keine Pfeile mehr. Wechsle die Waffe (Q) oder kaufe Pfeile im Krämerladen.")
		busy = 0.4
		return
	var aim = facing()
	if G.opt["aim"] and not pad:
		aim = mouse_dir()
	else:
		var near = enemies_in(c["range"] + 3.0 if not c["ranged"] else 24.0)
		if not near.is_empty():
			aim = flat_dir(near[0].global_position)
	body.rotation.y = atan2(aim.x, aim.z)
	var a: String = c["atk"][combo % c["atk"].size()]
	combo += 1
	if heavy or randf() < 0.3:
		Audio.voice("attack")
	var spd: float = c["speed"] * (0.8 if heavy else 1.0)
	play(a, spd, true, 0.08)
	busy = clamp(anim_length(a) / spd * 0.8, 0.35, 1.0)
	var mult = 1.0
	var reach: float = c["range"]
	if heavy:
		G.p["stamina"] -= 18.0
		mult = 2.2
		reach += 0.7
		Audio.sfx("schwer" if Audio.has("schwer") else "schlag", 0.8, 0.9)
	else:
		Audio.sfx("zauber" if c.get("shot", "") == "feuer" else ("pfeil" if c.get("shot", "") == "pfeil" and Audio.has("pfeil") else "schlag"), 1.0, 0.6)
	pending_t = 0.2 if not heavy else 0.3
	if c["ranged"]:
		pending = func():
			if c.get("shot", "") == "pfeil":
				G.add_item("pfeil", -1)
			var pr = PROJECTILE.new()
			var r = _roll_damage(mult)
			pr.dmg = r[0]
			pr.crit = r[1]
			pr.dir = aim
			if c.get("shot", "") == "pfeil":
				pr.color = Color(0.95, 0.9, 0.7)
				pr.speed = 40.0
				pr.arrow = true
			if G.p["rune"] != "":
				pr.color = G.RUNES[G.p["rune"]]["color"]
			get_parent().add_child(pr)
			pr.global_position = global_position + Vector3(0, 1.5, 0) + aim * 1.0
	else:
		pending = func():
			var hit = false
			for e in enemies_in(reach):
				if aim.dot(flat_dir(e.global_position)) > (0.25 if not heavy else 0.0) or flat_dist(e.global_position) < 1.4:
					_strike(e, mult, 0.8 if heavy else 0.0)
					hit = true
			if heavy:
				G.world.ring(global_position + aim * 1.5, reach * 0.7, Color(1.0, 0.8, 0.3))
			if hit:
				Audio.sfx("treffer")


func _skill(i: int) -> void:
	var id: String = G.cls()["skills"][i]
	var rk = G.rank(id)
	var s: Dictionary = G.SKILLS[id]
	if rk <= 0:
		G.say("%s ist noch nicht erlernt (Taste C, Talente)." % s["name"])
		return
	if cds[i] > 0.0:
		return
	if G.p["mana"] < s["cost"]:
		G.say("Zu wenig Mana.")
		return
	G.p["mana"] -= s["cost"]
	cds[i] = s["cd"]
	var mult: float = s.get("mult", 1.0) * (1.0 + 0.18 * (rk - 1))
	play(s["anim"], 1.3, true, 0.08)
	Audio.voice(Audio.SPELL.get(id, "attack1"))
	busy = clamp(anim_length(s["anim"]) / 1.3 * 0.75, 0.4, 1.0)
	Audio.sfx("zauber")
	var col = Color(1.0, 0.7, 0.3)
	if id == "nova": col = Color(0.5, 0.85, 1.0)
	if id == "rauch": col = Color(0.6, 0.6, 0.65)
	if id == "blitz": col = Color(0.8, 0.8, 1.0)
	pending_t = 0.25
	match s["type"]:
		"aoe":
			pending = func():
				G.world.ring(global_position, s["radius"], col)
				for e in enemies_in(s["radius"]):
					_strike(e, mult, s.get("stun", 0.0) * (1.0 + 0.1 * (rk - 1)))
				Audio.sfx("treffer")
		"chain":
			pending = func():
				var list = enemies_in(s["radius"])
				for k in min(list.size(), s["n"] + rk - 1):
					G.world.beam(global_position + Vector3(0, 1.6, 0), list[k].global_position + Vector3(0, 1.2, 0), col)
					_strike(list[k], mult)
		"heal":
			pending = func():
				G.heal(G.max_hp() * s["pct"] * (1.0 + 0.15 * (rk - 1)))
				G.world.ring(global_position, 2.5, Color(0.4, 1.0, 0.5))
		"buff":
			pending = func():
				G.buff_dmg = s["dmg"] * (1.0 + 0.15 * (rk - 1))
				G.buff_time = s["dur"]
				G.world.ring(global_position, 3.0, Color(1.0, 0.3, 0.2))
				G.say("%s: Schaden erhöht" % s["name"])
		"dash":
			var list = enemies_in(s["radius"])
			if list.is_empty():
				G.say("Kein Gegner in Reichweite.")
				cds[i] = 0.5
				G.p["mana"] += s["cost"]
				return
			var e = list[0]
			var d = flat_dir(e.global_position)
			G.world.ring(global_position, 1.5, Color(0.3, 0.2, 0.5))
			global_position = e.global_position - d * 1.8
			body.rotation.y = atan2(d.x, d.z)
			iframes = 0.5
			pending = func():
				if is_instance_valid(e) and not e.dead:
					_strike(e, mult)
					Audio.sfx("treffer")


func take_damage(n: float, from: Node) -> void:
	if dead or iframes > 0.0:
		return
	if blocking:
		n *= 1.0 - block_factor()
		G.p["stamina"] = max(0.0, G.p["stamina"] - 12.0)
		Audio.sfx("block")
		play("Block_Hit", 1.2, true)
	else:
		Audio.sfx("treffer", 0.8)
		if busy <= 0.0:
			play("Hit_A", 1.4, true)
			busy = 0.2
	var real = G.hurt(n)
	if real > 0.0:
		Audio.voice("damaged")
		flash(Color(1, 0.2, 0.2, 0.6))
		G.world.popup(global_position + Vector3(0, 3.0, 0), "-%d" % int(ceil(real)), Color(1, 0.35, 0.3))
	if G.p["hp"] <= 0.0:
		dead = true
		play("Death_A", 1.0, true)
		G.world.player_died()


func revive() -> void:
	dead = false
	busy = 0.0
	velocity = Vector3.ZERO
	play(G.weapon()["idle"], 1.0, true)
