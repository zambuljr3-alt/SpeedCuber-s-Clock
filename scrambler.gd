extends RefCounted
# Generator scramble (2x2-5x5, Pyraminx, Skewb, Megaminx, Clock) dan
# simulasi cube NxN (2x2-5x5) untuk preview net 2D.

const PUZZLES := ["2x2", "3x3", "4x4", "5x5", "Pyraminx", "Skewb", "Megaminx", "Clock"]
const MODS := ["", "'", "2"]

# Urutan face: U D R L F B
const NORMALS := [
	Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const RIGHTS := [
	Vector3i(1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, -1),
	Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
]
const DOWNS := [
	Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(0, -1, 0),
	Vector3i(0, -1, 0), Vector3i(0, -1, 0), Vector3i(0, -1, 0),
]
const FACE_X := [1, 1, 2, 0, 1, 3]
const FACE_Y := [0, 2, 1, 1, 1, 1]
const COLORS := [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.85, 0.0), Color(0.85, 0.1, 0.1),
	Color(1.0, 0.5, 0.0), Color(0.1, 0.7, 0.2), Color(0.1, 0.3, 0.9),
]


static func cube_size(puzzle: String) -> int:
	match puzzle:
		"2x2":
			return 2
		"3x3":
			return 3
		"4x4":
			return 4
		"5x5":
			return 5
	return 0


static func generate(puzzle: String) -> String:
	match puzzle:
		"2x2":
			return _cube(9, ["R", "U", "F"], [])
		"3x3":
			return _cube(20, ["U", "D", "R", "L", "F", "B"], [])
		"4x4":
			return _cube(40, ["U", "D", "R", "L", "F", "B"], ["Rw", "Uw", "Fw"])
		"5x5":
			return _cube(60, ["U", "D", "R", "L", "F", "B"], ["Rw", "Uw", "Fw"])
		"Pyraminx":
			return _pyraminx()
		"Skewb":
			return _skewb()
		"Megaminx":
			return _megaminx()
		"Clock":
			return _clock()
	return _cube(20, ["U", "D", "R", "L", "F", "B"], [])


static func _cube(n: int, faces: Array, wide: Array) -> String:
	var axis := {"U": 0, "D": 0, "R": 1, "L": 1, "F": 2, "B": 2}
	var pool: Array = []
	pool.append_array(faces)
	pool.append_array(wide)
	var out := PackedStringArray()
	var last := ""
	var last2 := ""
	while out.size() < n:
		var tok: String = pool[randi() % pool.size()]
		var f: String = tok.substr(0, 1)
		if f == last:
			continue
		if last != "" and last2 != "" and axis[f] == axis[last] and axis[last] == axis[last2]:
			continue
		var m: String = MODS[randi() % 3]
		out.append(tok + m)
		last2 = last
		last = f
	return " ".join(out)


static func _pyraminx() -> String:
	var out := PackedStringArray()
	var faces := ["U", "L", "R", "B"]
	var last := ""
	while out.size() < 10:
		var f: String = faces[randi() % 4]
		if f == last:
			continue
		out.append(f + ("'" if randi() % 2 == 0 else ""))
		last = f
	for t in ["l", "r", "b", "u"]:
		var r := randi() % 3
		if r == 1:
			out.append(t)
		elif r == 2:
			out.append(t + "'")
	return " ".join(out)


static func _skewb() -> String:
	var out := PackedStringArray()
	var faces := ["R", "L", "U", "B"]
	var last := ""
	while out.size() < 11:
		var f: String = faces[randi() % 4]
		if f == last:
			continue
		out.append(f + ("'" if randi() % 2 == 0 else ""))
		last = f
	return " ".join(out)


static func _megaminx() -> String:
	var lines := PackedStringArray()
	for _l in 7:
		var parts := PackedStringArray()
		for _i in 5:
			parts.append("R" + ("++" if randi() % 2 == 0 else "--"))
			parts.append("D" + ("++" if randi() % 2 == 0 else "--"))
		parts.append("U" if randi() % 2 == 0 else "U'")
		lines.append(" ".join(parts))
	return "\n".join(lines)


static func _clk(p: String) -> String:
	var n := randi() % 12 - 5
	return "%s%d%s" % [p, absi(n), "+" if n >= 0 else "-"]


static func _clock() -> String:
	var parts := PackedStringArray()
	for p in ["UR", "DR", "DL", "UL", "U", "R", "D", "L", "ALL"]:
		parts.append(_clk(p))
	parts.append("y2")
	for p in ["U", "R", "D", "L", "ALL"]:
		parts.append(_clk(p))
	for p in ["UR", "DR", "DL", "UL"]:
		if randi() % 2 == 0:
			parts.append(p)
	return " ".join(parts)


# ------------------------------------------------------------ cube sim

static func _plane_axes(nv: Vector3i) -> Array:
	if nv.x != 0:
		return [Vector3i(0, 1, 0), Vector3i(0, 0, 1)]
	if nv.y != 0:
		return [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]
	return [Vector3i(1, 0, 0), Vector3i(0, 1, 0)]


static func solved_state(n: int) -> Array:
	var st: Array = []
	for fi in 6:
		var nv: Vector3i = NORMALS[fi]
		var axes: Array = _plane_axes(nv)
		var a0: Vector3i = axes[0]
		var a1: Vector3i = axes[1]
		for i in n:
			for j in n:
				var pos: Vector3i = nv * n + a0 * (2 * i - (n - 1)) + a1 * (2 * j - (n - 1))
				st.append([pos, nv, fi])
	return st


static func _rot(v: Vector3i, axis: int, k: int) -> Vector3i:
	match axis:
		0:
			return Vector3i(v.x, -v.z * k, v.y * k)
		1:
			return Vector3i(v.z * k, v.y, -v.x * k)
	return Vector3i(-v.y * k, v.x * k, v.z)


static func apply(st: Array, n: int, token: String) -> void:
	var t := token
	var depth := 1
	if t.length() > 0 and t.substr(0, 1).is_valid_int():
		depth = int(t.substr(0, 1))
		t = t.substr(1)
	var face := t.substr(0, 1)
	var rest := t.substr(1)
	if rest.begins_with("w"):
		if depth == 1:
			depth = 2
		rest = rest.substr(1)
	var turns := 1
	if rest == "2":
		turns = 2
	elif rest == "'":
		turns = 3
	var fi := ["U", "D", "R", "L", "F", "B"].find(face)
	if fi < 0:
		return
	var nv: Vector3i = NORMALS[fi]
	var axis := 0
	if nv.y != 0:
		axis = 1
	elif nv.z != 0:
		axis = 2
	var s := nv.x + nv.y + nv.z
	var thr := n - 1 - 2 * (depth - 1)
	for _k in turns:
		for e in st:
			var p: Vector3i = e[0]
			if p[axis] * s >= thr:
				var q: Vector3i = e[1]
				e[0] = _rot(p, axis, -s)
				e[1] = _rot(q, axis, -s)


# Hasil: list [gx, gy, warna, face_x, face_y] untuk digambar sebagai net.
static func preview(puzzle: String, scr: String) -> Array:
	var n := cube_size(puzzle)
	if n == 0:
		return []
	var st := solved_state(n)
	for tok in scr.split(" ", false):
		apply(st, n, tok)
	var out: Array = []
	for e in st:
		var p: Vector3i = e[0]
		var nv: Vector3i = e[1]
		var fi := NORMALS.find(nv)
		if fi < 0:
			continue
		var r: Vector3i = RIGHTS[fi]
		var d: Vector3i = DOWNS[fi]
		var col := (p.x * r.x + p.y * r.y + p.z * r.z + n - 1) >> 1
		var row := (p.x * d.x + p.y * d.y + p.z * d.z + n - 1) >> 1
		var fx: int = FACE_X[fi]
		var fy: int = FACE_Y[fi]
		out.append([fx * n + col, fy * n + row, e[2], fx, fy])
	return out
