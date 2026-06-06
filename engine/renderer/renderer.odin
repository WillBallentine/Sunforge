package renderer

import rl "vendor:raylib"

//do i need a renderer_config??

Renderer_State :: struct {
	width:  i32,
	height: i32,
}

Render_Target :: rl.RenderTexture2D

renderer_init :: proc(state: ^Renderer_State, width, height: i32) {
	state.height = height
	state.width = width
}

renderer_shutdown :: proc(state: ^Renderer_State) {
}

renderer_make_target :: proc(state: ^Renderer_State) -> Render_Target {
	return rl.LoadRenderTexture(state.width, state.height)
}

renderer_destroy_target :: proc(target: Render_Target) {
	rl.UnloadRenderTexture(target)
}

renderer_begin_target :: proc(target: Render_Target) {
	rl.BeginTextureMode(target)
}

renderer_end_target :: proc() {
	rl.EndTextureMode()
}

renderer_blit :: proc(state: ^Renderer_State, target: Render_Target) {
	src := rl.Rectangle{0, 0, f32(target.texture.width), -f32(target.texture.height)}
	dest := rl.Rectangle{0, 0, f32(state.width), f32(state.height)}
	rl.DrawTexturePro(target.texture, src, dest, {0, 0}, 0, rl.WHITE)
}

renderer_blit_shader :: proc(state: ^Renderer_State, target: Render_Target, shader: rl.Shader) {
	rl.BeginShaderMode(shader)
	renderer_blit(state, target)
	rl.EndShaderMode()
}

renderer_begin_camera :: proc(camera: rl.Camera2D) {
	rl.BeginMode2D(camera)
}

renderer_end_camera :: proc() {
	rl.EndMode2D()
}

renderer_clear :: proc(color: rl.Color) {
	rl.ClearBackground(color)
}

renderer_draw_texture :: proc(texture: rl.Texture2D, src, dest: rl.Rectangle, tint: rl.Color) {
	rl.DrawTexturePro(texture, src, dest, {0, 0}, 0, tint)
}

renderer_draw_rect :: proc(rect: rl.Rectangle, thickness: f32, color: rl.Color) {
	rl.DrawRectangleLinesEx(rect, thickness, color)
}

renderer_draw_circle :: proc(center: rl.Vector2, radius: f32, color: rl.Color) {
	rl.DrawCircleV(center, radius, color)
}

renderer_draw_line :: proc(start, end: rl.Vector2, thickness: f32, color: rl.Color) {
	rl.DrawLineEx(start, end, thickness, color)
}

renderer_draw_text :: proc(text: cstring, x, y, size: i32, color: rl.Color) {
	rl.DrawText(text, x, y, size, color)
}

