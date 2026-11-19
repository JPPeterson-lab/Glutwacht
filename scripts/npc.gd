extends Actor
## Dorfbewohner mit eigenem Leben: Jede Figur hat Bedürfnisse und Vorlieben und entscheidet
## selbst, was sie als Nächstes tut. Es gibt keinen festen Stundenplan.

const PEOPLE := {
	"gernot": {"name": "Hauptmann Gernot", "model": "Knight", "gear": {"r": "sword_1handed", "l": "shield_badge_color"}, "hide": [], "workanim": ["Idle_A"], "job": "Hauptmann der Wache",
		"work": "wache", "fleiss": 0.95, "gesellig": 0.4, "abenteuer": 0.3, "romance": false, "likes": ["met", "braten"],
		"chat": ["Seit die Glut erloschen ist, schlafe ich schlecht.", "Halte deine Klinge scharf, die Nächte werden länger.", "Früher waren wir zwölf in der Glutwacht. Heute bin ich allein, und du."]},
	"hilda": {"name": "Hilda", "indoor": true, "model": "Rogue", "gear": {"r": "tools3d/hammer"}, "hide": ["Rogue_Cape"], "workanim": ["Hammering", "Hammering", "Working_A"], "job": "Schmiedin",
		"work": "schmiede", "fleiss": 0.8, "gesellig": 0.6, "abenteuer": 0.5, "romance": true, "likes": ["erz", "met", "braten"],
		"chat": ["Eisen lügt nicht. Menschen schon.", "Mein Vater hat diese Esse gebaut. Ich bringe sie wieder zum Glühen.", "Wenn ich nicht schmiede, sitze ich gern am Brunnen und tue gar nichts."]},
	"bruno": {"name": "Bruno", "indoor": true, "model": "Barbarian", "gear": {"r": "mug_full"}, "hide": ["Barbarian_BearHat"], "workanim": ["Holding_A", "Working_B", "Use_Item"], "job": "Wirt",
		"work": "wirtshaus", "fleiss": 0.7, "gesellig": 0.95, "abenteuer": 0.2, "romance": false, "likes": ["fleisch", "kaese"],
		"chat": ["Ein voller Bauch kämpft besser, merk dir das.", "Ich war mal Söldner. Dann habe ich Eintopf entdeckt.", "Wer schläft und isst, hält länger durch als jeder Held."]},
	"mira": {"name": "Mira", "model": "Mage", "gear": {}, "hide": ["Mage_Hat", "Mage_Cape"], "workanim": ["Working_B", "Working_C", "Interact"], "job": "Händlerin",
		"work": "markt", "fleiss": 0.75, "gesellig": 0.8, "abenteuer": 0.4, "romance": true, "likes": ["kette", "blume", "festmahl"],
		"chat": ["Ich handle mit allem, außer mit meinem Wort.", "Eines Tages eröffne ich einen Laden in der Hauptstadt.", "Abends gehe ich gern spazieren, wenn die Glühwürmchen kommen."]},
	"elara": {"name": "Elara", "indoor": true, "model": "Mage", "gear": {"l": "spellbook_open"}, "hide": [], "workanim": ["Ranged_Magic_Spellcasting", "Working_C"], "job": "Gelehrte",
		"work": "studierstube", "fleiss": 0.6, "gesellig": 0.45, "abenteuer": 0.7, "romance": true, "likes": ["buch", "blume"],
		"chat": ["Die Flamme ist kein Feuer. Sie ist eine Erinnerung.", "Ich lese oft bis tief in die Nacht, dann verschlafe ich den Morgen.", "Im Dämmerwald höre ich manchmal die alten Hüter flüstern."]},
	"finn": {"name": "Finn", "model": "Ranger", "gear": {"l": "bow_withString"}, "hide": [], "workanim": ["Ranged_Bow_Aiming_Idle", "Sneaking", "Ranged_Bow_Idle"], "job": "Jäger",
		"work": "waldrand", "fleiss": 0.5, "gesellig": 0.5, "abenteuer": 0.95, "romance": true, "likes": ["fleisch", "braten", "met"],
		"chat": ["Der Wald ist ehrlicher als das Dorf.", "Ich bleibe selten lange an einem Ort.", "Wer leise geht, sieht mehr."]},
	"tomas": {"name": "Tomas", "model": "Knight", "gear": {"r": "tools3d/shovel"}, "hide": ["Knight_Helmet", "Knight_HelmetVisor", "Knight_Cape"], "workanim": ["Digging", "Working_A", "PickUp"], "job": "Bauer",
		"work": "acker_rand", "fleiss": 0.9, "gesellig": 0.7, "abenteuer": 0.2, "romance": true, "likes": ["eintopf", "brot", "met"],
		"chat": ["Die Erde gibt, wenn man ihr Zeit lässt.", "Nach der Arbeit ein Krug bei Bruno, mehr brauche ich nicht.", "Ich stehe mit der Sonne auf. Meistens."]},
	"odo": {"name": "Odo", "model": "Barbarian", "gear": {"r": "tools3d/axe"}, "hide": [], "workanim": ["Chopping", "Chopping", "Holding_A"], "job": "Holzfäller",
		"work": "holzplatz", "fleiss": 0.85, "gesellig": 0.5, "abenteuer": 0.6, "romance": false, "likes": ["braten", "met"],
		"chat": ["Ein guter Baum fällt dahin, wo man ihn haben will.", "Im Dämmerwald schlage ich nichts mehr. Dort schauen die Bäume zurück.", "Abends tun mir die Arme weh, aber das Bier schmeckt doppelt."]},
	"lina": {"name": "Lina", "model": "Rogue_Hooded", "gear": {"r": "rute"}, "hide": ["RogueHooded_Mask"], "workanim": ["Fishing_Idle", "Fishing_Cast", "Fishing_Reeling"], "job": "Fischerin",
		"work": "teich", "fleiss": 0.55, "gesellig": 0.65, "abenteuer": 0.5, "romance": false, "likes": ["brot", "kaese"],
		"chat": ["Die Enten kennen mich schon, die fressen mir aus der Hand.", "Angeln ist die Kunst, beschäftigt auszusehen.", "Am Teich ist es am schönsten, wenn die Glühwürmchen kommen."]},
	"karl": {"name": "Karl", "model": "Knight", "gear": {"r": "sword_1handed", "l": "shield_round_color"}, "hide": ["Knight_Cape"], "workanim": ["Idle_A", "Idle_B"], "job": "Torwächter",
		"work": "tor", "fleiss": 0.7, "gesellig": 0.6, "abenteuer": 0.8, "romance": false, "likes": ["eintopf", "met"],
		"chat": ["Am Südtor kommt selten wer vorbei. Mir ist das recht.", "Ich drehe gern meine Runden, vom Stehen kriege ich Rücken.", "Der Hauptmann ist streng, aber gerecht."]},
	"bertha": {"name": "Bertha", "model": "Mage", "gear": {}, "hide": ["Mage_Hat"], "workanim": ["Working_A", "Holding_B", "PickUp"], "job": "Müllerin",
		"work": "muehle", "fleiss": 0.85, "gesellig": 0.9, "abenteuer": 0.3, "romance": false, "likes": ["tomate", "blume"],
		"chat": ["Ohne Mehl kein Brot, ohne Brot kein Aschfurt.", "Ich weiß alles, was im Dorf geredet wird. Fast alles.", "Tomas und ich teilen uns den Wind: er fürs Feld, ich für die Mühle."]},
	"jorik": {"name": "Jorik", "model": "Ranger", "gear": {"r": "tools3d/pickaxe"}, "hide": ["Ranger_Cape", "Ranger_Quiver"], "workanim": ["Pickaxing", "Pickaxing", "Working_B"], "job": "Steinmetz",
		"work": "steinbruch", "fleiss": 0.8, "gesellig": 0.45, "abenteuer": 0.55, "romance": false, "likes": ["erz", "braten"],
		"chat": ["Früher habe ich in der Mine gearbeitet. Dann kamen die Knochen.", "Stein ist geduldig. Ich nicht immer.", "Wenn Hilda Erz braucht, klopfe ich ihr welches aus dem Fels."]},
	"walda": {"name": "Walda", "dorf": "b", "indoor": true, "model": "Barbarian", "gear": {"r": "mug_full"}, "hide": ["Barbarian_BearHat"], "workanim": ["Holding_A", "Working_B", "Use_Item"], "job": "Wirtin in Weidenau",
		"work": "b_wirtshaus", "fleiss": 0.8, "gesellig": 0.9, "abenteuer": 0.2, "romance": false, "likes": ["fisch", "met"],
		"chat": ["Der Hecht im See ist so alt, dass er Steuern zahlen müsste.", "Aschfurt hat einen Hauptmann. Wir haben mich.", "Wer bei mir isst, zahlt. Wer bei mir singt, zahlt doppelt."]},
	"ivo": {"name": "Ivo", "dorf": "b", "model": "Ranger", "gear": {"r": "rute"}, "hide": ["Ranger_Quiver"], "workanim": ["Fishing_Idle", "Fishing_Cast", "Fishing_Reeling"], "job": "Fischer",
		"work": "b_steg", "fleiss": 0.9, "gesellig": 0.4, "abenteuer": 0.5, "romance": false, "likes": ["brot", "met"],
		"chat": ["Am Ostufer klappert es nachts. Das sind keine Fische.", "Der See vergisst nichts. Er behält es nur für sich.", "Morgens beißen sie am besten. Abends beiße ich."]},
	"selma": {"name": "Selma", "dorf": "b", "model": "Rogue", "gear": {}, "hide": ["Rogue_Cape"], "workanim": ["Working_A", "Working_C", "PickUp"], "job": "Korbflechterin",
		"work": "b_ufer", "fleiss": 0.7, "gesellig": 0.7, "abenteuer": 0.4, "romance": false, "likes": ["blume", "kaese"],
		"chat": ["Ein guter Korb hält länger als eine schlechte Ehe.", "Ich flechte, was der See hergibt: Weide, Schilf, manchmal Hoffnung.", "Komm abends ins Gasthaus, dann ist ganz Weidenau da. Alle drei."]},
	# ---- Salzhafen
	"greta": {"name": "Greta", "dorf": "salz", "indoor": true, "model": "Rogue", "gear": {"r": "mug_full"}, "hide": ["Rogue_Cape"], "workanim": ["Holding_A", "Working_B", "Use_Item"], "job": "Wirtin „Zum Anker“",
		"work": "salz_wirtshaus", "fleiss": 0.8, "gesellig": 0.9, "abenteuer": 0.2, "romance": false, "likes": ["met", "kaese"],
		"chat": ["Bei mir trinkt jeder Kapitän, und jeder lügt über den Fang.", "Das Meer nimmt, das Meer gibt. Ich nehme nur Münzen.", "Seit der Turm dunkel ist, kommen weniger Schiffe und mehr Gesindel."]},
	"marek": {"name": "Kapitän Marek", "dorf": "salz", "model": "Knight", "gear": {}, "hide": ["Knight_Helmet", "Knight_HelmetVisor"], "workanim": ["Idle_A", "Working_A", "Holding_A"], "job": "Kapitän der „Möwe“",
		"work": "salz_steg", "fleiss": 0.85, "gesellig": 0.6, "abenteuer": 0.8, "romance": false, "likes": ["met", "braten"],
		"chat": ["Die Möwe ist alt, aber sie schwimmt. Das kann man von mir auch sagen.", "Wer über den See will, fährt mit mir oder läuft außen herum.", "Früher hatte ich zwölf Mann. Heute habe ich Rücken."]},
	"nele": {"name": "Nele", "dorf": "salz", "model": "Mage", "gear": {}, "hide": ["Mage_Hat", "Mage_Cape"], "workanim": ["Working_B", "Working_C", "Interact"], "job": "Fischhändlerin",
		"work": "salz_markt", "fleiss": 0.8, "gesellig": 0.85, "abenteuer": 0.5, "romance": true, "likes": ["kette", "blume", "festmahl"],
		"chat": ["Frischer wird es nicht, der hat heute Morgen noch geschwommen.", "Ich rieche nach Fisch, ich weiß. Man gewöhnt sich an alles, sagen die anderen.", "Eines Tages kaufe ich mir ein eigenes Boot und nenne es nach niemandem."]},
	"ole": {"name": "Ole", "dorf": "salz", "model": "Ranger", "gear": {"r": "tools3d/lantern"}, "hide": ["Ranger_Quiver"], "workanim": ["Idle_A", "Holding_A", "Working_A"], "job": "Leuchtturmwärter",
		"work": "salz_turm", "fleiss": 0.7, "gesellig": 0.4, "abenteuer": 0.4, "romance": false, "likes": ["fackel", "brot"],
		"chat": ["Ein Leuchtturm ohne Licht ist nur ein teurer Stein.", "Ich habe dreißig Jahre lang jede Nacht das Feuer gehütet. Wie ihr, nur mit besserer Aussicht.", "Wenn es wieder brennt, schlafe ich drei Tage."]},
	# ---- Hochwacht
	"bjarne": {"name": "Bjarne", "dorf": "hoch", "model": "Barbarian", "gear": {"r": "tools3d/hammer"}, "hide": [], "workanim": ["Hammering", "Hammering", "Working_A"], "job": "Meisterschmied",
		"work": "hoch_schmiede", "fleiss": 0.9, "gesellig": 0.5, "abenteuer": 0.5, "romance": true, "likes": ["erz", "met", "braten"],
		"chat": ["Hilda in Aschfurt? Gute Hände. Sag ihr, mein Stahl ist trotzdem härter.", "Hier oben härtet der Frost die Klinge und den Schmied.", "Ich rede nicht viel. Der Hammer sagt genug."]},
	"sigrun": {"name": "Sigrun", "dorf": "hoch", "indoor": true, "model": "Rogue_Hooded", "gear": {"r": "mug_full"}, "hide": ["RogueHooded_Mask"], "workanim": ["Holding_A", "Working_B", "Use_Item"], "job": "Wirtin der Berghütte",
		"work": "hoch_wirtshaus", "fleiss": 0.8, "gesellig": 0.8, "abenteuer": 0.3, "romance": false, "likes": ["kaese", "zwiebel"],
		"chat": ["Bei mir gibt es Eintopf. Wer etwas anderes will, geht ins Tal.", "Im Winter sind wir drei Monate eingeschneit. Da lernt man sich kennen.", "Zieh die Stiefel aus, bevor du mir den Boden volltropfst."]},
	"torvald": {"name": "Torvald", "dorf": "hoch", "model": "Ranger", "gear": {"l": "bow_withString"}, "hide": [], "workanim": ["Ranged_Bow_Aiming_Idle", "Sneaking", "Ranged_Bow_Idle"], "job": "Jäger",
		"work": "hoch_alm", "fleiss": 0.6, "gesellig": 0.4, "abenteuer": 0.9, "romance": false, "likes": ["fleisch", "pfeil"],
		"chat": ["Ein Wolf allein ist ein Tier. Sechs sind eine Meinung.", "Im Schnee liest man jede Spur. Deine auch.", "Ich schieße nur, was ich auch trage."]},
	"ylva": {"name": "Ylva", "dorf": "hoch", "model": "Mage", "gear": {"r": "staff"}, "hide": ["Mage_Hat"], "workanim": ["Idle_A", "Working_C", "Interact"], "job": "Bergführerin",
		"work": "hoch_brunnen", "fleiss": 0.6, "gesellig": 0.5, "abenteuer": 0.85, "romance": false, "likes": ["fackel", "heiltrank"],
		"chat": ["Der Berg verzeiht einen Fehler. Den ersten.", "Ich kenne jeden Pfad bis zum Gletscher, und einen kenne ich zu gut.", "Wer hier oben ruft, bekommt Antwort. Nicht immer vom Echo."]},
	# ---- Dornfeld
	"konrad": {"name": "Konrad", "dorf": "dorn", "indoor": true, "model": "Barbarian", "gear": {"r": "mug_full"}, "hide": ["Barbarian_BearHat"], "workanim": ["Holding_A", "Working_B", "Use_Item"], "job": "Wirt „Zur goldenen Ähre“",
		"work": "dorn_wirtshaus", "fleiss": 0.75, "gesellig": 0.95, "abenteuer": 0.2, "romance": false, "likes": ["fleisch", "met"],
		"chat": ["Am Markttag schlafen sie bei mir in drei Schichten.", "Bestes Bier südlich von Aschfurt. Einziges auch.", "Ein Hüter der Glut! Setz dich, der erste Krug geht auf mich. Der zweite auf dich."]},
	"rosalind": {"name": "Rosalind", "dorf": "dorn", "model": "Mage", "gear": {}, "hide": ["Mage_Hat"], "workanim": ["Working_B", "PickUp", "Interact"], "job": "Blumenhändlerin",
		"work": "dorn_markt", "fleiss": 0.7, "gesellig": 0.8, "abenteuer": 0.5, "romance": true, "likes": ["blume", "buch", "kette"],
		"chat": ["Jede Blume hat eine Bedeutung. Die meisten bedeuten: Verzeih mir.", "Ich verkaufe Sträuße und lese dabei, was die Leute nicht sagen.", "Dornfeld ist flach wie ein Tisch. Manchmal wünsche ich mir einen Berg, nur zum Ansehen."]},
	"hedda": {"name": "Hedda", "dorf": "dorn", "model": "Rogue", "gear": {"r": "tools3d/shovel"}, "hide": ["Rogue_Cape"], "workanim": ["Digging", "Working_A", "PickUp"], "job": "Bäuerin",
		"work": "dorn_feld", "fleiss": 0.95, "gesellig": 0.6, "abenteuer": 0.3, "romance": false, "likes": ["eintopf", "brot"],
		"chat": ["Unser Korn ernährt Aschfurt, Weidenau und halb Salzhafen. Sag das mal den Räubern.", "Wer um fünf nicht auf dem Feld ist, hat den Tag verloren.", "Tomas aus Aschfurt? Guter Mann. Zu weiche Hände."]},
	"veit": {"name": "Veit", "dorf": "dorn", "model": "Knight", "gear": {}, "hide": ["Knight_Helmet", "Knight_HelmetVisor", "Knight_Cape"], "workanim": ["Idle_A", "Working_A", "Holding_A"], "job": "Kutscher",
		"work": "dorn_kutsche", "fleiss": 0.7, "gesellig": 0.7, "abenteuer": 0.7, "romance": false, "likes": ["met", "karotte"],
		"chat": ["Zwei Gäule, vier Räder, ein Weg. Mehr braucht ein Mann nicht.", "Die Karotten sind für die Pferde. Meistens.", "Ich kenne jedes Schlagloch zwischen hier und Aschfurt beim Vornamen."]},
}
const STOCK := {
	"mira": ["brot", "kaese", "fleisch", "tomate", "zwiebel", "fackel", "pfeil", "schaufel", "saat_karotte", "saat_kartoffel", "saat_tomate", "saat_zwiebel", "heiltrank", "manatrank", "blume", "buch", "kette", "ring"],
	"bruno": ["eintopf", "braten", "brot", "met", "festmahl"],
	"walda": ["bratfisch", "fisch", "brot", "met", "eintopf", "fackel", "pfeil"],
	"greta": ["bratfisch", "fisch", "brot", "met", "festmahl", "fackel"],
	"nele": ["fisch", "bratfisch", "pfeil", "fackel", "kette", "heiltrank", "manatrank"],
	"sigrun": ["eintopf", "braten", "kaese", "met", "fackel", "heiltrank"],
	"konrad": ["braten", "eintopf", "festmahl", "brot", "met"],
	"rosalind": ["blume", "saat_karotte", "saat_kartoffel", "saat_tomate", "saat_zwiebel", "kaese", "brot", "buch", "ring"],
}
const ACT_TEXT := {
	"schlafen": "Ich wollte mich gerade hinlegen.",
	"essen": "Ich habe Hunger und hole mir etwas zu essen.",
	"arbeiten": "Ich bin bei der Arbeit, wie du siehst.",
	"daheim": "Ich bin zu Hause und lasse es mir gut gehen.",
	"fest": "Heute wird gefeiert! Nimm dir einen Krug und bleib.",
	"plaudern": "Ich unterhalte mich gerade mit %s.",
	"spazieren": "Ich vertrete mir die Beine. Tut gut.",
	"wirtshaus": "Ich gönne mir etwas im Wirtshaus.",
	"ausruhen": "Ich ruhe mich am Brunnen aus und schaue den Leuten zu.",
}

var id := ""
var d := {}
var needs := {"hunger": 80.0, "energy": 80.0, "social": 60.0, "fun": 60.0}
var act := "ausruhen"
var goal := Vector3.ZERO
var arrived := false
var timer := 0.0
var mate: Node = null
var friends := {}
var hidden := false
var reach := 3.8
var tag: Label3D
var stuck := 0.0
var idle_t := 0.0
var woken := false
var spot_pos := Vector3.INF
var spot_rot := 0.0
var spot_sit := false
var spot_t := 12.0
var following := false      # begleitet den Helden und kämpft mit
var bite_t := 0.0
var room := ""           # Haus, in dem die Figur gerade ist
var goal_place := ""
var detour_t := 0.0
var detour_sign := 1.0
var travel_t := 0.0


func init(npc_id: String, pos: Vector3) -> void:
	id = npc_id
	d = PEOPLE[npc_id]
	position = pos


func _ready() -> void:
	add_to_group("npc")
	add_to_group("interact")
	collision_layer = 8
	collision_mask = 1
	setup("chars2/%s.glb" % d["model"])
	gear(d["gear"])
	for h in d["hide"]:
		set_part(h, false)
	for k in needs:
		needs[k] = randf_range(45.0, 95.0)
	tag = Label3D.new()
	tag.text = d["name"]
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 3.5
	tag.font_size = 44
	tag.outline_size = 10
	tag.pixel_size = 0.008
	tag.modulate = Color(1.0, 0.9, 0.7)
	tag.visibility_range_end = 45.0
	add_child(tag)
	goal = position
	arrived = true
	timer = randf_range(0.2, 3.0)
	play("Idle")


func usable() -> bool:
	return not hidden

func prompt() -> String:
	return "Mit %s sprechen" % d["name"]

func home_place() -> String:
	return "spielerhaus" if G.p.get("partner", "") == id else "haus_" + id


# ---------------------------------------------------------------- eigenes Leben

func _decide() -> void:
	var h = G.hour()
	var night = h >= 22.0 or h < 6.0
	var day = h >= 8.0 and h < 18.0
	var sc = {}
	sc["schlafen"] = (100.0 - needs["energy"]) * 1.3 + (45.0 if night else -25.0) + (30.0 if act == "schlafen" and needs["energy"] < 95.0 else 0.0)
	sc["essen"] = (100.0 - needs["hunger"]) * 1.1
	sc["arbeiten"] = d["fleiss"] * 70.0 * (1.0 if day else 0.15) + (10.0 if act == "arbeiten" else 0.0)
	sc["plaudern"] = (100.0 - needs["social"]) * 0.8 * (0.5 + d["gesellig"])
	sc["spazieren"] = ((100.0 - needs["fun"]) * 0.5 + d["abenteuer"] * 25.0) * (0.5 if night else 1.0)
	sc["wirtshaus"] = (100.0 - needs["fun"]) * 0.5 + (25.0 if h >= 17.0 and h < 23.0 else 0.0)
	sc["ausruhen"] = 15.0
	var wt = G.world.wetter
	if wt.bad():
		# bei Regen, Gewitter und Schnee bleibt man lieber unter einem Dach
		sc["spazieren"] *= 0.2
		sc["ausruhen"] *= 0.2
		sc["plaudern"] *= 0.5
		sc["wirtshaus"] += 25.0
		if not d.get("indoor", false):
			sc["arbeiten"] *= 0.5
	if wt.festive() and d.get("dorf", "") == "" and needs["energy"] > 15.0:
		sc["fest"] = 400.0
	var best = "ausruhen"
	var bv = -999.0
	for k in sc:
		var v: float = sc[k] + randf() * 24.0
		if v > bv:
			bv = v
			best = k
	if best == "plaudern":
		mate = _pick_mate()
		if mate == null:
			best = "spazieren"
	_start(best)


func _pick_mate() -> Node:
	var best: Node = null
	var bv = -1.0
	for n in get_tree().get_nodes_in_group("npc"):
		if n == self or n.room != "" or n.act == "schlafen" or n.d.get("dorf", "") != d.get("dorf", ""):
			continue
		var v: float = friends.get(n.id, 0.0) + randf() * 30.0 - flat_dist(n.global_position) * 0.15
		if best == null or v > bv:
			bv = v
			best = n
	return best


func _start(a: String) -> void:
	var pl: Dictionary = G.world.places
	var pre: String = d.get("dorf", "")     # Bewohner anderer Dörfer bleiben in ihrem Dorf
	var b = pre != ""
	var inn = (pre + "_wirtshaus") if b else "wirtshaus"
	var well = (pre + "_brunnen") if b else "brunnen"
	var jitter = Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	var new_goal = global_position
	var new_place = ""        # Gebäude, das betreten wird (leer: Ziel im Freien)
	match a:
		"schlafen":
			new_place = home_place()
		"essen":
			new_place = inn if randf() < 0.6 else home_place()
		"arbeiten":
			if d.get("indoor", false):
				new_place = d["work"]
			else:
				new_goal = pl[d["work"]] + jitter * 0.4
		"plaudern":
			new_goal = mate.global_position
		"spazieren":
			var spots = ["brunnen", "waldrand", "acker_rand", "markt", "teich", "wache", "tor", "muehle", "holzplatz"]
			if b:
				spots = G.world.dorf_spots[pre]
			new_goal = pl[spots.pick_random()] + jitter * 3.0
		"wirtshaus":
			new_place = inn
		"ausruhen":
			new_goal = pl[well] + jitter.normalized() * 4.0
		"fest":
			new_goal = pl["brunnen"] + Vector3(randf_range(-9, 9), 0, randf_range(-3, 12))
	timer = randf_range(30.0, 75.0)
	if room != "" and room == new_place:
		# schon im richtigen Haus: drinnen bleiben und nur die Tätigkeit wechseln
		if act != a:
			act = a
			_spot()
		return
	if room != "":
		_leave()
	act = a
	arrived = false
	travel_t = 0.0
	goal_place = new_place
	goal = pl[new_place] if new_place != "" else new_goal


func _leave() -> void:
	global_position = G.world.places[room] + Vector3(randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6))
	room = ""
	body.position = Vector3.ZERO


## Sucht sich im Haus einen passenden Platz: Bett, Arbeitsplatz, Tisch.
func _spot() -> void:
	var rd: Dictionary = G.world.rooms[room]
	var sp: Dictionary = rd["spots"]
	var o: Vector3 = rd["o"]
	var pos = o + Vector3(randf_range(-2.0, 2.0), 0.2, randf_range(-0.5, 1.5))
	var rot = randf() * TAU
	if act == "schlafen" and sp.has("bed"):
		pos = sp["bed"][0]
		rot = sp["bed"][1]
		play("Lie_Idle", 1.0, true)
	elif act == "arbeiten" and sp.has("work"):
		pos = sp["work"][0]
		rot = sp["work"][1]
	elif sp.has("guests"):
		var g = sp["guests"].pick_random()
		pos = g[0] + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		rot = g[1]
	spot_rot = rot
	spot_sit = act != "schlafen" and act != "arbeiten" and sp.has("sitze") and randf() < 0.6
	if spot_sit:
		var st = sp["sitze"].pick_random()
		pos = st[0]
		spot_rot = st[1]
	velocity = Vector3.ZERO
	if act == "schlafen" or global_position.distance_to(pos) > 30.0:
		global_position = pos           # gerade erst hereingekommen oder ins Bett: direkt hin
		body.rotation.y = rot
		spot_pos = Vector3.INF
	else:
		spot_pos = pos                  # sonst zu Fuß durchs Zimmer
	spot_t = randf_range(10.0, 26.0)


func _physics_process(delta: float) -> void:
	var gh = delta / G.HOUR_SECONDS      # vergangene Spielstunden
	needs["hunger"] = max(0.0, needs["hunger"] - gh * 5.0)
	needs["energy"] = max(0.0, needs["energy"] - gh * (4.5 if act != "arbeiten" else 6.0))
	needs["social"] = max(0.0, needs["social"] - gh * 4.0 * (0.5 + d["gesellig"]))
	needs["fun"] = max(0.0, needs["fun"] - gh * (3.0 if act != "arbeiten" else 6.0))
	if following:
		_follow(delta)
		return
	if room != "":
		# im Haus: von Platz zu Platz gehen, sich setzen, der Tätigkeit nachgehen
		if spot_pos != Vector3.INF:
			var to = spot_pos - global_position
			to.y = 0
			if to.length() > 0.25:
				global_position += to.normalized() * 2.0 * delta
				face(to, delta, 8.0)
				play("Walking_A")
				return
			global_position = spot_pos
			body.rotation.y = spot_rot
			spot_pos = Vector3.INF
			if spot_sit:
				play("Sit_Chair_Idle", 1.0, true)
			else:
				play("Idle_A", 1.0, true)
		spot_t -= delta
		if spot_t <= 0.0 and act != "schlafen":
			_spot()
		if spot_sit and act != "schlafen":
			play("Sit_Chair_Idle")
			needs["hunger"] = min(100.0, needs["hunger"] + gh * (40.0 if act == "essen" else 10.0))
			needs["fun"] = min(100.0, needs["fun"] + gh * 20.0)
		else:
			_perform(delta, gh)
		timer -= delta
		if timer <= 0.0:
			_decide()
		return
	velocity.y = velocity.y - 24.0 * delta if not is_on_floor() else -1.0

	if act == "plaudern" and is_instance_valid(mate) and not arrived:
		if mate.room != "":
			timer = 0.0
		else:
			goal = mate.global_position
	var dist = flat_dist(goal)
	var near = 2.6 if act == "plaudern" else 1.2
	if not arrived and dist > near:
		var dir = flat_dir(goal)
		if stuck > 0.25 and detour_t <= 0.0:
			detour_t = 1.8
			stuck = 0.0
			if randf() < 0.3: detour_sign = -detour_sign
		if detour_t > 0.0:
			detour_t -= delta
			dir = dir.rotated(Vector3.UP, 1.25 * detour_sign)
		travel_t += delta
		if travel_t > 90.0:      # Notlösung, falls jemand wirklich festhängt
			global_position = goal + Vector3(0, 0.3, 0)
		var sp = 5.2 if dist > 45.0 else 2.7
		dir = G.world.avoid(global_position, dir)
		velocity.x = dir.x * sp
		velocity.z = dir.z * sp
		face(dir, delta, 7.0)
		play("Running_A" if sp > 4.0 else "Walking_A", 1.0)
		var before = global_position
		move_and_slide()
		if global_position.distance_to(before) < sp * delta * 0.3:
			stuck += delta
			if stuck > 1.3:
				stuck = 0.0
		else:
			stuck = max(0.0, stuck - delta * 2.0)
		return
	if not arrived:
		arrived = true
		_arrive()
	velocity.x = 0.0
	velocity.z = 0.0
	if not hidden:
		move_and_slide()
	_perform(delta, gh)
	timer -= delta
	if timer <= 0.0:
		_decide()


## Begleiter: folgt dem Helden, greift nahe Gegner an, nimmt selbst keinen Schaden.
func _follow(delta: float) -> void:
	var pl = G.player
	if pl == null:
		return
	if room != "":
		_leave()
	bite_t -= delta
	velocity.y = velocity.y - 24.0 * delta if not is_on_floor() else -1.0
	var target: Node = null
	var best = 11.0
	for e in get_tree().get_nodes_in_group("enemy"):
		var dd: float = e.global_position.distance_to(pl.global_position)
		if not e.dead and e.state != "idle" and dd < best and e.zone == G.p.get("room", ""):
			best = dd
			target = e
	var goal_pos: Vector3 = pl.global_position - pl.facing() * 2.6 + Vector3(1.6, 0, 0)
	var stop = 1.2
	var ranged = d["model"] == "Ranger"
	if target:
		goal_pos = target.global_position
		stop = 9.0 if ranged else 2.6
	var dist = flat_dist(goal_pos)
	if global_position.distance_to(pl.global_position) > 45.0:
		global_position = pl.global_position + Vector3(1.5, 0.3, 1.5)      # auch in Häuser und Dungeons hinein
		return
	if dist > stop:
		var dir = flat_dir(goal_pos)
		if G.p.get("room", "") == "":
			dir = G.world.avoid(global_position, dir)
		var sp = 8.0 if dist > 6.0 else 4.5
		velocity.x = dir.x * sp
		velocity.z = dir.z * sp
		face(dir, delta, 9.0)
		play("Running_A", 1.1)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if target:
			face(flat_dir(target.global_position), delta, 12.0)
			if bite_t <= 0.0:
				bite_t = 1.5
				play("Ranged_Bow_Release" if ranged else "1H_Melee_Attack_Slice_Diagonal", 1.3, true)
				target.take_damage(8.0 + G.p["level"] * 3.0, false)
		elif not anim.is_playing() or anim.current_animation.begins_with("Running"):
			play("Idle_A")
	move_and_slide()


func set_following(on: bool) -> void:
	following = on
	G.p["flags"]["begleitet"] = id if on else ""
	if on:
		if not d["gear"].has("r") and d["model"] != "Ranger":
			gear({"r": "sword_1handed"})
	else:
		gear(d["gear"])
		_decide()


func _arrive() -> void:
	if goal_place != "" and G.world.rooms.has(goal_place):
		room = goal_place
		_spot()
		return
	match act:
		"plaudern":
			if is_instance_valid(mate) and not mate.hidden and mate.act != "schlafen":
				# der andere lässt sich auf das Gespräch ein, wenn ihm danach ist
				if mate.needs["social"] < 85.0 or randf() < mate.d["gesellig"]:
					mate.mate = self
					mate.act = "plaudern"
					mate.arrived = true
					mate.timer = timer
				else:
					timer = 3.0
			else:
				timer = 0.5


func _perform(delta: float, gh: float) -> void:
	idle_t -= delta
	match act:
		"schlafen":
			play("Lie_Idle")
			needs["energy"] = min(100.0, needs["energy"] + gh * 14.0)
			if needs["energy"] >= 99.0:
				timer = 0.0
		"essen":
			needs["hunger"] = min(100.0, needs["hunger"] + gh * 60.0)
			if idle_t <= 0.0:
				idle_t = randf_range(3.0, 6.0)
				play("Use_Item", 1.0, true)
			elif not anim.is_playing():
				play("Idle")
			if needs["hunger"] >= 98.0:
				timer = min(timer, 2.0)
		"arbeiten":
			if idle_t <= 0.0:
				idle_t = randf_range(2.5, 6.0)
				play(d["workanim"].pick_random(), 1.0, true)
			elif anim.current_animation in Actor.LOOPS:
				pass
			elif not anim.is_playing():
				play("Idle")
		"plaudern":
			needs["social"] = min(100.0, needs["social"] + gh * 45.0)
			needs["fun"] = min(100.0, needs["fun"] + gh * 10.0)
			if is_instance_valid(mate):
				face(flat_dir(mate.global_position), delta)
				friends[mate.id] = min(100.0, friends.get(mate.id, 0.0) + gh * 12.0)
			if idle_t <= 0.0:
				idle_t = randf_range(2.5, 5.0)
				play(["Interact", "Waving", "Cheering", "Idle_A"].pick_random(), 1.0, true)
			elif not anim.is_playing():
				play("Idle")
		"spazieren":
			needs["fun"] = min(100.0, needs["fun"] + gh * 30.0)
			play("Idle")
			timer = min(timer, 6.0)
		"wirtshaus":
			needs["fun"] = min(100.0, needs["fun"] + gh * 35.0)
			needs["social"] = min(100.0, needs["social"] + gh * 15.0)
			needs["hunger"] = min(100.0, needs["hunger"] + gh * 15.0)
			if idle_t <= 0.0:
				idle_t = randf_range(4.0, 8.0)
				play(["Use_Item", "Cheer"].pick_random(), 1.0, true)
			elif not anim.is_playing():
				play("Idle")
		"fest":
			needs["fun"] = 100.0
			needs["social"] = 100.0
			needs["hunger"] = min(100.0, needs["hunger"] + gh * 30.0)
			if idle_t <= 0.0:
				idle_t = randf_range(2.0, 5.0)
				play(["Cheering", "Waving", "Use_Item", "Cheering"].pick_random(), 1.0, true)
			elif not anim.is_playing():
				play("Idle_A")
		"ausruhen":
			needs["energy"] = min(100.0, needs["energy"] + gh * 3.0)
			needs["fun"] = min(100.0, needs["fun"] + gh * 8.0)
			play("Sit_Floor_Idle")


func best_friend() -> String:
	var best = ""
	for k in friends:
		if best == "" or friends[k] > friends[best]:
			best = k
	return best


# ---------------------------------------------------------------- Gespräch

func aff_name(a: float) -> String:
	if a >= 85.0: return "Liebe"
	if a >= 60.0: return "Zuneigung"
	if a >= 40.0: return "Freundschaft"
	if a >= 20.0: return "Bekannt"
	return "Fremd"


func interact() -> void:
	var nd = G.npc_data(id)
	if act == "schlafen" and room != "" and not woken:
		G.ui.dialog(d["name"], "%s schläft tief und fest." % d["name"], [
			["Wecken", func():
				woken = true
				nd["aff"] = max(0.0, nd["aff"] - 2.0)
				needs["energy"] = max(needs["energy"], 40.0)
				play("Idle_A", 1.0, true)
				act = "ausruhen"
				timer = 40.0
				menu("Hm? Was ist denn los? Es ist mitten in der Nacht ...")
				woken = false],
			["Schlafen lassen", Callable()]])
		return
	if G.player:
		body.rotation.y = atan2(G.player.global_position.x - global_position.x, G.player.global_position.z - global_position.z)
	if nd["talk_day"] != G.p["day"]:
		nd["talk_day"] = G.p["day"]
		nd["aff"] = min(100.0, nd["aff"] + 2.0)
	var fin = G.event("talk", id)
	if not fin.is_empty():
		G.ui.dialog(d["name"], G.QUESTS[fin[0]]["outro"], [["Weiter", func(): menu("Kann ich sonst noch etwas für dich tun?")]])
		return
	if id == "gernot" and not G.p["flags"].get("m1_intro", false):
		G.p["flags"]["m1_intro"] = true
		menu(G.QUESTS["m1"]["intro"])
		return
	menu(_greeting(nd))


func _greeting(nd: Dictionary) -> String:
	var n: String = G.p["name"]
	var wt = G.world.wetter
	if wt.festive() and d.get("dorf", "") == "":
		return "%s! Komm, feier mit uns, heute ist %s!" % [n, wt.today()]
	if wt.cur == "gewitter" and room == "":
		return "Bei dem Gewitter sollte niemand draußen sein. Mach es kurz, %s." % n
	if wt.cur == "regen" and room == "":
		return "Was für ein Wetter. Ich bin nass bis auf die Haut. Was gibt es, %s?" % n
	if wt.cur == "schnee":
		return "Kalt heute, %s. Halt dich warm." % n
	if G.p["partner"] == id and nd.get("eifersucht", false):
		return "Ach, du. Ich habe gehört, mit wem du schöne Worte wechselst. Hast du mir etwas zu sagen?"
	if G.p["partner"] == id:
		return "Da bist du ja, %s. Ich habe an dich gedacht." % n
	if nd["aff"] >= 60.0:
		return "%s! Schön, dich zu sehen." % n
	if nd["aff"] >= 20.0:
		return "Hallo %s. Was gibt es?" % n
	return "Ja? Ich bin %s, %s hier in Aschfurt." % [d["name"], d["job"]]


func menu(text: String) -> void:
	var nd = G.npc_data(id)
	var o = []
	for q in G.QUESTS:
		if G.QUESTS[q]["giver"] == id and G.quest_available(q):
			o.append(["Aufgabe: " + G.QUESTS[q]["name"], func(): _offer(q)])
	if id == "hilda":
		o.append(["Schmieden (Waffe und Schutz verbessern)", func():
			if G.p["flags"].get("smith_free", false):
				G.ui.show_smith()
			else:
				menu("Erst das Erz, dann die Arbeit. Frag mich nach der Aufgabe.")])
	if STOCK.has(id):
		o.append(["Handeln", func(): G.ui.show_shop(d["name"], STOCK[id])])
	if id == "bjarne":
		o.append(["Meisterschmiede (Waffen, Rüstung, Runen)", func(): G.ui.show_smith()])
	if id == "marek":
		o.append(["Überfahrt nach Weidenau%s" % ("" if G.p["flags"].get("schiff_frei", false) else " (15 Gold)"), func():
			G.world.reise("", G.world.places["b_steg"], "Das Schiff legt ab. Salzhafen wird kleiner, der See von Weidenau kommt in Sicht.", 0 if G.p["flags"].get("schiff_frei", false) else 15)])
	if id == "veit" and not G.p["flags"].get("esel", false):
		o.append(["Einen Packesel kaufen (250 Gold, Traglast 160 statt 60)", func():
			if G.p["gold"] < 250:
				menu("Zweihundertfünfzig, und ich gebe dir den braven Grauen. Der beißt nur manchmal.")
			else:
				G.add_gold(-250)
				G.p["flags"]["esel"] = true
				G.world.spawn_dog("esel")
				menu("Er heißt Fridolin. Er trägt alles, solange du ihm ab und zu eine Karotte gibst.")])
	if id == "veit":
		o.append(["Mit der Kutsche nach Aschfurt (10 Gold)", func():
			G.world.reise("", G.world.places["tor"], "Die Kutsche rumpelt über die Feldwege nach Norden, bis das Südtor von Aschfurt auftaucht.", 10)])
	if id in ["bruno", "walda", "greta", "sigrun", "konrad"]:
		o.append(["Zimmer für die Nacht (10 Gold)", func():
			if G.p["gold"] < 10:
				menu("Ohne Münzen kein Bett, tut mir leid.")
			else:
				G.add_gold(-10)
				G.world.sleep_scene("Du schläfst in einer Kammer über der Schankstube.", 0.85)])
	if id == "tomas" and int(G.p["flags"].get("huhn", 0)) < 4:
		o.append(["Ein Huhn für den eigenen Stall kaufen (40 Gold)", func():
			if G.p["gold"] < 40:
				menu("Ein Huhn kostet vierzig. Es legt dir das in einem Monat wieder herein.")
			else:
				G.add_gold(-40)
				G.p["flags"]["huhn"] = int(G.p["flags"].get("huhn", 0)) + 1
				menu("Gute Legehenne. Der Stall steht neben deinem Garten, morgens liegt ein Ei drin.")])
	if id == "tomas" and not G.p["flags"].get("hund", false):
		o.append(["Den Hofhund Bello mitnehmen (120 Gold)", func():
			if G.p["gold"] < 120:
				menu("Bello ist ein guter Hund. Für weniger gebe ich ihn nicht her.")
			else:
				G.add_gold(-120)
				G.p["flags"]["hund"] = true
				G.world.spawn_dog()
				menu("Er hört auf seinen Namen und beißt alles, was klappert. Sei gut zu ihm.")])
	o.append(["Was machst du gerade?", func(): menu(_activity_text())])
	o.append(["Plaudern", func(): _chat()])
	if Texte.BIO.has(id):
		o.append(["Erzähl mir von dir", func():
			if not nd.get("bio", false):
				nd["bio"] = true
				nd["aff"] = min(100.0, nd["aff"] + 3.0)
			menu(Texte.BIO[id])])
	o.append(["Geschenk machen", func(): _gift_menu()])
	if d["romance"] and G.p["partner"] == id and nd.get("eifersucht", false):
		o.append(["Es tut mir leid. Es bedeutete nichts.", func():
			nd["eifersucht"] = false
			nd["aff"] = min(100.0, nd["aff"] + 4.0)
			menu("Sag das nie wieder so leicht dahin. Aber gut. Ich glaube dir. Dieses eine Mal.")])
	if d["romance"] and nd["love"] and nd.get("married_day", 0) > 0 and G.p["day"] - nd["married_day"] >= 5 and not G.p["flags"].has("kind_day"):
		o.append(["Über die Zukunft sprechen", func():
			G.p["flags"]["kind_day"] = G.p["day"] + 6
			menu("Ein Kind? In diesen Zeiten? ... Ja. Gerade in diesen Zeiten. Jemand muss die Glut ja nach uns hüten.")])
	if d["romance"]:
		if nd["aff"] >= 40.0:
			o.append(["Flirten", func(): _flirt()])
		if nd["aff"] >= 60.0:
			o.append(["Zum Abend am Brunnen einladen", func(): _date()])
		if nd["aff"] >= 70.0:
			o.append(["Küssen", func(): _kiss()])
		if nd["aff"] >= 85.0 and not nd["love"] and G.p["partner"] == "":
			o.append(["Antrag machen (Verlobungsring)", func(): _propose()])
		if nd["love"]:
			if following:
				o.append(["Geh ruhig nach Hause", func():
					set_following(false)
					menu("Pass auf dich auf. Ich warte zu Hause.")])
			else:
				o.append(["Begleite mich auf meinem Weg", func():
					if G.p["flags"].get("begleitet", "") != "":
						menu("Du hast schon Begleitung.")
					else:
						set_following(true)
						menu("Ich dachte schon, du fragst nie. Ich bleibe an deiner Seite.")])
			o.append(["Die Nacht gemeinsam verbringen", func(): _night()])
			if nd.get("meal_day", 0) != G.p["day"]:
				o.append(["Hast du etwas zu essen für mich?", func():
					nd["meal_day"] = G.p["day"]
					G.add_item("eintopf")
					menu("Natürlich, ich habe für uns gekocht. Hier, noch warm.")])
	o.append(["Auf Wiedersehen", Callable()])
	G.ui.dialog("%s  ·  %s  ·  %s (%d)" % [d["name"], d["job"], aff_name(nd["aff"]), int(nd["aff"])], text, o)
	# jede Figur hat ihre eigene Tonlage (aus dem Namen abgeleitet)
	Audio.babble(id in ["hilda", "mira", "elara", "lina", "bertha", "selma", "walda", "greta", "nele", "sigrun", "ylva", "rosalind", "hedda"], 0.88 + (hash(id) % 25) / 100.0, text.length())


func _offer(q: String) -> void:
	G.ui.dialog(d["name"], G.QUESTS[q]["intro"], [
		["Ich übernehme das.", func():
			G.start_quest(q)
			menu("Danke. Ich zähle auf dich.")],
		["Jetzt nicht.", func(): menu("Dann vielleicht später.")]])


func _activity_text() -> String:
	var t: String = ACT_TEXT.get(act, "Nichts Besonderes.")
	if act == "plaudern":
		t = t % (mate.d["name"] if is_instance_valid(mate) else "jemandem")
	var extra = ""
	if needs["energy"] < 30.0: extra += " Ich bin ziemlich müde."
	if needs["hunger"] < 30.0: extra += " Und mein Magen knurrt."
	var bf = best_friend()
	if bf != "" and friends[bf] > 8.0:
		extra += " Mit %s verstehe ich mich übrigens gut." % PEOPLE[bf]["name"]
	return t + extra


func _chat() -> void:
	var nd = G.npc_data(id)
	if nd.get("chat_day", 0) != G.p["day"]:
		nd["chat_day"] = G.p["day"]
		nd["aff"] = min(100.0, nd["aff"] + 3.0)
	needs["social"] = min(100.0, needs["social"] + 15.0)
	menu(d["chat"].pick_random())


func _gift_menu() -> void:
	var nd = G.npc_data(id)
	if nd["gift_day"] == G.p["day"]:
		menu("Du hast mir heute schon etwas geschenkt. Das reicht für einen Tag.")
		return
	var o = []
	for i in G.p["inv"]:
		var it: Dictionary = G.ITEMS[i]
		if it["type"] in ["gift", "food", "mat"] and i != "knochen":
			o.append(["%s (%d)" % [it["name"], G.count(i)], func(): _gift(i)])
	o.append(["Doch nichts", func(): menu("Na gut.")])
	G.ui.dialog(d["name"], "Ein Geschenk? Für mich?", o)


func _gift(i: String) -> void:
	var nd = G.npc_data(id)
	G.add_item(i, -1)
	nd["gift_day"] = G.p["day"]
	if i in d["likes"]:
		nd["aff"] = min(100.0, nd["aff"] + 12.0)
		play("Cheer", 1.0, true)
		menu("%s! Genau das mag ich. Danke dir." % G.ITEMS[i]["name"])
	else:
		nd["aff"] = min(100.0, nd["aff"] + 4.0)
		menu("Oh, %s. Das ist nett von dir." % G.ITEMS[i]["name"])


func _flirt() -> void:
	var nd = G.npc_data(id)
	if nd.get("flirt_day", 0) != G.p["day"]:
		nd["flirt_day"] = G.p["day"]
		nd["flirt_n"] = 0
	if nd.get("flirt_n", 0) >= 3:
		menu("Genug geflirtet für heute, sonst komme ich zu nichts mehr. Morgen wieder.")
		return
	var o = []
	o.append(["Charmant  (sicher, kleine Wirkung)", func(): _flirt_lines(1)])
	if nd["aff"] >= 60.0:
		o.append(["Verwegen  (mehr Wirkung, kann danebengehen)", func(): _flirt_lines(2)])
	if nd["aff"] >= 80.0 or nd["love"]:
		o.append(["Heiß  (große Wirkung, nur wenn ihr euch sehr nah seid)", func(): _flirt_lines(3)])
	o.append(["Lieber nicht", func(): menu("Na gut.")])
	G.ui.dialog(d["name"], "In welchem Ton willst du es versuchen? (%d von 3 Versuchen heute übrig)" % (3 - nd.get("flirt_n", 0)), o)


func _flirt_lines(level: int) -> void:
	var o = []
	for kind in ["witz", "poesie", "direkt"]:
		var line: String = Texte.FLIRT[level][kind].pick_random()
		o.append(["„%s“" % line, func(): _flirt_result(level, kind)])
	o.append(["Doch nichts sagen", func(): menu("Hm? Du wolltest etwas sagen?")])
	G.ui.dialog("%s · %s" % [d["name"], Texte.TON[level]], "Was sagst du?", o)


func _flirt_result(level: int, kind: String) -> void:
	var nd = G.npc_data(id)
	nd["flirt_n"] = nd.get("flirt_n", 0) + 1
	_jealousy()
	var taste: Dictionary = Texte.FLIRT_ANTWORT[id] if Texte.FLIRT_ANTWORT.has(id) else Texte.FLIRT_ANTWORT_2[id]
	# Chance: je vertrauter, desto besser; der passende Ton hilft, ein forscher Ton ist riskanter
	var chance = [0.0, 0.7, 0.5, 0.45][level] + nd["aff"] / 300.0 + (0.3 if taste["mag"] == kind else -0.05)
	if needs["energy"] < 25.0:
		chance -= 0.2
	if randf() < chance:
		nd["aff"] = min(100.0, nd["aff"] + [0.0, 4.0, 7.0, 10.0][level])
		needs["fun"] = min(100.0, needs["fun"] + 20.0)
		play("Cheering" if level == 1 else "Interact", 1.0, true)
		menu(taste[level].pick_random())
	else:
		nd["aff"] = max(0.0, nd["aff"] - [0.0, 1.0, 3.0, 5.0][level])
		menu(Texte.FLIRT_KORB[level].pick_random())


## Wer vergeben ist und trotzdem mit anderen anbandelt, riskiert, dass es sich herumspricht.
func _jealousy() -> void:
	var pid: String = G.p["partner"]
	if pid == "" or pid == id or randf() > 0.5:
		return
	var pd = G.npc_data(pid)
	pd["aff"] = max(0.0, pd["aff"] - 15.0)
	pd["eifersucht"] = true
	G.say("Bertha hat euch gesehen. Morgen weiß es das ganze Dorf, %s zuerst." % PEOPLE[pid]["name"])
	if pd["aff"] < 40.0:
		pd["love"] = false
		pd["eifersucht"] = false
		G.p["partner"] = ""
		if G.npcs.has(pid):
			G.npcs[pid].following = false
			G.npcs[pid].tag.modulate = Color(1.0, 0.9, 0.7)
		G.say("%s hat die Sachen gepackt und ist aus deinem Haus ausgezogen." % PEOPLE[pid]["name"])


func _kiss() -> void:
	var nd = G.npc_data(id)
	_jealousy()
	if nd.get("kiss_day", 0) == G.p["day"]:
		menu("Noch einen? Du bekommst nie genug. Heute Abend vielleicht.")
		return
	nd["kiss_day"] = G.p["day"]
	nd["aff"] = min(100.0, nd["aff"] + 5.0)
	G.world.fade(Texte.KUSS[id], func(): G.changed.emit())


func _date() -> void:
	var nd = G.npc_data(id)
	if nd["date_day"] == G.p["day"]:
		menu("Wir waren heute schon zusammen aus. Morgen wieder, ja?")
		return
	if needs["energy"] < 25.0:
		menu("Heute bin ich zu müde, mir fallen gleich die Augen zu. Frag mich morgen.")
		return
	var nm: String = d["name"]
	var o = [
		["Abend am Brunnen", func(): _outing("Ihr sitzt am Brunnen, teilt einen Krug Met und redet, bis die Sterne aufgehen.\n%s lehnt sich an deine Schulter." % nm, 10.0)],
		["Angeln am Teich", func(): _outing("Ihr sitzt am Steg, die Füße im Wasser. %s fängt mehr als du und lässt es dich den ganzen Abend wissen." % nm, 9.0, "fisch")],
		["Tanz im Wirtshaus", func(): _outing("Bruno schiebt die Tische zur Seite, jemand spielt Laute. %s tanzt, bis euch beiden die Luft ausgeht, und lacht dabei wie selten." % nm, 12.0)],
	]
	if G.p["flags"].get("glut", false):
		o.append(["Spaziergang zum Schrein im Dämmerwald", func(): _outing("Die Glutschale wirft warmes Licht zwischen die Bäume. %s nimmt deine Hand und sagt lange nichts. Es ist die gute Art von Stille." % nm, 14.0)])
	if G.count("festmahl") > 0:
		o.append(["Picknick auf der Wiese (1 Festmahl)", func():
			G.add_item("festmahl", -1)
			_outing("Ihr breitet eine Decke zwischen den Blumen aus. %s füttert dich mit Braten und nennt dich einen hoffnungslosen Fall. Liebevoll." % nm, 16.0)])
	o.append(["Doch nicht", func(): menu("Dann ein andermal.")])
	G.ui.dialog(d["name"], "Gern! Was unternehmen wir?", o)


func _outing(text: String, gain: float, gift := "") -> void:
	var nd = G.npc_data(id)
	nd["date_day"] = G.p["day"]
	nd["aff"] = min(100.0, nd["aff"] + gain)
	needs["fun"] = 100.0
	needs["social"] = 100.0
	G.world.fade(text, func():
		G.advance(2.0)
		if gift != "":
			G.add_item(gift, 2)
		G.changed.emit())


func _propose() -> void:
	var nd = G.npc_data(id)
	if not G.p["flags"].get("home", false):
		menu("Ich würde ja sagen. Aber wo sollen wir wohnen? Du hast noch kein eigenes Haus.")
		return
	if G.count("ring") <= 0:
		menu("Du meinst es ernst? Dann komm mit einem Ring wieder. Mira verkauft welche.")
		return
	G.add_item("ring", -1)
	nd["love"] = true
	nd["aff"] = 100.0
	G.p["partner"] = id
	tag.modulate = Color(1.0, 0.6, 0.75)
	play("Cheer", 1.0, true)
	G.p["flags"]["hochzeit_day"] = G.p["day"] + 1
	G.world.fade("%s sagt Ja.\nVon heute an wohnt ihr gemeinsam in deinem Haus.\n\nMorgen Abend richtet Aschfurt euch die Hochzeit aus: ab 17 Uhr am Dorffeuer." % d["name"], func(): G.changed.emit())


func _night() -> void:
	if not G.p["flags"].get("home", false):
		menu("Wir haben doch gar kein Zuhause.")
		return
	var h = G.hour()
	if h > 5.0 and h < 19.0:
		menu("Mitten am Tag? Heute Abend, versprochen.")
		return
	G.p["flags"]["geborgen_day"] = G.p["day"] + (1 if h >= 19.0 else 0)
	needs["energy"] = 100.0
	G.world.sleep_scene("Ihr geht Hand in Hand nach Hause. Die Tür fällt ins Schloss, die Kerze erlischt.\n\nAm Morgen wachst du ausgeruht und geborgen auf. (+10 % Erfahrung heute)", 1.2)
