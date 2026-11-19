extends Node
## Globaler Spielzustand: Daten, Werte des Helden, Zeit, Aufgaben, Speichern.

signal changed
signal toast(text)
signal quest_changed
signal level_up
signal new_day

const SAVE := "user://spielstand.json"
const OPT_FILE := "user://einstellungen.json"
const KEY_LABELS := {"vor": "Vorwärts", "zurueck": "Rückwärts", "links": "Links", "rechts": "Rechts", "sprint": "Sprinten", "ausweichen": "Ausweichen",
	"benutzen": "Benutzen", "essen": "Essen", "trank": "Heiltrank", "skill1": "Fähigkeit 1", "skill2": "Fähigkeit 2", "skill3": "Fähigkeit 3",
	"waffe": "Waffe wechseln", "fackel": "Fackel", "inventar": "Inventar", "charakter": "Charakter", "aufgaben": "Aufgaben", "karte": "Karte",
	"hilfe": "Hilfe", "kamera_l": "Kamera links", "kamera_r": "Kamera rechts", "schnellspeichern": "Schnellspeichern"}
var opt := {"pad": false, "fps": 2, "quality": 2, "fullscreen": false, "size": 1, "vsync": true, "music": 0.7, "sfx": 0.9, "aim": true, "keys": {}}
const FPS_CAPS := [30, 45, 60, 0]
const SIZES := [[1280, 720], [1600, 900], [1920, 1080], [2560, 1440], [3840, 2160]]
var pad_events := []         # Gamepad-Belegung, wird nur eingehängt, wenn das Gamepad eingeschaltet ist
var slot := 1
var autosave_t := 0.0
const HOUR_SECONDS := 50.0   # reale Sekunden je Spielstunde

const CLASSES := {
	"ritter": {"start": ["schwert", "bogen"], "prof": ["schwert", "zweihaender", "speer", "hammer"], "name": "Ritter", "model": "Knight", "attr": {"str": 7, "ges": 4, "int": 2, "vit": 7}, "main": "str",
		"weapon": "Schwert", "guard": "Schild", "gear": {"r": "sword_1handed", "l": "shield_round"}, "tiers": {"r": ["gear/sword_1handed", "waffen/sword_A", "waffen/sword_B", "waffen/sword_C"]}, "idle": "Idle",
		"atk": ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal"],
		"range": 3.0, "ranged": false, "block": 0.85, "skills": ["wirbel", "schildstoss", "schrei"],
		"desc": "Standhaft mit Schwert und Schild. Blockt fast jeden Schlag."},
	"barbar": {"start": ["axt", "bogen"], "prof": ["axt", "zweihaender", "hammer", "speer"], "name": "Barbar", "model": "Barbarian", "attr": {"str": 9, "ges": 4, "int": 1, "vit": 6}, "main": "str",
		"weapon": "Streitaxt", "guard": "Rüstung", "gear": {"r": "axe_2handed"}, "tiers": {"r": ["gear/axe_2handed", "waffen/axe_A", "waffen/axe_B", "waffen/axe_C"]}, "idle": "2H_Melee_Idle",
		"atk": ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice"],
		"range": 3.6, "ranged": false, "block": 0.5, "skills": ["sturm", "spalter", "raserei"],
		"desc": "Wuchtige Hiebe mit der Zweihandaxt. Langsam, aber verheerend."},
	"magier": {"start": ["stab", "dolche"], "prof": ["stab", "dolche"], "name": "Magierin", "model": "Mage", "attr": {"str": 2, "ges": 4, "int": 9, "vit": 5}, "main": "int",
		"weapon": "Stab", "guard": "Schutzzauber", "gear": {"r": "staff"}, "tiers": {"r": ["gear/staff", "waffen/staff_A", "waffen/staff_B"]}, "idle": "Idle",
		"atk": ["Spellcast_Shoot"],
		"range": 22.0, "ranged": true, "block": 0.4, "skills": ["nova", "blitz", "heilung"],
		"desc": "Greift aus der Ferne mit Feuer an und heilt sich selbst."},
	"schurke": {"start": ["dolche", "bogen"], "prof": ["dolche", "bogen", "schwert"], "name": "Schurkin", "model": "Rogue_Hooded", "attr": {"str": 4, "ges": 9, "int": 3, "vit": 4}, "main": "ges",
		"weapon": "Dolche", "guard": "Lederwams", "gear": {"r": "dagger", "l": "dagger"}, "tiers": {"r": ["gear/dagger", "waffen/dagger_A", "waffen/dagger_B"], "l": ["gear/dagger", "waffen/dagger_A", "waffen/dagger_B"]}, "idle": "Idle",
		"atk": ["Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Stab", "Dualwield_Melee_Attack_Chop"],
		"range": 2.6, "ranged": false, "block": 0.4, "skills": ["faecher", "schritt", "rauch"],
		"desc": "Schnell, tödlich, kritische Treffer. Hält wenig aus."},
	"waldlaeufer": {"start": ["bogen", "dolche"], "prof": ["bogen", "dolche", "speer"], "name": "Waldläufer", "model": "Ranger", "attr": {"str": 3, "ges": 9, "int": 3, "vit": 5}, "main": "ges",
		"weapon": "Bogen", "guard": "Lederrüstung", "gear": {"l": "bow_withString"}, "tiers": {"l": ["gear/bow_withString", "waffen/bow_A_withString", "waffen/bow_B_withString"]}, "idle": "Ranged_Bow_Idle",
		"atk": ["Ranged_Bow_Release"],
		"range": 24.0, "ranged": true, "block": 0.4, "skills": ["salve", "fussangel", "adlerauge"],
		"desc": "Trifft mit dem Bogen aus großer Entfernung. Hält Gegner auf Abstand."},
}

## Waffen sind eigene Gegenstände: Man besitzt mehrere, trägt zwei in den Slots und wechselt mit Q.
const WEAPONS := {
	"schwert": {"name": "Schwert", "attr": "str", "base": 9.0, "range": 3.0, "ranged": false, "idle": "Idle", "speed": 1.5, "shield": true, "price": 90,
		"atk": ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal"],
		"tiers": {"r": ["gear/sword_1handed", "waffen/sword_A", "waffen/sword_B", "waffen/sword_C"]}, "desc": "Ausgewogen, mit Schild in der anderen Hand."},
	"zweihaender": {"name": "Zweihänder", "attr": "str", "base": 13.0, "range": 3.8, "ranged": false, "idle": "2H_Melee_Idle", "speed": 1.2, "price": 180,
		"atk": ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice"],
		"tiers": {"r": ["gear/sword_2handed", "gear/sword_2handed_color", "waffen/sword_D", "waffen/sword_E"]}, "desc": "Langsam, große Reichweite, viel Schaden."},
	"axt": {"name": "Streitaxt", "attr": "str", "base": 12.5, "range": 3.6, "ranged": false, "idle": "2H_Melee_Idle", "speed": 1.25, "price": 160,
		"atk": ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice"],
		"tiers": {"r": ["gear/axe_2handed", "waffen/axe_A", "waffen/axe_B", "waffen/axe_C"]}, "desc": "Wuchtige Hiebe."},
	"hammer": {"name": "Kriegshammer", "attr": "str", "base": 14.0, "range": 3.4, "ranged": false, "idle": "2H_Melee_Idle", "speed": 1.1, "price": 220,
		"atk": ["2H_Melee_Attack_Chop"],
		"tiers": {"r": ["waffen/hammer_A", "waffen/hammer_B", "waffen/hammer_C"]}, "desc": "Am langsamsten, am härtesten."},
	"speer": {"name": "Speer", "attr": "str", "base": 10.5, "range": 4.8, "ranged": false, "idle": "2H_Melee_Idle", "speed": 1.45, "price": 150,
		"atk": ["2H_Melee_Attack_Stab"],
		"tiers": {"r": ["waffen/spear_A", "waffen/spear_A", "waffen/halberd"]}, "desc": "Hält Gegner auf Abstand."},
	"dolche": {"name": "Dolche", "attr": "ges", "base": 8.0, "range": 2.6, "ranged": false, "idle": "Idle", "speed": 1.8, "price": 120,
		"atk": ["Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Stab", "Dualwield_Melee_Attack_Chop"],
		"tiers": {"r": ["gear/dagger", "waffen/dagger_A", "waffen/dagger_B"], "l": ["gear/dagger", "waffen/dagger_A", "waffen/dagger_B"]}, "desc": "Sehr schnell, kurze Reichweite."},
	"bogen": {"name": "Bogen", "attr": "ges", "base": 9.0, "range": 24.0, "ranged": true, "idle": "Ranged_Bow_Idle", "speed": 1.5, "price": 130, "shot": "pfeil",
		"atk": ["Ranged_Bow_Release"],
		"tiers": {"l": ["gear/bow_withString", "waffen/bow_A_withString", "waffen/bow_B_withString"]}, "desc": "Trifft aus der Ferne."},
	"stab": {"name": "Zauberstab", "attr": "int", "base": 9.0, "range": 22.0, "ranged": true, "idle": "Idle", "speed": 1.5, "price": 150, "shot": "feuer",
		"atk": ["Spellcast_Shoot"],
		"tiers": {"r": ["gear/staff", "waffen/staff_A", "waffen/staff_B"]}, "desc": "Feuerbälle aus der Ferne."},
}

const SKILLS := {
	"wirbel": {"name": "Wirbelhieb", "type": "aoe", "cost": 12, "cd": 6.0, "mult": 1.6, "radius": 4.5, "anim": "2H_Melee_Attack_Spin", "desc": "Trifft alle Gegner um dich herum."},
	"schildstoss": {"name": "Schildstoß", "type": "aoe", "cost": 10, "cd": 8.0, "mult": 1.0, "radius": 4.0, "stun": 2.5, "anim": "Block_Attack", "desc": "Betäubt nahe Gegner."},
	"schrei": {"name": "Kampfschrei", "type": "buff", "cost": 15, "cd": 25.0, "dmg": 0.3, "dur": 12.0, "anim": "Cheer", "desc": "Mehr Schaden für kurze Zeit."},
	"sturm": {"name": "Wirbelsturm", "type": "aoe", "cost": 14, "cd": 7.0, "mult": 2.0, "radius": 5.0, "anim": "2H_Melee_Attack_Spin", "desc": "Die Axt kreist, alles ringsum wird getroffen."},
	"spalter": {"name": "Erdspalter", "type": "aoe", "cost": 18, "cd": 10.0, "mult": 2.6, "radius": 4.0, "stun": 1.0, "anim": "2H_Melee_Attack_Chop", "desc": "Gewaltiger Hieb, der Gegner kurz betäubt."},
	"raserei": {"name": "Raserei", "type": "buff", "cost": 15, "cd": 30.0, "dmg": 0.5, "dur": 10.0, "anim": "Cheer", "desc": "Deutlich mehr Schaden für kurze Zeit."},
	"nova": {"name": "Frostnova", "type": "aoe", "cost": 18, "cd": 9.0, "mult": 1.4, "radius": 6.5, "stun": 3.0, "anim": "Spellcast_Raise", "desc": "Friert Gegner um dich herum ein."},
	"blitz": {"name": "Kettenblitz", "type": "chain", "cost": 20, "cd": 7.0, "mult": 2.0, "n": 3, "radius": 16.0, "anim": "Spellcast_Long", "desc": "Springt auf bis zu drei Gegner über."},
	"heilung": {"name": "Heilung", "type": "heal", "cost": 25, "cd": 15.0, "pct": 0.35, "anim": "Spellcast_Raise", "desc": "Stellt Leben wieder her."},
	"faecher": {"name": "Dolchfächer", "type": "aoe", "cost": 12, "cd": 6.0, "mult": 1.5, "radius": 5.0, "anim": "Dualwield_Melee_Attack_Slice", "desc": "Klingen in alle Richtungen."},
	"schritt": {"name": "Schattenschritt", "type": "dash", "cost": 15, "cd": 8.0, "mult": 2.8, "radius": 14.0, "anim": "Dualwield_Melee_Attack_Stab", "desc": "Springt zum nächsten Gegner und sticht zu."},
	"salve": {"name": "Pfeilsalve", "type": "chain", "cost": 14, "cd": 6.0, "mult": 1.5, "n": 4, "radius": 20.0, "anim": "Ranged_Bow_Release_Up", "desc": "Trifft bis zu vier Gegner auf einmal."},
	"fussangel": {"name": "Fußangel", "type": "aoe", "cost": 14, "cd": 12.0, "mult": 0.6, "radius": 6.0, "stun": 3.5, "anim": "Throw", "desc": "Hält Gegner in der Nähe fest."},
	"adlerauge": {"name": "Adlerauge", "type": "buff", "cost": 15, "cd": 25.0, "dmg": 0.4, "dur": 12.0, "anim": "Cheer", "desc": "Mehr Schaden für kurze Zeit."},
	"rauch": {"name": "Rauchbombe", "type": "aoe", "cost": 15, "cd": 14.0, "mult": 0.5, "radius": 6.0, "stun": 4.0, "anim": "Throw", "desc": "Betäubt Gegner in der Nähe für längere Zeit."},
}

const PASSIVES := {
	"zaeh": {"name": "Zähigkeit", "desc": "+8 % Leben je Rang"},
	"kraft": {"name": "Waffenkunst", "desc": "+6 % Schaden je Rang"},
	"flink": {"name": "Leichtfüßig", "desc": "+4 % Tempo, +10 % Ausdauer je Rang"},
	"geist": {"name": "Wacher Geist", "desc": "+10 % Mana und Manaregeneration je Rang"},
	"gourmet": {"name": "Genügsam", "desc": "Hunger und Müdigkeit steigen 10 % langsamer je Rang"},
	"gelehrig": {"name": "Gelehrig", "desc": "+6 % Erfahrung je Rang"},
}
const MAX_RANK := 5
## Berufe steigen durch Ausüben: Kochen, Angeln, Holzfällen, Schmieden.
const JOBS := {"alchemie": ["Alchemie", "Chance auf einen zweiten Trank"], "kochen": ["Kochen", "Chance auf eine doppelte Portion"], "angeln": ["Angeln", "bessere Fangchance, mehr Fische"],
	"holz": ["Holzfällen", "mehr Holz je Stunde"], "schmieden": ["Schmieden", "Verbesserungen werden billiger, mehr Pfeile je Barren"]}

## Rüstungsteile in drei Güten. Der Schutz der getragenen Teile addiert sich.
const ARMOR := {
	"helm": {"name": "Helm", "tiers": [["Lederkappe", 0.03, 60], ["Eisenhelm", 0.06, 180], ["Glutstahlhelm", 0.10, 420]]},
	"brust": {"name": "Brust", "tiers": [["Lederwams", 0.05, 90], ["Kettenhemd", 0.10, 260], ["Glutstahlharnisch", 0.16, 600]]},
	"stiefel": {"name": "Stiefel", "tiers": [["Lederstiefel", 0.02, 50], ["Eisenstiefel", 0.04, 150], ["Glutstahlstiefel", 0.07, 360]]},
}
const ARMOR_COLOR := [Color(0, 0, 0, 0), Color(0.42, 0.27, 0.13, 0.6), Color(0.62, 0.65, 0.72, 0.65), Color(0.95, 0.42, 0.14, 0.55)]

const ITEMS := {
	"brot": {"name": "Brot", "type": "food", "price": 6, "hunger": 22, "heal": 5, "model": "food_ingredient_bun"},
	"kaese": {"name": "Käse", "type": "food", "price": 9, "hunger": 20, "heal": 6, "model": "food_ingredient_cheese"},
	"karotte": {"name": "Karotte", "type": "food", "price": 3, "hunger": 9, "heal": 2, "model": "food_ingredient_carrot"},
	"kartoffel": {"name": "Kartoffel", "type": "food", "price": 3, "hunger": 8, "heal": 2, "model": "food_ingredient_potato"},
	"zwiebel": {"name": "Zwiebel", "type": "food", "price": 3, "hunger": 6, "heal": 1, "model": "food_ingredient_onion"},
	"tomate": {"name": "Tomate", "type": "food", "price": 4, "hunger": 9, "heal": 3, "model": "food_ingredient_tomato"},
	"salat": {"name": "Wildsalat", "type": "food", "price": 3, "hunger": 7, "heal": 3, "model": "food_ingredient_lettuce"},
	"fleisch": {"name": "Rohes Fleisch", "type": "food", "price": 10, "hunger": 10, "heal": -5, "model": "food_ingredient_steak"},
	"braten": {"name": "Braten", "type": "food", "price": 24, "hunger": 45, "heal": 25, "model": "food_ingredient_ham_cooked"},
	"eintopf": {"name": "Eintopf", "type": "food", "price": 20, "hunger": 55, "heal": 20, "model": "food_stew"},
	"festmahl": {"name": "Festmahl", "type": "food", "price": 60, "hunger": 100, "heal": 60, "model": "food_dinner"},
	"fisch": {"name": "Roher Fisch", "type": "food", "price": 8, "hunger": 10, "heal": -3},
	"bratfisch": {"name": "Bratfisch", "type": "food", "price": 20, "hunger": 40, "heal": 18},
	"heiltrank": {"name": "Heiltrank", "type": "potion", "price": 30, "heal": 80},
	"manatrank": {"name": "Manatrank", "type": "potion", "price": 30, "mana": 60},
	"staerketrank": {"name": "Stärketrank", "type": "potion", "price": 60, "buff": "kraft"},
	"gift": {"name": "Waffengift", "type": "potion", "price": 70, "buff": "gift"},
	"kraut": {"name": "Heilkraut", "type": "mat", "price": 5},
	"schaufel": {"name": "Schaufel", "type": "geraet", "price": 25},
	"schatzkarte": {"name": "Schatzkarte", "type": "karte", "price": 80},
	"fackel": {"name": "Fackel", "type": "tool", "price": 6},
	"holz": {"name": "Holz", "type": "mat", "price": 4},
	"ei": {"name": "Ei", "type": "food", "price": 4, "hunger": 10, "heal": 2},
	"ruehrei": {"name": "Rührei", "type": "food", "price": 12, "hunger": 34, "heal": 12},
	"saat_karotte": {"name": "Karottensaat", "type": "saat", "price": 2, "crop": "karotte"},
	"saat_kartoffel": {"name": "Saatkartoffeln", "type": "saat", "price": 2, "crop": "kartoffel"},
	"saat_tomate": {"name": "Tomatensaat", "type": "saat", "price": 3, "crop": "tomate"},
	"saat_zwiebel": {"name": "Steckzwiebeln", "type": "saat", "price": 2, "crop": "zwiebel"},
	"pfeil": {"name": "Pfeil", "type": "mat", "price": 1},
	"erz": {"name": "Eisenerz", "type": "mat", "price": 12},
	"knochen": {"name": "Knochenmehl", "type": "mat", "price": 4},
	"splitter": {"name": "Glutsplitter", "type": "mat", "price": 150},
	"blume": {"name": "Glutblume", "type": "gift", "price": 8},
	"kette": {"name": "Silberkette", "type": "gift", "price": 90},
	"buch": {"name": "Altes Buch", "type": "gift", "price": 45},
	"met": {"name": "Krug Met", "type": "gift", "price": 15},
	"ring": {"name": "Verlobungsring", "type": "quest", "price": 300},
	"lieferung": {"name": "Verlorene Lieferung", "type": "quest", "price": 0},
}

const RECIPES := {
	"braten": {"fleisch": 1},
	"bratfisch": {"fisch": 1},
	"ruehrei": {"ei": 2},
	"eintopf": {"karotte": 1, "kartoffel": 1, "zwiebel": 1},
	"festmahl": {"braten": 1, "kaese": 1, "brot": 1},
}

## Alchemie bei Elara: Zutaten je Trank
const ALCHEMIE := {
	"heiltrank": {"kraut": 2},
	"manatrank": {"kraut": 1, "blume": 1},
	"staerketrank": {"kraut": 1, "knochen": 2, "fleisch": 1},
	"gift": {"knochen": 3, "kraut": 1, "fisch": 1},
}
## Handel: Preisfaktor je Ort (was dort reichlich ist, ist billig; was fehlt, teuer)
const ORTE := {"aschfurt": "Aschfurt", "weidenau": "Weidenau", "salzhafen": "Salzhafen", "hochwacht": "Hochwacht", "dornfeld": "Dornfeld", "asche": "Aschenlande"}
const PREISE := {
	"aschfurt": {"erz": 0.9, "blume": 0.7, "kraut": 0.8},
	"weidenau": {"fisch": 0.5, "bratfisch": 0.6, "erz": 1.3, "kaese": 1.3, "braten": 1.3},
	"salzhafen": {"fisch": 0.4, "bratfisch": 0.5, "kette": 0.7, "erz": 1.5, "holz": 1.6, "karotte": 1.5, "kartoffel": 1.5, "blume": 1.8, "kaese": 1.4},
	"hochwacht": {"erz": 0.5, "splitter": 0.8, "fisch": 2.0, "bratfisch": 1.8, "holz": 0.6, "brot": 1.5, "karotte": 1.8, "tomate": 2.0, "blume": 2.0, "fackel": 1.3},
	"dornfeld": {"brot": 0.6, "karotte": 0.5, "kartoffel": 0.5, "zwiebel": 0.5, "tomate": 0.6, "kaese": 0.7, "festmahl": 0.8, "blume": 0.6, "erz": 1.6, "fisch": 1.7, "kette": 1.3, "holz": 1.4},
	"asche": {},
}
## Besondere Waren, die ein Ort erst ab Ruf 30 anbietet
const SONDERWAREN := {"aschfurt": ["splitter"], "weidenau": ["kette"], "salzhafen": ["schatzkarte", "ring"], "hochwacht": ["splitter", "staerketrank"], "dornfeld": ["festmahl", "gift"]}
const SCHWER := ["leicht", "normal", "schwer"]

const RUNES := {
	"feuer": {"name": "Feuerrune", "desc": "+20 % Schaden", "color": Color(1.0, 0.45, 0.1)},
	"frost": {"name": "Frostrune", "desc": "20 % Chance, Gegner einzufrieren", "color": Color(0.4, 0.8, 1.0)},
	"blitz": {"name": "Blitzrune", "desc": "+20 % kritische Treffer", "color": Color(1.0, 0.95, 0.4)},
}

const QUESTS := {
	"m1": {"name": "Die erloschene Glut", "main": true, "giver": "gernot",
		"intro": "Die Glutschale im Dämmerwald ist erloschen, und seither kriechen Skelette aus dem Boden. Du bist der letzte Anwärter der Glutwacht. Geh nach Nordwesten zum Schrein, vertreibe die Knochen und entzünde die Schale neu.",
		"outro": "Die Flamme brennt wieder! Aschfurt steht in deiner Schuld. Nimm diesen Lohn aus der Dorfkasse, du hast ihn dir verdient.",
		"stages": [
			{"t": "reach", "key": "schrein", "text": "Erreiche den Schrein im Dämmerwald (Nordwesten)"},
			{"t": "kill", "key": "schrein", "n": 4, "text": "Besiege die Skelette am Schrein"},
			{"t": "use", "key": "glutschale", "text": "Entzünde die Glutschale"},
			{"t": "talk", "key": "gernot", "text": "Kehre zu Hauptmann Gernot zurück"}],
		"reward": {"xp": 220, "gold": 120, "items": {"heiltrank": 2}}, "next": "m2"},
	"m2": {"name": "Stahl und Glut", "main": true, "giver": "hilda", "req": "m1",
		"intro": "Mit dem stumpfen Ding willst du gegen den Aschenritter ziehen? Bring mir drei Brocken Eisenerz von der alten Mine im Osten, dann zeige ich dir, was eine Glutschmiede kann.",
		"outro": "Gutes Erz. Ab jetzt verbessere ich dir Waffe und Schutz, so oft du Erz und Gold bringst.",
		"stages": [
			{"t": "bring", "key": "hilda", "item": "erz", "n": 3, "text": "Bringe Hilda 3 Eisenerz (Mine im Osten)"}],
		"reward": {"xp": 180, "gold": 40, "flag": "smith_free"}, "next": "m3"},
	"m3": {"name": "Der Aschenritter", "main": true, "giver": "gernot", "req": "m2",
		"intro": "In den Ruinen im Norden wacht der Aschenritter über einen Glutsplitter. Er war einst einer von uns. Erlöse ihn und bring den Splitter zurück.",
		"outro": "Der erste Splitter! Zwei weitere liegen in den Aschenlanden jenseits der Berge. Ruh dich aus, Hüter. Die Reise geht weiter. (Ende von Akt I)",
		"stages": [
			{"t": "reach", "key": "ruinen", "text": "Erreiche die Ruinen im Norden"},
			{"t": "kill", "key": "boss", "n": 1, "text": "Besiege den Aschenritter"},
			{"t": "talk", "key": "gernot", "text": "Bringe den Glutsplitter zu Gernot"}],
		"reward": {"xp": 600, "gold": 250, "flag": "akt1"}},
	"m4": {"name": "Über den Pass", "main": true, "giver": "gernot", "req": "m3",
		"intro": "Der Splitter des Aschenritters ist nur der erste. Zwei weitere liegen in den Aschenlanden, hinter dem Bergpass im äußersten Norden. Dort steht das Aschentor. Kein Hüter ist je von dort zurückgekehrt. Du wirst der erste sein. Nimm Fackeln mit, Tränke, und jemanden, der dir den Rücken freihält.",
		"outro": "Du stehst in den Aschenlanden. Der Himmel ist rot, der Boden grau, und irgendwo schlägt etwas wie ein Herz.",
		"stages": [{"t": "reach", "key": "pass", "text": "Erreiche den Bergpass im äußersten Norden"},
			{"t": "use", "key": "aschentor", "text": "Durchschreite das Aschentor"}],
		"reward": {"xp": 400, "gold": 100}, "auto_next": "m5"},
	"m5": {"name": "Zwei Splitter in der Asche", "main": true, "giver": "niemand",
		"intro": "", "outro": "Beide Horte sind entschieden. Im Norden der Aschenlande öffnet sich der Weg zum Aschenthron.",
		"stages": [{"t": "kill", "key": "hort_w", "n": 1, "text": "Besiege den Wächter des Westhorts (Aschenlande, Westen)"},
			{"t": "use", "key": "hort_w", "text": "Entscheide über den Glutsplitter des Westens"},
			{"t": "kill", "key": "hort_o", "n": 1, "text": "Besiege den Wächter des Osthorts (Aschenlande, Osten)"},
			{"t": "use", "key": "hort_o", "text": "Sprich mit dem Geist der letzten Hüterin"}],
		"reward": {"xp": 1200, "gold": 400}, "auto_next": "m6"},
	"m6": {"name": "Der Aschenthron", "main": true, "giver": "niemand",
		"intro": "", "outro": "Es ist vollbracht. Was du gewählt hast, wird das Land lange tragen.",
		"stages": [{"t": "kill", "key": "thron_boss", "n": 1, "text": "Besiege Alderan, den Aschenkönig (Aschenthron, Norden der Aschenlande)"},
			{"t": "use", "key": "entscheidung", "text": "Tritt vor die erste Glut und entscheide"}],
		"reward": {"xp": 2000, "gold": 600, "flag": "akt3"}},
	"s1": {"name": "Ungebetene Gäste", "giver": "tomas",
		"intro": "Auf meinem Acker hinter der Mühle wühlen Knochenmänner die Rüben um. Ich bin Bauer, kein Krieger. Kannst du die verscheuchen?",
		"outro": "Endlich Ruhe auf dem Feld. Hier, frisch aus der Erde, und ein paar Münzen.",
		"stages": [{"t": "kill", "key": "acker", "n": 3, "text": "Besiege 3 Skelette auf dem Acker (Südosten)"},
			{"t": "talk", "key": "tomas", "text": "Sprich mit Bauer Tomas"}],
		"reward": {"xp": 90, "gold": 30, "items": {"karotte": 4, "kartoffel": 4}, "aff": 15}},
	"s2": {"name": "Glutblumen für Elara", "giver": "elara",
		"intro": "Im Dämmerwald wachsen Glutblumen, sie leuchten schwach im Dunkeln. Ich brauche vier davon für meine Forschung über die Flamme.",
		"outro": "Wunderschön. Nimm diese Tränke, ich habe sie selbst gebraut.",
		"stages": [{"t": "bring", "key": "elara", "item": "blume", "n": 4, "text": "Bringe Elara 4 Glutblumen (Dämmerwald)"}],
		"reward": {"xp": 110, "gold": 20, "items": {"heiltrank": 2, "manatrank": 2}, "aff": 15}},
	"s3": {"name": "Volle Töpfe", "giver": "bruno",
		"intro": "Mein Kessel ist leer und die Gäste murren. Bring mir drei Karotten und zwei Kartoffeln, die wachsen wild auf den Wiesen.",
		"outro": "Das gibt einen Eintopf! Drei Schüsseln gehen aufs Haus.",
		"stages": [{"t": "bring", "key": "bruno", "item": "karotte", "n": 3, "text": "Bringe Bruno 3 Karotten"},
			{"t": "bring", "key": "bruno", "item": "kartoffel", "n": 2, "text": "Bringe Bruno 2 Kartoffeln"}],
		"reward": {"xp": 70, "gold": 25, "items": {"eintopf": 3}, "aff": 15}},
	"s4": {"name": "Die verlorene Lieferung", "giver": "finn",
		"intro": "Mein Karren ist im Sumpf im Süden stecken geblieben, und die Kiste mit den Fellen liegt noch dort. Allein traue ich mich nicht zurück.",
		"outro": "Du hast sie wirklich geholt! Ich schulde dir was.",
		"stages": [{"t": "use", "key": "lieferung", "text": "Finde die Kiste im Sumpf (Süden)"},
			{"t": "bring", "key": "finn", "item": "lieferung", "n": 1, "text": "Bringe die Lieferung zu Finn"}],
		"reward": {"xp": 130, "gold": 60, "items": {"fleisch": 3}, "aff": 20}},
	"s5": {"name": "Ein Geschenk für die Händlerin", "giver": "mira",
		"intro": "Mir fehlt Knochenmehl für meine Salben. Die Skelette lassen es fallen. Fünf Beutel würden reichen.",
		"outro": "Perfekt. Such dir etwas aus meinem Vorrat aus, nun ja, ich habe schon gewählt.",
		"stages": [{"t": "bring", "key": "mira", "item": "knochen", "n": 5, "text": "Bringe Mira 5 Knochenmehl"}],
		"reward": {"xp": 90, "gold": 45, "items": {"festmahl": 1}, "aff": 15}},
	"s6": {"name": "Klappern am Ostufer", "giver": "ivo",
		"intro": "Am Ostufer des Sees treiben sich Knochenmänner herum. Sie zerreißen meine Netze und vergraulen die Fische. Vier sind es, glaube ich.",
		"outro": "Jetzt hört man nachts wieder nur den See. Nimm das, Hüter.",
		"stages": [{"t": "kill", "key": "ufer", "n": 4, "text": "Besiege 4 Skelette am Ostufer des Sees"},
			{"t": "talk", "key": "ivo", "text": "Sprich mit Fischer Ivo in Weidenau"}],
		"reward": {"xp": 260, "gold": 110, "items": {"bratfisch": 3}, "aff": 15}},
	"s7": {"name": "Ein Festessen für Weidenau", "giver": "walda",
		"intro": "Seit die Straße unsicher ist, kommt kein Händler mehr durch. Bring mir drei Käse und zwei Braten aus Aschfurt, dann koche ich für das ganze Dorf.",
		"outro": "Heute Abend wird gegessen wie früher! Du schläfst bei mir, solange du willst, das Bett geht aufs Haus. Na ja, heute.",
		"stages": [{"t": "bring", "key": "walda", "item": "kaese", "n": 3, "text": "Bringe Walda 3 Käse"},
			{"t": "bring", "key": "walda", "item": "braten", "n": 2, "text": "Bringe Walda 2 Braten"}],
		"reward": {"xp": 200, "gold": 90, "items": {"festmahl": 2}, "aff": 15}},
	"s8": {"name": "Die Ruhe der Toten", "giver": "elara", "req": "m1",
		"intro": "Auf dem alten Friedhof im Westen liegen Hüter der Glutwacht begraben. Wenn selbst sie aufstehen, ist die Asche stärker, als ich dachte. Schick sie zurück in die Erde. Sechs, wenn du es schaffst.",
		"outro": "Danke. Ich habe ihre Namen aufgeschrieben, damit wenigstens das Papier sie behält.",
		"stages": [{"t": "kill", "key": "friedhof", "n": 6, "text": "Besiege 6 Skelette auf dem alten Friedhof (Westen)"},
			{"t": "talk", "key": "elara", "text": "Kehre zu Elara zurück"}],
		"reward": {"xp": 420, "gold": 160, "items": {"splitter": 1, "manatrank": 2}, "aff": 20}},
	"s9": {"name": "Der verlassene Wachturm", "giver": "gernot", "req": "m2",
		"intro": "Im Nordosten steht unser alter Wachturm. Von dort sah man jede Schale im Land brennen. Jetzt hausen Knochen darin. Räum ihn frei, damit wir wieder Ausschau halten können.",
		"outro": "Der Turm gehört wieder der Glutwacht. Das hätte den Alten gefallen.",
		"stages": [{"t": "kill", "key": "turm", "n": 5, "text": "Besiege 5 Skelette am Wachturm (Nordosten)"},
			{"t": "talk", "key": "gernot", "text": "Melde dich bei Hauptmann Gernot"}],
		"reward": {"xp": 520, "gold": 220, "items": {"heiltrank": 3}}},
	"s10": {"name": "Der Knochenhauer", "giver": "jorik", "req": "m2",
		"intro": "In der alten Mine, tief unten, schlägt etwas im Takt gegen den Fels. Das ist mein alter Vorarbeiter, oder was die Asche von ihm übrig ließ. Geh hinein und beende seine Schicht. Nimm eine Fackel mit, und achte auf den Hebel am Stollentor.",
		"outro": "Dann ist die Mine wieder frei. Zwölf Jahre habe ich darauf gewartet, das zu hören.",
		"stages": [{"t": "kill", "key": "mine_boss", "n": 1, "text": "Besiege den Knochenhauer in der alten Mine (Dungeon)"},
			{"t": "talk", "key": "jorik", "text": "Sprich mit Jorik"}],
		"reward": {"xp": 480, "gold": 200, "items": {"erz": 5}, "aff": 20}},
	"s11": {"name": "Gruftfürst Malrik", "giver": "elara", "req": "s8",
		"intro": "Unter dem Friedhof liegt die Gruft der Hüter. Dort ruht Malrik, der Dritte der Zwölf, und er ruht nicht mehr. Solange er wacht, stehen die Toten immer wieder auf.",
		"outro": "Malrik hat Frieden. Und ich habe sein Siegel für die Chronik. Du hast etwas Großes getan.",
		"stages": [{"t": "kill", "key": "gruft_boss", "n": 1, "text": "Besiege Gruftfürst Malrik in der Gruft der Hüter (Dungeon)"},
			{"t": "talk", "key": "elara", "text": "Kehre zu Elara zurück"}],
		"reward": {"xp": 700, "gold": 260, "items": {"splitter": 1}, "aff": 20}},
	"s12": {"name": "Der Hauptmann ohne Namen", "giver": "gernot", "req": "s9",
		"intro": "Unter dem Wachturm ist ein Keller. Dort hat sich mein Vorgänger eingeschlossen, als die Asche kam, um niemanden mitzunehmen. Er hat seinen Namen vergessen. Ich nicht. Erlöse ihn.",
		"outro": "Er hieß Wendelin. Schreib das irgendwo auf, damit es einer weiß, wenn ich es vergesse.",
		"stages": [{"t": "kill", "key": "turmkeller_boss", "n": 1, "text": "Besiege den Hauptmann ohne Namen im Turmkeller (Dungeon)"},
			{"t": "talk", "key": "gernot", "text": "Melde dich bei Hauptmann Gernot"}],
		"reward": {"xp": 900, "gold": 320, "items": {"heiltrank": 4}}},
	"r1": {"name": "Das Licht von Salzhafen", "giver": "ole", "req_ruf": ["salzhafen", 15],
		"intro": "Seit drei Wochen ist der Leuchtturm dunkel. Schmuggler haben ihn besetzt, damit kein Zöllner ihre Boote sieht. Ihr Anführer nennt sich König. Hol mir meinen Turm zurück, und Salzhafen hat wieder ein Licht.",
		"outro": "Heute Nacht brennt das Feuer wieder. Jedes Schiff, das heil einläuft, verdankt es dir.",
		"stages": [{"t": "kill", "key": "leuchtturm_boss", "n": 1, "text": "Besiege den Schmugglerkönig im Leuchtturm (Salzhafen, Dungeon)"},
			{"t": "talk", "key": "ole", "text": "Sprich mit Leuchtturmwärter Ole"}],
		"reward": {"xp": 800, "gold": 320, "items": {"heiltrank": 3}, "aff": 20}},
	"r2": {"name": "Strandgut", "giver": "marek",
		"intro": "Am Oststrand lauern Schmuggler meinen Leuten auf. Vier oder fünf, mit Bogen. Solange die da sind, legt bei mir keiner mehr ab.",
		"outro": "Saubere Arbeit. Ab jetzt fährst du bei mir umsonst.",
		"stages": [{"t": "kill", "key": "salz_strand", "n": 4, "text": "Besiege 4 Schmuggler am Oststrand von Salzhafen"},
			{"t": "talk", "key": "marek", "text": "Sprich mit Kapitän Marek"}],
		"reward": {"xp": 500, "gold": 200, "flag": "schiff_frei", "aff": 15}},
	"r3": {"name": "Wolfswinter", "giver": "torvald",
		"intro": "Die Wölfe kommen jede Nacht näher an die Hütten. Sechs müssen weg, sonst traut sich im Frühjahr keiner mehr auf die Alm.",
		"outro": "Das Rudel hat es begriffen. Nimm die Felle, na ja, den Lohn dafür.",
		"stages": [{"t": "kill", "key": "hoch_wolf", "n": 6, "text": "Besiege 6 Wölfe rund um Hochwacht"},
			{"t": "talk", "key": "torvald", "text": "Sprich mit Jäger Torvald"}],
		"reward": {"xp": 520, "gold": 210, "items": {"braten": 3}, "aff": 15}},
	"r4": {"name": "Was in der Eishöhle wohnt", "giver": "ylva", "req_ruf": ["hochwacht", 15],
		"intro": "Oben am Gletscher ist eine Höhle, in die geht kein Tier. Etwas Altes sitzt darin und atmet Frost. Meine Schwester ist hineingegangen. Ich will wissen, was aus ihr geworden ist.",
		"outro": "Dann war sie es. Danke, dass du sie nach Hause geschickt hast.",
		"stages": [{"t": "kill", "key": "eishoehle_boss", "n": 1, "text": "Besiege den Frostgeist in der Eishöhle (Hochwacht, Dungeon)"},
			{"t": "talk", "key": "ylva", "text": "Sprich mit Bergführerin Ylva"}],
		"reward": {"xp": 900, "gold": 300, "items": {"splitter": 1}, "aff": 20}},
	"r5": {"name": "Räuber auf den Feldwegen", "giver": "hedda",
		"intro": "Jede zweite Fuhre nach Aschfurt wird überfallen. Die Bande lagert im Osten bei den alten Scheunen. Fünf von denen weniger, und wir können wieder fahren.",
		"outro": "Die erste Fuhre seit Wochen ist durchgekommen. Dornfeld vergisst so etwas nicht.",
		"stages": [{"t": "kill", "key": "dorn_raeuber", "n": 5, "text": "Besiege 5 Räuber östlich von Dornfeld"},
			{"t": "talk", "key": "hedda", "text": "Sprich mit Bäuerin Hedda"}],
		"reward": {"xp": 520, "gold": 240, "items": {"festmahl": 1}, "aff": 15}},
	"r6": {"name": "Blumen für den Markt", "giver": "rosalind",
		"intro": "Glutblumen kennt hier niemand, und alle wollen sie haben. Bring mir fünf aus eurem Dämmerwald, dann zeige ich dir, was Dornfeld unter einem Dank versteht.",
		"outro": "Sieh sie dir an. Wie kleine Laternen. Du hast mir den Markttag gerettet.",
		"stages": [{"t": "bring", "key": "rosalind", "item": "blume", "n": 5, "text": "Bringe Rosalind 5 Glutblumen (Dämmerwald)"}],
		"reward": {"xp": 300, "gold": 180, "aff": 20}},
	"b1": {"name": "Kopfgeld: Knochenplage", "giver": "brett", "repeat": true,
		"intro": "Aushang der Dorfwache: Wer sechs Skelette gleich welcher Art erschlägt, erhält Lohn aus der Dorfkasse.",
		"outro": "Die Dorfkasse zahlt aus.",
		"stages": [{"t": "kill", "key": "*", "n": 6, "text": "Besiege 6 Skelette"},
			{"t": "use", "key": "brett", "text": "Hole den Lohn am Anschlagbrett"}],
		"reward": {"xp": 120, "gold": 70}},
}

var p := {}            # alles, was gespeichert wird
var playing := false
var ui_open := false
var player = null
var world = null
var ui = null
var npcs := {}         # id -> Knoten
var buff_dmg := 0.0
var buff_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inputs()
	load_opt.call_deferred()
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(save_path(1)):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE), ProjectSettings.globalize_path(save_path(1)))


# ---------------------------------------------------------------- Einstellungen

func load_opt() -> void:
	if not FileAccess.file_exists(OPT_FILE) and OS.get_name() == "macOS":
		# MacBooks rechnen wegen des hochauflösenden Bildschirms viermal so viele Bildpunkte: sparsamer beginnen
		opt["quality"] = 1
		opt["fps"] = 1
	if FileAccess.file_exists(OPT_FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(OPT_FILE))
		if typeof(d) == TYPE_DICTIONARY:
			for k in d:
				opt[k] = d[k]
			if OS.get_name() == "macOS" and not d.has("fps"):
				# einmalig beim ersten Start nach dem Update: sparsame Voreinstellung für MacBooks
				opt["quality"] = 1
				opt["fps"] = 1
				save_opt.call_deferred()
	for a in opt["keys"]:
		_bind(a, int(opt["keys"][a]))
	apply_opt()


func save_opt() -> void:
	var f = FileAccess.open(OPT_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(opt))


func apply_opt() -> void:
	var win = get_window()
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return
	win.mode = Window.MODE_FULLSCREEN if opt["fullscreen"] else Window.MODE_WINDOWED
	if not opt["fullscreen"]:
		var sz: Array = SIZES[clamp(int(opt["size"]), 0, SIZES.size() - 1)]
		win.size = Vector2i(sz[0], sz[1])
	# Gamepad nur, wenn gewünscht: manche Geräte (Lenkräder, Flugsticks, driftende Sticks) melden
	# sonst dauernd eine Richtung, und die Figur läuft von allein los.
	for q in pad_events:
		if InputMap.action_has_event(q[0], q[1]):
			InputMap.action_erase_event(q[0], q[1])
		if opt["pad"]:
			InputMap.action_add_event(q[0], q[1])
	Engine.max_fps = FPS_CAPS[clamp(int(opt["fps"]), 0, FPS_CAPS.size() - 1)]
	# Begrenzungen, die nicht zum Bildschirmtakt passen (30, 45), wirken nur ohne VSync genau
	var cap: int = Engine.max_fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if opt["vsync"] and (cap == 0 or cap == 60) else DisplayServer.VSYNC_DISABLED)
	Audio.music_volume = opt["music"]
	Audio.sfx_volume = opt["sfx"]
	if world:
		world.apply_quality()


## Legt eine Aktion auf eine andere Taste (physische Position auf der Tastatur).
func _bind(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	var k = InputEventKey.new()
	k.physical_keycode = code
	InputMap.action_add_event(action, k)


func rebind(action: String, code: int) -> void:
	_bind(action, code)
	opt["keys"][action] = code
	save_opt()


func key_name(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode))
	return "?"


func _inputs() -> void:
	var keys = {
		"vor": [KEY_W, KEY_UP], "zurueck": [KEY_S, KEY_DOWN], "links": [KEY_A, KEY_LEFT], "rechts": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "ausweichen": [KEY_SPACE], "benutzen": [KEY_E], "essen": [KEY_F],
		"skill1": [KEY_1], "skill2": [KEY_2], "skill3": [KEY_3], "trank": [KEY_R],
		"inventar": [KEY_I, KEY_TAB], "charakter": [KEY_C], "aufgaben": [KEY_J], "cheats": [KEY_F1],
		"kamera_l": [KEY_Z], "kamera_r": [KEY_X], "waffe": [KEY_Q], "karte": [KEY_M], "fackel": [KEY_T], "hilfe": [KEY_H], "schnellspeichern": [KEY_F5], "bild": [KEY_F12],
	}
	for a in keys:
		InputMap.add_action(a, 0.5)
		for k in keys[a]:
			var e = InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	for q in [["angriff", MOUSE_BUTTON_LEFT, JOY_BUTTON_X], ["block", MOUSE_BUTTON_RIGHT, JOY_BUTTON_DPAD_DOWN]]:
		InputMap.add_action(q[0], 0.5)
		var m = InputEventMouseButton.new()
		m.button_index = q[1]
		InputMap.action_add_event(q[0], m)
		var jb = InputEventJoypadButton.new()
		jb.button_index = q[2]
		pad_events.append([q[0], jb])
	var pads = {"ausweichen": JOY_BUTTON_B, "benutzen": JOY_BUTTON_A, "skill1": JOY_BUTTON_LEFT_SHOULDER,
		"skill2": JOY_BUTTON_RIGHT_SHOULDER, "skill3": JOY_BUTTON_Y, "inventar": JOY_BUTTON_BACK, "sprint": JOY_BUTTON_LEFT_STICK}
	for a in pads:
		var e = InputEventJoypadButton.new()
		e.button_index = pads[a]
		pad_events.append([a, e])
	var axes = {"vor": [JOY_AXIS_LEFT_Y, -1.0], "zurueck": [JOY_AXIS_LEFT_Y, 1.0], "links": [JOY_AXIS_LEFT_X, -1.0], "rechts": [JOY_AXIS_LEFT_X, 1.0]}
	for a in axes:
		var e = InputEventJoypadMotion.new()
		e.axis = axes[a][0]
		e.axis_value = axes[a][1]
		pad_events.append([a, e])


# ---------------------------------------------------------------- Spielstand

func new_game(pname: String, cls: String, attr: Dictionary) -> void:
	p = {
		"name": pname, "cls": cls, "level": 1, "xp": 0, "attr": attr.duplicate(), "attr_pts": 0, "talent_pts": 1,
		"talents": {}, "gold": 60, "inv": {"brot": 3, "heiltrank": 2, "karotte": 2, "fackel": 3, "pfeil": 40}, "armor": {"helm": 0, "brust": 0, "stiefel": 0}, "chest": {},
		"weapons": {CLASSES[cls]["start"][0]: 0, CLASSES[cls]["start"][1]: 0}, "slots": CLASSES[cls]["start"].duplicate(), "active": 0,
		"guard_lvl": 0, "rune": "", "hunger": 85.0, "fatigue": 90.0,
		"train": {"str": 0, "ges": 0, "int": 0, "vit": 0}, "day": 1, "time": 8.0,
		"quests": {}, "npc": {}, "cheats": {"god": false, "stamina": false, "needs": false, "onehit": false},
		"flags": {"home": true}, "kills": 0, "looted": {}, "pos": [0.0, 0.0, 6.0], "inside": false, "partner": "", "schwer": 1, "ruf": {}, "region": "", "kill_log": {}, "beruf": {}, "garten": [null, null, null, null, null, null], "voice": 0,
	}
	p["hp"] = max_hp()
	p["mana"] = max_mana()
	p["stamina"] = max_stamina()
	start_quest("m1")


func save_path(n: int) -> String:
	return "user://spielstand_%d.json" % n


func save_game(silent := false) -> void:
	if p.is_empty():
		return
	if player and not p.get("inside", false):
		p["pos"] = [player.global_position.x, player.global_position.y, player.global_position.z]
	var f = FileAccess.open(save_path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(p))
		toast.emit("Automatisch gespeichert" if silent else "Spiel gespeichert (Spielstand %d)" % slot)


## n = 0: irgendein Spielstand vorhanden?
func has_save(n := 0) -> bool:
	if n == 0:
		return has_save(1) or has_save(2) or has_save(3)
	return FileAccess.file_exists(save_path(n))


## Kurzbeschreibung eines Spielstands für die Auswahl.
func slot_info(n: int) -> String:
	if not has_save(n):
		return "leer"
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path(n)))
	if typeof(d) != TYPE_DICTIONARY or not d.has("cls"):
		return "beschädigt"
	return "%s, %s, Stufe %d, Tag %d" % [d["name"], CLASSES[d["cls"]]["name"], int(d["level"]), int(d["day"])]


func load_game(n := 0) -> bool:
	if n == 0:
		n = slot
	if not has_save(n):
		return false
	slot = n
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path(n)))
	if typeof(d) != TYPE_DICTIONARY or not d.has("cls"):
		return false
	p = d
	if not p.has("ruf"):
		p["ruf"] = {}
	for k in p["ruf"]:
		p["ruf"][k] = int(p["ruf"][k])
	p["schwer"] = int(p.get("schwer", 1))
	if not p.has("kill_log"):
		p["kill_log"] = {}
	for k in p["kill_log"]:
		p["kill_log"][k] = int(p["kill_log"][k])
	p["region"] = ""
	if not p.has("beruf"):
		p["beruf"] = {}
	if not p.has("garten"):
		p["garten"] = [null, null, null, null, null, null]
	for k in p["beruf"]:
		p["beruf"][k] = int(p["beruf"][k])
	if not p.has("armor"):
		p["armor"] = {"helm": 0, "brust": 0, "stiefel": 0}
		p["inv"]["pfeil"] = 40
	if not p.has("weapons"):       # alter Spielstand: Waffe der Klasse übernehmen
		var st: Array = CLASSES[p["cls"]]["start"]
		p["weapons"] = {st[0]: int(p.get("weapon_lvl", 0)), st[1]: 0}
		p["slots"] = st.duplicate()
		p["active"] = 0
	p["active"] = int(p["active"])
	for k in p["weapons"]:
		p["weapons"][k] = int(p["weapons"][k])
	p["flags"]["home"] = true
	for k in ["level", "xp", "attr_pts", "talent_pts", "gold", "guard_lvl", "day", "kills"]:
		p[k] = int(p[k])
	for k in p["attr"]:
		p["attr"][k] = int(p["attr"][k])
	for k in p["train"]:
		p["train"][k] = int(p["train"][k])
	for box in ["inv", "chest", "talents"]:
		for k in p[box]:
			p[box][k] = int(p[box][k])
	for q in p["quests"]:
		p["quests"][q]["stage"] = int(p["quests"][q]["stage"])
		p["quests"][q]["count"] = int(p["quests"][q]["count"])
	return true


# ---------------------------------------------------------------- Werte

func cls() -> Dictionary:
	return CLASSES[p["cls"]]

func rank(id: String) -> int:
	return int(p["talents"].get(id, 0))

func max_hp() -> float:
	return (70.0 + p["attr"]["vit"] * 10.0 + p["level"] * 6.0) * (1.0 + 0.08 * rank("zaeh"))

func max_mana() -> float:
	return (30.0 + p["attr"]["int"] * 6.0 + p["level"] * 2.0) * (1.0 + 0.1 * rank("geist"))

func max_stamina() -> float:
	return (90.0 + p["attr"]["ges"] * 3.0) * (1.0 + 0.1 * rank("flink"))

func needs_factor() -> float:
	# Hunger und Müdigkeit schwächen, satt und ausgeruht stärkt leicht.
	var f = 1.0
	if p["hunger"] < 25.0: f -= 0.2
	if p["fatigue"] < 25.0: f -= 0.2
	if p["hunger"] > 75.0 and p["fatigue"] > 75.0: f += 0.1
	return f

func wid() -> String:
	return p["slots"][p["active"]]

func weapon() -> Dictionary:
	return WEAPONS[wid()]

func wlvl(id := "") -> int:
	return int(p["weapons"].get(id if id != "" else wid(), 0))

func proficient(id := "") -> bool:
	return (id if id != "" else wid()) in cls()["prof"]

func weapon_damage() -> float:
	return weapon()["base"] + wlvl() * 3.5

func swap_weapon() -> void:
	if p["slots"][1 - p["active"]] == "":
		say("Der zweite Waffenslot ist leer.")
		return
	p["active"] = 1 - p["active"]
	changed.emit()

func damage() -> float:
	var d: float = weapon_damage() * (1.0 + p["attr"][weapon()["attr"]] * 0.06) * (1.0 + 0.06 * rank("kraft"))
	if not proficient(): d *= 0.75
	if p["rune"] == "feuer": d *= 1.2
	if p["flags"].get("scharf_day", 0) == p["day"]: d *= 1.1
	if p["flags"].get("d2", "") == "gebunden": d *= 1.12
	if p["flags"].get("ende", "") == "c": d *= 1.2
	d *= needs_factor() * (1.0 + buff_dmg)
	return d

func crit_chance() -> float:
	return 0.05 + p["attr"]["ges"] * 0.008 + (0.2 if p["rune"] == "blitz" else 0.0)

func defense() -> float:
	# Anteil des Schadens, der abgefangen wird (0..0.7)
	var a = 0.0
	for part in ARMOR:
		var t: int = int(p["armor"].get(part, 0))
		if t > 0:
			a += ARMOR[part]["tiers"][t - 1][1]
	return min(0.78, 0.04 * p["guard_lvl"] + 0.006 * p["attr"]["vit"] + a)

func speed() -> float:
	return 7.0 * (1.0 + 0.04 * rank("flink")) * (0.85 if p["fatigue"] < 25.0 else 1.0) * (0.7 if load_now() > capacity() else 1.0)

func xp_need(lvl: int) -> int:
	return 80 + lvl * lvl * 22       # Balance: mit Aufgaben und rund 250 Siegen erreicht man Stufe 15

func add_xp(n: float) -> void:
	p["xp"] += int(n * (1.0 + 0.06 * rank("gelehrig")) * (1.1 if p["flags"].get("geborgen_day", -1) == p["day"] else 1.0))
	while p["xp"] >= xp_need(p["level"]) and p["level"] < 30:
		p["xp"] -= xp_need(p["level"])
		p["level"] += 1
		p["attr_pts"] += 3
		p["talent_pts"] += 1
		p["hp"] = max_hp()
		p["mana"] = max_mana()
		level_up.emit()
		toast.emit("Stufe %d erreicht! 3 Attributspunkte, 1 Talentpunkt" % p["level"])
	changed.emit()

func add_gold(n: int) -> void:
	p["gold"] = max(0, p["gold"] + n)
	changed.emit()

func count(item: String, box := "inv") -> int:
	return int(p[box].get(item, 0))

func add_item(item: String, n := 1, box := "inv") -> void:
	p[box][item] = count(item, box) + n
	if p[box][item] <= 0:
		p[box].erase(item)
	changed.emit()

func hurt(n: float) -> float:
	if p["cheats"]["god"]:
		return 0.0
	n *= (1.0 - defense()) * [0.7, 1.0, 1.4][int(p.get("schwer", 1))]
	p["hp"] = max(0.0, p["hp"] - n)
	changed.emit()
	return n

func heal(n: float) -> void:
	p["hp"] = clamp(p["hp"] + n, 1.0 if n < 0 else 0.0, max_hp())
	changed.emit()

func use_item(item: String) -> bool:
	if count(item) <= 0:
		return false
	var d: Dictionary = ITEMS[item]
	if d["type"] == "food":
		if p["hunger"] >= 99.0 and d.get("heal", 0) <= 0:
			toast.emit("Du bist satt.")
			return false
		p["hunger"] = min(100.0, p["hunger"] + d["hunger"])
		heal(d.get("heal", 0))
		Audio.sfx("essen")
		toast.emit("%s gegessen" % d["name"])
	elif d["type"] == "potion":
		if d.has("buff"):
			if d["buff"] == "kraft":
				buff_dmg = 0.25
				buff_time = 180.0
				toast.emit("Stärketrank: +25 % Schaden für drei Minuten")
			else:
				p["flags"]["gift_n"] = 25
				toast.emit("Waffengift aufgetragen: die nächsten 25 Treffer +35 % Schaden")
		# Heiltränke wachsen mit: fester Wert plus 15 % des höchsten Lebens
		heal(d.get("heal", 0) + (max_hp() * 0.15 if d.get("heal", 0) > 0 else 0.0))
		p["mana"] = min(max_mana(), p["mana"] + d.get("mana", 0))
		Audio.sfx("zauber")
	else:
		return false
	add_item(item, -1)
	return true

func best_food() -> String:
	var best = ""
	for i in p["inv"]:
		if ITEMS[i]["type"] == "food" and (best == "" or ITEMS[i]["hunger"] > ITEMS[best]["hunger"]):
			best = i
	return best


# ---------------------------------------------------------------- Zeit und Bedürfnisse

func hour() -> float:
	return p["time"]

func is_night() -> bool:
	return p["time"] >= 21.0 or p["time"] < 5.5

func clock_text() -> String:
	return "Tag %d · %02d:%02d" % [p["day"], int(p["time"]), int(fmod(p["time"], 1.0) * 60.0)]

func advance(hours: float, resting := false) -> void:
	p["time"] += hours
	while p["time"] >= 24.0:
		p["time"] -= 24.0
		p["day"] += 1
		new_day.emit()
	if not p["cheats"]["needs"]:
		var slow = 1.0 - 0.1 * rank("gourmet")
		p["hunger"] = max(0.0, p["hunger"] - hours * 3.2 * slow)
		if not resting:
			p["fatigue"] = max(0.0, p["fatigue"] - hours * 5.0 * slow)
	else:
		p["hunger"] = 100.0
		p["fatigue"] = 100.0

func _notification(what: int) -> void:
	# verliert das Fenster den Fokus, alle gedrückten Tasten loslassen (sonst „klebt“ eine Richtung)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for a in InputMap.get_actions():
			if not str(a).begins_with("ui_"):
				Input.action_release(a)


func _process(delta: float) -> void:
	if not playing or get_tree().paused:
		return
	autosave_t += delta
	if autosave_t > 300.0 and player and not player.dead:       # alle fünf Minuten
		autosave_t = 0.0
		save_game(true)
	advance(delta / HOUR_SECONDS)
	if buff_time > 0.0:
		buff_time -= delta
		if buff_time <= 0.0:
			buff_dmg = 0.0
	if p["hunger"] <= 0.0 and p["hp"] > 1.0:
		p["hp"] = max(1.0, p["hp"] - delta * 0.6)
	var reg = 1.0 if p["hunger"] > 25.0 else 0.3
	p["mana"] = min(max_mana(), p["mana"] + delta * 1.2 * reg * (1.0 + 0.1 * rank("geist")))
	if p["hunger"] > 60.0:
		p["hp"] = min(max_hp(), p["hp"] + delta * 0.5)
	if p["cheats"]["stamina"]:
		p["stamina"] = max_stamina()
		p["mana"] = max_mana()

func sleep(hours: float, quality := 1.0) -> void:
	advance(hours, true)
	p["fatigue"] = min(100.0, p["fatigue"] + hours * 13.0 * quality)
	p["hp"] = min(max_hp(), p["hp"] + max_hp() * 0.12 * hours)
	p["mana"] = max_mana()
	p["stamina"] = max_stamina()
	changed.emit()

func sleep_until_morning() -> float:
	var h = fmod(31.0 - p["time"], 24.0)   # bis 7 Uhr
	if h < 2.0:
		h += 24.0
	return h


# ---------------------------------------------------------------- Aufgaben

func quest(id: String) -> Dictionary:
	return p["quests"].get(id, {})

func quest_done(id: String) -> bool:
	return quest(id).get("done", false)

func quest_active(id: String) -> bool:
	return p["quests"].has(id) and not p["quests"][id]["done"]

func quest_available(id: String) -> bool:
	var q: Dictionary = QUESTS[id]
	if quest_active(id):
		return false
	if quest_done(id) and not q.get("repeat", false):
		return false
	if q.has("req_ruf") and ruf(q["req_ruf"][0]) < q["req_ruf"][1]:
		return false
	return not q.has("req") or quest_done(q["req"])

func start_quest(id: String) -> void:
	p["quests"][id] = {"stage": 0, "count": 0, "done": false}
	toast.emit("Neue Aufgabe: %s" % QUESTS[id]["name"])
	_credit(id)
	quest_changed.emit()


## Rechnet an, was schon vor Annahme der Aufgabe erledigt wurde: besiegte Endgegner und frühere Siege im selben Lager.
func _credit(id: String) -> void:
	for guard in 6:
		var s = stage(id)
		if s.is_empty() or s["t"] != "kill" or s["key"] == "*" or QUESTS[id].get("repeat", false):
			return
		var done = p["flags"].get(s["key"] + "_tot", false)
		var prior: int = int(p.get("kill_log", {}).get(s["key"], 0))
		if not done and prior < s["n"]:
			p["quests"][id]["count"] = prior
			return
		toast.emit("Schon erledigt: " + s["text"])
		if _advance_quest(id):
			return

func stage(id: String) -> Dictionary:
	if not quest_active(id):
		return {}
	return QUESTS[id]["stages"][p["quests"][id]["stage"]]

func stage_text(id: String) -> String:
	var s = stage(id)
	if s.is_empty():
		return ""
	var t: String = s["text"]
	if s["t"] == "kill" and s["n"] > 1:
		t += " (%d/%d)" % [p["quests"][id]["count"], s["n"]]
	elif s["t"] == "bring":
		t += " (%d/%d)" % [min(count(s["item"]), s["n"]), s["n"]]
	return t

## Meldet ein Ereignis. Gibt die IDs der Aufgaben zurück, die dabei abgeschlossen wurden.
func event(type: String, key: String) -> Array:
	var finished = []
	if type == "kill":        # jeden Sieg je Lager merken, damit spätere Aufgaben ihn anrechnen können
		if not p.has("kill_log"):
			p["kill_log"] = {}
		p["kill_log"][key] = int(p["kill_log"].get(key, 0)) + 1
	for id in p["quests"].keys():
		var s = stage(id)
		if s.is_empty():
			continue
		var hit = false
		if type == "talk" and s["t"] == "bring" and s["key"] == key:
			if count(s["item"]) >= s["n"]:
				add_item(s["item"], -s["n"])
				hit = true
		elif s["t"] == type and (s["key"] == key or s["key"] == "*"):
			if type == "kill":
				p["quests"][id]["count"] += 1
				hit = p["quests"][id]["count"] >= s["n"]
			else:
				hit = true
		if hit:
			if _advance_quest(id):
				finished.append(id)
			else:
				_credit(id)       # der nächste Schritt ist vielleicht auch schon erledigt
				if quest_done(id):
					finished.append(id)
		quest_changed.emit()
	return finished

func _advance_quest(id: String) -> bool:
	var st: Dictionary = p["quests"][id]
	st["stage"] += 1
	st["count"] = 0
	if st["stage"] < QUESTS[id]["stages"].size():
		toast.emit("Aufgabe: " + QUESTS[id]["stages"][st["stage"]]["text"])
		return false
	st["done"] = true
	var r: Dictionary = QUESTS[id].get("reward", {})
	add_gold(r.get("gold", 0))
	for i in r.get("items", {}):
		add_item(i, r["items"][i])
	if r.has("flag"):
		p["flags"][r["flag"]] = true
	if r.has("aff"):
		npc_data(QUESTS[id]["giver"])["aff"] += r["aff"]
	if QUESTS[id]["giver"] != "niemand" and QUESTS[id]["giver"] != "brett":
		add_ruf(ort_of_npc(QUESTS[id]["giver"]), 20 if QUESTS[id].get("main", false) else 15)
	if QUESTS[id].has("auto_next"):
		start_quest.call_deferred(QUESTS[id]["auto_next"])
	Audio.sfx("aufgabe")
	toast.emit("Aufgabe erledigt: %s (+%d EP, +%d Gold)" % [QUESTS[id]["name"], r.get("xp", 0), r.get("gold", 0)])
	add_xp(r.get("xp", 0))
	return true

# ---------------------------------------------------------------- Handel, Ruf, Traglast

## In welchem Ort befindet sich der Held gerade (für Preise und Ruf)?
func ort() -> String:
	var reg: String = p.get("region", "")
	if reg != "":
		return reg
	if player and world:
		var ref: Vector3 = player.global_position if p.get("room", "") == "" else world.places.get(p.get("room_door", ""), Vector3.ZERO)
		if ref.distance_to(Vector3(250, 0, 190)) < 90.0:
			return "weidenau"
	return "aschfurt"


func ort_of_npc(id: String) -> String:
	var Npc = load("res://scripts/npc.gd")
	if not Npc.PEOPLE.has(id):
		return "aschfurt"
	return {"": "aschfurt", "b": "weidenau", "salz": "salzhafen", "hoch": "hochwacht", "dorn": "dornfeld"}[Npc.PEOPLE[id].get("dorf", "")]


func ruf(o := "") -> int:
	return int(p.get("ruf", {}).get(o if o != "" else ort(), 0))


func add_ruf(o: String, n: int) -> void:
	if not p.has("ruf"):
		p["ruf"] = {}
	var before = ruf(o)
	p["ruf"][o] = before + n
	if before < 30 and before + n >= 30:
		toast.emit("Dein Ruf in %s ist gewachsen: Die Händler dort bieten dir jetzt besondere Waren an." % ORTE[o])


## Preis eines Gegenstands am aktuellen Ort: Ortsfaktor, Markttag, Rabatt durch Ruf (bis 20 %).
func preis(item: String, verkauf := false) -> int:
	var base: float = ITEMS[item]["price"] * PREISE.get(ort(), {}).get(item, 1.0)
	if verkauf:
		return max(1, int(base * 0.5))
	if world and world.wetter.today() == "Markttag":
		base *= 0.8
	base *= 1.0 - min(0.2, ruf() / 250.0)
	return max(1, int(round(base)))


func load_now() -> int:
	var n = 0
	for i in p["inv"]:
		if i != "pfeil" and ITEMS[i]["type"] != "quest":
			n += int(p["inv"][i])
	return n


func capacity() -> int:
	return 160 if p["flags"].get("esel", false) else 60


func job_lvl(j: String) -> int:
	return min(10, int(sqrt(p.get("beruf", {}).get(j, 0) / 3.0)) + 1)


func job_xp(j: String, n := 1) -> void:
	if not p.has("beruf"):
		p["beruf"] = {}
	var before = job_lvl(j)
	p["beruf"][j] = int(p["beruf"].get(j, 0)) + n
	if job_lvl(j) > before:
		Audio.sfx("stufe", 1.2, 0.6)
		toast.emit("%s steigt auf Stufe %d (%s)" % [JOBS[j][0], job_lvl(j), JOBS[j][1]])


func npc_data(id: String) -> Dictionary:
	if not p["npc"].has(id):
		p["npc"][id] = {"aff": 0.0, "talk_day": 0, "gift_day": 0, "flirt_day": 0, "date_day": 0, "love": false}
	return p["npc"][id]


# ---------------------------------------------------------------- Hilfen

func model(path: String) -> Node3D:
	var res = load("res://assets/" + path)
	if res == null:
		push_warning("Modell fehlt: " + path)
		return Node3D.new()
	return res.instantiate()

func say(t: String) -> void:
	toast.emit(t)
