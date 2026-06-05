package main

import eng "./engine"
import rl "vendor:raylib"

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
	timer: f32,
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
	s.timer = 0
}

title_update :: proc(e: ^eng.Engine, data: rawptr, dt: f32) {
	s := cast(^Title_State)data
	s.timer += dt
}

title_render :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Title_State)data
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.DrawText("we used the engine", 480, 300, 48, rl.WHITE)
	_ = s
	rl.EndDrawing()
}

title_destroy :: proc(e: ^eng.Engine, data: rawptr) {
	free(data)
}

