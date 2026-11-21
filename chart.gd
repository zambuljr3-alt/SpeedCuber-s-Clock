extends Control
# Grafik waktu solve: titik = solve, garis biru = Ao5, titik merah = DNF.

var vals: Array = []  # float, INF = DNF
var ao: Array = []    # float, <0 = belum ada, INF = DNF


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.10, 0.13))
	var n := vals.size()
	if n < 2:
		draw_string(font, Vector2(0, h * 0.5), "Butuh minimal 2 solve untuk grafik",
			HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(0.6, 0.65, 0.7))
		return
	var lo := INF
	var hi := 0.0
	for v in vals:
		if not is_inf(v):
			lo = minf(lo, v)
			hi = maxf(hi, v)
	if is_inf(lo):
		return
	if hi - lo < 0.5:
		hi = lo + 0.5
	var left := 60.0
	var top := 24.0
	var bottom := h - 24.0
	var pts := PackedVector2Array()
	for i in n:
		var x := left + (w - left - 20.0) * float(i) / float(n - 1)
		if is_inf(vals[i]):
			draw_circle(Vector2(x, top - 8.0), 4.0, Color(1.0, 0.3, 0.25))
		else:
			var y: float = bottom - (bottom - top) * (float(vals[i]) - lo) / (hi - lo)
			draw_circle(Vector2(x, y), 4.0, Color(0.9, 0.95, 1.0))
		var a: float = ao[i]
		if a >= 0.0 and not is_inf(a):
			var ya := bottom - (bottom - top) * (clampf(a, lo, hi) - lo) / (hi - lo)
			pts.append(Vector2(x, ya))
	if pts.size() >= 2:
		draw_polyline(pts, Color(0.3, 0.65, 1.0), 3.0, true)
	draw_line(Vector2(left, top), Vector2(w - 10.0, top), Color(1, 1, 1, 0.12), 1.0)
	draw_line(Vector2(left, bottom), Vector2(w - 10.0, bottom), Color(1, 1, 1, 0.12), 1.0)
	draw_string(font, Vector2(4, top + 6.0), "%.2f" % hi, HORIZONTAL_ALIGNMENT_LEFT, 56, 16, Color(0.6, 0.65, 0.7))
	draw_string(font, Vector2(4, bottom + 6.0), "%.2f" % lo, HORIZONTAL_ALIGNMENT_LEFT, 56, 16, Color(0.6, 0.65, 0.7))
