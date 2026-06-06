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
	world_target:    eng.Render_Target,
	ui_target:       eng.Render_Target,
	camera:          rl.Camera2D,
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
	s := cast(^Title_State)data

	s.world_target = eng.renderer_make_target(&e.renderer)
	s.ui_target = eng.renderer_make_target(&e.renderer)

	s.camera = rl.Camera2D {
		offset = {f32(e.renderer.width) / 2, f32(e.renderer.height) / 2},
		target = {0, 0},
		zoom   = 1.0,
	}
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

	eng.renderer_begin_target(s.world_target)
	eng.renderer_clear(rl.BLACK)
	eng.renderer_begin_camera(s.camera)
	eng.renderer_draw_text(cstring("hello world"), i32(50), i32(50), i32(100), rl.BLUE)
	eng.renderer_draw_circle(rl.Vector2(10), f32(100.00), rl.WHITE)
	eng.renderer_end_camera()
	eng.renderer_end_target()

	eng.renderer_begin_target(s.ui_target)
	eng.renderer_clear({0, 0, 0, 0})
	eng.renderer_draw_text(cstring("hello ui"), i32(90), i32(90), i32(100), rl.GREEN)
	eng.renderer_draw_rect(rl.Rectangle{f32(150), f32(15), f32(25), f32(25)}, f32(25), rl.GREEN)
	eng.renderer_end_target()

	eng.renderer_blit(&e.renderer, s.world_target)
	eng.renderer_blit(&e.renderer, s.ui_target)
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

	rl.DrawText("Sunforge Testing", 800, 90, 48, rl.GREEN)

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
	s := cast(^Title_State)data

	eng.renderer_destroy_target(s.world_target)
	eng.renderer_destroy_target(s.ui_target)
	free(data)
}

