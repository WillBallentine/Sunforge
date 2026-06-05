package core

import rl "vendor:raylib"

MAX_ACTIONS :: 128
Action_ID :: distinct u32

Action_State :: struct {
	key:      rl.KeyboardKey,
	pressed:  bool,
	held:     bool,
	released: bool,
}

Mouse_State :: struct {
	position: rl.Vector2,
	delta:    rl.Vector2,
	wheel:    f32,
	left:     Action_State,
	right:    Action_State,
	middle:   Action_State,
}

Input_State :: struct {
	actions: [MAX_ACTIONS]Action_State,
	mouse:   Mouse_State,
}

input_init :: proc(input: ^Input_State) {}

input_bind :: proc(input: ^Input_State, id: Action_ID, key: rl.KeyboardKey) {
	assert(int(id) < MAX_ACTIONS)
	input.actions[id].key = key
}

input_poll :: proc(input: ^Input_State) {
	for &action in input.actions {
		action.pressed = rl.IsKeyPressed(action.key)
		action.held = rl.IsKeyDown(action.key)
		action.released = rl.IsKeyReleased(action.key)
	}

	input.mouse.position = rl.GetMousePosition()
	input.mouse.delta = rl.GetMouseDelta()
	input.mouse.wheel = rl.GetMouseWheelMove()

	poll_button :: proc(s: ^Action_State, btn: rl.MouseButton) {
		s.pressed = rl.IsMouseButtonPressed(btn)
		s.held = rl.IsMouseButtonDown(btn)
		s.released = rl.IsMouseButtonReleased(btn)
	}

	poll_button(&input.mouse.left, .LEFT)
	poll_button(&input.mouse.right, .RIGHT)
	poll_button(&input.mouse.middle, .MIDDLE)
}

input_pressed :: proc(input: ^Input_State, id: Action_ID) -> bool {
	return input.actions[id].pressed
}
input_held :: proc(input: ^Input_State, id: Action_ID) -> bool {
	return input.actions[id].held
}
input_released :: proc(input: ^Input_State, id: Action_ID) -> bool {
	return input.actions[id].released
}


input_key_pressed :: proc(key: rl.KeyboardKey) -> bool {
	return rl.IsKeyPressed(key)
}
input_key_held :: proc(key: rl.KeyboardKey) -> bool {
	return rl.IsKeyDown(key)
}
input_key_released :: proc(key: rl.KeyboardKey) -> bool {
	return rl.IsKeyReleased(key)
}

