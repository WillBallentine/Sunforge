package core

import rl "vendor:raylib"

Clock_State :: struct {
	delta_time:  f32,
	total_time:  f32,
	frame_count: u64,
}

clock_init :: proc(c: ^Clock_State) {
	c.delta_time = 0
	c.total_time = 0
	c.frame_count = 0
}

clock_tick :: proc(c: ^Clock_State) {
	c.delta_time = min(rl.GetFrameTime(), 0.1)
	c.total_time += c.delta_time
	c.frame_count += 1
}

