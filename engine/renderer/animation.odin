package renderer

// i need to take in the texture, the starting sprite, the ending sprite, the speed

import rl "vendor:raylib"

Animation :: struct {
	texture:           rl.Texture2D,
	first_frame_index: i32,
	frame_w:           i32,
	frame_h:           i32,
	frame_count:       i32,
	columns:           i32,
	fps:               f32,
	looping:           bool,
}

Animation_State :: struct {
	anim:          ^Animation,
	current_frame: i32,
	timer:         f32,
	paused:		bool,
	finished:      bool,
}

animation_state_create :: proc(anim: ^Animation) -> Animation_State {
	return Animation_State{anim = anim, current_frame = 0, timer = 0, paused = false, finished = false}
}

animation_state_update :: proc(state: ^Animation_State, dt: f32) {
	if state.finished || state.paused do return
	if state.anim.fps <= 0 do return
	if state.anim == nil do return
	if state.anim.frame_count <= 0 do return

	frame_duration := 1.0 / state.anim.fps
	state.timer += dt

	for state.timer >= frame_duration {
		state.timer -= frame_duration
		state.current_frame += 1

		if state.current_frame >= state.anim.frame_count {
			if state.anim.looping {
				state.current_frame = 0
			} else {
				state.current_frame = state.anim.frame_count - 1
				state.finished = true
				return
			}
		}
	}
}

animation_state_get_sprite :: proc(state: ^Animation_State) -> Sprite {
	if state.anim == nil do return {}

	return get_sprite(
		state.anim.texture,
		state.anim.frame_w,
		state.anim.frame_h,
		state.anim.first_frame_index + state.current_frame,
		state.anim.columns,
	)
}

animation_state_reset :: proc(state: ^Animation_State) {
	state.current_frame = 0
	state.paused = false
	state.finished = false
	state.timer = 0
}

