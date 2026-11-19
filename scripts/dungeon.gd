class_name Dungeon
extends RefCounted
## Baut einen Dungeon aus einer Zeichenkarte. Jede Zelle ist 4 × 4 Einheiten groß.
## # Wand · . Boden · S Eingang · F Fackel · T Falle · L Hebel · G Tor · C Schatzkiste · B Endgegner
## d Diener · k Krieger · m Magier · s Schurke · g Geist · w Wolf · u Sumpfkriecher

const KIND := {"d": "diener", "k": "krieger", "m": "magier", "s": "schurke", "g": "geist", "w": "wolf", "u": "sumpf"}
const PLAENE := {
	"mine": {"name": "Alte Mine", "boss": "minenkoenig", "power": 1.4, "gold": 180, "loot": {"erz": 6, "splitter": 1}, "stein": Color(0.3, 0.26, 0.22), "map": [
		"####################",
		"#S.F....#....d.....#",
		"#.......#..........#",
		"####.####...T..k...#",
		"#..d....#####.######",
		"#.......G....F.....#",
		"#..k..T.#..........#",
		"####.####..d..k....#",
		"#L......#..........#",
		"#...F...#####.######",
		"#.......#C....B....#",
		"####################"]},
	"gruft": {"name": "Gruft der Hüter", "boss": "gruftfuerst", "power": 1.9, "gold": 260, "loot": {"splitter": 1, "manatrank": 3, "kette": 1}, "stein": Color(0.22, 0.24, 0.3), "map": [
		"##################",
		"#S..F...#...m....#",
		"#.......#........#",
		"#..T....G..k..T..#",
		"#.......#........#",
		"###.#####...g....#",
		"#...#...####.#####",
		"#.k.#.L.#...F....#",
		"#...#...#..g..m..#",
		"#.T.....#....B..C#",
		"#...#...#........#",
		"##################"]},
	"turmkeller": {"name": "Turmkeller", "boss": "turmherr", "power": 2.2, "gold": 340, "loot": {"splitter": 1, "heiltrank": 4, "erz": 4}, "stein": Color(0.28, 0.27, 0.3), "map": [
		"################",
		"#S...#....k....#",
		"#..F.#..T......#",
		"#....G.........#",
		"#....#....m..F.#",
		"##.#######.#####",
		"#..k.#L..#.....#",
		"#....#...#..B..#",
		"#.T..#.d.#.....#",
		"#........#...C.#",
		"################"]},
	"leuchtturm": {"name": "Leuchtturm von Salzhafen", "boss": "schmugglerkoenig", "power": 1.9, "gold": 300, "loot": {"kette": 1, "heiltrank": 3, "pfeil": 30}, "stein": Color(0.34, 0.33, 0.36), "kinds": {"d": "bandit", "k": "schlaeger", "m": "schuetze"}, "map": [
		"###############",
		"#S..F..#..d...#",
		"#......#......#",
		"#..d...G...m..#",
		"#......#..T...#",
		"###.######.####",
		"#...#L...#....#",
		"#.k.#....#..B.#",
		"#...#.d..#....#",
		"#.T......#.C..#",
		"###############"]},
	"eishoehle": {"name": "Eishöhle", "boss": "frostgeist", "power": 2.2, "gold": 320, "loot": {"splitter": 1, "manatrank": 3, "erz": 5}, "stein": Color(0.55, 0.68, 0.8), "kinds": {"d": "wolf", "k": "geist", "m": "geist"}, "map": [
		"################",
		"#S.F...#....d..#",
		"#......#.......#",
		"#..d...#..T..k.#",
		"###.####.......#",
		"#......G...F...#",
		"#.T....#####.###",
		"#...d..#.......#",
		"#L.....#...B...#",
		"#..F...#.....C.#",
		"################"]},
	"thron": {"name": "Aschenthron", "boss": "aschenkoenig", "power": 2.6, "gold": 0, "loot": {}, "stein": Color(0.2, 0.17, 0.17), "map": [
		"#################",
		"#S..F.#.....g...#",
		"#.....#..T......#",
		"#.....G.....k...#",
		"#..k..#..g....F.#",
		"###.#####.#######",
		"#.....#.........#",
		"#.L.g.#....B....#",
		"#.....#.........#",
		"#..T......F...F.#",
		"#################"]},
}


static func build(w: Node3D, id: String, origin: Vector3) -> void:
	var plan: Dictionary = PLAENE[id]
	var rows: Array = plan["map"]
	var gates = []
	var wall_mesh = BoxMesh.new()
	wall_mesh.size = Vector3(4, 4.4, 4)
	var wm = StandardMaterial3D.new()
	wm.albedo_color = plan["stein"]
	wm.roughness = 0.95
	wall_mesh.material = wm
	var shape = BoxShape3D.new()
	shape.size = Vector3(4, 4.4, 4)
	var cells = []
	for z in rows.size():
		for x in rows[z].length():
			var c: String = rows[z][x]
			var pos = origin + Vector3(x * 4.0, 0, z * 4.0)
			if c == "#":
				# nur Wände bauen, die an einen begehbaren Raum grenzen
				var near = false
				for dz in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var zz = z + dz
						var xx = x + dx
						if zz >= 0 and zz < rows.size() and xx >= 0 and xx < rows[zz].length() and rows[zz][xx] != "#":
							near = true
				if near:
					cells.append(pos)
				continue
			w.put("dungeon/floor_tile_large.glb", pos)
			match c:
				"S":
					w.dungeons[id]["start"] = pos
					w.thing(pos, "Hinaufsteigen (Dungeon verlassen)", w.exit_room, 2.6)
					w.glow_mesh(w._cyl(1.4, 0.06), pos + Vector3(0, 0.2, 0), Color(0.4, 0.8, 1.0), 1.5)
				"F":
					w.put("dungeon/torch_lit.glb", pos + Vector3(0, 0.15, 0))
					w.lamp(pos + Vector3(0, 2.2, 0), Color(1.0, 0.6, 0.3), 2.6, 15.0, true)
				"T":
					var f = Node3D.new()
					f.set_script(load("res://scripts/falle.gd"))
					f.zone = id
					f.position = pos
					w.add_child(f)
				"L":
					var lever = w.flat_mesh(w._box(Vector3(0.2, 1.6, 0.2)), pos + Vector3(0, 0.8, 0), Color(0.5, 0.4, 0.25))
					lever.rotation.z = 0.5
					w.flat_mesh(w._box(Vector3(1.0, 0.3, 1.0)), pos + Vector3(0, 0.15, 0), Color(0.3, 0.3, 0.33))
					var li = w.thing(pos, "Hebel umlegen", Callable(), 2.8)
					li.action = func():
						G.p["flags"]["tor_" + id] = true
						lever.rotation.z = -0.5
						Audio.sfx("hebel")
						G.say("Irgendwo fährt ein schweres Tor in den Boden.")
						for g in gates:
							w.open_gate(g)
					li.condition = func(): return not G.p["flags"].get("tor_" + id, false)
				"G":
					var gate = StaticBody3D.new()
					gate.position = pos + Vector3(0, 2.2, 0)
					var gm = MeshInstance3D.new()
					var gb = BoxMesh.new()
					gb.size = Vector3(4, 4.4, 1.2)
					gm.mesh = gb
					var gmat = StandardMaterial3D.new()
					gmat.albedo_color = Color(0.4, 0.3, 0.16)
					gmat.metallic = 0.5
					gm.material_override = gmat
					gate.add_child(gm)
					var gs = CollisionShape3D.new()
					gs.shape = shape
					gate.add_child(gs)
					# Tor quer zur Durchgangsrichtung stellen
					if x > 0 and rows[z][x - 1] != "#":
						gate.rotation.y = PI / 2.0
					w.add_child(gate)
					gates.append(gate)
				"C":
					var ch = w.put("dungeon/chest_gold.glb", pos + Vector3(0, 0.15, 0))
					w.solid(pos, Vector3(1.6, 1, 1.6), 0.0, 16)
					var ci = w.thing(pos, "Schatz des Dungeons öffnen", Callable(), 3.4)
					ci.action = func():
						G.p["looted"]["schatz_" + id] = true
						G.add_gold(plan["gold"])
						var txt = "+%d Gold" % plan["gold"]
						for it in plan["loot"]:
							G.add_item(it, plan["loot"][it])
							txt += ", %d %s" % [plan["loot"][it], G.ITEMS[it]["name"]]
						Audio.sfx("muenze")
						G.say("Schatz: " + txt)
					ci.condition = func(): return G.playing and not G.p["looted"].get("schatz_" + id, false)
				"B":
					w.dungeon_spawns.append([plan["boss"], pos, id + "_boss", 1.0, id])
					w.lamp(pos + Vector3(0, 4, 0), Color(1.0, 0.3, 0.15), 2.5, 20.0, true)
				_:
					var kinds: Dictionary = plan.get("kinds", {})
					if kinds.has(c) or KIND.has(c):
						w.dungeon_spawns.append([kinds.get(c, KIND.get(c, "diener")), pos, id, plan["power"], id])
	# Wände als ein gemeinsames Netz, jede mit Kollision
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = wall_mesh
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, cells[i] + Vector3(0, 2.2, 0)))
		var b = StaticBody3D.new()
		var s = CollisionShape3D.new()
		s.shape = shape
		b.add_child(s)
		b.position = cells[i] + Vector3(0, 2.2, 0)
		w.add_child(b)
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	w.add_child(mmi)
	w.dungeons[id]["gates"] = gates
