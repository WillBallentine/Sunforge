package engine

import core "./core"

Window_Config :: core.Window_Config
Action_ID :: core.Action_ID

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
	window: core.Window_State,
	clock:  core.Clock_State,
	input:  core.Input_State,
	//assets:   Asset_Cache,
	//renderer: Renderer_State,
	//physics:  Physics_World,
	//audio:    Audio_State,
	//entities: Entity_Pool,
	//scenes:   Scene_System,
	//shaders:  Shader_State,
	//timers:   Timer_System,
	//ui:       UI_Context,
	_scene: Scene_Procs,
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
}

shutdown :: proc(e: ^Engine) {
	if e._scene.destroy != nil do e._scene.destroy(e, e._scene.data)
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
	core.clock_tick(&e.clock)
	core.input_poll(&e.input)

	if e._scene.update != nil do e._scene.update(e, e._scene.data, e.clock.delta_time)

	if e._scene.render != nil do e._scene.render(e, e._scene.data)
}

