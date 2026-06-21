package main

import eng "../engine"
import engCore "../engine/core"
import proj "../project"
import ui "./ui"
import "core:fmt"
import "core:path/filepath"
import "core:strings"
import util "utils"
import rl "vendor:raylib"

PANEL_LEFT_WIDTH :: 220
PANEL_RIGHT_WIDTH :: 280
PANEL_BOTTOM_HEIGHT :: 180
PANEL_TOP_HEIGHT :: 90

EDIT_ZOOM_SPEED :: 0.1
EDIT_ZOOM_MIN :: 0.1
EDIT_ZOOM_MAX :: 5.0

ENTITY_Z :: f32(1.0)

Editor_Action :: enum u32 {
	Undo,
	Redo,
	Grid,
	Copy,
	Rotate,
}

Panel_Layout :: struct {
	left:   rl.Rectangle,
	right:  rl.Rectangle,
	bottom: rl.Rectangle,
	top:    rl.Rectangle,
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
	active_tool:         util.Editor_Tools,
	tilemap_painter:     Tilemap_Painter_State,
	entity_placer:       Entity_Placement_State,
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
	s.tilemap_painter = tilemap_painter_init()
	s.entity_placer = entity_placement_init()

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
		tilemap_painter_on_scene_loaded(&s.tilemap_painter, s)
		s.edit_camera.camera.target = {
			f32(s.scene_tilemap.cols * s.scene_tilemap.tile_w) / 2,
			f32(s.scene_tilemap.rows * s.scene_tilemap.tile_h) / 2,
		}
	} else {
		s.new_scene_dialog.open = true
	}

	eng.input_bind_keyboard(&e.input, act(.Undo), .Z)
	eng.input_bind_keyboard(&e.input, act(.Redo), .Y)
	eng.input_bind_keyboard(&e.input, act(.Grid), .G)
	eng.input_bind_keyboard(&e.input, act(.Copy), .LEFT_ALT)
	eng.input_bind_keyboard(&e.input, act(.Rotate), .R)
}

editor_update :: proc(e: ^eng.Engine, data: rawptr, dt: f32) {
	s := cast(^Editor_State)data
	panels := compute_panel_layout()

	if e.input.mouse.middle.held || e.input.mouse.right.held {
		s.edit_camera.camera.target -= e.input.mouse.delta / s.edit_camera.camera.zoom
	}

	if e.input.mouse.wheel != 0 &&
	   !rl.CheckCollisionPointRec(e.input.mouse.position, panels.bottom) &&
	   !rl.CheckCollisionPointRec(e.input.mouse.position, panels.top) &&
	   !rl.CheckCollisionPointRec(e.input.mouse.position, panels.left) {
		s.edit_camera.camera.zoom += e.input.mouse.wheel * EDIT_ZOOM_SPEED
		s.edit_camera.camera.zoom = engCore.clamp(
			s.edit_camera.camera.zoom,
			EDIT_ZOOM_MIN,
			EDIT_ZOOM_MAX,
		)
	}

	if eng.input_pressed(&e.input, act(.Grid)) {
		s.tilemap_painter.show_grid = !s.tilemap_painter.show_grid
	}

	if eng.input_pressed(&e.input, act(.Rotate)) {
		s.tilemap_painter.active_rotation = (s.tilemap_painter.active_rotation + 1) % 4
	}

	if rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT) {
		if !s.tilemap_painter.pick_mode {
			s.tilemap_painter.pick_mode = true
			rl.SetMouseCursor(.POINTING_HAND)
		}
	} else if s.tilemap_painter.pick_mode {
		s.tilemap_painter.pick_mode = false
		rl.SetMouseCursor(.DEFAULT)
	}


	ctrl_down := rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	if ctrl_down && eng.input_pressed(&e.input, act(.Undo)) {
		history_undo(&s.history)
		rebuild_entity_sprites(s)
	}
	if ctrl_down && eng.input_pressed(&e.input, act(.Redo)) {
		history_redo(&s.history)
		rebuild_entity_sprites(s)
	}
	tilemap_painter_update(&s.tilemap_painter, s, e, panels)
	entity_placement_update(&s.entity_placer, s, e, panels)

	if s.active_tool == .Entity &&
	   s.entity_placer.selected >= 0 &&
	   rl.IsMouseButtonReleased(.LEFT) {
		scene_save_current(s)
	}

	ui.ui_begin(&e.input)
}

editor_render :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Editor_State)data
	fmt.println("editor_render: start")
	panels := compute_panel_layout()
	fmt.println("editor_render: panels computed, world=", panels.world)

	if i32(panels.world.width) != s.world_target.texture.width ||
	   i32(panels.world.height) != s.world_target.texture.height {
		fmt.println(
			"editor_render: resizing render target to:",
			panels.world.width,
			"x",
			panels.world.height,
		)
		eng.destroy_render_target(s.world_target)
		s.world_target = eng.make_render_target_sized(
			&e.renderer,
			i32(panels.world.width),
			i32(panels.world.height),
		)
		s.edit_camera.camera.offset = {panels.world.width / 2, panels.world.height / 2}
	}

	fmt.println("editor_render: begin render target")
	eng.begin_render_target(s.world_target)
	eng.renderer_clear(rl.Color{40, 40, 45, 255})
	eng.begin_camera(s.edit_camera)

	ENTITY_Z :: f32(1.0)

	Render_Item :: struct {
		z:     f32,
		layer: i32,
	}

	items: [eng.MAX_TILE_LAYERS + 1]Render_Item
	item_count := 0

	for i in 0 ..< s.scene_tilemap.layers {
		if s.tilemap_painter.layer_visible[i] {
			items[item_count] = {
				z     = s.scene_tilemap.layer_z[i],
				layer = i32(i),
			}
			item_count += 1
		}
	}

	if s.tilemap_painter.entities_visible {
		items[item_count] = {
			z     = ENTITY_Z,
			layer = -1,
		}
		item_count += 1
	}

	for i in 1 ..< item_count {
		key := items[i]
		j := i - 1
		for j >= 0 && items[j].z > key.z {
			items[j + 1] = items[j]
			j -= 1
		}
		items[j + 1] = key
	}

	for i in 0 ..< item_count {
		item := items[i]
		if item.layer < 0 {
			for entity, ei in s.current_scene.entities {
				entity_scale := entity.scale if entity.scale > 0 else 1.0
				eng.draw_buffer_push(
					&e.renderer.draw_buffer,
					eng.Draw_Command {
						sprite = s.entity_sprites[ei],
						position = entity.position,
						scale = entity.scale,
						rotation = 0,
						pivot_point = .CENTER,
						flip = .NONE,
						tint = rl.WHITE,
						z = entity.z,
					},
				)
			}
			eng.draw_buffer_flush(&e.renderer.draw_buffer)
		} else {
			eng.draw_tilemap_layer(&s.scene_tilemap, s.edit_camera.camera, item.layer)
		}
	}


	x := f32(0)
	y := f32(0)
	for row in 0 ..< s.scene_tilemap.rows {
		for col in 0 ..< s.scene_tilemap.cols {
			if s.tilemap_painter.show_grid {
				rl.DrawRectangleLinesEx(
					{x, y, f32(s.scene_tilemap.tile_w), f32(s.scene_tilemap.tile_h)},
					1 / s.current_scene.camera.zoom,
					rl.GRAY,
				)
			}
			x += f32(s.scene_tilemap.tile_w)
		}
		x = 0
		y += f32(s.scene_tilemap.tile_h)
	}

	if s.active_tool == .Entity {
		t := 1.5 / s.edit_camera.camera.zoom
		for entity, i in s.current_scene.entities {
			pos := entity.position
			half := ENTITY_GIZMO_HALF
			color := ui.ACCENT if i == s.entity_placer.selected else rl.Color{180, 180, 255, 100}
			rl.DrawLineEx({pos.x - half, pos.y}, {pos.x + half, pos.y}, t, color)
			rl.DrawLineEx({pos.x, pos.y - half}, {pos.x, pos.y + half}, t, color)
			if i == s.entity_placer.selected {
				rl.DrawRectangleLinesEx(entity_gizmo_rect(pos), t * 2, ui.ACCENT)
			}
		}
	}

	if s.scene_tilemap.cols > 0 {
		w := f32(s.scene_tilemap.cols * s.scene_tilemap.tile_w)
		h := f32(s.scene_tilemap.rows * s.scene_tilemap.tile_h)
		thickness := 2 / s.edit_camera.camera.zoom
		rl.DrawRectangleLinesEx({0, 0, w, h}, thickness, rl.Color{255, 255, 255, 60})
	}
	eng.end_camera()
	eng.end_render_target()
	fmt.println("editor_render: end render target")

	fmt.println("editor_render: blit world")
	rl.DrawTexturePro(
		s.world_target.texture,
		{0, 0, f32(s.world_target.texture.width), -f32(s.world_target.texture.height)},
		panels.world,
		{0, 0},
		0,
		rl.WHITE,
	)

	tools := ui.ui_panel(panels.top, "Tools")
	inspector := ui.ui_panel(panels.right, "Inspector")
	inspector_rw := inspector.width - ui.PADDING * 2
	inspector_y := inspector.y + ui.PADDING
	tools_btn_w := tools.width / 10
	tools_rw := tools.width - ui.PADDING * 2
	tools_y := tools.y + ui.PADDING

	if s.active_tool == .Entity {
		entity_rect := ui.ui_panel(panels.left, "Entities")
		entity_list_render(&s.entity_placer, &s.current_scene, entity_rect, e.input.mouse.wheel)
	} else {
		palette_rect := ui.ui_panel(panels.left, "Palette")
		tilemap_painter_render_palette(
			&s.tilemap_painter,
			s,
			&s.scene_tilemap,
			palette_rect,
			tools,
			e.input.mouse.wheel,
		)
	}

	// TODO: eventually this should be a dropdown or toolbar of somekind
	if ui.ui_button(
		{tools.x + ui.PADDING, tools.y + ui.PADDING, tools_btn_w, ui.ROW_HEIGHT},
		"New Scene",
	) {
		s.new_scene_dialog.open = true
	}
	if ui.ui_button(
		{
			tools.x + ui.PADDING,
			tools.y + ui.PADDING + ui.ROW_HEIGHT + ui.PADDING,
			tools_btn_w,
			ui.ROW_HEIGHT,
		},
		"Select Scene",
	) {
		s.browse_scene_dialog.open = true
		browse_scenes_dialog_refresh(&s.browse_scene_dialog, s)
	}
	if ui.ui_button(
		{
			tools.x + (ui.PADDING * 2) + tools_btn_w,
			tools.y + ui.PADDING,
			tools_btn_w,
			ui.ROW_HEIGHT,
		},
		"Tilemap Tool",
	) {
		s.active_tool = .Tilemap
	}
	if ui.ui_button(
		{
			tools.x + (ui.PADDING * 2) + tools_btn_w,
			tools.y + (ui.PADDING * 2) + ui.ROW_HEIGHT,
			tools_btn_w,
			ui.ROW_HEIGHT,
		},
		"Entity Tool",
	) {
		s.active_tool = .Entity
	}
	tools.y += ui.ROW_HEIGHT + ui.PADDING

	if s.active_tool == .Entity && s.entity_placer.selected >= 0 {
		idx := s.entity_placer.selected

		if idx < len(s.current_scene.entities) {
			entity := &s.current_scene.entities[idx]
			x := inspector.x + ui.PADDING
			rw := inspector.width - ui.PADDING * 2
			half := (rw - ui.PADDING) / 2
			y := inspector.y + (ui.ROW_HEIGHT * 4) + (ui.PADDING * 5)

			ui.ui_text_input({x, y, rw, ui.ROW_HEIGHT}, &entity.name)
			y += ui.ROW_HEIGHT + ui.PADDING

			ui.ui_drag_float({x, y, half, ui.ROW_HEIGHT}, "X", &entity.position.x, 1)
			ui.ui_drag_float(
				{x + half + ui.PADDING, y, half, ui.ROW_HEIGHT},
				"Y",
				&entity.position.y,
				1,
			)
			y += ui.ROW_HEIGHT + ui.PADDING
			ui.ui_drag_float({x, y, half, ui.ROW_HEIGHT}, "Z", &entity.z, 0.1)
			ui.ui_drag_float(
				{x + half + ui.PADDING, y, half, ui.ROW_HEIGHT},
				"Scale",
				&entity.scale,
				0.01,
			)
			y += ui.ROW_HEIGHT + ui.PADDING

			sp := entity.sprite_sheet_path if entity.sprite_sheet_path != "" else "(no sprite)"
			rl.DrawText(
				strings.clone_to_cstring(sp, context.temp_allocator),
				i32(x),
				i32(y) + 3,
				ui.FONT_SIZE,
				ui.TEXT,
			)
			y += ui.ROW_HEIGHT + ui.PADDING

			if ui.ui_button({x, y, rw, ui.ROW_HEIGHT}, "Assign Sprite") {
				sel := s.asset_browser.selected
				if sel >= 0 && sel < len(s.asset_browser.assets) {
					entry := s.asset_browser.assets[sel]
					if entry.kind == .TEXTURE {
						delete(entity.sprite_sheet_path)
						full_rel, _ := filepath.join({proj.RESOURCES_DIR, entry.rel_path})
						entity.sprite_sheet_path = full_rel
						rebuild_entity_sprites(s)
						scene_save_current(s)
					}
				}
			}
		}
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

	fmt.println("editor_render: done")
}

editor_destroy :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Editor_State)data
	tilemap_save(s)
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
	tilemap_painter_destroy(&s.tilemap_painter)
	entity_placement_destroy(&s.entity_placer)
	free(data)
}

compute_panel_layout :: proc() -> Panel_Layout {
	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	return Panel_Layout {
		left = {
			0,
			PANEL_TOP_HEIGHT,
			PANEL_LEFT_WIDTH,
			sh - PANEL_BOTTOM_HEIGHT - PANEL_TOP_HEIGHT,
		},
		right = {
			sw - PANEL_RIGHT_WIDTH,
			PANEL_TOP_HEIGHT,
			PANEL_RIGHT_WIDTH,
			sh - PANEL_BOTTOM_HEIGHT - PANEL_TOP_HEIGHT,
		},
		bottom = {0, sh - PANEL_BOTTOM_HEIGHT, sw, PANEL_BOTTOM_HEIGHT},
		top = {0, 0, sw, PANEL_TOP_HEIGHT},
		world = {
			PANEL_LEFT_WIDTH,
			PANEL_TOP_HEIGHT,
			sw - PANEL_LEFT_WIDTH - PANEL_RIGHT_WIDTH,
			sh - PANEL_BOTTOM_HEIGHT - PANEL_TOP_HEIGHT,
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
	fmt.println("scene_load_resources: start, tilemap_path: ", s.current_scene.tilemap_path)
	tilemap_abs, _ := filepath.join({s.project_root, s.current_scene.tilemap_path})
	defer delete(tilemap_abs)
	fmt.println("scene_load_resources: tilemap_abs: ", tilemap_abs)

	image_rels, ok := eng.tiled_get_all_tileset_images(tilemap_abs)
	fmt.println(
		"scene_load_resources: tiled_get_all_tileset_images: ok = ",
		ok,
		"count = ",
		len(image_rels),
	)
	if !ok {
		rebuild_entity_sprites(s)
		return
	}

	tileset_dir := filepath.dir(tilemap_abs)
	defer delete(tileset_dir)

	tileset_texs := make([]rl.Texture2D, len(image_rels))
	defer delete(tileset_texs)

	for rel, i in image_rels {
		fmt.println("scene_load_resources: loading tileset: ", i, "rel =", rel)
		joined, _ := filepath.join({tileset_dir, rel})
		tileset_abs, _ := filepath.clean(joined)
		delete(joined)
		tileset_texs[i] = scene_texture(s, tileset_abs)
		delete(tileset_abs)
		delete(rel)
	}
	delete(image_rels)

	fmt.println("scene_load_resources: calling destroy_tilemap")
	eng.destroy_tilemap(&s.scene_tilemap)
	fmt.println("scene_load_resources: calling tilemap_load_tiled")
	s.scene_tilemap, _ = eng.tilemap_load_tiled(tilemap_abs, tileset_texs)

	fmt.println(
		"scene_load_resources: tilemap loaded, cols =",
		s.scene_tilemap.cols,
		"layers = ",
		s.scene_tilemap.layers,
	)

	fmt.println("scene_load_resources: calling rebuild_entity_sprites")
	rebuild_entity_sprites(s)
	fmt.println("scene_load_resources: done")
}

rebuild_entity_sprites :: proc(s: ^Editor_State) {
	delete(s.entity_sprites)
	s.entity_sprites = nil
	s.entity_sprites = make([]eng.Sprite, len(s.current_scene.entities))

	for entity, i in s.current_scene.entities {
		if entity.sprite_sheet_path == "" do continue

		sprite_abs, _ := filepath.join({s.project_root, entity.sprite_sheet_path})
		defer delete(sprite_abs)

		tex := scene_texture(s, sprite_abs)
		if tex.id == 0 do continue

		s.entity_sprites[i] = eng.Sprite {
			texture = tex,
			src     = {0, 0, f32(tex.width), f32(tex.height)},
		}
	}
}

