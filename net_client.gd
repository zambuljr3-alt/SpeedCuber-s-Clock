extends Node
# Klien WebSocket untuk Remote Timer Display (Host dan Remote).
# Sinkron jam ala NTP: ping/pong -> selisih jam (offset) terhadap jam server.
# Host mengirim timestamp "mulai" dalam waktu server; Remote menghitung waktu
# yang tampil dari timestamp itu, bukan dari angka timer yang dikirim terus-menerus.

signal phase_changed
signal state_received(s: Dictionary)
signal error_message(text: String)

enum Phase { OFF, CONNECTING, ONLINE, IN_ROOM }

var url := ""
var role := ""            # "host" / "remote" / ""
var room := ""
var token := ""           # token host, dibuat server (hanya ada di memori)
var want := false         # true = terus mencoba tersambung
var phase: int = Phase.OFF
var status_text := "Offline"
var host_online := false
var remotes := 0
var rtt_ms := -1.0
var offset_ms := 0.0
var synced := false
var last_state: Dictionary = {}

var _ws: WebSocketPeer
var _opened := false
var _connect_started := 0.0
var _retry_in := 0.0
var _attempts := 0
var _last_rx := 0.0
var _ping_in := 0.0
var _burst := 0
var _samples: Array = []
var _seq := 0


# ------------------------------------------------------------ waktu

func local_ms() -> float:
	return Time.get_ticks_usec() / 1000.0


func server_now() -> float:
	return local_ms() + offset_ms


func local_to_server(ms: float) -> float:
	return ms + offset_ms


func in_room() -> bool:
	return phase == Phase.IN_ROOM


# -------------------------------------------------------------- API

func start_host(u: String) -> void:
	_drop()
	role = "host"
	_begin(u)


func start_remote(u: String, code: String) -> void:
	_drop()
	role = "remote"
	room = code
	_begin(u)


func stop(reason: String = "") -> void:
	want = false
	if _ws != null:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_send({"t": "leave"})
		_ws.close()
	_ws = null
	_opened = false
	_clear_session()
	_set_phase(Phase.OFF, reason if reason != "" else "Offline")


# Host: kirim status timer (hanya saat berubah). Disimpan agar bisa dikirim ulang setelah reconnect.
func send_state(d: Dictionary) -> void:
	last_state = d
	if role == "host" and phase == Phase.IN_ROOM:
		_seq += 1
		_send({"t": "state", "q": _seq, "s": d})


func summary() -> String:
	var ping := "sinkron jam..."
	if synced and rtt_ms >= 0.0:
		ping = "%d ms" % int(rtt_ms)
	if role == "host" and in_room():
		return "HOST | Room %s | %d remote | %s" % [room, remotes, ping]
	if role == "remote" and in_room():
		return "REMOTE | Room %s | host %s | %s" % [room, "online" if host_online else "OFFLINE", ping]
	return status_text


# --------------------------------------------------------- internal

func _clear_session() -> void:
	role = ""
	room = ""
	token = ""
	host_online = false
	remotes = 0
	synced = false
	rtt_ms = -1.0
	offset_ms = 0.0
	last_state = {}
	_samples.clear()
	_seq = 0
	_attempts = 0


func _drop() -> void:
	if _ws != null:
		_ws.close()
	_ws = null
	_opened = false
	_clear_session()


func _normalize(u: String) -> String:
	var s := u.strip_edges()
	if s.begins_with("https://"):
		s = "wss://" + s.substr(8)
	elif s.begins_with("http://"):
		s = "ws://" + s.substr(7)
	elif not (s.begins_with("ws://") or s.begins_with("wss://")):
		s = "wss://" + s
	return s


func _begin(u: String) -> void:
	url = _normalize(u)
	want = true
	_attempts = 0
	_retry_in = 0.0
	_connect()


func _connect() -> void:
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		error_message.emit("Alamat server tidak valid.")
		stop("Alamat server tidak valid.")
		return
	_opened = false
	_connect_started = local_ms()
	_set_phase(Phase.CONNECTING, "Menghubungkan ke server...")


func _set_phase(p: int, text: String) -> void:
	phase = p
	status_text = text
	phase_changed.emit()


func _process(delta: float) -> void:
	if not want:
		return
	if _ws == null:
		_retry_in -= delta
		if _retry_in <= 0.0:
			_connect()
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _opened:
			_opened = true
			_last_rx = local_ms()
			_on_open()
		while _ws != null and _ws.get_available_packet_count() > 0:
			_on_text(_ws.get_packet().get_string_from_utf8())
		if _ws != null:
			_tick_ping(delta)
			if local_ms() - _last_rx > 15000.0:
				_ws.close()  # server diam terlalu lama -> anggap putus
	elif st == WebSocketPeer.STATE_CONNECTING:
		if local_ms() - _connect_started > 10000.0:
			_ws.close()
	elif st == WebSocketPeer.STATE_CLOSED:
		var had := _opened
		_ws = null
		_opened = false
		_schedule_retry(had)


func _schedule_retry(had: bool) -> void:
	_attempts += 1
	if _attempts == 1 and not had:
		error_message.emit("Tidak bisa terhubung ke server. Periksa alamat server dan internet.")
	_retry_in = minf(10.0, pow(2.0, float(mini(_attempts - 1, 4))))
	_set_phase(Phase.CONNECTING, "Terputus. Mencoba lagi dalam %d detik..." % int(_retry_in))


func _on_open() -> void:
	_attempts = 0
	_burst = 5
	_ping_in = 0.0
	_set_phase(Phase.ONLINE, "Terhubung ke server...")
	if role == "host":
		if room != "" and token != "":
			_send({"t": "resume", "room": room, "token": token})
		else:
			_send({"t": "create"})
	else:
		_send({"t": "join", "room": room})


func _tick_ping(delta: float) -> void:
	_ping_in -= delta
	if _ping_in > 0.0:
		return
	_send({"t": "ping", "c": Time.get_ticks_usec()})
	if _burst > 0:
		_burst -= 1
		_ping_in = 0.15
	else:
		_ping_in = 4.0


func _send(d: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(d))


func _on_pong(d: Dictionary) -> void:
	var c_ms := float(d.get("c", -1.0)) / 1000.0
	var s_ms := float(d.get("s", 0.0))
	if c_ms < 0.0:
		return
	var rtt := local_ms() - c_ms
	if rtt < 0.0 or rtt > 5000.0:
		return
	_samples.append([rtt, s_ms - (c_ms + rtt * 0.5)])
	if _samples.size() > 8:
		_samples.pop_front()
	var best: Array = _samples[0]
	for sm in _samples:
		if sm[0] < best[0]:
			best = sm
	offset_ms = best[1]
	rtt_ms = rtt
	if not synced:
		synced = true
		phase_changed.emit()


func _on_text(txt: String) -> void:
	_last_rx = local_ms()
	var data: Variant = JSON.parse_string(txt)
	if not (data is Dictionary):
		return
	var d: Dictionary = data
	match str(d.get("t", "")):
		"pong":
			_on_pong(d)
		"created":
			room = str(d.get("room", ""))
			token = str(d.get("token", ""))
			_set_phase(Phase.IN_ROOM, "Room dibuat")
			_resend_state()
		"resumed":
			_set_phase(Phase.IN_ROOM, "Tersambung kembali")
			_resend_state()
		"joined":
			room = str(d.get("room", room))
			host_online = bool(d.get("host", false))
			_set_phase(Phase.IN_ROOM, "Terhubung")
		"presence":
			host_online = bool(d.get("host", false))
			remotes = int(d.get("remotes", 0))
			phase_changed.emit()
		"state":
			if role == "remote" and d.get("s") is Dictionary:
				last_state = d["s"]
				state_received.emit(last_state)
		"error":
			var msg := str(d.get("msg", "Kesalahan dari server."))
			error_message.emit(msg)
			if bool(d.get("fatal", true)):
				stop(msg)


func _resend_state() -> void:
	if role == "host" and not last_state.is_empty():
		_seq += 1
		_send({"t": "state", "q": _seq, "s": last_state})
