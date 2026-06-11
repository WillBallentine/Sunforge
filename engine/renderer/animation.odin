package renderer

// i need to take in the texture, the starting sprite, the ending sprite, the speed

import rl "vendor:raylib"

MAX_FRAME_EVENTS := 16

Animation :: struct {
	texture:           rl.Texture2D,
	first_frame_index: i32,
	frame_w:           i32,
	frame_h:           i32,
	frame_count:       i32,
	columns:           i32,
	fps:               f32,
	looping:           bool,
	frame_events:      [MAX_FRAME_EVENTS]Frame_Event,
	event_count:       i32,
}

Animation_State :: struct {
	anim:          ^Animation,
	current_frame: i32,
	timer:         f32,
	paused:        bool,
	fired_event: u32,
	speed: f32,
	finished:      bool,
}

//export this to the engine package
FRAME_EVENT_TAG_NONE := 0

Frame_Event :: struct {
	frame: i32,
	tag: u32,
}

animation_state_create :: proc(anim: ^Animation) -> Animation_State {
	return Animation_State {
		anim = anim,
		current_frame = 0,
		timer = 0,
		paused = false,
		fired_event = FRAME_EVENT_TAG_NONE,
		speed = 1.0,
		finished = false,
	}
}

check_frame_event :: proc(anim: ^Animation, frame: i32) -> u32 {
	if anim == nil do return FRAME_EVENT_TAG_NONE
	for i in 0 .. anim.event_count {
		if anim.frame_events[i].frame == frame do return anim.frame_events[i].tag
	}
	return FRAME_EVENT_TAG_NONE
}

animation_state_update :: proc(state: ^Animation_State, dt: f32) {
	state.fired_event = FRAME_EVENT_TAG_NONE
	if state.anim == nil do return
	if state.finished || state.paused do return
	if state.anim.fps <= 0 do return
	if state.anim.frame_count <= 0 do return


	frame_duration := 1.0 / state.anim.fps
	effective_dt := dt * state.speed
	state.timer += effective_dt

	for state.timer >= frame_duration {
		state.timer -= frame_duration
		state.current_frame += 1

		if state.current_frame >= state.anim.frame_count {
			if state.anim.looping {
				state.current_frame = 0
				if tag := check_frame_event(state.anim, state.current_frame); tag != FRAME_EVENT_TAG_NONE {
					state.fired_event = tag
				}
			} else {
				state.current_frame = state.anim.frame_count - 1
				state.finished = true
				return
			}
		} else {
			if tag := check_frame_event(state.anim, state.current_frame); tag != FRAME_EVENT_TAG_NONE {
				state.fired_event = tag
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

