extends Control
# Ikon sederhana untuk kartu menu (digambar lewat kode).

var kind := ""
var col := Color(0.4, 0.8, 1.0)


func _draw() -> void:
	var c := size * 0.5
	var u := minf(size.x, size.y) * 0.34
	var lw := maxf(3.0, u * 0.1)
	var soft := Color(col.r, col.g, col.b, 0.5)
	match kind:
		"sesi":
			for i in 3:
				var y := c.y + (i - 1) * u * 0.75
				draw_rect(Rect2(c.x - u, y - u * 0.2, u * 2.0, u * 0.4), col if i == 1 else soft)
		"puzzle":
			var cs := u * 0.62
			var pal := [Color(1, 1, 1), Color(0.9, 0.15, 0.15), Color(0.1, 0.7, 0.25),
				Color(1, 0.85, 0), Color(0.1, 0.35, 0.95), Color(1, 0.5, 0)]
			for r in 3:
				for k in 3:
					draw_rect(Rect2(c.x - cs * 1.5 + k * cs + 1.5, c.y - cs * 1.5 + r * cs + 1.5,
						cs - 3.0, cs - 3.0), pal[(r * 3 + k) % 6])
		"mode":
			var cc := c + Vector2(0, u * 0.12)
			draw_arc(cc, u * 0.85, 0.0, TAU, 48, col, lw, true)
			draw_line(cc, cc + Vector2(u * 0.4, -u * 0.35), col, lw, true)
			draw_rect(Rect2(c.x - u * 0.2, c.y - u * 1.02, u * 0.4, u * 0.17), col)
		"stat":
			var hs := [0.5, 1.0, 0.7, 1.3]
			for i in 4:
				var h: float = hs[i] * u
				draw_rect(Rect2(c.x - u + i * u * 0.52, c.y + u * 0.8 - h, u * 0.36, h), col if i == 1 else soft)
		"riwayat":
			for i in 3:
				var y2 := c.y + (i - 1) * u * 0.7
				draw_circle(Vector2(c.x - u * 0.85, y2), u * 0.12, col)
				draw_line(Vector2(c.x - u * 0.55, y2), Vector2(c.x + u * 0.95, y2), col, lw, true)
		"tema":
			draw_arc(c, u * 0.9, 0.0, TAU, 48, col, lw, true)
			var dots := [Color(1, 0.3, 0.3), Color(0.3, 0.9, 0.4), Color(0.3, 0.6, 1.0)]
			for i in 3:
				var a := -PI * 0.5 + i * TAU / 3.0
				draw_circle(c + Vector2(cos(a), sin(a)) * u * 0.45, u * 0.2, dots[i])
		"data":
			draw_rect(Rect2(c.x - u * 0.6, c.y - u * 0.95, u * 1.2, u * 1.6), col, false, lw)
			draw_line(Vector2(c.x, c.y - u * 0.5), Vector2(c.x, c.y + u * 0.1), col, lw, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - u * 0.3, c.y), Vector2(c.x + u * 0.3, c.y), Vector2(c.x, c.y + u * 0.4)]), col)
		"online":
			var o := c + Vector2(0, u * 0.55)
			draw_circle(o, u * 0.13, col)
			for i in 3:
				draw_arc(o, u * (0.5 + i * 0.4), deg_to_rad(-135), deg_to_rad(-45), 24, col if i < 2 else soft, lw, true)
		"panduan":
			draw_arc(c + Vector2(0, -u * 0.35), u * 0.5, deg_to_rad(-200), deg_to_rad(40), 24, col, lw * 1.3, true)
			draw_line(c + Vector2(u * 0.3, -u * 0.05), c + Vector2(0, u * 0.25), col, lw * 1.3, true)
			draw_line(c + Vector2(0, u * 0.25), c + Vector2(0, u * 0.4), col, lw * 1.3, true)
			draw_circle(c + Vector2(0, u * 0.8), u * 0.13, col)
		"info":
			draw_arc(c, u * 0.9, 0.0, TAU, 48, col, lw, true)
			draw_circle(c + Vector2(0, -u * 0.45), u * 0.12, col)
			draw_line(c + Vector2(0, -u * 0.15), c + Vector2(0, u * 0.5), col, lw * 1.4, true)
