package renderer

import rl "vendor:raylib"

//do i need a renderer_config??

Renderer_State :: struct {
	logical_width:  i32,
	logical_height: i32,
	screen_width:   i32,
	screen_height:  i32,
	viewport:       rl.Rectangle,
}

Render_Target :: rl.RenderTexture2D

renderer_init :: proc(state: ^Renderer_State, width, height: i32) {
	state.logical_height = height
	state.logical_width = width
	state.screen_height = height
	state.screen_width = width
}

renderer_shutdown :: proc(state: ^Renderer_State) {
}

renderer_make_target :: proc(state: ^Renderer_State) -> Render_Target {
	return rl.LoadRenderTexture(state.logical_width, state.logical_height)
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
	logical_aspect := f32(state.logical_width) / f32(state.logical_height)
	screen_aspect := f32(state.screen_width) / f32(state.screen_height)

	dest_w, dest_h, dest_x, dest_y: f32

	if screen_aspect >= logical_aspect {
		dest_h = f32(state.screen_height)
		dest_w = dest_h * logical_aspect
		dest_x = (f32(state.screen_width) - dest_w) / 2
		dest_y = 0
	} else {
		dest_w = f32(state.screen_width)
		dest_h = dest_w / logical_aspect
		dest_x = 0
		dest_y = (f32(state.screen_height) - dest_h) / 2
	}

	src := rl.Rectangle{0, 0, f32(target.texture.width), -f32(target.texture.height)}
	dest := rl.Rectangle{dest_x, dest_y, dest_w, dest_h}
	state.viewport = dest
	rl.DrawTexturePro(target.texture, src, dest, {0, 0}, 0, rl.WHITE)
}

renderer_blit_shader :: proc(state: ^Renderer_State, target: Render_Target, shader: rl.Shader) {
	rl.BeginShaderMode(shader)
	renderer_blit(state, target)
	rl.EndShaderMode()
}

renderer_screen_to_world :: proc(
	viewport: rl.Rectangle,
	locical_w: i32,
	cam: Camera_State,
	screen_pos: rl.Vector2,
) -> rl.Vector2 {
	scale := viewport.width / f32(locical_w)
	logical_pos := rl.Vector2 {
		(screen_pos.x - viewport.x) / scale,
		(screen_pos.y - viewport.y) / scale,
	}

	return rl.GetScreenToWorld2D(logical_pos, cam.camera)
}

renderer_world_to_screen :: proc(
	viewport: rl.Rectangle,
	logical_w: i32,
	cam: Camera_State,
	world_pos: rl.Vector2,
) -> rl.Vector2 {
	logical_pos := rl.GetWorldToScreen2D(world_pos, cam.camera)
	scale := viewport.width / f32(logical_w)
	return rl.Vector2{logical_pos.x * scale + viewport.x, logical_pos.y * scale + viewport.y}
}

renderer_clear :: proc(color: rl.Color) {
	rl.ClearBackground(color)
}

draw_texture :: proc {
	renderer_draw_texture,
	renderer_draw_sprite,
}

renderer_draw_texture :: proc(texture: rl.Texture2D, src, dest: rl.Rectangle, tint: rl.Color) {
	rl.DrawTexturePro(texture, src, dest, {0, 0}, 0, tint)
}

draw_basic_shape :: proc {
	renderer_draw_circle,
	renderer_draw_line,
	renderer_draw_rect,
	renderer_draw_text,
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

renderer_handle_resize :: proc(state: ^Renderer_State, w, h: i32) {
	state.screen_width = w
	state.screen_height = h
}

