package main

import eng "../engine"
import engCore "../engine/core"
import proj "../project"
import ui "./ui"
import rl "vendor:raylib"

PANEL_LEFT_WIDTH :: 220
PANEL_RIGHT_WIDTH :: 280
PANEL_BOTTOM_HEIGHT :: 180

EDIT_ZOOM_SPEED :: 0.1
EDIT_ZOOM_MIN :: 0.1
EDIT_ZOOM_MAX :: 5.0

Panel_Layout :: struct {
	left:   rl.Rectangle,
	right:  rl.Rectangle,
	bottom: rl.Rectangle,
	world:  rl.Rectangle,
}

Editor_State :: struct {
	project_root:  string,
	project:       proj.Project_Data,
	asset_browser: Asset_Browser_State,
	edit_camera:   eng.Camera_State,
	world_target:  eng.Render_Target,
}

editor_scene :: proc(root: string, project: proj.Project_Data) -> eng.Scene_Procs {
	state := new(Editor_State)
	state.project_root = root
	state.project = project
	return eng.Scene_Procs {
		data = state,
		init = editor_init,
		update = editor_update,
		render = editor_render,
		destroy = editor_destroy,
	}
}

editor_init :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Editor_State)data

	eng.camera_init(
		&s.edit_camera,
		offset = {f32(e.renderer.logical_width) / 2, f32(e.renderer.logical_height) / 2},
		follow_speed = 0,
		trauma_decay = 0,
		shake_max = 0,
	)
	s.edit_camera.camera.target = {0, 0}
	rl.SetWindowMinSize(PANEL_LEFT_WIDTH + PANEL_RIGHT_WIDTH + 400, PANEL_BOTTOM_HEIGHT + 400)

	s.world_target = eng.make_render_target(&e.renderer)
	s.asset_browser = asset_browser_init(s.project_root)
}

editor_update :: proc(e: ^eng.Engine, data: rawptr, dt: f32) {
	s := cast(^Editor_State)data
	panels := compute_panel_layout()

	if e.input.mouse.middle.held || e.input.mouse.right.held {
		s.edit_camera.camera.target -= e.input.mouse.delta / s.edit_camera.camera.zoom
	}

	if e.input.mouse.wheel != 0 &&
	   !rl.CheckCollisionPointRec(e.input.mouse.position, panels.bottom) {
		s.edit_camera.camera.zoom += e.input.mouse.wheel * EDIT_ZOOM_SPEED
		s.edit_camera.camera.zoom = engCore.clamp(
			s.edit_camera.camera.zoom,
			EDIT_ZOOM_MIN,
			EDIT_ZOOM_MAX,
		)
	}

	ui.ui_begin(&e.input)
}

editor_render :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Editor_State)data
	panels := compute_panel_layout()

	if i32(panels.world.width) != s.world_target.texture.width ||
	   i32(panels.world.height) != s.world_target.texture.height {
		eng.destroy_render_target(s.world_target)
		s.world_target = eng.make_render_target_sized(
			&e.renderer,
			i32(panels.world.width),
			i32(panels.world.height),
		)
		s.edit_camera.camera.offset = {panels.world.width / 2, panels.world.height / 2}
	}

	eng.begin_render_target(s.world_target)
	eng.renderer_clear(rl.Color{40, 40, 45, 255})
	eng.begin_camera(s.edit_camera)
	eng.end_camera()
	eng.end_render_target()

	rl.DrawTexturePro(
		s.world_target.texture,
		{0, 0, f32(s.world_target.texture.width), -f32(s.world_target.texture.height)},
		panels.world,
		{0, 0},
		0,
		rl.WHITE,
	)

	eng.blit(&e.renderer, s.world_target)

	ui.ui_panel(panels.left, "Palette")
	ui.ui_panel(panels.right, "Inspector")
	assets_rect := ui.ui_panel(panels.bottom, "Assets")
	asset_browser_render(&s.asset_browser, assets_rect, e.input.mouse.wheel)
}

editor_destroy :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Editor_State)data
	eng.destroy_render_target(s.world_target)
	asset_browser_destroy(&s.asset_browser)
	free(data)
}

compute_panel_layout :: proc() -> Panel_Layout {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	return Panel_Layout {
		left = {0, 0, PANEL_LEFT_WIDTH, sh - PANEL_BOTTOM_HEIGHT},
		right = {sw - PANEL_RIGHT_WIDTH, 0, PANEL_RIGHT_WIDTH, sh - PANEL_BOTTOM_HEIGHT},
		bottom = {0, sh - PANEL_BOTTOM_HEIGHT, sw, PANEL_BOTTOM_HEIGHT},
		world = {
			PANEL_LEFT_WIDTH,
			0,
			sw - PANEL_LEFT_WIDTH - PANEL_RIGHT_WIDTH,
			sh - PANEL_BOTTOM_HEIGHT,
		},
	}
}

