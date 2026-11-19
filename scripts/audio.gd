extends Node
## Musik nach Stimmung (Stücke wechseln sich ab), Umgebungsschleifen, Klangeffekte, Stimmen.

const MOODS := {
	"menue": ["light_1", "light_3", "ambient_9"],
	"dorf": ["ambient_1", "ambient_2", "ambient_4", "ambient_5", "ambient_6", "ambient_8", "ambient_10"],
	"wildnis": ["ambient_3", "ambient_7", "ambient_9", "light_2", "light_4"],
	"nacht": ["dark_1", "dark_2", "light_3", "light_5"],
	"kampf": ["action_1", "action_2", "action_3", "action_4", "action_5"],
	"dungeon": ["dark_3", "dark_4", "dark_5"],
	"haus": ["light_1", "light_2", "light_5"],
	"asche": ["dark_1", "dark_4", "dark_5"],
}
const FALLBACK := {"menue": "menue", "dorf": "dorf", "haus": "dorf", "wildnis": "wildnis", "nacht": "wildnis", "dungeon": "wildnis", "kampf": "kampf", "asche": "kampf"}
const SPELL := {"nova": "freeze", "blitz": "hex", "heilung": "heal", "wirbel": "cyclone", "sturm": "tornado", "faecher": "twister",
	"rauch": "corruption", "schritt": "wind", "spalter": "attack3", "raserei": "burn", "schrei": "burn", "adlerauge": "cure",
	"salve": "attack2", "fussangel": "curse", "schildstoss": "attack1"}

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _mood := ""
var _last := ""
var _amb_name := ""
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}
var music_volume := 0.7
var sfx_volume := 0.9


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	_amb = AudioStreamPlayer.new()
	_voice = AudioStreamPlayer.new()
	for pl in [_a, _b, _amb, _voice]:
		add_child(pl)
	_a.volume_db = -60.0
	_b.volume_db = -60.0
	_a.finished.connect(func(): _ended(_a))
	_b.finished.connect(func(): _ended(_b))
	for i in 12:
		var s = AudioStreamPlayer.new()
		add_child(s)
		_pool.append(s)


func _ended(pl: AudioStreamPlayer) -> void:
	if pl == _a:
		_next()


## Wechselt die Stimmung; innerhalb einer Stimmung folgen die Stücke zufällig aufeinander.
func music(mood: String) -> void:
	if mood == _mood or not MOODS.has(mood):
		return
	_mood = mood
	_next()


func _next() -> void:
	var list: Array = MOODS[_mood]
	var pick: String = list.pick_random()
	if list.size() > 1:
		while pick == _last:
			pick = list.pick_random()
	_last = pick
	var path = "res://audio/m/%s.mp3" % pick
	var st = null
	if ResourceLoader.exists(path):
		st = load(path)
	else:
		# Fassung ohne das Musikpaket: selbst erzeugte Stücke (tools/musik.py), endlos wiederholt
		var own = "res://audio/musik_%s.ogg" % FALLBACK.get(_mood, "dorf")
		if not ResourceLoader.exists(own):
			return
		st = load(own)
		if st is AudioStreamOggVorbis:
			st.loop = true
	var old = _a
	_a = _b
	_b = old
	_a.stream = st
	_a.volume_db = -60.0
	_a.play()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(_a, "volume_db", linear_to_db(max(0.0001, music_volume * 0.55)), 3.0)
	tw.tween_property(_b, "volume_db", -60.0, 3.0)
	tw.chain().tween_callback(_b.stop)


func set_music_volume(v: float) -> void:
	music_volume = v
	_a.volume_db = linear_to_db(max(0.0001, v * 0.55))


## Umgebungsschleife (Vögel, Regen, Höhle ...), läuft unter der Musik.
func ambience(n: String) -> void:
	if n == _amb_name:
		return
	_amb_name = n
	var path = "res://audio/amb_%s.ogg" % n
	if not ResourceLoader.exists(path):
		_amb.stop()
		return
	var st = load(path)
	if st is AudioStreamOggVorbis:
		st.loop = true
	_amb.stream = st
	_amb.volume_db = linear_to_db(max(0.0001, sfx_volume * 0.5))
	_amb.play()


func has(n: String) -> bool:
	return ResourceLoader.exists("res://audio/sfx_%s.wav" % n)


func _load(path: String):
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func sfx(n: String, pitch := 1.0, vol := 1.0) -> void:
	_play(_load("res://audio/sfx_%s.wav" % n), pitch * randf_range(0.94, 1.06), vol)


func _play(stream, pitch: float, vol: float) -> void:
	if stream == null:
		return
	for s in _pool:
		if not s.playing:
			s.stream = stream
			s.pitch_scale = pitch
			s.volume_db = linear_to_db(max(0.0001, sfx_volume * vol))
			s.play()
			return


## Stimme des Helden (Typ 1 bis 3, 0 = aus). kind: attack, damaged, healed, jump oder ein Zauberwort.
## Sind die Kampfrufe aus dem Stimmenpaket vorhanden? (Nicht in der öffentlichen Fassung.)
func has_voices() -> bool:
	return ResourceLoader.exists("res://audio/stimme/t1/attack1.wav")


func voice(kind: String, type := -1) -> void:
	if type < 0:
		type = int(G.p.get("voice", 0)) if not G.p.is_empty() else 0
	if type <= 0 or _voice.playing:
		return
	if kind in ["attack", "damaged", "healed", "jump"]:
		kind += str(randi() % 3 + 1)
	var st = _load("res://audio/stimme/t%d/%s.wav" % [type, kind])
	if st:
		_voice.stream = st
		_voice.volume_db = linear_to_db(max(0.0001, sfx_volume * 0.8))
		_voice.play()


## Sprechlaute der Dorfbewohner: eine kurze Folge heller Töne, je Figur in eigener Tonlage
## (wie in vielen Rollenspielen ohne Sprachausgabe). Die Töne werden hier berechnet, nicht geladen.
var _blips := []
var _babble_n := 0
var _babble_t := 0.0
var _babble_base := 1.0


func _make_blips() -> void:
	for mix in [[1.0, 0.55, 0.3, 0.12], [1.0, 0.25, 0.5, 0.2], [0.8, 0.7, 0.15, 0.3]]:
		var rate = 44100
		var n = int(rate * 0.085)
		var data = PackedByteArray()
		data.resize(n * 2)
		for i in n:
			var t = float(i) / rate
			var env = min(1.0, t / 0.004) * exp(-t * 34.0)
			var f = 540.0 * (1.0 + 0.06 * sin(t * 40.0))
			var v = 0.0
			for k in mix.size():
				v += mix[k] * sin(TAU * f * (k + 1) * t)
			data.encode_s16(i * 2, int(clamp(v * env * 0.34, -1.0, 1.0) * 32767.0))
		var st = AudioStreamWAV.new()
		st.format = AudioStreamWAV.FORMAT_16_BITS
		st.mix_rate = rate
		st.data = data
		_blips.append(st)


## Lässt eine Figur „sprechen“: woman bestimmt die Grundlage, ton die eigene Tonlage, length die Textlänge.
func babble(woman: bool, ton: float, length: int) -> void:
	if _blips.is_empty():
		_make_blips()
	_babble_base = (1.22 if woman else 0.72) * ton
	_babble_n = clamp(int(length / 9.0), 4, 14)
	_babble_t = 0.0


func _process(delta: float) -> void:
	if _babble_n <= 0:
		return
	_babble_t -= delta
	if _babble_t <= 0.0:
		_babble_n -= 1
		# kleine Pausen wie zwischen Wörtern
		_babble_t = 0.075 if randf() < 0.8 else 0.17
		_play(_blips.pick_random(), _babble_base * randf_range(0.88, 1.18), 0.5)


func hush() -> void:
	_babble_n = 0
