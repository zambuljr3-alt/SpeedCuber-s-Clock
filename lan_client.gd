extends Node
# Mode Wi-Fi / Hotspot (tanpa server, tanpa internet): Host dan Remote bicara langsung lewat UDP.
# Antarmukanya sama dengan net_client.gd, jadi main.gd memakai keduanya dengan cara yang sama.
# Jam acuan = jam Host. Remote menyinkronkan jamnya ke Host dengan ping/pong ala NTP.

signal phase_changed
signal state_received(s: Dictionary)
signal error_message(text: String)

enum Phase { OFF, CONNECTING, ONLINE, IN_ROOM }

const PORT_HOST := 47777
const PORT_REMOTE := 47778

var role := ""
var room := ""
var token := ""
var phase: int = Phase.OFF
var status_text := "Offline"
var host_online := false
var remotes := 0
var rtt_ms := -1.0
var offset_ms := 0.0
var synced := false
var last_state: Dictionary = {}

var _udp: PacketPeerUDP
var _clients := {}
var _host_ip := ""
var _host_port := PORT_HOST
var _last_rx := 0.0
var _seq := 0
var _last_q := 0
var _samples: Array = []
var _ping_in := 0.0
var _burst := 0
var _join_in := 0.0
var _search_since := 0.0
var _warned := false
var _resend_in := 0.0
var _repeat_in := -1.0
var _expire_in := 0.0


# ------------------------------------------------------------ waktu

func local_ms() -> float:
	return Time.get_ticks_usec() / 1000.0


func server_now() -> float:
	return local_ms() + offset_ms


func local_to_server(ms: float) -> float:
	return ms + offset_ms


func in_room() -> bool:
	return phase == Phase.IN_ROOM


# Alamat IP privat HP ini (untuk info dan pencarian host).
func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var s := str(a)
		if s.contains(":"):
			continue
		var p := s.split(".")
		if p.size() != 4:
			continue
		var f := int(p[0])
		var g := int(p[1])
		if (f == 192 and g == 168) or f == 10 or (f == 172 and g >= 16 and g <= 31):
			out.append(s)
	return out


# -------------------------------------------------------------- API

func start_host(_u: String = "") -> void:
	_drop()
	role = "host"
	room = str(randi_range(100000, 999999))
	_udp = PacketPeerUDP.new()
	if _udp.bind(PORT_HOST) != OK:
		_udp = null
		role = ""
		room = ""
		error_message.emit("Tidak bisa membuka port %d. Pastikan Wi-Fi/hotspot aktif dan tidak ada aplikasi lain yang memakainya." % PORT_HOST)
		_set_phase(Phase.OFF, "Gagal membuat room")
		return
	synced = true      # Host adalah sumber waktu
	rtt_ms = 0.0
	offset_ms = 0.0
	_set_phase(Phase.IN_ROOM, "Room dibuat")


func start_remote(_u: String, code: String) -> void:
	_drop()
	role = "remote"
	room = code
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	if _udp.bind(PORT_REMOTE) != OK:
		_udp = PacketPeerUDP.new()
		_udp.set_broadcast_enabled(true)
		if _udp.bind(PORT_REMOTE + 1) != OK:
			_udp = null
			role = ""
			room = ""
			error_message.emit("Tidak bisa membuka koneksi jaringan di HP ini.")
			_set_phase(Phase.OFF, "Gagal")
			return
	_search_since = local_ms()
	_warned = false
	_join_in = 0.0
	_set_phase(Phase.CONNECTING, "Mencari host...")


func stop(reason: String = "") -> void:
	if _udp != null:
		if role == "host":
			for c in _clients.values():
				_send_to(str(c["ip"]), int(c["port"]), {"t": "bye"})
		_udp.close()
	_udp = null
	_clear()
	_set_phase(Phase.OFF, reason if reason != "" else "Offline")


func send_state(d: Dictionary) -> void:
	last_state = d
	if role != "host":
		return
	_seq += 1
	_broadcast_state()
	_repeat_in = 0.06   # kirim ulang sebentar lagi (UDP bisa hilang)


func summary() -> String:
	var ping := "sinkron jam..."
	if synced and rtt_ms >= 0.0:
		ping = "%d ms" % int(rtt_ms)
	if role == "host" and in_room():
		return "HOST (Wi-Fi) | Room %s | %d remote" % [room, remotes]
	if role == "remote" and in_room():
		return "REMOTE (Wi-Fi) | Room %s | host %s | %s" % [room, "online" if host_online else "OFFLINE", ping]
	return status_text


# --------------------------------------------------------- internal

func _clear() -> void:
	role = ""
	room = ""
	host_online = false
	remotes = 0
	synced = false
	rtt_ms = -1.0
	offset_ms = 0.0
	last_state = {}
	_clients.clear()
	_host_ip = ""
	_samples.clear()
	_seq = 0
	_last_q = 0
	_repeat_in = -1.0


func _drop() -> void:
	if _udp != null:
		_udp.close()
	_udp = null
	_clear()


func _set_phase(p: int, text: String) -> void:
	phase = p
	status_text = text
	phase_changed.emit()


func _send_to(ip: String, port: int, d: Dictionary) -> void:
	if _udp == null:
		return
	_udp.set_dest_address(ip, port)
	_udp.put_packet(JSON.stringify(d).to_utf8_buffer())


func _process(delta: float) -> void:
	if _udp == null:
		return
	var now := local_ms()
	while _udp != null and _udp.get_available_packet_count() > 0:
		var txt := _udp.get_packet().get_string_from_utf8()
		_handle(txt, _udp.get_packet_ip(), _udp.get_packet_port())
	if _udp == null:
		return
	if role == "host":
		_host_tick(delta, now)
	else:
		_remote_tick(delta, now)


func _handle(txt: String, ip: String, port: int) -> void:
	var data: Variant = JSON.parse_string(txt)
	if not (data is Dictionary):
		return
	var d: Dictionary = data
	var t := str(d.get("t", ""))
	if role == "host":
		_host_msg(t, d, ip, port)
	else:
		_remote_msg(t, d, ip, port)


# ------------------------------------------------------------- Host

func _host_msg(t: String, d: Dictionary, ip: String, port: int) -> void:
	var key := ip + ":" + str(port)
	if t == "join":
		if str(d.get("room", "")) != room:
			return
		var is_new := not _clients.has(key)
		_clients[key] = {"ip": ip, "port": port, "seen": local_ms()}
		_send_to(ip, port, {"t": "joined", "room": room, "host": true})
		if is_new:
			remotes = _clients.size()
			phase_changed.emit()
			_send_state_to(ip, port)
	elif t == "ping":
		if _clients.has(key):
			_clients[key]["seen"] = local_ms()
			_send_to(ip, port, {"t": "pong", "c": int(d.get("c", 0)), "s": Time.get_ticks_usec()})


func _send_state_to(ip: String, port: int) -> void:
	if last_state.is_empty():
		return
	_send_to(ip, port, {"t": "state", "q": _seq, "s": last_state})


func _broadcast_state() -> void:
	for c in _clients.values():
		_send_state_to(str(c["ip"]), int(c["port"]))


func _host_tick(delta: float, now: float) -> void:
	_expire_in -= delta
	if _expire_in <= 0.0:
		_expire_in = 1.0
		var changed := false
		for k in _clients.keys():
			if now - float(_clients[k]["seen"]) > 6000.0:
				_clients.erase(k)
				changed = true
		if changed:
			remotes = _clients.size()
			phase_changed.emit()
	if _repeat_in > 0.0:
		_repeat_in -= delta
		if _repeat_in <= 0.0:
			_broadcast_state()
	_resend_in -= delta
	if _resend_in <= 0.0:
		_resend_in = 1.0
		_broadcast_state()   # status diulang tiap detik: yang hilang pasti tersusul


# ----------------------------------------------------------- Remote

func _remote_msg(t: String, d: Dictionary, ip: String, port: int) -> void:
	if t == "joined":
		if str(d.get("room", "")) != room:
			return
		_host_ip = ip
		_host_port = port
		_last_rx = local_ms()
		host_online = true
		_burst = 6
		_ping_in = 0.0
		if phase != Phase.IN_ROOM:
			_set_phase(Phase.IN_ROOM, "Terhubung")
		return
	if ip != _host_ip:
		return
	_last_rx = local_ms()
	if t == "pong":
		_on_pong(d)
	elif t == "state":
		var q := int(d.get("q", 0))
		if q >= _last_q and d.get("s") is Dictionary:
			_last_q = q
			last_state = d["s"]
			state_received.emit(last_state)
	elif t == "bye":
		host_online = false
		_host_ip = ""
		_search_since = local_ms()
		_warned = false
		_set_phase(Phase.CONNECTING, "Host menutup room. Mencari lagi...")


func _remote_tick(delta: float, now: float) -> void:
	if _host_ip == "":
		_join_in -= delta
		if _join_in <= 0.0:
			_join_in = 1.0
			_discover()
		if not _warned and now - _search_since > 20000.0:
			_warned = true
			error_message.emit("Host belum ditemukan. Pastikan kodenya benar dan kedua HP di Wi-Fi yang sama (atau HP 2 tersambung ke hotspot HP 1).")
		return
	_ping_in -= delta
	if _ping_in <= 0.0:
		_send_to(_host_ip, _host_port, {"t": "ping", "c": Time.get_ticks_usec(), "room": room})
		if _burst > 0:
			_burst -= 1
			_ping_in = 0.15
		else:
			_ping_in = 1.5
	if now - _last_rx > 5000.0:
		host_online = false
		_host_ip = ""
		_search_since = now
		_warned = false
		_set_phase(Phase.CONNECTING, "Koneksi ke host hilang. Mencari lagi...")


# Cari host: siaran (broadcast) + kirim langsung ke seluruh alamat 1-254 di jaringan yang sama.
func _discover() -> void:
	var msg := JSON.stringify({"t": "join", "room": room}).to_utf8_buffer()
	_udp.set_dest_address("255.255.255.255", PORT_HOST)
	_udp.put_packet(msg)
	for ip in local_ips():
		var parts := str(ip).split(".")
		var base := parts[0] + "." + parts[1] + "." + parts[2] + "."
		_udp.set_dest_address(base + "255", PORT_HOST)
		_udp.put_packet(msg)
		for i in range(1, 255):
			var target := base + str(i)
			if target == str(ip):
				continue
			_udp.set_dest_address(target, PORT_HOST)
			_udp.put_packet(msg)


func _on_pong(d: Dictionary) -> void:
	var c_ms := float(d.get("c", -1.0)) / 1000.0
	var s_ms := float(d.get("s", 0.0)) / 1000.0
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
