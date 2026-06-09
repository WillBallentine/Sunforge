package core

import "core:sys/llvm"
import rl "vendor:raylib"

MAX_ACTIONS :: 128
Action_ID :: distinct u32

Action_State :: struct {
	key:               rl.KeyboardKey,
	controller_button: rl.GamepadButton,
	has_controller:    bool,
	pressed:           bool,
	held:              bool,
	released:          bool,
	_prev:             bool,
}

Mouse_State :: struct {
	position: rl.Vector2,
	delta:    rl.Vector2,
	wheel:    f32,
	left:     Action_State,
	right:    Action_State,
	middle:   Action_State,
}

Controller_Config :: struct {
	deadzone:          f32,
	trigger_threshold: f32,
	stick_threshold:   f32,
}

Controller_State :: struct {
	connected:     bool,
	config:        Controller_Config,
	buttons:       [32]Action_State,
	left_stick:    Stick_State,
	right_stick:   Stick_State,
	left_trigger:  Trigger_State,
	right_trigger: Trigger_State,
}

Stick_State :: struct {
	x:     f32,
	y:     f32,
	raw_x: f32,
	raw_y: f32,
}

Trigger_State :: struct {
	value:    f32,
	pressed:  bool,
	held:     bool,
	released: bool,
	_prev:    bool,
}

Input_State :: struct {
	actions:    [MAX_ACTIONS]Action_State,
	mouse:      Mouse_State,
	controller: Controller_State,
}

input_init :: proc(input: ^Input_State) {
	input.controller.config = Controller_Config {
		deadzone          = 0.15,
		trigger_threshold = 0.10,
		stick_threshold   = 0.50,
	}
}

input_bind_keyboard :: proc(input: ^Input_State, id: Action_ID, key: rl.KeyboardKey) {
	assert(int(id) < MAX_ACTIONS)
	input.actions[id].key = key
}

input_bind_controller :: proc(input: ^Input_State, id: Action_ID, button: rl.GamepadButton) {
	assert(int(id) < MAX_ACTIONS)
	input.actions[id].controller_button = button
	input.actions[id].has_controller = true
}

input_poll :: proc(input: ^Input_State) {
	for &action in input.actions {
		key_held := rl.IsKeyDown(action.key)
		pad_held := action.has_controller && rl.IsGamepadButtonDown(0, action.controller_button)
		action._prev = action.held
		action.held = key_held || pad_held
		action.pressed = action.held && !action._prev
		action.released = !action.held && action._prev
	}

	ct := &input.controller
	ct.connected = rl.IsGamepadAvailable(0)

	if ct.connected {
		for btn in rl.GamepadButton {
			state := &ct.buttons[int(btn)]
			state._prev = state.held
			state.held = rl.IsGamepadButtonDown(0, btn)
			state.pressed = state.held && !state._prev
			state.released = !state.held && state._prev
		}

		poll_stick :: proc(stick: ^Stick_State, raw_x, raw_y: f32, deadzone: f32) {
			stick.raw_x = raw_x
			stick.raw_y = raw_y
			magnitude := rl.Vector2Length({raw_x, raw_y})
			if magnitude < deadzone {
				stick.x = 0
				stick.y = 0
			} else {
				scale := (magnitude - deadzone) / (1.0 - deadzone)
				scale = min(scale, 1.0)
				stick.x = (raw_x / magnitude) * scale
				stick.y = (raw_y / magnitude) * scale
			}
		}

		poll_trigger :: proc(t: ^Trigger_State, raw: f32, threshold: f32) {
			t.value = clamp((raw + 1.0) / 2.0, 0, 1)
			t._prev = t.held
			t.held = t.value > threshold
			t.pressed = t.held && !t._prev
			t.released = !t.held && t._prev
		}

		poll_stick(
			&ct.left_stick,
			rl.GetGamepadAxisMovement(0, .LEFT_X),
			rl.GetGamepadAxisMovement(0, .LEFT_Y),
			ct.config.deadzone,
		)
		poll_stick(
			&ct.right_stick,
			rl.GetGamepadAxisMovement(0, .RIGHT_X),
			rl.GetGamepadAxisMovement(0, .RIGHT_Y),
			ct.config.deadzone,
		)
		poll_trigger(
			&ct.left_trigger,
			rl.GetGamepadAxisMovement(0, .LEFT_TRIGGER),
			ct.config.trigger_threshold,
		)
		poll_trigger(
			&ct.right_trigger,
			rl.GetGamepadAxisMovement(0, .RIGHT_TRIGGER),
			ct.config.trigger_threshold,
		)
	}


	input.mouse.position = rl.GetMousePosition()
	input.mouse.delta = rl.GetMouseDelta()
	input.mouse.wheel = rl.GetMouseWheelMove()

	input.mouse.left.pressed = rl.IsMouseButtonPressed(.LEFT)
	input.mouse.left.held = rl.IsMouseButtonDown(.LEFT)
	input.mouse.left.released = rl.IsMouseButtonReleased(.LEFT)

	input.mouse.right.pressed = rl.IsMouseButtonPressed(.RIGHT)
	input.mouse.right.held = rl.IsMouseButtonDown(.RIGHT)
	input.mouse.right.released = rl.IsMouseButtonReleased(.RIGHT)

	input.mouse.middle.pressed = rl.IsMouseButtonPressed(.MIDDLE)
	input.mouse.middle.held = rl.IsMouseButtonDown(.MIDDLE)
	input.mouse.middle.released = rl.IsMouseButtonReleased(.MIDDLE)
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

