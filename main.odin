package main

import eng "./engine"
import "core:fmt"
import rl "vendor:raylib"

Game_Action :: enum u32 {
	Move_Left,
	Move_Right,
	Jump,
	Confirm,
	Back,
}

act :: #force_inline proc(a: Game_Action) -> eng.Action_ID {
	return eng.Action_ID(a)
}

main :: proc() {
	eng.run(
		eng.Engine_Config {
			window = eng.Window_Config {
				width = 1280,
				height = 720,
				title = "test",
				target_fps = 60,
			},
		},
		title_screen(),
	)
}

Title_State :: struct {
	timer:           f32,
	confirm_pressed: bool,
	mouse_pos:       rl.Vector2,
	mouse_delta:     rl.Vector2,
}

title_screen :: proc() -> eng.Scene_Procs {
	state := new(Title_State)
	return eng.Scene_Procs {
		data = state,
		init = title_init,
		update = title_update,
		render = title_render,
		destroy = title_destroy,
	}
}

title_init :: proc(e: ^eng.Engine, data: rawptr) {
	eng.input_bind(&e.input, act(.Move_Left), .A)
	eng.input_bind(&e.input, act(.Confirm), .ENTER)
}

title_update :: proc(e: ^eng.Engine, data: rawptr, dt: f32) {
	s := cast(^Title_State)data
	s.timer += dt
	s.mouse_pos = e.input.mouse.position

	s.mouse_delta = e.input.mouse.delta

	if eng.input_pressed(&e.input, act(.Confirm)) {
		s.confirm_pressed = true
	}
}

title_render :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Title_State)data
	rl.ClearBackground(rl.BLACK)

	//debug inputs
	//keyboard
	rl.DrawText(fmt.ctprintf("pressed: %v", e.input.actions[3].pressed), 10, 30, 16, rl.YELLOW)
	rl.DrawText(fmt.ctprintf("held: %v", e.input.actions[3].held), 10, 50, 16, rl.YELLOW)
	rl.DrawText(fmt.ctprintf("released: %v", e.input.actions[3].released), 10, 70, 16, rl.YELLOW)

	//mouse
	rl.DrawText(
		fmt.ctprintf("left mouse pressed: %v", e.input.mouse.left.pressed),
		10,
		200,
		16,
		rl.YELLOW,
	)
	rl.DrawText(
		fmt.ctprintf("left mouse held: %v", e.input.mouse.left.held),
		10,
		220,
		16,
		rl.YELLOW,
	)
	rl.DrawText(
		fmt.ctprintf("left mouse released: %v", e.input.mouse.left.released),
		10,
		240,
		16,
		rl.YELLOW,
	)
	//end debug inputs

	rl.DrawText("Sunforge Testing", 480, 300, 48, rl.GREEN)

	rl.DrawText(fmt.ctprintf("mouse pos: %v", s.mouse_pos), 10, 100, 16, rl.YELLOW)
	rl.DrawText(fmt.ctprintf("mouse delta: %v", s.mouse_delta), 10, 140, 16, rl.YELLOW)
	rl.DrawText(
		fmt.ctprintf("mouse pressed: %v", e.input.mouse.left.pressed),
		10,
		120,
		16,
		rl.YELLOW,
	)
	rl.DrawText(fmt.ctprintf("mouse held: %v", e.input.mouse.left.held), 10, 160, 16, rl.YELLOW)
	rl.DrawText(
		fmt.ctprintf("mouse released: %v", e.input.mouse.left.released),
		10,
		180,
		16,
		rl.YELLOW,
	)
	rl.DrawText(fmt.ctprintf("mouse wheel: %v", e.input.mouse.wheel), 10, 260, 16, rl.YELLOW)
}

title_destroy :: proc(e: ^eng.Engine, data: rawptr) {
	free(data)
}

