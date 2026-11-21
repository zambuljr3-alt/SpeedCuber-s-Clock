extends Node
# Efek suara dibuat lewat kode (tanpa file audio) + suara inspeksi via TTS.

var enabled := true
var players := {}


func _ready() -> void:
	_add("ready", [[880, 90]])
	_add("tick", [[1400, 25]])
	_add("stop", [[600, 60]])
	_add("i8", [[700, 140]])
	_add("i12", [[700, 120], [0, 80], [700, 120]])
	_add("end", [[420, 450]])
	_add("pb", [[660, 110], [880, 110], [1100, 220]])


func _add(key: String, notes: Array) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _make(notes)
	add_child(p)
	players[key] = p


func play(key: String) -> void:
	if enabled and players.has(key):
		players[key].play()


# Mengembalikan true kalau TTS berhasil dipakai.
func say(text: String) -> bool:
	if not enabled:
		return false
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		var voices := DisplayServer.tts_get_voices_for_language("en")
		if voices.size() > 0:
			DisplayServer.tts_speak(text, voices[0])
			return true
	return false


func _make(notes: Array) -> AudioStreamWAV:
	var rate := 22050
	var total := 0
	for nt in notes:
		total += int(rate * nt[1] / 1000.0)
	var data := PackedByteArray()
	data.resize(total * 2)
	var idx := 0
	for nt in notes:
		var cnt := int(rate * nt[1] / 1000.0)
		var fade := mini(cnt >> 1, int(rate * 0.005))
		for i in cnt:
			var v := 0.0
			if nt[0] > 0:
				var env := 1.0
				if i < fade:
					env = float(i) / fade
				elif i > cnt - fade:
					env = float(cnt - i) / fade
				v = sin(TAU * nt[0] * i / rate) * 11000.0 * env
			data.encode_s16(idx * 2, int(v))
			idx += 1
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
