package main

import eng "../engine"
import proj "../project"
import ui "./ui"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

DIALOG_WIDTH :: 360
DIALOG_HEIGHT :: 260

New_Scene_Dialog_State :: struct {
	open:             bool,
	name:             string,
	cols, rows:       f32,
	tile_w, tile_h:   f32,
	tileset_selected: int,
}

new_scene_dialog_init :: proc() -> New_Scene_Dialog_State {
	return New_Scene_Dialog_State {
		open = false,
		name = strings.clone("level_01"),
		cols = 20,
		rows = 15,
		tile_w = 32,
		tile_h = 32,
		tileset_selected = -1,
	}
}

new_scene_dialog_render :: proc(s: ^Editor_State) -> bool {
	d := &s.new_scene_dialog
	if !d.open {
		return false
	}

	sw := f32(rl.GetScreenWidth())
	sh := f32(rl.GetScreenHeight())
	rect := rl.Rectangle {
		(sw - DIALOG_WIDTH) / 2,
		(sh - DIALOG_HEIGHT) / 2,
		DIALOG_WIDTH,
		DIALOG_HEIGHT,
	}

	body := ui.ui_panel(rect, "New Scene")
	pad: f32 = ui.PADDING
	row_h: f32 = ui.ROW_HEIGHT
	row := body.y

	ui.ui_text_input({body.x + pad, row, body.width - pad * 2, row_h}, &d.name)
	row += row_h + pad
	ui.ui_drag_float({body.x + pad, row, body.width - pad * 2, row_h}, "Columns", &d.cols, 0.25)
	row += row_h + pad
	ui.ui_drag_float({body.x + pad, row, body.width - pad * 2, row_h}, "Rows", &d.rows, 0.25)
	row += row_h + pad
	ui.ui_drag_float(
		{body.x + pad, row, body.width - pad * 2, row_h},
		"Tile Width",
		&d.tile_w,
		0.25,
	)
	row += row_h + pad
	ui.ui_drag_float(
		{body.x + pad, row, body.width - pad * 2, row_h},
		"Tile Height",
		&d.tile_h,
		0.25,
	)
	row += row_h + pad

	tileset_paths := make([dynamic]string, 0, len(s.asset_browser.assets), context.temp_allocator)
	for entry in s.asset_browser.assets {
		if entry.kind != .TEXTURE do continue
		append(&tileset_paths, entry.rel_path)
	}
	combo_rect := rl.Rectangle{body.x + pad, row, body.width - pad * 2, row_h}

	row += row_h + pad

	cols_i := i32(d.cols + 0.5)
	rows_i := i32(d.rows + 0.5)
	tw_i := i32(d.tile_w + 0.5)
	th_i := i32(d.tile_h + 0.5)

	can_create :=
		d.name != "" &&
		cols_i >= 1 &&
		rows_i >= 1 &&
		tw_i >= 1 &&
		th_i >= 1 &&
		d.tileset_selected >= 0 &&
		d.tileset_selected < len(tileset_paths)

	btn_w := (body.width - pad * 3) / 2
	create_rect := rl.Rectangle{body.x + pad, row, btn_w, row_h}
	cancel_rect := rl.Rectangle{body.x + pad * 2 + btn_w, row, btn_w, row_h}

	created := false
	if ui.ui_button(create_rect, "Create") && can_create {
		created = true
	}
	if ui.ui_button(cancel_rect, "Cancel") {
		d.open = false
	}

	if len(tileset_paths) == 0 {
		rl.DrawText(
			"No textures in resources/ yet - import one first",
			i32(body.x + pad),
			i32(row + row_h + pad),
			ui.FONT_SIZE,
			ui.TEXT,
		)
	}

	ui.ui_combo(combo_rect, "Tileset", tileset_paths[:], &d.tileset_selected)

	return created
}

create_new_scene :: proc(s: ^Editor_State) -> bool {
	d := &s.new_scene_dialog

	cols_i := i32(d.cols + 0.5)
	rows_i := i32(d.rows + 0.5)
	tw_i := i32(d.tile_w + 0.5)
	th_i := i32(d.tile_h + 0.5)

	tileset_rel := ""
	i := 0
	for entry in s.asset_browser.assets {
		if entry.kind != .TEXTURE do continue
		if i == d.tileset_selected {
			tileset_rel = entry.rel_path
			break
		}

		i += 1
	}
	if tileset_rel == "" {
		return false
	}

	tileset_abs, _ := filepath.join({s.project_root, proj.RESOURCES_DIR, tileset_rel})
	defer delete(tileset_abs)
	tex := scene_texture(s, tileset_abs)

	ts_columns := tex.width / tw_i
	ts_rows := tex.height / th_i
	ts_tilecount := ts_columns * ts_rows

	scene_filename, ok := scene_create_new(
		s.project_root,
		d.name,
		cols_i,
		rows_i,
		tw_i,
		th_i,
		tileset_rel,
		ts_columns,
		ts_tilecount,
	)
	if !ok {
		return false
	}

	defer delete(scene_filename)

	scene_path, _ := filepath.join({s.project_root, proj.SCENES_DIR, scene_filename})
	defer delete(scene_path)

	loaded, load_ok := scene_load(scene_path)
	if !load_ok {
		return false
	}

	eng.destroy_tilemap(&s.scene_tilemap)
	delete(s.entity_sprites)
	scene_destroy(&s.current_scene)

	s.current_scene = loaded
	scene_load_resources(s)
	s.edit_camera.camera.target = {
		f32(s.scene_tilemap.cols * s.scene_tilemap.tile_w) / 2,
		f32(s.scene_tilemap.rows * s.scene_tilemap.tile_h) / 2,
	}

	delete(s.project.entry_scene)
	s.project.entry_scene = strings.clone(scene_filename)
	proj.project_save(s.project_root, s.project)

	return true
}

new_scene_dialog_destroy :: proc(d: ^New_Scene_Dialog_State) {
	delete(d.name)
}

tilemap_create_empty_tiled_json :: proc(
	cols, rows, tile_w, tile_h: i32,
	image_rel: string,
	ts_columns, ts_tilecount: i32,
) -> string {
	b: strings.Builder
	strings.builder_init(&b)

	strings.write_string(&b, "\n")
	fmt.sbprintf(&b, "  \"width\": %d,\n", cols)
	fmt.sbprintf(&b, "  \"height\": %d,\n", rows)
	fmt.sbprintf(&b, "  \"tilewidth\": %d,\n", tile_w)
	fmt.sbprintf(&b, "  \"tileheight\": %d,\n", tile_h)
	strings.write_string(&b, "  \"orientation\": \"orthogonal\",\n")
	strings.write_string(&b, "  \"layers\": [\n")
	strings.write_string(&b, "    {\n")
	strings.write_string(&b, "     \"type\": \"tilelayer\", \n")
	strings.write_string(&b, "     \"name\": \"ground\", \n")
	strings.write_string(&b, "     \"data\": [\n")
	for row in 0 ..< rows {
		strings.write_string(&b, "        ")
		for col in 0 ..< cols {
			strings.write_string(&b, "0")
			if row != rows - 1 || col != cols - 1 {
				strings.write_string(&b, ", ")
			}
		}
		strings.write_string(&b, "\n")
	}
	strings.write_string(&b, "      ]\n")
	strings.write_string(&b, "    }\n")
	strings.write_string(&b, "  ],\n")
	strings.write_string(&b, "  \"tilesets\": [\n")
	strings.write_string(&b, "    {\n")
	fmt.sbprintf(&b, "      \"firstgid\": %d,\n", 1)
	fmt.sbprintf(&b, "      \"image\": \"%s\",\n", image_rel)
	fmt.sbprintf(&b, "      \"titlewidth\": %d,\n", tile_w)
	fmt.sbprintf(&b, "      \"titleheight\": %d,\n", tile_h)
	fmt.sbprintf(&b, "      \"columns\": %d,\n", ts_columns)
	fmt.sbprintf(&b, "      \"tilecount\": %d,\n", ts_tilecount)
	strings.write_string(&b, "      \"tiles\": []\n")
	strings.write_string(&b, "    }\n")
	strings.write_string(&b, "  ]\n")
	strings.write_string(&b, "}\n")

	return strings.to_string(b)
}


scene_create_new :: proc(
	project_root, name: string,
	cols, rows, tile_w, tile_h: i32,
	tileset_rel: string,
	ts_columns, ts_tilecount: i32,
) -> (
	scene_filename: string,
	ok: bool,
) {
	scene_filename = fmt.tprintf("%s.json", name)
	scene_abs, _ := filepath.join({project_root, proj.SCENES_DIR, scene_filename})
	defer delete(scene_abs)

	if os.exists(scene_abs) {
		return "", false
	}


	tilemaps_dir, _ := filepath.join({project_root, proj.RESOURCES_DIR, "tilemaps"})
	defer delete(tilemaps_dir)

	if !os.exists(tilemaps_dir) {
		if os.make_directory(tilemaps_dir) != nil {
			return "", false
		}
	}

	tilemap_rel := fmt.tprintf("%s/tilemaps/%s.json", proj.RESOURCES_DIR, name)
	tilemap_abs, _ := filepath.join({project_root, tilemap_rel})
	defer delete(tilemap_abs)

	image_rel_raw, rel_err := filepath.rel("tilemaps", tileset_rel)
	if rel_err != .None {
		return "", false
	}
	defer delete(image_rel_raw)

	image_for_json, was_alloc := strings.replace_all(image_rel_raw, "\\", "/")
	if was_alloc {
		defer delete(image_for_json)
	}

	json_text := tilemap_create_empty_tiled_json(
		cols,
		rows,
		tile_w,
		tile_h,
		image_for_json,
		ts_columns,
		ts_tilecount,
	)
	defer delete(json_text)

	if os.write_entire_file(tilemap_abs, transmute([]byte)json_text) != nil {
		return "", false
	}

	scene := Scene_Data {
		tilemap_path = strings.clone(tilemap_rel),
		camera = Camera_Config_Data{follow_speed = 0, zoom = 1.0},
	}


	if !scene_save(scene_abs, scene) {
		return "", false
	}

	return strings.clone(scene_filename), true
}

