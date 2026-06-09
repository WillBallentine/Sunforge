package core

import rl "vendor:raylib"

Window_Config :: struct {
	width:         i32,
	height:        i32,
	title:         cstring,
	target_fps:    i32,
	is_resizeable: bool,
}

Window_State :: struct {
	width:         i32,
	height:        i32,
	target_fps:    i32,
	is_resizeable: bool,
}

window_init :: proc(w: ^Window_State, config: Window_Config) {
	w.width = config.width
	w.height = config.height
	w.target_fps = config.target_fps
	w.is_resizeable = config.is_resizeable

	if config.is_resizeable {
		rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_ALWAYS_RUN})
	}

	rl.InitWindow(config.width, config.height, config.title)
	rl.SetTargetFPS(config.target_fps)
}

window_toggle_fullscreen :: proc(w: ^Window_State) {
	if !w.is_resizeable do return
	rl.ToggleFullscreen()
	w.width = rl.GetScreenWidth()
	w.height = rl.GetScreenHeight()
}

window_set_size :: proc(w: ^Window_State, width, height: i32) {
	if !w.is_resizeable do return
	w.width = width
	w.height = height
	rl.SetWindowSize(w.width, w.height)
}

window_handle_resize :: proc(wstate: ^Window_State, w, h: i32) {
	if !wstate.is_resizeable do return

	wstate.width = w
	wstate.height = h
	rl.SetWindowSize(wstate.width, wstate.height)
}

window_shutdown :: proc(w: ^Window_State) {
	rl.CloseWindow()
}

window_should_close :: proc(w: ^Window_State) -> bool {
	return rl.WindowShouldClose()
}

