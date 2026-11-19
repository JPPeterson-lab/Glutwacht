extends Actor
## Gegner: streifen umher, verfolgen den Helden, greifen an, lassen Beute fallen.

const PROJECTILE := preload("res://scripts/projectile.gd")
const KINDS := {
	"diener": {"name": "Skelett-Diener", "model": "Skeleton_Minion", "hp": 34.0, "dmg": 7.0, "xp": 22, "speed": 4.4, "weapon": "", "atk": "Unarmed_Melee_Attack_Punch_A", "scale": 1.0},
	"krieger": {"name": "Skelett-Krieger", "model": "Skeleton_Warrior", "hp": 85.0, "dmg": 13.0, "xp": 50, "speed": 4.2, "weapon": "Skeleton_Blade", "shield": "Skeleton_Shield_Large_A", "atk": "1H_Melee_Attack_Chop", "scale": 1.05},
	"schurke": {"name": "Skelett-Schurke", "model": "Skeleton_Rogue", "hp": 55.0, "dmg": 11.0, "xp": 40, "speed": 5.8, "weapon": "Skeleton_Axe", "atk": "1H_Melee_Attack_Slice_Diagonal", "scale": 1.0},
	"magier": {"name": "Skelett-Magier", "model": "Skeleton_Mage", "hp": 46.0, "dmg": 12.0, "xp": 45, "speed": 3.8, "weapon": "Skeleton_Staff", "atk": "Spellcast_Shoot", "ranged": true, "scale": 1.0},
	"bandit": {"name": "Wegelagerer", "human": "Rogue_Hooded", "gear": {"r": "dagger", "l": "dagger"}, "hp": 70.0, "dmg": 12.0, "xp": 48, "speed": 5.4, "weapon": "", "atk": "Dualwield_Melee_Attack_Slice", "scale": 1.0},
	"schlaeger": {"name": "Schläger", "human": "Barbarian", "gear": {"r": "axe_2handed"}, "hp": 125.0, "dmg": 18.0, "xp": 75, "speed": 4.2, "weapon": "", "atk": "2H_Melee_Attack_Chop", "scale": 1.08},
	"schuetze": {"name": "Wildschütze", "human": "Ranger", "gear": {"l": "bow_withString"}, "hp": 60.0, "dmg": 13.0, "xp": 55, "speed": 4.6, "weapon": "", "atk": "Ranged_Bow_Release", "ranged": true, "arrow": true, "scale": 1.0},
	"wolf": {"name": "Grauwolf", "prim": "wolf", "hp": 50.0, "dmg": 10.0, "xp": 35, "speed": 7.2, "weapon": "", "atk": "", "scale": 1.0, "sound": "wolf"},
	"sumpf": {"name": "Sumpfkriecher", "prim": "sumpf", "hp": 95.0, "dmg": 14.0, "xp": 55, "speed": 3.2, "weapon": "", "atk": "", "scale": 1.0, "sound": "sumpf"},
	"geist": {"name": "Aschengeist", "prim": "geist", "hp": 60.0, "dmg": 15.0, "xp": 65, "speed": 4.6, "weapon": "", "atk": "", "ranged": true, "scale": 1.0, "sound": "geist"},
	"minenkoenig": {"name": "Der Knochenhauer", "model": "Skeleton_Warrior", "hp": 520.0, "dmg": 22.0, "xp": 260, "speed": 4.4, "weapon": "Skeleton_Axe", "atk": "1H_Melee_Attack_Chop", "scale": 1.6, "chef": true},
	"gruftfuerst": {"name": "Gruftfürst Malrik", "model": "Skeleton_Mage", "hp": 480.0, "dmg": 24.0, "xp": 320, "speed": 3.6, "weapon": "Skeleton_Staff", "atk": "Spellcast_Shoot", "ranged": true, "scale": 1.6, "chef": true},
	"turmherr": {"name": "Hauptmann ohne Namen", "model": "Skeleton_Warrior", "hp": 820.0, "dmg": 30.0, "xp": 420, "speed": 4.8, "weapon": "Skeleton_Blade", "shield": "Skeleton_Shield_Large_A", "atk": "1H_Melee_Attack_Chop", "scale": 1.7, "chef": true},
	"aschenwaechter": {"name": "Aschenwächter", "model": "Skeleton_Warrior", "hp": 1400.0, "dmg": 36.0, "xp": 650, "speed": 4.8, "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_B", "atk": "1H_Melee_Attack_Chop", "scale": 1.8, "chef": true},
	"aschenkoenig": {"name": "Alderan, der Aschenkönig", "model": "Skeleton_Mage", "hp": 2600.0, "dmg": 42.0, "xp": 0, "speed": 4.2, "weapon": "Skeleton_Staff", "atk": "Spellcast_Shoot", "ranged": true, "scale": 2.1, "chef": true},
	"schattenwolf": {"name": "Schattenwolf", "prim": "wolf", "dunkel": true, "hp": 85.0, "dmg": 15.0, "xp": 60, "speed": 7.8, "weapon": "", "atk": "", "scale": 1.15, "sound": "heulen"},
	"irrlicht": {"name": "Irrlicht", "prim": "geist", "hp": 55.0, "dmg": 14.0, "xp": 55, "speed": 5.0, "weapon": "", "atk": "", "ranged": true, "scale": 0.8, "sound": "geist"},
	"turniermeister": {"name": "Turniermeister Wolfram", "human": "Knight", "gear": {"r": "sword_1handed", "l": "shield_badge_color"}, "hp": 640.0, "dmg": 24.0, "xp": 300, "speed": 4.8, "weapon": "", "atk": "1H_Melee_Attack_Slice_Diagonal", "scale": 1.3, "chef": true},
	"schmugglerkoenig": {"name": "Der Schmugglerkönig", "human": "Barbarian", "gear": {"r": "axe_2handed"}, "hp": 900.0, "dmg": 30.0, "xp": 450, "speed": 4.6, "weapon": "", "atk": "2H_Melee_Attack_Chop", "scale": 1.5, "chef": true},
	"frostgeist": {"name": "Frostgeist", "prim": "geist", "hp": 950.0, "dmg": 32.0, "xp": 500, "speed": 4.4, "weapon": "", "atk": "", "ranged": true, "scale": 1.7, "chef": true, "sound": "geist"},
	"boss": {"name": "Aschenritter", "chef": true, "model": "Skeleton_Warrior", "hp": 600.0, "dmg": 26.0, "xp": 300, "speed": 4.6, "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_B", "atk": "1H_Melee_Attack_Chop", "scale": 1.75},
}

var kind := "diener"
var d := {}
var camp := ""
var hp := 10.0
var hp_max := 10.0
var home := Vector3.ZERO
var state := "idle"
var t := 0.0
var stun := 0.0
var dead := false
var wander := Vector3.ZERO
var power := 1.0
var bar: Node3D
var fill: Sprite3D
var info: Label3D
var stuck := 0.0
var legs := []
var wobble := 0.0
var zone := ""            # Dungeon oder Gebiet, in dem der Gegner lebt (leer: offene Welt)
var detour_t := 0.0
var detour_sign := 1.0


func init(k: String, pos: Vector3, camp_id: String, strength := 1.0) -> void:
	kind = k
	d = KINDS[k]
	camp = camp_id
	power = strength
	home = pos
	position = pos


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	if d.has("prim"):
		_prim()
	elif d.has("human"):
		setup("chars2/%s.glb" % d["human"], d["scale"])
		gear(d["gear"])
	else:
		setup("skel/%s.glb" % d["model"], d["scale"])
	if d["weapon"] != "":
		attach("handslot.r", G.model("skel/%s.gltf" % d["weapon"]))
	if d.has("shield"):
		attach("handslot.l", G.model("skel/%s.gltf" % d["shield"]))
	hp_max = d["hp"] * power * [0.8, 1.0, 1.3][int(G.p.get("schwer", 1))]
	hp = hp_max
	wander = home
	t = randf_range(0.5, 3.0)
	body.rotation.y = randf() * TAU
	play("Idle")
	# Lebensanzeige: dunkler Rahmen, farbige Füllung, Name und Zahlen
	bar = Node3D.new()
	bar.position.y = 3.3 * d["scale"]
	add_child(bar)
	var big = 1.5 if kind == "boss" else 1.0
	var img = Image.create(100, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex = ImageTexture.create_from_image(img)
	var bg = Sprite3D.new()
	bg.texture = tex
	bg.modulate = Color(0.08, 0.05, 0.03, 0.9)
	bg.scale = Vector3(1.06, 1.5, 1)
	fill = Sprite3D.new()
	fill.texture = tex
	fill.centered = false
	fill.offset = Vector2(-50, -5)
	fill.region_enabled = true
	fill.render_priority = 1
	for sp in [bg, fill]:
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.no_depth_test = true
		sp.pixel_size = 0.022 * big
		sp.shaded = false
		bar.add_child(sp)
	info = Label3D.new()
	info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	info.no_depth_test = true
	info.font_size = 40
	info.outline_size = 10
	info.pixel_size = 0.008 * big
	info.position.y = 0.38 * big
	info.modulate = Color(1.0, 0.86, 0.6) if kind == "boss" else Color(0.95, 0.92, 0.85)
	bar.add_child(info)
	_bar()
	bar.visible = false
	if kind == "boss":
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.35, 0.1)
		l.light_energy = 3.0
		l.omni_range = 9.0
		l.position.y = 2.5
		add_child(l)


## Wesen ohne Modell (Wolf, Sumpfkriecher, Aschengeist) entstehen aus Grundformen.
func _prim() -> void:
	body = Node3D.new()
	add_child(body)
	match d["prim"]:
		"wolf":
			if d.get("dunkel", false):
				legs = Formen.vierbeiner(body, Color(0.1, 0.09, 0.14), Color(0.25, 0.2, 0.32))
			else:
				legs = Formen.vierbeiner(body, Color(0.4, 0.4, 0.44), Color(0.72, 0.7, 0.68))
		"sumpf":
			Formen.sumpfwesen(body)
		"geist":
			Formen.aschengeist(body)
	body.scale = Vector3.ONE * d["scale"]
	var shape = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.6 * d["scale"]
	cap.height = 2.0 * d["scale"]
	shape.shape = cap
	shape.position.y = 1.0
	add_child(shape)
	_flash = StandardMaterial3D.new()
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _animate(delta: float, moving: bool) -> void:
	# einfache Bewegung für Wesen ohne Skelett
	wobble += delta * (10.0 if moving else 2.0)
	match d["prim"]:
		"wolf":
			for i in legs.size():
				legs[i].rotation.x = sin(wobble + (PI if i % 3 == 0 else 0.0)) * (0.7 if moving else 0.0)
			body.position.y = abs(sin(wobble)) * 0.08 if moving else 0.0
		"sumpf":
			body.scale = Vector3(1.0 + sin(wobble) * 0.06, 1.0 - sin(wobble) * 0.08, 1.0 + sin(wobble) * 0.06)
		"geist":
			body.position.y = 0.4 + sin(wobble * 0.5) * 0.25
	if state == "windup":
		body.position.z = lerp(body.position.z, 0.0, 0.3)
		body.rotation.x = -0.35
	else:
		body.rotation.x = lerp(body.rotation.x, 0.0, 0.2)


func _physics_process(delta: float) -> void:
	if dead:
		return
	var pl = G.player
	# Gegner in anderen Gebieten oder weit weg ruhen vollständig (spart Rechenzeit und Wärme)
	if G.p.get("room", "") != zone or (pl and abs(pl.global_position.x - global_position.x) + abs(pl.global_position.z - global_position.z) > 150.0):
		return
	velocity.y = velocity.y - 24.0 * delta if not is_on_floor() else -1.0
	if stun > 0.0:
		stun -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if stun <= 0.0:
			tint(Color(0, 0, 0, 0))
		return
	t -= delta
	var dist = 999.0
	if pl and not pl.dead and G.p.get("room", "") == zone:
		dist = flat_dist(pl.global_position)
	bar.visible = dist < 26.0
	var reach: float = (2.4 + 0.8 * d["scale"]) if not d.get("ranged", false) else 15.0
	var move = Vector3.ZERO
	var sp: float = d["speed"]
	match state:
		"idle":
			if dist < (20.0 if d.get("chef", false) else 15.0) * (G.world.wetter.sight() if zone == "" else 1.0):
				state = "chase"
				if d.has("sound"):
					Audio.sfx(d["sound"], 1.0, 0.6)
				if anim and anim.has_animation("Taunt") and d.get("chef", false):
					play("Taunt", 1.2, true)
					t = 1.2
					state = "recover"
			else:
				if t <= 0.0:
					t = randf_range(3.0, 7.0)
					wander = home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
				if flat_dist(wander) > 1.0:
					move = flat_dir(wander)
					sp = 1.6
		"chase":
			if dist > 34.0 or flat_dist(home) > 55.0:
				state = "return"
			elif dist <= reach:
				state = "windup"
				t = 0.5 if kind != "boss" else 0.7
				play(d["atk"], 1.1, true, 0.08)
				var dd = flat_dir(pl.global_position)
				body.rotation.y = atan2(dd.x, dd.z)
			else:
				move = flat_dir(pl.global_position)
		"windup":
			if t <= 0.0:
				_hit(pl, dist, reach)
				state = "recover"
				t = 0.9 if not d.get("ranged", false) else 1.6
		"recover":
			if t <= 0.0:
				state = "chase"
		"return":
			move = flat_dir(home)
			hp = min(hp_max, hp + hp_max * delta * 0.2)
			_bar()
			if flat_dist(home) < 2.0:
				state = "idle"
			elif dist < 10.0:
				state = "chase"

	if move != Vector3.ZERO:
		# kleine Ausweichbewegung, wenn die Figur an einem Hindernis hängt
		if stuck > 0.25 and detour_t <= 0.0:
			detour_t = 1.2
			stuck = 0.0
			if randf() < 0.3: detour_sign = -detour_sign
		if detour_t > 0.0:
			detour_t -= delta
			move = move.rotated(Vector3.UP, 1.2 * detour_sign)
		if zone == "":
			move = G.world.avoid(global_position, move)       # um Bäume herumlaufen
		velocity.x = move.x * sp
		velocity.z = move.z * sp
		face(move, delta, 8.0)
		play("Running_A" if sp > 2.0 else "Walking_A", sp / 4.5 if sp > 2.0 else 1.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 40.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 40.0)
		if state == "idle" or state == "chase":
			play("Idle")
	if d.has("prim"):
		_animate(delta, move != Vector3.ZERO)
	var before = global_position
	move_and_slide()
	if move != Vector3.ZERO and global_position.distance_to(before) < sp * delta * 0.3:
		stuck += delta
		if stuck > 1.2:
			stuck = 0.0
	else:
		stuck = max(0.0, stuck - delta * 2.0)


func _bar() -> void:
	var r: float = clamp(hp / hp_max, 0.0, 1.0)
	fill.region_rect = Rect2(0, 0, 100.0 * r, 10)
	fill.modulate = Color(0.25, 0.8, 0.25).lerp(Color(0.95, 0.75, 0.15), clamp((1.0 - r) * 2.0, 0.0, 1.0)).lerp(Color(0.9, 0.15, 0.1), clamp((0.5 - r) * 2.0, 0.0, 1.0))
	info.text = "%s  %d/%d" % [d["name"], ceil(max(hp, 0.0)), ceil(hp_max)]


func _hit(pl: Node, dist: float, reach: float) -> void:
	if pl == null or pl.dead:
		return
	var dmg: float = d["dmg"] * power * randf_range(0.85, 1.15)
	if d.get("ranged", false):
		var pr = PROJECTILE.new()
		pr.from_player = false
		pr.dmg = dmg
		pr.speed = 15.0
		pr.color = Color(0.5, 1.0, 0.4) if not d.has("prim") else Color(1.0, 0.45, 0.15)
		if d.get("arrow", false):
			pr.arrow = true
			pr.speed = 26.0
		pr.dir = (pl.global_position - global_position).normalized()
		pr.dir.y = 0.0
		get_parent().add_child(pr)
		pr.global_position = global_position + Vector3(0, 1.6, 0) + pr.dir
		Audio.sfx("zauber", 0.7, 0.5)
	elif dist <= reach + 1.2:
		pl.take_damage(dmg, self)
	else:
		Audio.sfx("schlag", 0.8, 0.4)


func take_damage(n: float, crit := false, stun_time := 0.0) -> void:
	if dead:
		return
	hp -= n
	_bar()
	flash()
	G.world.popup(global_position + Vector3(randf_range(-0.5, 0.5), 2.8 * d["scale"], 0), ("%d!" if crit else "%d") % int(n),
		Color(1.0, 0.85, 0.3) if crit else Color(1, 1, 1))
	if state == "idle" or state == "return":
		state = "chase"
	if stun_time > 0.0 and not d.get("chef", false):
		stun = stun_time
		tint(Color(0.5, 0.8, 1.0, 0.45))
		play("Idle")
	elif stun_time > 0.0:
		stun = stun_time * 0.3
	if hp <= 0.0:
		_die()
	elif state != "windup" and not d.get("chef", false):
		play("Hit_A", 1.5, true)
		state = "recover"
		t = 0.25


func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 1
	bar.visible = false
	tint(Color(0, 0, 0, 0))
	if anim:
		play("Death_C_Skeletons" if anim.has_animation("Death_C_Skeletons") else "Death_A", 1.0, true)
	else:
		var tw = create_tween()
		tw.tween_property(body, "scale", Vector3(1.2, 0.05, 1.2) if d["prim"] != "geist" else Vector3(0.01, 2.0, 0.01), 0.5)
	Audio.sfx("tod")
	remove_from_group("enemy")
	G.p["kills"] += 1
	var gold = int(randf_range(4, 10) * power * (8.0 if kind == "boss" else 1.0))
	var loot = []
	var bony = not d.has("prim") and not d.has("human")
	if bony and randf() < 0.55: loot.append("knochen")
	if d.get("prim", "") == "wolf" and randf() < 0.6: loot.append("fleisch")
	if randf() < 0.03 and zone == "": loot.append("schatzkarte")
	if d.has("human"):
		gold *= 3
		if randf() < 0.5: loot.append("pfeil")
		if randf() < 0.3: loot.append("brot")
	if d.get("prim", "") == "geist" and randf() < 0.08: loot.append("splitter")
	if randf() < 0.14: loot.append("erz")
	if randf() < 0.08: loot.append("heiltrank")
	if randf() < 0.06: loot.append("fleisch")
	if d.get("chef", false) and kind != "boss":
		loot = ["erz", "erz", "heiltrank", "heiltrank"]
		gold *= 10
		G.p["flags"][camp + "_tot"] = true
	if kind == "boss":
		loot = ["splitter", "erz", "erz", "heiltrank"]
		G.p["flags"]["boss_tot"] = true
	G.add_gold(gold)
	var txt = "+%d Gold" % gold
	for i in loot:
		G.add_item(i)
		txt += ", " + G.ITEMS[i]["name"]
	G.say(txt)
	G.add_xp(d["xp"] * power)
	G.event("kill", camp)
	G.world.enemy_died(self)
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(self):
		queue_free()
