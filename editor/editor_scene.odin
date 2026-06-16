package main

import eng "../engine"
import engCore "../engine/core"
import proj "../project"
import ui "./ui"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

PANEL_LEFT_WIDTH :: 220
PANEL_RIGHT_WIDTH :: 280
PANEL_BOTTOM_HEIGHT :: 180

EDIT_ZOOM_SPEED :: 0.1
EDIT_ZOOM_MIN :: 0.1
EDIT_ZOOM_MAX :: 5.0

Editor_Action :: enum u32 {
	Undo,
	Redo,
}

Panel_Layout :: struct {
	left:   rl.Rectangle,
	right:  rl.Rectangle,
	bottom: rl.Rectangle,
	world:  rl.Rectangle,
}

Editor_State :: struct {
	project_root:        string,
	project:             proj.Project_Data,
	asset_browser:       Asset_Browser_State,
	edit_camera:         eng.Camera_State,
	world_target:        eng.Render_Target,
	current_scene:       Scene_Data,
	history:             Editor_History,
	textures:            map[string]rl.Texture2D,
	scene_tilemap:       eng.Tilemap,
	entity_sprites:      []eng.Sprite,
	new_scene_dialog:    New_Scene_Dialog_State,
	browse_scene_dialog: Browse_Scenes_Dialog_State,
}

act :: #force_inline proc(a: Editor_Action) -> eng.Action_ID {
	return eng.Action_ID(a)
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
	s.textures = make(map[string]rl.Texture2D)
	s.new_scene_dialog = new_scene_dialog_init()
	s.browse_scene_dialog = browse_scenes_dialog_init()

	scene_path, _ := filepath.join({s.project_root, proj.SCENES_DIR, "level_01.json"})
	defer delete(scene_path)

	if loaded, ok := scene_load(scene_path); ok {
		s.current_scene = loaded
	} else {
		s.current_scene = default_title_scene()
		scene_save(scene_path, s.current_scene)
	}

	scene_load_resources(s)
	s.edit_camera.camera.target = {
		f32(s.scene_tilemap.cols * s.scene_tilemap.tile_w) / 2,
		f32(s.scene_tilemap.rows * s.scene_tilemap.tile_h) / 2,
	}

	s.current_scene = Scene_Data{}
	if s.project.entry_scene != "" {
		scene_path, _ := filepath.join({s.project_root, proj.SCENES_DIR, s.project.entry_scene})
		defer delete(scene_path)

		if loaded, ok := scene_load(scene_path); ok {
			s.current_scene = loaded
		}
	}

	if s.current_scene.tilemap_path != "" {
		scene_load_resources(s)
		s.edit_camera.camera.target = {
			f32(s.scene_tilemap.cols * s.scene_tilemap.tile_w) / 2,
			f32(s.scene_tilemap.rows * s.scene_tilemap.tile_h) / 2,
		}
	} else {
		s.new_scene_dialog.open = true
	}

	eng.input_bind_keyboard(&e.input, act(.Undo), .Z)
	eng.input_bind_keyboard(&e.input, act(.Redo), .Y)
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

	ctrl_down := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	if ctrl_down && eng.input_pressed(&e.input, act(.Undo)) {
		history_undo(&s.history)
	}
	if ctrl_down && eng.input_pressed(&e.input, act(.Redo)) {
		history_redo(&s.history)
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
	eng.draw_tilemap(&s.scene_tilemap, s.edit_camera.camera)
	for entity, i in s.current_scene.entities {
		eng.draw_buffer_push(
			&e.renderer.draw_buffer,
			eng.Draw_Command {
				sprite = s.entity_sprites[i],
				position = entity.position,
				scale = 1,
				rotation = 0,
				pivot_point = .CENTER,
				flip = .NONE,
				tint = rl.WHITE,
				z = 0,
			},
		)
	}
	eng.draw_buffer_flush(&e.renderer.draw_buffer)
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

	ui.ui_panel(panels.left, "Palette")
	ui.ui_panel(panels.right, "Inspector")
	inspector := ui.ui_panel(panels.right, "Inspector")
	if ui.ui_button(
		{
			inspector.x + ui.PADDING,
			inspector.y + ui.PADDING,
			inspector.width - ui.PADDING * 2,
			ui.ROW_HEIGHT,
		},
		"New Scene",
	) {
		s.new_scene_dialog.open = true
	}
	if ui.ui_button(
		{
			inspector.x + ui.PADDING,
			inspector.y + ui.PADDING + ui.ROW_HEIGHT,
			inspector.width - ui.PADDING * 2,
			ui.ROW_HEIGHT,
		},
		"Select Scene",
	) {
		s.browse_scene_dialog.open = true
		browse_scenes_dialog_refresh(&s.browse_scene_dialog, s)
	}

	assets_rect := ui.ui_panel(panels.bottom, "Assets")
	asset_browser_render(&s.asset_browser, assets_rect, e.input.mouse.wheel)

	if new_scene_dialog_render(s) {
		if create_new_scene(s) {
			s.new_scene_dialog.open = false
		}
	}

	if browse_scene_dialog_render(s) {
		if select_scene(s) {
			s.browse_scene_dialog.open = false
		}
	}
}

editor_destroy :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Editor_State)data
	eng.destroy_render_target(s.world_target)
	asset_browser_destroy(&s.asset_browser)
	history_destroy(&s.history)
	eng.destroy_tilemap(&s.scene_tilemap)
	delete(s.entity_sprites)
	for key, tex in s.textures {
		delete(key)
		rl.UnloadTexture(tex)
	}
	delete(s.textures)
	new_scene_dialog_destroy(&s.new_scene_dialog)
	browse_scene_dialog_destroy(&s.browse_scene_dialog)
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

scene_texture :: proc(s: ^Editor_State, path: string) -> rl.Texture2D {
	if tex, ok := s.textures[path]; ok {
		return tex
	}
	cpath := strings.clone_to_cstring(path, context.temp_allocator)
	tex := rl.LoadTexture(cpath)
	s.textures[strings.clone(path)] = tex
	return tex
}

scene_load_resources :: proc(s: ^Editor_State) {
	tilemap_abs, _ := filepath.join({s.project_root, s.current_scene.tilemap_path})
	defer delete(tilemap_abs)

	tileset_tex: rl.Texture2D
	if image_rel, ok := eng.tiled_get_tileset_image(tilemap_abs); ok {
		defer delete(image_rel)
		tileset_dir := filepath.dir(tilemap_abs)
		joined, _ := filepath.join({tileset_dir, image_rel})
		defer delete(joined)
		tileset_abs, _ := filepath.clean(joined)
		defer delete(tileset_abs)
		tileset_tex = scene_texture(s, tileset_abs)
	}

	s.scene_tilemap, _ = eng.tilemap_load_tiled(tilemap_abs, tileset_tex)

	s.entity_sprites = make([]eng.Sprite, len(s.current_scene.entities))
	for entity, i in s.current_scene.entities {
		sprite_abs, _ := filepath.join({s.project_root, entity.sprite_sheet_path})
		defer delete(sprite_abs)
		tex := scene_texture(s, sprite_abs)
		s.entity_sprites[i] = eng.Sprite {
			texture = tex,
			src     = {0, 0, f32(tex.width), f32(tex.height)},
		}
	}
}


//for testing for now this will be removed once the proper editor is up and working
default_title_scene :: proc() -> Scene_Data {
	scene := Scene_Data {
		tilemap_path = strings.clone("resources/tilemaps/level_01.json"),
		entities = make([]Entity_Data, 1),
		camera = Camera_Config_Data{follow_speed = 6.0, zoom = 1.0},
	}

	scene.entities[0] = Entity_Data {
		name              = strings.clone("player"),
		position          = rl.Vector2{635, 201},
		sprite_sheet_path = strings.clone("resources/textures/test.png"),
		animation         = strings.clone("idle"),
		tags              = make([]string, 2),
		properties        = make(map[string]string),
	}

	scene.entities[0].tags[0] = strings.clone("player")
	scene.entities[0].tags[1] = strings.clone("controllable")
	scene.entities[0].properties[strings.clone("speed")] = strings.clone("200")

	return scene
}

