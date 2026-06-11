package renderer

import rl "vendor:raylib"

Font_ID :: distinct u32

Font_State :: struct {
	fonts:   map[Font_ID]rl.Font,
	next_id: Font_ID,
}

font_init :: proc(state: ^Font_State) {
	state.fonts = make(map[Font_ID]rl.Font)
	state.next_id = 1
}

load_font :: proc(state: ^Font_State, path: cstring, size: i32) -> Font_ID {
	font := rl.LoadFontEx(path, size, nil, 0)
	id := state.next_id
	state.fonts[id] = font
	state.next_id += 1
	return id
}

unload_font :: proc(state: ^Font_State, id: Font_ID) {
	_, ok := state.fonts[id]; if !ok do return
	rl.UnloadFont(state.fonts[id])
	delete_key(&state.fonts, id)
}

draw_font :: proc(
	state: ^Font_State,
	id: Font_ID,
	text: cstring,
	pos: rl.Vector2,
	size: f32,
	spacing: f32,
	color: rl.Color,
) {
	_, ok := state.fonts[id]; if !ok do return
	rl.DrawTextEx(state.fonts[id], text, pos, size, spacing, color)
}

measure_font :: proc(
	state: ^Font_State,
	id: Font_ID,
	text: cstring,
	size: f32,
	spacing: f32,
) -> rl.Vector2 {
	_, ok := state.fonts[id]; if !ok do return rl.Vector2{}
	return rl.MeasureTextEx(state.fonts[id], text, size, spacing)
}

font_shutdown :: proc(state: ^Font_State) {
	for _, font in state.fonts {
		rl.UnloadFont(font)
	}
	delete(state.fonts)
}

