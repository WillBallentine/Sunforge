package core

import rl "vendor:raylib"

Window_Config :: struct {
	width:      i32,
	height:     i32,
	title:      cstring,
	target_fps: i32,
}

Window_State :: struct {
	width:      i32,
	height:     i32,
	target_fps: i32,
}

window_init :: proc(w: ^Window_State, config: Window_Config) {
	w.width = config.width
	w.height = config.height
	w.target_fps = config.target_fps

	rl.InitWindow(config.width, config.height, config.title)
	rl.SetTargetFPS(config.target_fps)
}

window_shutdown :: proc(w: ^Window_State) {
	rl.CloseWindow()
}

window_should_close :: proc(w: ^Window_State) -> bool {
	return rl.WindowShouldClose()
}

