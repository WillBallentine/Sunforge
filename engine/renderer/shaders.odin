package renderer

import rl "vendor:raylib"

Shader_ID :: distinct u32

Shader_State :: struct {
	shaders: map[Shader_ID]rl.Shader,
	next_id: Shader_ID,
}

shader_init :: proc(state: ^Shader_State) {
	state.shaders = make(map[Shader_ID]rl.Shader)
	state.next_id = 1
}

shader_shutdown :: proc(state: ^Shader_State) {
	for _, shader in state.shaders {
		rl.UnloadShader(shader)
	}
	delete(state.shaders)
}

shader_load :: proc(state: ^Shader_State, fs_path: cstring) -> Shader_ID {
	shader := rl.LoadShader(nil, fs_path)
	id := state.next_id
	state.shaders[id] = shader
	state.next_id += 1
	return id
}

shader_unload :: proc(state: ^Shader_State, id: Shader_ID) {
	shader, ok := state.shaders[id]
	if !ok do return
	rl.UnloadShader(shader)
	delete_key(&state.shaders, id)
}

shader_get :: proc(state: ^Shader_State, id: Shader_ID) -> rl.Shader {
	return state.shaders[id]
}

shader_set_float :: proc(state: ^Shader_State, id: Shader_ID, name: cstring, value: f32) {
	shader, ok := state.shaders[id]
	if !ok do return
	loc := rl.GetShaderLocation(shader, name)
	v := value
	rl.SetShaderValue(shader, loc, &v, .FLOAT)
}

shader_set_vec2 :: proc(state: ^Shader_State, id: Shader_ID, name: cstring, value: rl.Vector2) {
	shader, ok := state.shaders[id]
	if !ok do return
	loc := rl.GetShaderLocation(shader, name)
	v := value
	rl.SetShaderValue(shader, loc, &v, .VEC2)
}

shader_set_texture :: proc(
	state: ^Shader_State,
	id: Shader_ID,
	name: cstring,
	tex: rl.Texture2D,
	slot: i32,
) {
	shader, ok := state.shaders[id]
	if !ok do return
	loc := rl.GetShaderLocation(shader, name)
	rl.SetShaderValueTexture(shader, loc, tex)
}

renderer_blit_shader :: proc(state: ^Renderer_State, target: Render_Target, id: Shader_ID) {
	shader := shader_get(&state.shaders, id)
	rl.BeginShaderMode(shader)
	renderer_blit(state, target)
	rl.EndShaderMode()
}

