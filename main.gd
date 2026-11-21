extends Control
# Speedcuber's Clock v12 - timer cube ala Stackmat (Godot 4)
# UI utama digambar lewat _draw(); menu/riwayat/statistik memakai overlay Control.

const Scr = preload("res://scrambler.gd")
const SfxScript = preload("res://sfx.gd")
const ChartScript = preload("res://chart.gd")
const IcoScript = preload("res://ico.gd")
const NetScript = preload("res://net_client.gd")
const LanScript = preload("res://lan_client.gd")

enum State { IDLE, HOLD, READY, RUNNING }

const SAVE_PATH := "user://solves.json"
const THEME_KEYS := ["bg", "pad", "pad_on", "body", "edge", "lcd", "hand", "idle",
	"plate", "ptxt", "stat", "stat_dim", "txt", "muted"]
const THEME_NAMES := ["Stackmat Asli", "Stackmat", "Neon Biru", "Merah Racing", "Hijau Matrix", "Putih Bersih"]
const SEG := {
	"0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg",
	"5": "acdfg", "6": "acdefg", "7": "abc", "8": "abcdefg", "9": "abcdfg",
}
const COL_HAND_OK := Color(0.25, 1.0, 0.45)
const COL_HAND_HOLD := Color(1.0, 0.35, 0.25)

var state: int = State.IDLE
var left_down := false
var right_down := false
var kb_down := false
var touch_pad := {}
var mouse_pad := ""

var hold_start := 0
var run_start := 0
var elapsed := 0.0
var last_text := "0.000"
var lockout := false

# pengaturan
var inspection_on := true
var sound_on := true
var voice_on := true
var mode := 0              # 0 normal, 1 countdown, 2 BLD
var cd_limit := 60
var metro_on := false
var metro_bpm := 120
var theme_name := "Stackmat Asli"
var hold_ms := 1000
var stop_both := true
var stop_armed := false
var orient := 0            # 0 landscape, 1 otomatis (landscape + portrait)
var server_url := ""
var url_text := ""
var code_text := ""
var online_error := ""
var online_screen := false
var online_lbl: Label
var next_ui := 0
var net: Node
var net_inet: Node
var lan: Node
var seen_guide := false
var link_mode := 0         # 0 Wi-Fi/Hotspot (tanpa server), 1 Internet (server)
var remote_mode := false
var remote_state: Dictionary = {}
var remote_ui_until := 0
var run_start_srv := 0
var inspect_start_srv := 0
var last_push := ""
var exit_box: StyleBoxFlat

var inspecting := false
var inspect_start := 0
var v8 := false
var v12 := false
var pending_pen := 0
var bld_stage := 0
var bld_memo := 0.0
var next_tick := 0

var pb_text := ""
var pb_until := 0

var sessions: Array = []
var cur := 0
var solves: Array = []
var puzzle := "3x3"
var scramble := ""
var preview: Array = []
var pn := 0

var best_s := "-"
var ao5_s := "-"
var ao12_s := "-"

var themes := {}
var th: Dictionary = {}
var left_poly := PackedVector2Array()
var right_poly := PackedVector2Array()
var btn := {}
var body_box: StyleBoxFlat
var lcd_box: StyleBoxFlat
var lcd_rect := Rect2(478, 318, 320, 126)
var ox := 0.0
var oy := 0.0

var sfx: Node
var overlay: Control
var title_lbl: Label
var back_btn: Button
var head_line: ColorRect
var list_box: VBoxContainer
var confirm_key := ""
var data_status := ""


func _ready() -> void:
	randomize()
	resized.connect(_update_layout)
	_update_layout()
	btn = {
		"power": Vector2(435, 475),
		"play": Vector2(845, 350),
		"save": Vector2(845, 410),
		"reset": Vector2(845, 475),
		"menu": Vector2(1220, 60),
	}
	_build_themes()
	_load()
	sfx = SfxScript.new()
	add_child(sfx)
	sfx.enabled = sound_on
	net_inet = NetScript.new()
	lan = LanScript.new()
	for n in [net_inet, lan]:
		add_child(n)
		n.phase_changed.connect(_on_net_phase)
		n.state_received.connect(_on_remote_state)
		n.error_message.connect(_on_net_error)
	net = lan if link_mode == 0 else net_inet
	get_tree().quit_on_go_back = false
	body_box = StyleBoxFlat.new()
	body_box.set_corner_radius_all(40)
	body_box.set_border_width_all(5)
	lcd_box = StyleBoxFlat.new()
	lcd_box.set_corner_radius_all(14)
	lcd_box.set_border_width_all(4)
	lcd_box.border_color = Color(0.02, 0.03, 0.03)
	exit_box = _sbox(Color(0.08, 0.10, 0.16), Color(0.3, 0.85, 1.0), 30, 3)
	url_text = server_url
	_apply_theme()
	_apply_orientation()
	_sync_session()
	_new_scramble()
	_refresh_stats()
	_build_overlay()
	if not seen_guide:
		call_deferred("_first_run")


# ------------------------------------------------------------- themes

func _update_layout() -> void:
	# Layout dasar 1280x720 ditaruh di tengah; pad melebar sampai tepi layar.
	ox = maxf(0.0, (size.x - 1280.0) * 0.5)
	oy = maxf(0.0, (size.y - 720.0) * 0.5)
	left_poly = PackedVector2Array([
		Vector2(10.0 - ox, 190), Vector2(385, 125), Vector2(392, 250),
		Vector2(392, 690), Vector2(280, 712), Vector2(25.0 - ox, 660),
	])
	right_poly = PackedVector2Array()
	for p in left_poly:
		right_poly.append(Vector2(1280.0 - p.x, p.y))


func _build_themes() -> void:
	var raw := {
		"Stackmat Asli": ["0b0d10", "17292e", "24424a", "353d44", "15191c", "070707", "fac71a",
			"ff3b2e", "0a0f18", "4d99ff", "e8edf0", "9aa6ad", "ebf2f7", "8c9ea8"],
		"Stackmat": ["0f1217", "1a3036", "264a4d", "617885", "1f292e", "0a120f", "fac71a",
			"bff2e0", "0d1a2e", "4d99ff", "0f1719", "1f2b33", "ebf2f7", "8c9ea8"],
		"Neon Biru": ["050a1f", "0a1a47", "143380", "1a4da6", "050f33", "03081a", "59d9ff",
			"80e6ff", "050d26", "66d9ff", "e6f2ff", "9cc3f0", "e6f2ff", "6d8fcf"],
		"Merah Racing": ["170a0a", "400f0f", "661a1a", "8c1f1f", "330a0a", "120505", "ffd933",
			"ff998a", "1a0808", "ff8066", "faeae6", "e0a39b", "faeae6", "b07a74"],
		"Hijau Matrix": ["05120a", "0d3319", "145226", "1f6138", "08210f", "030d05", "99ff4d",
			"80ff99", "051408", "66ff80", "e6ffeb", "9fe0ad", "e6ffeb", "6fae80"],
		"Putih Bersih": ["e0e6eb", "9fadb8", "8094a3", "ccd4db", "808c99", "1f2426", "2666cc",
			"d9f2e6", "333f4d", "cce6ff", "1a1f26", "4d5966", "1a1f26", "596673"],
	}
	for k in raw:
		var d := {}
		for i in THEME_KEYS.size():
			d[THEME_KEYS[i]] = Color.html(raw[k][i])
		themes[k] = d


func _apply_theme() -> void:
	if not themes.has(theme_name):
		theme_name = "Stackmat Asli"
	th = themes[theme_name]
	body_box.bg_color = th["body"]
	body_box.border_color = th["edge"]
	lcd_box.bg_color = th["lcd"]
	RenderingServer.set_default_clear_color(th["bg"])
	if overlay != null:
		_build_ui_theme()


# ----------------------------------------------------------- sessions

func _sync_session() -> void:
	cur = clampi(cur, 0, sessions.size() - 1)
	solves = sessions[cur]["solves"]
	puzzle = str(sessions[cur]["puzzle"])
	last_text = "0.000" if solves.is_empty() else _fmt_solve(solves[-1])
	bld_stage = 0
	inspecting = false


func _new_scramble() -> void:
	scramble = Scr.generate(puzzle)
	pn = Scr.cube_size(puzzle)
	preview = Scr.preview(puzzle, scramble)


func _refresh_stats() -> void:
	var b := _best_val()
	best_s = "-" if is_inf(b) else _fmt(b)
	ao5_s = _fmt_f(_avg_at(solves.size(), 5))
	ao12_s = _fmt_f(_avg_at(solves.size(), 12))


# -------------------------------------------------------------- logic

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if state == State.HOLD and now - hold_start >= hold_ms:
		state = State.READY
		sfx.play("ready")
	if state == State.RUNNING:
		elapsed = (now - run_start) / 1000.0
		if mode == 1 and elapsed >= cd_limit:
			_stop(true)
		elif metro_on and now >= next_tick:
			sfx.play("tick")
			next_tick += int(60000.0 / metro_bpm)
	elif inspecting:
		var el := (now - inspect_start) / 1000.0
		if el >= 8.0 and not v8:
			v8 = true
			_voice("8 seconds", "i8")
		if el >= 12.0 and not v12:
			v12 = true
			_voice("12 seconds", "i12")
	_net_sync()
	_ui_tick(now)
	queue_redraw()


func _voice(text: String, key: String) -> void:
	if not voice_on:
		return
	if not sfx.say(text):
		sfx.play(key)


func _input(event: InputEvent) -> void:
	if remote_mode:
		_remote_input(event)
		return
	if overlay.visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var pad := _pad_at(t.position)
			if pad != "":
				touch_pad[t.index] = pad
				_recount()
			else:
				_press_ui(t.position)
		elif touch_pad.has(t.index):
			touch_pad.erase(t.index)
			_recount()
	elif event is InputEventMouseButton and not OS.has_feature("mobile"):
		var m := event as InputEventMouseButton
		if m.button_index != MOUSE_BUTTON_LEFT:
			return
		if m.pressed:
			var pad2 := _pad_at(m.position)
			if pad2 != "":
				mouse_pad = pad2
				_recount()
			else:
				_press_ui(m.position)
		elif mouse_pad != "":
			mouse_pad = ""
			_recount()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_SPACE and not k.echo:
			kb_down = k.pressed
			_recount()


func _pad_at(pos: Vector2) -> String:
	# Zona sentuh lebar: seluruh sisi kiri/kanan layar, supaya telapak tangan utuh bisa menempel.
	pos.x -= ox
	pos.y -= oy
	if pos.y >= 115.0:
		if pos.x <= 396.0:
			return "L"
		if pos.x >= 884.0:
			return "R"
	return ""


func _recount() -> void:
	var vals := touch_pad.values()
	left_down = vals.has("L") or mouse_pad == "L" or kb_down
	right_down = vals.has("R") or mouse_pad == "R" or kb_down
	_pads_changed()


func _pads_changed() -> void:
	var any := left_down or right_down
	var both := left_down and right_down
	match state:
		State.RUNNING:
			if not any:
				stop_armed = true
			elif stop_armed and (both or not stop_both) and Time.get_ticks_msec() - run_start > 150:
				_stop()
		State.IDLE:
			if lockout:
				if not any:
					lockout = false
			elif both:
				state = State.HOLD
				hold_start = Time.get_ticks_msec()
		State.HOLD:
			if not both:
				state = State.IDLE
		State.READY:
			if not both:
				_start()


func _start() -> void:
	pending_pen = 0
	if inspecting:
		var el := (Time.get_ticks_msec() - inspect_start) / 1000.0
		if el > 17.0:
			pending_pen = -1
		elif el > 15.0:
			pending_pen = 2
		inspecting = false
	run_start = Time.get_ticks_msec()
	run_start_srv = int(net.local_to_server(float(run_start)))
	next_tick = run_start + int(60000.0 / metro_bpm)
	elapsed = 0.0
	stop_armed = not (left_down or right_down)
	state = State.RUNNING


func _stop(auto: bool = false) -> void:
	elapsed = (Time.get_ticks_msec() - run_start) / 1000.0
	state = State.IDLE
	lockout = left_down or right_down
	if mode == 2 and bld_stage == 0:
		bld_memo = elapsed
		bld_stage = 1
		last_text = _fmt(bld_memo)
		sfx.play("stop")
		return
	var t := elapsed
	var pen := pending_pen
	var memo := -1.0
	if mode == 2:
		memo = bld_memo
		t = bld_memo + elapsed
		bld_stage = 0
	if auto:
		t = float(cd_limit)
		pen = -1
		sfx.play("end")
	else:
		sfx.play("stop")
	var prev_single := _best_val()
	var s := {"t": t, "pen": pen, "scr": scramble, "memo": memo}
	solves.append(s)
	last_text = _fmt_solve(s)
	_check_pb(s, prev_single)
	_new_scramble()
	_refresh_stats()
	_save()


func _check_pb(s: Dictionary, prev_single: float) -> void:
	pb_text = ""
	var n := solves.size()
	if int(s["pen"]) != -1 and n > 1 and not is_inf(prev_single) and _eff(s) < prev_single:
		pb_text = "PB!"
	for k in [5, 12]:
		if pb_text == "" and n >= k + 1:
			var c := _avg_at(n, k)
			var prev := _best_ao(k, n - 1)
			if c >= 0.0 and not is_inf(c) and not is_inf(prev) and c < prev:
				pb_text = "PB Ao%d!" % k
	if pb_text != "":
		pb_until = Time.get_ticks_msec() + 4000
		sfx.play("pb")


func _press_ui(pos: Vector2) -> void:
	if state != State.IDLE or left_down or right_down:
		return
	pos.x -= ox
	pos.y -= oy
	for key in btn:
		if pos.distance_to(btn[key]) <= 40.0:
			_on_button(key)
			return
	if pos.y < 140.0:
		_new_scramble()


func _on_button(key: String) -> void:
	match key:
		"power":
			inspection_on = not inspection_on
			if not inspection_on:
				inspecting = false
			_save()
		"play":
			if inspection_on and not inspecting and bld_stage == 0:
				inspecting = true
				inspect_start = Time.get_ticks_msec()
				inspect_start_srv = int(net.local_to_server(float(inspect_start)))
				v8 = false
				v12 = false
		"save":
			_show_history()
		"reset":
			inspecting = false
			bld_stage = 0
			last_text = "0.000"
		"menu":
			_show_menu()


# ------------------------------------------------- format dan statistik

func _fmt(sec: float) -> String:
	if sec >= 60.0:
		var m := int(sec / 60.0)
		return "%d:%06.3f" % [m, sec - m * 60.0]
	return "%.3f" % sec


func _fmt_f(v: float) -> String:
	if v < 0.0:
		return "-"
	if is_inf(v):
		return "DNF"
	return _fmt(v)


func _eff(s: Dictionary) -> float:
	var pen := int(s["pen"])
	if pen == -1:
		return INF
	return float(s["t"]) + (2.0 if pen == 2 else 0.0)


func _fmt_solve(s: Dictionary) -> String:
	var pen := int(s["pen"])
	if pen == -1:
		return "DNF"
	if pen == 2:
		return _fmt(float(s["t"]) + 2.0) + "+"
	return _fmt(float(s["t"]))


func _best_val() -> float:
	var b := INF
	for s in solves:
		b = minf(b, _eff(s))
	return b


# Rata-rata n solve terakhir sebelum indeks "end" (eksklusif). -1 = belum cukup, INF = DNF.
func _avg_at(end: int, n: int) -> float:
	if end < n or n < 3:
		return -1.0
	var vals: Array = []
	for i in range(end - n, end):
		vals.append(_eff(solves[i]))
	vals.sort()
	var trim := int(ceil(n * 0.05))
	var total := 0.0
	for i in range(trim, n - trim):
		if is_inf(vals[i]):
			return INF
		total += vals[i]
	return total / (n - 2 * trim)


func _best_ao(n: int, upto: int) -> float:
	var b := INF
	for e in range(n, upto + 1):
		var a := _avg_at(e, n)
		if a >= 0.0 and a < b:
			b = a
	return b


func _display_text() -> String:
	match state:
		State.RUNNING:
			if mode == 1:
				return _fmt(maxf(0.0, cd_limit - elapsed))
			return _fmt(elapsed)
		State.HOLD, State.READY:
			return "0.000"
	if inspecting:
		var el := (Time.get_ticks_msec() - inspect_start) / 1000.0
		if el <= 15.0:
			return str(int(ceil(15.0 - el)))
		elif el <= 17.0:
			return "+2"
		return "DNF"
	return last_text


func _display_color() -> Color:
	match state:
		State.HOLD:
			return Color(1.0, 0.3, 0.25)
		State.READY:
			return Color(0.25, 1.0, 0.45)
		State.RUNNING:
			return Color(0.95, 0.98, 1.0)
	if inspecting:
		return Color(1.0, 0.7, 0.2)
	return th["idle"]


# --------------------------------------------------------- persistence

func _clean_solves(arr: Variant) -> Array:
	var out: Array = []
	if arr is Array:
		for s in arr:
			if s is Dictionary:
				out.append({
					"t": float(s.get("t", 0.0)),
					"pen": int(s.get("pen", 0)),
					"scr": str(s.get("scr", "")),
					"memo": float(s.get("memo", -1.0)),
				})
	return out


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"version": 7, "current": cur, "sessions": sessions,
			"inspection": inspection_on, "sound": sound_on, "voice": voice_on,
			"mode": mode, "cd": cd_limit, "metro": metro_on, "bpm": metro_bpm,
			"theme": theme_name, "hold": hold_ms, "stopboth": stop_both, "server": server_url, "orient": orient, "link": link_mode, "guide": seen_guide,
		}))


func _load() -> void:
	sessions = []
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				inspection_on = bool(data.get("inspection", true))
				sound_on = bool(data.get("sound", true))
				voice_on = bool(data.get("voice", true))
				mode = clampi(int(data.get("mode", 0)), 0, 2)
				cd_limit = clampi(int(data.get("cd", 60)), 10, 600)
				metro_on = bool(data.get("metro", false))
				metro_bpm = clampi(int(data.get("bpm", 120)), 40, 300)
				theme_name = str(data.get("theme", "Stackmat Asli"))
				if int(data.get("version", 2)) >= 7:
					hold_ms = clampi(int(data.get("hold", 1000)), 100, 3000)
				stop_both = bool(data.get("stopboth", true))
				server_url = str(data.get("server", ""))
				orient = clampi(int(data.get("orient", 0)), 0, 1)
				link_mode = clampi(int(data.get("link", 0)), 0, 1)
				seen_guide = bool(data.get("guide", false))
				if data.has("sessions") and data["sessions"] is Array:
					for s in data["sessions"]:
						if s is Dictionary:
							var pz := str(s.get("puzzle", "3x3"))
							if not Scr.PUZZLES.has(pz):
								pz = "3x3"
							sessions.append({
								"name": str(s.get("name", "Sesi")),
								"puzzle": pz,
								"solves": _clean_solves(s.get("solves", [])),
							})
					cur = int(data.get("current", 0))
				elif data.has("solves"):
					sessions.append({"name": "3x3", "puzzle": "3x3",
						"solves": _clean_solves(data["solves"])})
	if sessions.is_empty():
		sessions.append({"name": "3x3", "puzzle": "3x3", "solves": []})


# ------------------------------------------------------------- drawing

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var now := Time.get_ticks_msec()
	if remote_mode:
		_draw_remote()
		return
	var txt_col: Color = th["txt"]
	var muted: Color = th["muted"]
	var stat_col: Color = th["stat"]
	var stat_dim: Color = th["stat_dim"]
	draw_rect(Rect2(0, 0, size.x, size.y), th["bg"])
	draw_set_transform(Vector2(ox, oy))

	# preview scramble
	var has_prev := preview.size() > 0
	if has_prev:
		var cs := 36.0 / pn
		for c in preview:
			draw_rect(Rect2(24.0 + c[0] * cs + c[3] * 3.0, 14.0 + c[1] * cs + c[4] * 3.0,
				cs - 1.0, cs - 1.0), Scr.COLORS[c[2]])

	# teks scramble
	var sx := 190.0 if has_prev else 90.0
	var sw := 900.0 if has_prev else 1100.0
	var fsz := 30
	var sy := 56.0
	if scramble.contains("\n"):
		fsz = 14
		sy = 22.0
	elif scramble.length() > 220:
		fsz = 16
		sy = 34.0
	elif scramble.length() > 130:
		fsz = 19
		sy = 38.0
	elif scramble.length() > 70:
		fsz = 24
		sy = 44.0
	draw_multiline_string(font, Vector2(sx, sy), scramble, HORIZONTAL_ALIGNMENT_CENTER,
		sw, fsz, -1, txt_col)
	var mode_name: String = ["NORMAL", "COUNTDOWN %ds" % cd_limit, "BLD"][mode]
	var online_tag := ""
	if net.role == "host" and net.in_room():
		online_tag = " | ROOM %s (%d)" % [net.room, net.remotes]
	var info := "%s | %s | %s%s   (ketuk untuk scramble baru)" % [sessions[cur]["name"], puzzle, mode_name, online_tag]
	draw_string(font, Vector2(sx, 134), info, HORIZONTAL_ALIGNMENT_CENTER, sw, 15, muted)

	# pad
	var prog := 0.0
	var ready_now := state == State.READY
	if state == State.HOLD:
		prog = clampf((now - hold_start) / float(hold_ms), 0.0, 1.0)
	elif ready_now:
		prog = 1.0
	var press_col: Color = COL_HAND_OK if ready_now else COL_HAND_HOLD
	_draw_pad(left_poly, left_down, Vector2(201.0 - ox * 0.5, 420), press_col, prog)
	_draw_pad(right_poly, right_down, Vector2(1079.0 + ox * 0.5, 420), press_col, prog)

	# body + LCD
	draw_style_box(body_box, Rect2(395, 290, 490, 385))
	draw_style_box(lcd_box, lcd_rect)
	var txt := _display_text()
	var dcol := _display_color()
	if _is_numeric(txt):
		_draw_seg_text(txt, lcd_rect, dcol)
	else:
		var fs := 84
		while fs > 24 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 300.0:
			fs -= 4
		draw_string(font, Vector2(lcd_rect.position.x, lcd_rect.position.y + lcd_rect.size.y * 0.5 + fs * 0.35),
			txt, HORIZONTAL_ALIGNMENT_CENTER, lcd_rect.size.x, fs, dcol)
	var tag := ""
	if mode == 1:
		tag = "COUNTDOWN"
	elif mode == 2:
		tag = "MEMO" if bld_stage == 0 else "EKSEKUSI"
	if tag != "":
		draw_string(font, Vector2(lcd_rect.position.x + 10, lcd_rect.position.y + 20), tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(dcol.r, dcol.g, dcol.b, 0.65))
	if now < pb_until and pb_text != "":
		draw_string(font, Vector2(lcd_rect.position.x, lcd_rect.position.y + 20), pb_text,
			HORIZONTAL_ALIGNMENT_RIGHT, lcd_rect.size.x - 10, 18, Color(1.0, 0.85, 0.2))

	# LED
	_draw_led(Vector2(435, 345), left_down)
	_draw_led(Vector2(435, 392), right_down)

	# tombol
	for key in btn:
		var c: Vector2 = btn[key]
		var fill := Color(0.17, 0.23, 0.27)
		if key == "power":
			fill = Color(0.10, 0.25, 0.45) if inspection_on else Color(0.20, 0.24, 0.27)
		draw_circle(c, 28.0, fill)
		draw_arc(c, 28.0, 0.0, TAU, 40, Color(0.08, 0.11, 0.13), 3.0, true)
	_draw_icons()

	# plat merek
	draw_rect(Rect2(520, 462, 240, 44), th["plate"])
	draw_string(font, Vector2(520, 491), "SPEEDCUBER'S CLOCK", HORIZONTAL_ALIGNMENT_CENTER,
		240, 20, th["ptxt"])

	# statistik
	var cols := [["BEST", best_s], ["AO5", ao5_s], ["AO12", ao12_s]]
	for i in 3:
		var cx := 500.0 + i * 140.0
		draw_string(font, Vector2(cx - 70.0, 548), cols[i][0], HORIZONTAL_ALIGNMENT_CENTER, 140, 16, stat_dim)
		draw_string(font, Vector2(cx - 70.0, 584), cols[i][1], HORIZONTAL_ALIGNMENT_CENTER, 140, 24, stat_col)
	var ins := "Inspeksi: %s   |   Solve: %d" % ["ON" if inspection_on else "OFF", solves.size()]
	draw_string(font, Vector2(395, 640), ins, HORIZONTAL_ALIGNMENT_CENTER, 490, 16, stat_dim)


func _draw_pad(poly: PackedVector2Array, down: bool, center: Vector2, press_col: Color, prog: float) -> void:
	draw_colored_polygon(poly, th["pad_on"] if down else th["pad"])
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, th["edge"], 5.0, true)
	# cincin: putih, lalu terisi merah (hijau kalau siap) selama tahan
	draw_arc(center, 150.0, 0.0, TAU, 96, Color(0.92, 0.95, 0.95), 6.0, true)
	if prog > 0.0:
		draw_arc(center, 150.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 96, press_col, 11.0, true)
	var hc: Color = press_col if down else th["hand"]
	_draw_hand(center + Vector2(0, -14), hc, 2.3)


func _draw_hand(c: Vector2, col: Color, s: float = 2.3) -> void:
	var base_y := c.y + 4.0 * s
	var heights := [34.0, 42.0, 40.0, 31.0]
	for i in 4:
		var x := c.x - 17.0 * s + i * 11.5 * s
		var h: float = heights[i] * s
		draw_rect(Rect2(x - 4.5 * s, base_y - h, 9.0 * s, h), col)
		draw_circle(Vector2(x, base_y - h), 4.5 * s, col)
	draw_rect(Rect2(c.x - 22.0 * s, base_y - 6.0 * s, 44.0 * s, 36.0 * s), col)
	draw_circle(Vector2(c.x, base_y + 28.0 * s), 22.0 * s, col)
	var tip := Vector2(c.x - 36.0 * s, base_y - 6.0 * s)
	draw_line(Vector2(c.x - 18.0 * s, base_y + 16.0 * s), tip, col, 10.0 * s)
	draw_circle(tip, 5.0 * s, col)


func _draw_led(c: Vector2, lit: bool) -> void:
	draw_circle(c, 13.0, Color(0.30, 1.0, 0.40) if lit else Color(0.68, 0.75, 0.78))
	draw_arc(c, 13.0, 0.0, TAU, 24, Color(0.12, 0.16, 0.18), 2.5, true)


func _draw_icons() -> void:
	var c: Vector2 = btn["power"]
	var pc := Color(0.35, 0.65, 1.0) if inspection_on else Color(0.6, 0.65, 0.68)
	draw_arc(c, 11.0, deg_to_rad(-60), deg_to_rad(240), 24, pc, 3.0, true)
	draw_line(c + Vector2(0, -14), c + Vector2(0, -2), pc, 3.0, true)
	c = btn["play"]
	draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -11), c + Vector2(-7, 11), c + Vector2(12, 0)]),
		Color(0.92, 0.95, 0.97))
	c = btn["save"]
	var sc := Color(0.92, 0.95, 0.97)
	draw_rect(Rect2(c + Vector2(-11, -11), Vector2(22, 22)), sc, false, 2.5)
	draw_rect(Rect2(c + Vector2(-6, -11), Vector2(12, 8)), sc)
	draw_rect(Rect2(c + Vector2(-6, 2), Vector2(12, 9)), sc, false, 2.0)
	c = btn["reset"]
	var rc := Color(1.0, 0.75, 0.15)
	draw_arc(c, 11.0, deg_to_rad(-30), deg_to_rad(250), 24, rc, 3.0, true)
	var p := c + 11.0 * Vector2(cos(deg_to_rad(-30)), sin(deg_to_rad(-30)))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -4), p + Vector2(4, -8), p + Vector2(3, 5)]), rc)
	c = btn["menu"]
	for dy in [-9, 0, 9]:
		draw_line(c + Vector2(-12, dy), c + Vector2(12, dy), Color(0.92, 0.95, 0.97), 3.5, true)


# ---- LCD 7-segmen

func _is_numeric(text: String) -> bool:
	if text == "":
		return false
	for ch in text:
		if not "0123456789.:+".contains(ch):
			return false
	return true


func _cw(ch: String) -> float:
	if ch == "." or ch == ":":
		return 0.2
	if ch == "+":
		return 0.45
	return 0.55


func _draw_seg_text(text: String, rect: Rect2, col: Color) -> void:
	var units := 0.0
	for ch in text:
		units += _cw(ch) + 0.12
	units -= 0.12
	var h := minf(rect.size.y * 0.72, (rect.size.x - 24.0) / maxf(units, 0.1))
	var x := rect.position.x + (rect.size.x - units * h) * 0.5
	var y := rect.position.y + (rect.size.y - h) * 0.5
	var dim := Color(col.r, col.g, col.b, 0.09)
	for ch in text:
		var w := _cw(ch) * h
		_draw_seg_char(ch, Rect2(x, y, w, h), col, dim)
		x += w + 0.12 * h


func _seg_rect(k: String, r: Rect2, t: float) -> Rect2:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	match k:
		"a":
			return Rect2(x + t, y, w - 2.0 * t, t)
		"g":
			return Rect2(x + t, y + h * 0.5 - t * 0.5, w - 2.0 * t, t)
		"d":
			return Rect2(x + t, y + h - t, w - 2.0 * t, t)
		"f":
			return Rect2(x, y + t * 0.5, t, h * 0.5)
		"b":
			return Rect2(x + w - t, y + t * 0.5, t, h * 0.5)
		"e":
			return Rect2(x, y + h * 0.5, t, h * 0.5 - t * 0.5)
		"c":
			return Rect2(x + w - t, y + h * 0.5, t, h * 0.5 - t * 0.5)
	return Rect2()


func _draw_seg_char(ch: String, r: Rect2, col: Color, dim: Color) -> void:
	var t := r.size.y * 0.095
	if ch.is_valid_int():
		var on: String = SEG[ch]
		for k in "abcdefg":
			draw_rect(_seg_rect(k, r, t), col if on.contains(k) else dim)
	elif ch == ".":
		draw_rect(Rect2(r.position.x + (r.size.x - t) * 0.5, r.position.y + r.size.y - t, t, t), col)
	elif ch == ":":
		var cx := r.position.x + (r.size.x - t) * 0.5
		draw_rect(Rect2(cx, r.position.y + r.size.y * 0.3, t, t), col)
		draw_rect(Rect2(cx, r.position.y + r.size.y * 0.65, t, t), col)
	elif ch == "+":
		var my := r.position.y + r.size.y * 0.5
		draw_rect(Rect2(r.position.x, my - t * 0.5, r.size.x, t), col)
		draw_rect(Rect2(r.position.x + (r.size.x - t) * 0.5, my - r.size.x * 0.5, t, r.size.x), col)


# --------------------------------------------------------- overlay UI

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.visible = false
	add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.98)
	overlay.add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	overlay.add_child(margin)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	back_btn = _btn("< Menu", _show_menu, 24, 150.0)
	head.add_child(back_btn)
	title_lbl = _lbl("", 34)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)
	head.add_child(_btn("Tutup", _close_overlay, 24, 150.0))
	head_line = ColorRect.new()
	head_line.custom_minimum_size = Vector2(0, 3)
	root.add_child(head_line)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(list_box)
	_build_ui_theme()


func _sbox(bg: Color, border: Color, radius: int = 16, bw: int = 2) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_corner_radius_all(radius)
	b.set_border_width_all(bw)
	b.content_margin_left = 18.0
	b.content_margin_right = 18.0
	b.content_margin_top = 10.0
	b.content_margin_bottom = 10.0
	return b


func _build_ui_theme() -> void:
	var acc: Color = th["ptxt"]
	var card := Color(0.12, 0.15, 0.21)
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _sbox(card, Color(acc.r, acc.g, acc.b, 0.35)))
	t.set_stylebox("hover", "Button", _sbox(card.lightened(0.1), acc))
	t.set_stylebox("pressed", "Button", _sbox(Color(acc.r * 0.4, acc.g * 0.4, acc.b * 0.4), acc))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.93, 0.96, 1.0))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_color", "Label", Color(0.93, 0.96, 1.0))
	overlay.theme = t
	if head_line != null:
		head_line.color = acc
	if title_lbl != null:
		title_lbl.add_theme_color_override("font_color", acc)


func _lbl(text: String, size: int = 24, col: Color = Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _btn(text: String, cb: Callable, size: int = 26, minw: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(minw, 64)
	b.add_theme_font_size_override("font_size", size)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _gbtn(text: String, cb: Callable) -> Button:
	var b := _btn(text, cb, 26)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 76)
	return b


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_child(g)
	return g


func _begin(title: String, back: bool) -> void:
	if not overlay.visible:
		touch_pad.clear()
		mouse_pad = ""
		kb_down = false
		_recount()
		overlay.modulate = Color(1, 1, 1, 0.0)
		overlay.visible = true
		create_tween().tween_property(overlay, "modulate:a", 1.0, 0.18)
	confirm_key = ""
	online_screen = false
	title_lbl.text = title
	back_btn.visible = back
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()


func _close_overlay() -> void:
	overlay.visible = false
	online_screen = false
	_refresh_stats()


func _onoff(v: bool) -> String:
	return "ON" if v else "OFF"


func _confirm_btn(text: String, key: String, cb: Callable) -> Button:
	var b := _btn(text, Callable(), 24)
	b.pressed.connect(_confirm_press.bind(key, cb, b, text))
	return b


func _confirm_press(key: String, cb: Callable, b: Button, text: String) -> void:
	if confirm_key == key:
		confirm_key = ""
		cb.call()
	else:
		confirm_key = key
		b.text = "Yakin? Tap lagi"


# --- menu

func _show_menu() -> void:
	_begin("Menu", false)
	var g := _grid(3)
	var items := [
		["sesi", "Sesi", _show_sessions],
		["puzzle", "Puzzle", _show_puzzles],
		["mode", "Mode", _show_modes],
		["online", "Layar Remote", _show_online],
		["stat", "Statistik", _show_stats],
		["riwayat", "Riwayat", _show_history],
		["tema", "Tema dan Suara", _show_settings],
		["data", "Data CSV", _show_data],
		["panduan", "Panduan", _show_guides],
	]
	for it in items:
		g.add_child(_card(it[0], it[1], it[2]))


func _card(kind: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 170)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	var ico := IcoScript.new()
	ico.kind = kind
	ico.col = th["ptxt"]
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ico)
	ico.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ico.offset_bottom = -56.0
	var l := _lbl(text, 24)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -52.0
	l.offset_bottom = -10.0
	return b


func _show_about() -> void:
	_begin("Tentang", true)
	if ResourceLoader.exists("res://icon.png"):
		var logo := TextureRect.new()
		logo.texture = load("res://icon.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(0, 320)
		list_box.add_child(logo)
	var l := _lbl("Speedcuber's Clock v12", 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_box.add_child(l)
	var d := _lbl("Timer cube ala Stackmat, dibuat dengan Godot 4.", 20, Color(0.6, 0.7, 0.8))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_box.add_child(d)


# --- sesi

func _show_sessions() -> void:
	_begin("Sesi", true)
	for i in sessions.size():
		var s: Dictionary = sessions[i]
		var n: int = s["solves"].size()
		var label := "%s%s | %s | %d solve" % ["> " if i == cur else "", s["name"], s["puzzle"], n]
		var b := _btn(label, _select_session.bind(i), 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		list_box.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	list_box.add_child(row)
	var le := LineEdit.new()
	le.text = str(sessions[cur]["name"])
	le.custom_minimum_size = Vector2(0, 64)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.add_theme_font_size_override("font_size", 26)
	row.add_child(le)
	row.add_child(_btn("Ganti nama", _rename_session.bind(le), 24, 200.0))
	list_box.add_child(_btn("+ Sesi baru (puzzle: %s)" % puzzle, _new_session, 26))
	list_box.add_child(_confirm_btn("Hapus semua solve sesi ini", "clear", _clear_session))
	if sessions.size() > 1:
		list_box.add_child(_confirm_btn("Hapus sesi ini", "delsess", _delete_session))


func _select_session(i: int) -> void:
	cur = i
	_sync_session()
	_new_scramble()
	_refresh_stats()
	_save()
	_show_sessions()


func _new_session() -> void:
	sessions.append({"name": "Sesi %d" % (sessions.size() + 1), "puzzle": puzzle, "solves": []})
	cur = sessions.size() - 1
	_sync_session()
	_refresh_stats()
	_save()
	_show_sessions()


func _rename_session(le: LineEdit) -> void:
	var nm := le.text.strip_edges()
	if nm != "":
		sessions[cur]["name"] = nm
		_save()
	_show_sessions()


func _clear_session() -> void:
	solves.clear()
	last_text = "0.000"
	_refresh_stats()
	_save()
	_show_sessions()


func _delete_session() -> void:
	sessions.remove_at(cur)
	cur = maxi(0, cur - 1)
	_sync_session()
	_new_scramble()
	_refresh_stats()
	_save()
	_show_sessions()


# --- puzzle

func _show_puzzles() -> void:
	_begin("Pilih Puzzle", true)
	var g := _grid(2)
	for p in Scr.PUZZLES:
		g.add_child(_gbtn(("> " if p == puzzle else "") + p, _set_puzzle.bind(p)))
	list_box.add_child(_lbl("Puzzle berlaku untuk sesi aktif. Buat sesi baru kalau mau\nmemisahkan riwayat tiap puzzle. Preview gambar tersedia untuk 2x2 sampai 5x5.", 20, Color(0.6, 0.7, 0.8)))


func _set_puzzle(p: String) -> void:
	sessions[cur]["puzzle"] = p
	puzzle = p
	_new_scramble()
	_save()
	_show_puzzles()


# --- mode

func _show_modes() -> void:
	_begin("Mode dan Alat", true)
	var g := _grid(3)
	var names := ["Normal", "Countdown", "BLD"]
	for i in 3:
		g.add_child(_gbtn(("> " if mode == i else "") + names[i], _set_mode.bind(i)))
	list_box.add_child(_lbl("Countdown: ada batas waktu, otomatis DNF kalau habis.\nBLD: tahan-lepas = mulai memorisasi, sentuh pad = selesai memo, lalu\ntahan-lepas lagi untuk eksekusi. Waktu total = memo + eksekusi.", 20, Color(0.6, 0.7, 0.8)))
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 10)
	list_box.add_child(r1)
	r1.add_child(_btn("- 10s", _adj_cd.bind(-10), 24, 140.0))
	var l1 := _lbl("Batas countdown: %d detik" % cd_limit, 26)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r1.add_child(l1)
	r1.add_child(_btn("+ 10s", _adj_cd.bind(10), 24, 140.0))
	list_box.add_child(_btn("Inspeksi 15 detik: " + _onoff(inspection_on), _toggle_inspection, 26))
	list_box.add_child(_btn("Metronom: " + _onoff(metro_on), _toggle_metro, 26))
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 10)
	list_box.add_child(r2)
	r2.add_child(_btn("- 10", _adj_bpm.bind(-10), 24, 140.0))
	var l2 := _lbl("Tempo metronom: %d BPM" % metro_bpm, 26)
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r2.add_child(l2)
	r2.add_child(_btn("+ 10", _adj_bpm.bind(10), 24, 140.0))


func _set_mode(i: int) -> void:
	mode = i
	bld_stage = 0
	_save()
	_show_modes()


func _adj_cd(d: int) -> void:
	cd_limit = clampi(cd_limit + d, 10, 600)
	_save()
	_show_modes()


func _toggle_inspection() -> void:
	inspection_on = not inspection_on
	if not inspection_on:
		inspecting = false
	_save()
	_show_modes()


func _toggle_metro() -> void:
	metro_on = not metro_on
	_save()
	_show_modes()


func _adj_bpm(d: int) -> void:
	metro_bpm = clampi(metro_bpm + d, 40, 300)
	_save()
	_show_modes()


# --- tema dan suara

func _show_settings() -> void:
	_begin("Tema dan Suara", true)
	list_box.add_child(_lbl("Tema", 26))
	var g := _grid(2)
	for n in THEME_NAMES:
		g.add_child(_gbtn(("> " if n == theme_name else "") + n, _set_theme.bind(n)))
	list_box.add_child(_btn("Suara (beep): " + _onoff(sound_on), _toggle_sound, 26))
	list_box.add_child(_btn("Suara inspeksi 8 dan 12 detik: " + _onoff(voice_on), _toggle_voice, 26))
	list_box.add_child(_btn("Berhenti dengan: " + ("2 pad (seperti Stackmat)" if stop_both else "1 pad"), _toggle_stop, 26))
	list_box.add_child(_btn("Orientasi layar: " + ("Otomatis (landscape + portrait)" if orient == 1 else "Landscape"), _toggle_orient, 26))
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 10)
	list_box.add_child(rh)
	rh.add_child(_btn("- 100", _adj_hold.bind(-100), 24, 160.0))
	var hl := _lbl("Waktu tahan pad: %d ms" % hold_ms, 26)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rh.add_child(hl)
	rh.add_child(_btn("+ 100", _adj_hold.bind(100), 24, 160.0))


func _set_theme(n: String) -> void:
	theme_name = n
	_apply_theme()
	_save()
	_show_settings()


func _toggle_sound() -> void:
	sound_on = not sound_on
	sfx.enabled = sound_on
	_save()
	_show_settings()


func _toggle_voice() -> void:
	voice_on = not voice_on
	_save()
	_show_settings()


func _toggle_orient() -> void:
	orient = 1 - orient
	_apply_orientation()
	_save()
	_show_settings()


func _toggle_stop() -> void:
	stop_both = not stop_both
	_save()
	_show_settings()


func _adj_hold(d: int) -> void:
	hold_ms = clampi(hold_ms + d, 100, 3000)
	_save()
	_show_settings()


# --- statistik

func _show_stats() -> void:
	_begin("Statistik | " + str(sessions[cur]["name"]), true)
	var n := solves.size()
	var worst := 0.0
	var sum := 0.0
	var cnt := 0
	for s in solves:
		var e := _eff(s)
		if not is_inf(e):
			worst = maxf(worst, e)
			sum += e
			cnt += 1
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 6)
	list_box.add_child(g)
	var rows := [
		["Jumlah solve", str(n)],
		["Best", "-" if is_inf(_best_val()) else _fmt(_best_val())],
		["Worst", "-" if cnt == 0 else _fmt(worst)],
		["Mean", "-" if cnt == 0 else _fmt(sum / cnt)],
	]
	for k in [5, 12, 50, 100]:
		rows.append(["Ao%d sekarang" % k, _fmt_f(_avg_at(n, k))])
		var b := _best_ao(k, n)
		rows.append(["Best Ao%d" % k, "-" if is_inf(b) else _fmt(b)])
	for r in rows:
		g.add_child(_lbl(r[0], 24, Color(0.65, 0.75, 0.85)))
		g.add_child(_lbl(r[1], 26))
	var start := maxi(0, n - 50)
	var vals: Array = []
	var ao: Array = []
	for i in range(start, n):
		vals.append(_eff(solves[i]))
		ao.append(_avg_at(i + 1, 5))
	list_box.add_child(_lbl("Grafik 50 solve terakhir (titik = solve, garis biru = Ao5)", 20, Color(0.6, 0.7, 0.8)))
	var chart := ChartScript.new()
	chart.custom_minimum_size = Vector2(1180, 300)
	chart.vals = vals
	chart.ao = ao
	list_box.add_child(chart)


# --- riwayat

func _show_history() -> void:
	_begin("Riwayat | " + str(sessions[cur]["name"]), true)
	if solves.is_empty():
		list_box.add_child(_lbl("Belum ada solve.", 26))
		return
	var shown := 0
	for i in range(solves.size() - 1, -1, -1):
		var s: Dictionary = solves[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var memo := float(s.get("memo", -1.0))
		var extra := "" if memo < 0.0 else "   (memo %s)" % _fmt(memo)
		var lbl := _lbl("#%d    %s%s" % [i + 1, _fmt_solve(s), extra], 28)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		row.add_child(_btn("+2", _toggle_pen.bind(i, 2), 22, 110.0))
		row.add_child(_btn("DNF", _toggle_pen.bind(i, -1), 22, 110.0))
		row.add_child(_btn("Hapus", _delete_solve.bind(i), 22, 130.0))
		list_box.add_child(row)
		shown += 1
		if shown >= 100:
			break


func _toggle_pen(i: int, val: int) -> void:
	var s: Dictionary = solves[i]
	s["pen"] = 0 if int(s["pen"]) == val else val
	_after_edit()


func _delete_solve(i: int) -> void:
	solves.remove_at(i)
	_after_edit()


func _after_edit() -> void:
	last_text = "0.000" if solves.is_empty() else _fmt_solve(solves[-1])
	_refresh_stats()
	_save()
	_show_history()


# --- data CSV

func _show_data() -> void:
	_begin("Data (CSV)", true)
	list_box.add_child(_lbl("Ekspor menyalin riwayat sesi aktif ke clipboard (format mirip csTimer)\ndan menyimpan file di folder data aplikasi.", 20, Color(0.6, 0.7, 0.8)))
	list_box.add_child(_btn("Ekspor sesi ini ke CSV", _do_export, 26))
	list_box.add_child(_lbl("Impor: salin teks CSV / daftar waktu (satu per baris) dari csTimer atau\nlainnya, lalu tekan tombol di bawah. Hasil masuk ke sesi aktif.", 20, Color(0.6, 0.7, 0.8)))
	list_box.add_child(_btn("Impor dari clipboard", _do_import, 26))
	if data_status != "":
		list_box.add_child(_lbl(data_status, 22, Color(0.5, 1.0, 0.6)))


func _cs_time(s: Dictionary) -> String:
	var pen := int(s["pen"])
	if pen == -1:
		return "DNF(%s)" % _fmt(float(s["t"]))
	if pen == 2:
		return _fmt(float(s["t"]) + 2.0) + "+"
	return _fmt(float(s["t"]))


func _do_export() -> void:
	var lines := PackedStringArray(["No.;Time;Comment;Scramble;Date"])
	for i in solves.size():
		var s: Dictionary = solves[i]
		lines.append("%d;%s;;%s;" % [i + 1, _cs_time(s), str(s["scr"]).replace("\n", " ")])
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	var nm := str(sessions[cur]["name"]).validate_filename()
	var path := "user://export_%s.csv" % nm
	var f := FileAccess.open(path, FileAccess.WRITE)
	var where := ""
	if f:
		f.store_string(text)
		where = "\nFile: " + ProjectSettings.globalize_path(path)
	data_status = "%d solve disalin ke clipboard.%s" % [solves.size(), where]
	_show_data()


func _parse_time(raw: String) -> Variant:
	var s := raw.strip_edges().replace("\"", "")
	if s == "":
		return null
	var pen := 0
	if s.begins_with("DNF"):
		pen = -1
		s = s.trim_prefix("DNF").trim_prefix("(").trim_suffix(")")
		if s == "":
			return {"t": 0.0, "pen": -1}
	elif s.ends_with("+"):
		pen = 2
		s = s.trim_suffix("+")
	var secs := 0.0
	if ":" in s:
		var p := s.split(":")
		if p.size() != 2 or not p[0].is_valid_int() or not p[1].is_valid_float():
			return null
		secs = int(p[0]) * 60.0 + float(p[1])
	else:
		if not s.is_valid_float():
			return null
		secs = float(s)
	if pen == 2:
		secs = maxf(0.0, secs - 2.0)
	return {"t": secs, "pen": pen}


func _do_import() -> void:
	var text := DisplayServer.clipboard_get()
	var added := 0
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l == "":
			continue
		var sep := ";" if ";" in l else ","
		var f := l.split(sep)
		var r: Variant = null
		if f.size() >= 3 and f[0].strip_edges().is_valid_int():
			r = _parse_time(f[1])
		else:
			r = _parse_time(f[0])
		if r != null:
			var scr: String = f[3].strip_edges() if f.size() >= 4 else ""
			r["scr"] = scr
			r["memo"] = -1.0
			solves.append(r)
			added += 1
	if added > 0:
		last_text = _fmt_solve(solves[-1])
		_refresh_stats()
		_save()
	data_status = "%d solve berhasil diimpor ke sesi aktif." % added if added > 0 else "Tidak ada waktu valid di clipboard."
	_show_data()


# ====================================================================
# Online: Host (HP 1) dan Remote Display (HP 2)
# ====================================================================

const RED_LED := Color(1.0, 0.1, 0.08)
const GREEN_LED := Color(0.2, 1.0, 0.4)
const AMBER_LED := Color(1.0, 0.55, 0.1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if remote_mode:
			_leave_remote()
		elif overlay != null and overlay.visible:
			_close_overlay()
		else:
			get_tree().quit()


func _apply_orientation() -> void:
	if remote_mode or orient == 1:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	else:
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)


func _update_keep_on() -> void:
	DisplayServer.screen_set_keep_on(remote_mode or (net.role == "host" and net.in_room()))


func _ui_tick(now: int) -> void:
	if online_screen and now >= next_ui and online_lbl != null and is_instance_valid(online_lbl):
		next_ui = now + 500
		online_lbl.text = net.summary()


# ---- Host: kirim status timer hanya saat berubah (bukan tiap frame)

func _net_snapshot() -> Dictionary:
	var phase := "idle"
	if state == State.HOLD:
		phase = "hold"
	elif state == State.READY:
		phase = "ready"
	elif state == State.RUNNING:
		phase = "run"
	elif inspecting:
		phase = "insp"
	var tag := ""
	if mode == 1:
		tag = "COUNTDOWN"
	elif mode == 2:
		tag = "MEMO" if bld_stage == 0 else "EKSEKUSI"
	var pb := ""
	if Time.get_ticks_msec() < pb_until:
		pb = pb_text
	return {"p": phase, "txt": last_text, "tag": tag, "m": mode, "lim": cd_limit,
		"ins": inspect_start_srv, "st": run_start_srv, "pb": pb}


func _net_sync() -> void:
	if net.role != "host" or not net.in_room() or not net.synced:
		last_push = ""
		return
	var d := _net_snapshot()
	var js := JSON.stringify(d)
	if js != last_push:
		last_push = js
		net.send_state(d)


# ---- Callback jaringan

func _on_net_phase() -> void:
	if net.role == "remote" and net.in_room() and not remote_mode:
		_enter_remote()
	if remote_mode and net.role != "remote":
		_leave_remote(false)
	_update_keep_on()
	if online_screen:
		_show_online()


func _on_net_error(msg: String) -> void:
	online_error = msg
	if online_screen:
		_show_online()


func _on_remote_state(s: Dictionary) -> void:
	remote_state = s


# ---- Layar Online

func _on_url_changed(t: String) -> void:
	url_text = t


func _on_code_changed(t: String) -> void:
	code_text = t


func _set_link(m: int) -> void:
	link_mode = m
	net = lan if m == 0 else net_inet
	online_error = ""
	_save()
	_show_online()


func _online_create() -> void:
	if link_mode == 0:
		online_error = ""
		net.start_host("")
		_show_online()
		return
	var u := url_text.strip_edges()
	if u == "":
		online_error = "Isi alamat server dulu (lihat DEPLOY.md)."
		_show_online()
		return
	server_url = u
	online_error = ""
	_save()
	net.start_host(u)
	_show_online()


func _online_join() -> void:
	var u := url_text.strip_edges()
	var code := code_text.strip_edges()
	if code.length() != 6 or not code.is_valid_int():
		online_error = "Room Code harus 6 angka."
	elif link_mode == 1 and u == "":
		online_error = "Isi alamat server dulu."
	else:
		online_error = ""
		if link_mode == 1:
			server_url = u
			_save()
		net.start_remote(u, code)
	_show_online()


func _online_stop() -> void:
	online_error = ""
	net.stop()
	_show_online()


func _copy_room() -> void:
	DisplayServer.clipboard_set(net.room)


func _show_online() -> void:
	_begin("Layar Remote (2 HP)", true)
	online_screen = true
	online_lbl = null
	var muted := Color(0.6, 0.7, 0.8)
	var acc: Color = th["ptxt"]
	if online_error != "":
		list_box.add_child(_lbl(online_error, 22, Color(1.0, 0.45, 0.4)))
	if net.role == "":
		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 10)
		list_box.add_child(mrow)
		mrow.add_child(_gbtn(("> " if link_mode == 0 else "") + "Wi-Fi / Hotspot (mudah)", _set_link.bind(0)))
		mrow.add_child(_gbtn(("> " if link_mode == 1 else "") + "Internet (server)", _set_link.bind(1)))
		if link_mode == 0:
			list_box.add_child(_lbl("Tanpa server dan tanpa internet. Dua HP di Wi-Fi yang sama, atau HP 2 disambungkan ke hotspot HP 1.", 20, muted))
			list_box.add_child(_btn("BUAT ROOM  (HP ini jadi Host)", _online_create, 28))
		else:
			list_box.add_child(_lbl("Untuk beda jaringan. Perlu server (lihat DEPLOY.md).", 20, muted))
			list_box.add_child(_lbl("Alamat server", 22))
			var le := LineEdit.new()
			le.text = url_text
			le.placeholder_text = "wss://nama-server-kamu.onrender.com"
			le.custom_minimum_size = Vector2(0, 64)
			le.add_theme_font_size_override("font_size", 24)
			le.text_changed.connect(_on_url_changed)
			list_box.add_child(le)
			list_box.add_child(_btn("CREATE ROOM  (HP ini jadi Host)", _online_create, 26))
		list_box.add_child(_lbl("Gabung ke HP Host: ketik Room Code", 22))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		list_box.add_child(row)
		var lc := LineEdit.new()
		lc.text = code_text
		lc.placeholder_text = "123456"
		lc.max_length = 6
		lc.custom_minimum_size = Vector2(0, 64)
		lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lc.add_theme_font_size_override("font_size", 28)
		lc.text_changed.connect(_on_code_changed)
		row.add_child(lc)
		row.add_child(_btn("GABUNG" if link_mode == 0 else "CONNECT", _online_join, 26, 220.0))
		list_box.add_child(_lbl("Status: " + net.status_text, 20, muted))
		return
	online_lbl = _lbl(net.summary(), 24, acc)
	list_box.add_child(online_lbl)
	if net.role == "host":
		if net.room != "":
			var code: String = str(net.room).substr(0, 3) + " " + str(net.room).substr(3)
			var big := _lbl(code, 110, acc)
			big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			list_box.add_child(big)
			list_box.add_child(_lbl("Di HP 2: Menu > Layar Remote > ketik kode ini > GABUNG.", 22, muted))
			if link_mode == 0:
				var ips: Array = lan.local_ips()
				if ips.is_empty():
					list_box.add_child(_lbl("HP ini belum tersambung ke Wi-Fi/hotspot.", 20, Color(1.0, 0.7, 0.3)))
				else:
					list_box.add_child(_lbl("IP HP ini: " + ", ".join(PackedStringArray(ips)), 20, muted))
			list_box.add_child(_btn("Salin kode", _copy_room, 26))
		else:
			list_box.add_child(_lbl("Membuat room...", 24))
		list_box.add_child(_btn("Tutup room", _online_stop, 26))
	else:
		if net.in_room():
			list_box.add_child(_btn("Buka layar remote", _enter_remote, 26))
		list_box.add_child(_btn("Putuskan", _online_stop, 26))


# ---- Mode Remote Display (tampilan Rubik Timer Stand)

func _enter_remote() -> void:
	remote_mode = true
	overlay.visible = false
	online_screen = false
	remote_ui_until = Time.get_ticks_msec() + 4000
	_apply_orientation()
	_update_keep_on()


func _leave_remote(stop_net: bool = true) -> void:
	remote_mode = false
	remote_state = {}
	if stop_net:
		net.stop()
	_apply_orientation()
	_update_keep_on()
	_show_online()


func _exit_rect() -> Rect2:
	return Rect2(size.x - 250.0, 24.0, 220.0, 70.0)


func _remote_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var hit := false
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			pos = t.position
			hit = true
	elif event is InputEventMouseButton and not OS.has_feature("mobile"):
		var m := event as InputEventMouseButton
		if m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			pos = m.position
			hit = true
	if not hit:
		return
	var now := Time.get_ticks_msec()
	if now < remote_ui_until and _exit_rect().has_point(pos):
		_leave_remote()
	else:
		remote_ui_until = now + 4000


# Waktu tampil dihitung dari timestamp mulai milik Host (jam server), bukan dari angka kiriman.
func _remote_display() -> Array:
	var s := remote_state
	if s.is_empty():
		return ["0.000", RED_LED]
	var p := str(s.get("p", "idle"))
	var m := int(s.get("m", 0))
	var lim := float(s.get("lim", 60))
	var now_s: float = net.server_now()
	if p == "run":
		var el := maxf(0.0, (now_s - float(s.get("st", now_s))) / 1000.0)
		if m == 1:
			return [_fmt(maxf(0.0, lim - el)), RED_LED]
		return [_fmt(el), RED_LED]
	if p == "insp":
		var el2 := (now_s - float(s.get("ins", now_s))) / 1000.0
		if el2 <= 15.0:
			return [str(int(ceil(maxf(0.0, 15.0 - el2)))), AMBER_LED]
		if el2 <= 17.0:
			return ["+2", AMBER_LED]
		return ["DNF", AMBER_LED]
	if p == "hold":
		return ["0.000", RED_LED]
	if p == "ready":
		return ["0.000", GREEN_LED]
	return [str(s.get("txt", "0.000")), RED_LED]


func _draw_remote() -> void:
	var font := ThemeDB.fallback_font
	var now := Time.get_ticks_msec()
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0))
	var disp := _remote_display()
	var txt: String = disp[0]
	var col: Color = disp[1]
	var area := Rect2(size.x * 0.03, size.y * 0.14, size.x * 0.94, size.y * 0.72)
	if _is_numeric(txt):
		_draw_seg_text(txt, area, col)
	else:
		var fs := int(size.y * 0.45)
		while fs > 40 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > area.size.x:
			fs -= 8
		draw_string(font, Vector2(area.position.x, area.position.y + area.size.y * 0.5 + fs * 0.35),
			txt, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, fs, col)
	var tag := str(remote_state.get("tag", ""))
	if net.role == "remote" and not net.in_room():
		tag = "MENGHUBUNGKAN ULANG..."
	elif net.role == "remote" and not net.host_online:
		tag = "HOST OFFLINE"
	var pb := str(remote_state.get("pb", ""))
	if pb != "" and tag == "":
		tag = pb
	if tag != "":
		draw_string(font, Vector2(0, size.y * 0.095), tag, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28,
			Color(col.r, col.g, col.b, 0.75))
	var a := clampf((remote_ui_until - now) / 400.0, 0.0, 1.0)
	if a > 0.0:
		draw_string(font, Vector2(0, size.y - 22.0), net.summary(), HORIZONTAL_ALIGNMENT_CENTER,
			size.x, 20, Color(0.6, 0.7, 0.8, a))
		exit_box.bg_color = Color(0.08, 0.10, 0.16, a)
		exit_box.border_color = Color(0.3, 0.85, 1.0, a)
		var r := _exit_rect()
		draw_style_box(exit_box, r)
		draw_string(font, Vector2(r.position.x, r.position.y + 44.0), "KELUAR",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color(0.85, 0.95, 1.0, a))


# ====================================================================
# Panduan langkah demi langkah
# ====================================================================

func _first_run() -> void:
	seen_guide = true
	_save()
	_show_guide("timer", 0)


func _guide_data() -> Dictionary:
	return {
		"timer": ["Cara pakai timer", [
			["Letakkan HP", "Taruh HP di meja dalam posisi landscape. Tempelkan telapak tangan kiri dan kanan di sisi layar, di atas gambar tangan."],
			["Tahan sampai hijau", "Tekan dan tahan kedua sisi. Tangan berubah merah dan cincin terisi. Tunggu sampai tangan dan cincin berwarna hijau (waktu tahan bisa diatur di Menu > Tema dan Suara)."],
			["Lepas untuk mulai", "Angkat kedua tangan. Timer langsung berjalan. Ambil cube dan mulai solve."],
			["Sentuh untuk berhenti", "Saat cube selesai, sentuh KEDUA sisi layar bersamaan. Waktu berhenti dan hasilnya tersimpan otomatis."],
			["Inspeksi 15 detik (opsional)", "Ketuk tombol play (segitiga) sebelum menahan layar. Hitung mundur 15 detik berjalan, lalu mulai seperti biasa. Lewat 15 detik kena +2, lewat 17 detik DNF. Tombol power menyalakan atau mematikan inspeksi."],
			["Scramble dan hasil", "Ketuk tulisan scramble di atas untuk scramble baru. Tombol disket membuka riwayat (+2, DNF, hapus). Tombol reset mengembalikan layar ke 0.000. Tombol garis tiga di kanan atas membuka menu."],
		]],
		"wifi": ["Sambungkan 2 HP (Wi-Fi / Hotspot)", [
			["Satukan jaringan", "Nyalakan hotspot di HP 1 lalu sambungkan HP 2 ke sana, atau pakai Wi-Fi yang sama. Tidak perlu server dan tidak perlu internet."],
			["HP 1: buat room", "Menu > Layar Remote > BUAT ROOM. Catat Room Code 6 angka yang muncul besar di layar."],
			["HP 2: gabung", "Menu > Layar Remote > ketik Room Code dari HP 1 > GABUNG."],
			["Tunggu tersambung", "HP 2 otomatis masuk tampilan Remote (layar hitam, angka merah). Di HP 1 jumlah remote bertambah."],
			["Mulai timer", "Pakai timer di HP 1 seperti biasa, HP 2 ikut menampilkan waktu. Di HP 2 ketuk layar lalu KELUAR untuk berhenti."],
		]],
		"inet": ["Sambungkan lewat Internet (server)", [
			["Siapkan server", "Mode ini butuh server relay. Ikuti file DEPLOY.md untuk memasangnya (mis. di Render). Hasilnya berupa alamat wss://..."],
			["Pilih mode Internet", "Menu > Layar Remote, lalu ketuk tombol Internet (server) di bagian atas."],
			["HP 1: buat room", "Isi alamat server, lalu ketuk CREATE ROOM. Catat Room Code."],
			["HP 2: gabung", "Isi alamat server yang sama dan Room Code, lalu ketuk CONNECT."],
			["Tunggu ping", "Tunggu sampai ping tampil di HP 1 (tanda jam sudah sinkron), lalu pakai timer seperti biasa."],
		]],
		"mode": ["Mode dan fitur lain", [
			["Countdown", "Menu > Mode, pilih Countdown dan atur batas waktu. Timer menghitung mundur; kalau habis otomatis DNF."],
			["BLD", "Pilih BLD. Tahan-lepas untuk mulai memorisasi, sentuh layar saat selesai memo, lalu tahan-lepas lagi untuk eksekusi. Waktu total = memo + eksekusi."],
			["Metronom", "Di Menu > Mode, nyalakan metronom dan atur BPM. Detak terdengar saat timer berjalan untuk melatih ritme."],
			["Sesi dan puzzle", "Menu > Sesi untuk membuat sesi terpisah. Menu > Puzzle untuk memilih 2x2 sampai Megaminx. Buat sesi baru tiap ganti puzzle supaya statistik tidak tercampur."],
			["Statistik dan data", "Menu > Statistik menampilkan Best, Ao5, Ao12, Ao50, Ao100 dan grafik. Menu > Data CSV untuk ekspor dan impor riwayat."],
		]],
		"tips": ["Tips dan masalah umum", [
			["Timer berhenti sendiri", "Timer baru berhenti kalau semua tangan sudah terangkat dulu, lalu KEDUA sisi layar disentuh. Kalau masih terlalu sensitif, ubah Berhenti dengan di Menu > Tema dan Suara."],
			["Hijau terlalu cepat atau lambat", "Menu > Tema dan Suara > Waktu tahan pad. Tambah atau kurangi dengan tombol - dan +."],
			["Host tidak ketemu", "Pastikan Room Code benar dan kedua HP satu jaringan. Wi-Fi umum sering memblokir antar-perangkat; nyalakan hotspot di HP 1 dan sambungkan HP 2 ke sana."],
			["Layar portrait", "Menu > Tema dan Suara > Orientasi layar, pilih Otomatis agar layar bisa diputar."],
			["Ganti tampilan", "Menu > Tema dan Suara punya 6 tema, termasuk Stackmat Asli dengan digit merah."],
		]],
	}


func _show_guides() -> void:
	_begin("Panduan", true)
	list_box.add_child(_lbl("Pilih panduan langkah demi langkah:", 22, Color(0.6, 0.7, 0.8)))
	var data := _guide_data()
	for key in ["timer", "wifi", "inet", "mode", "tips"]:
		var g: Array = data[key]
		var n: int = (g[1] as Array).size()
		list_box.add_child(_btn("%s  (%d langkah)" % [str(g[0]), n], _show_guide.bind(key, 0), 26))
	list_box.add_child(_btn("Tentang aplikasi", _show_about, 24))


func _show_guide(key: String, step: int = 0) -> void:
	var g: Array = _guide_data()[key]
	var steps: Array = g[1]
	step = clampi(step, 0, steps.size() - 1)
	var st: Array = steps[step]
	var acc: Color = th["ptxt"]
	_begin(str(g[0]), true)
	list_box.add_child(_lbl("Langkah %d dari %d" % [step + 1, steps.size()], 22, Color(0.6, 0.7, 0.8)))
	var t := _lbl(str(st[0]), 44, acc)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_child(t)
	var d := _lbl(str(st[1]), 28)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_child(d)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	list_box.add_child(row)
	var prev := _gbtn("< Sebelumnya", _show_guide.bind(key, step - 1))
	prev.disabled = step == 0
	row.add_child(prev)
	if step < steps.size() - 1:
		row.add_child(_gbtn("Berikutnya >", _show_guide.bind(key, step + 1)))
	else:
		row.add_child(_gbtn("Selesai", _show_guides))
		if key == "wifi":
			list_box.add_child(_btn("Buka Layar Remote", _show_online, 26))
		elif key == "inet":
			list_box.add_child(_btn("Buka Layar Remote (Internet)", _goto_inet, 26))


func _goto_inet() -> void:
	_set_link(1)
