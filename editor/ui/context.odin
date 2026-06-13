package editorui

import engCore "../../engine/core"
import rl "vendor:raylib"

UI_Context :: struct {
	mouse_pos:      rl.Vector2,
	mouse_delta:    rl.Vector2,
	mouse_pressed:  bool,
	mouse_held:     bool,
	mouse_released: bool,
	active:         rawptr,
	active_combo:   rawptr,
}

ctx: UI_Context

ui_begin :: proc(input: ^engCore.Input_State) {
	ctx.mouse_pos = input.mouse.position
	ctx.mouse_delta = input.mouse.delta
	ctx.mouse_pressed = input.mouse.left.pressed
	ctx.mouse_held = input.mouse.left.held
	ctx.mouse_released = input.mouse.left.released
}

