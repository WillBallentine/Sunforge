package engine

import core "./core"
import rend "./renderer"
import rl "vendor:raylib"

//Window
Window_Config :: core.Window_Config
Action_ID :: core.Action_ID
set_window_size :: core.window_set_size
toggle_fullscreen :: core.window_toggle_fullscreen

//controls
input_bind_keyboard :: core.input_bind_keyboard
input_bind_controller :: core.input_bind_controller
input_pressed :: core.input_pressed
input_held :: core.input_held
input_released :: core.input_released

//render
Render_Target :: rend.Render_Target
Camera_State :: rend.Camera_State
//camera
camera_init :: rend.camera_init
camera_follow :: rend.camera_follow
add_trauma :: rend.add_trauma
update_camera :: rend.update_camera
renderer_init :: rend.renderer_init
world_to_screen :: rend.renderer_world_to_screen
screen_to_world :: rend.renderer_screen_to_world
make_render_target :: rend.renderer_make_target
destroy_render_target :: rend.renderer_destroy_target
begin_render_target :: rend.renderer_begin_target
end_render_target :: rend.renderer_end_target
renderer_clear :: rend.renderer_clear
blit :: rend.renderer_blit
begin_camera :: rend.renderer_begin_camera
end_camera :: rend.renderer_end_camera
draw_texture :: rend.draw_texture
draw_basic_shape :: rend.draw_basic_shape
get_sprite :: rend.get_sprite
//shaders
Shader_ID :: rend.Shader_ID
shader_load :: rend.shader_load
shader_unload :: rend.shader_unload
shader_get :: rend.shader_get
shader_set_float :: rend.shader_set_float
shader_set_vec2 :: rend.shader_set_vec2
shader_set_texture :: rend.shader_set_texture
blit_shader :: rend.renderer_blit_shader
//tilemap
Tilemap :: rend.Tilemap
create_tilemap :: rend.tilemap_create
tilemap_set_tile :: rend.tilemap_set_tile
draw_tilemap :: rend.tilemap_draw
tilemap_is_solid :: rend.tilemap_is_solid
destroy_tilemap :: rend.tilemap_destroy


//animation
Flip :: rend.Flip
Animation :: rend.Animation
Animation_State :: rend.Animation_State
create_animation_state :: rend.animation_state_create
reset_animation_state :: rend.animation_state_reset
get_sprite_for_animation :: rend.animation_state_get_sprite
update_animation_state :: rend.animation_state_update

Engine_Config :: struct {
	window: core.Window_Config,
}

Scene_Procs :: struct {
	data:    rawptr,
	init:    proc(e: ^Engine, data: rawptr),
	update:  proc(e: ^Engine, data: rawptr, dt: f32),
	render:  proc(e: ^Engine, data: rawptr),
	destroy: proc(e: ^Engine, data: rawptr),
}


Engine :: struct {
	window:   core.Window_State,
	clock:    core.Clock_State,
	input:    core.Input_State,
	//assets:   Asset_Cache,
	renderer: rend.Renderer_State,
	//physics:  Physics_World,
	//audio:    Audio_State,
	//entities: Entity_Pool,
	//scenes:   Scene_System,
	//timers:   Timer_System,
	//ui:       UI_Context,
	_scene:   Scene_Procs,
}

run :: proc(config: Engine_Config, first_scene: Scene_Procs) {
	e: Engine
	init(&e, config)
	defer shutdown(&e)
	scene_push(&e, first_scene)
	for !should_close(&e) {
		tick(&e)
	}
}

init :: proc(e: ^Engine, config: Engine_Config) {
	core.window_init(&e.window, config.window)
	core.clock_init(&e.clock)
	core.input_init(&e.input)
	rend.renderer_init(&e.renderer, config.window.width, config.window.height)
}

shutdown :: proc(e: ^Engine) {
	if e._scene.destroy != nil do e._scene.destroy(e, e._scene.data)
	rend.renderer_shutdown(&e.renderer)
	core.window_shutdown(&e.window)
}

should_close :: proc(e: ^Engine) -> bool {
	return core.window_should_close(&e.window)
}

scene_push :: proc(e: ^Engine, scene: Scene_Procs) {
	if e._scene.destroy != nil do e._scene.destroy(e, e._scene.data)
	e._scene = scene
	if e._scene.init != nil do e._scene.init(e, e._scene.data)
}

tick :: proc(e: ^Engine) {
	if rl.IsWindowResized() {
		new_width := rl.GetScreenWidth()
		new_height := rl.GetScreenHeight()
		core.window_handle_resize(&e.window, new_width, new_height)
		rend.renderer_handle_resize(&e.renderer, new_width, new_height)
	}
	rl.BeginDrawing()
	core.clock_tick(&e.clock)
	core.input_poll(&e.input)

	if e._scene.update != nil do e._scene.update(e, e._scene.data, e.clock.delta_time)

	if e._scene.render != nil do e._scene.render(e, e._scene.data)
	rl.EndDrawing()
}

