package core

import "core:math"

Vec2 :: [2]f32

vec2 :: proc(x, y: f32) -> Vec2 {return {x, y}}
vec2_zero :: proc() -> Vec2 {return {0, 0}}

vec2_add :: proc(a, b: Vec2) -> Vec2 {return {a.x + b.x, a.y + b.y}}
vec2_sub :: proc(a, b: Vec2) -> Vec2 {return {a.x - b.x, a.y - b.y}}
vec2_scale :: proc(v: Vec2, s: f32) -> Vec2 {return {v.x * s, v.y * s}}
vec2_length :: proc(v: Vec2) -> f32 {return math.sqrt(v.x * v.x + v.y * v.y)}


Rect :: struct {
	x, y, w, h: f32,
}

rect_contains :: proc(r: Rect, point: Vec2) -> bool {
	return point.x >= r.x && point.x <= r.x + r.w && point.y >= r.y && point.y <= r.y + r.h
}

lerp :: proc(a, b, t: f32) -> f32 {
	return a + (b - a) * t
}

clamp :: proc(v, lo, hi: f32) -> f32 {
	if v < lo {return lo}
	if v > hi {return hi}
	return v
}

