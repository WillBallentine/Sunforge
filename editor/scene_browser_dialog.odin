package main

import eng "../engine"
import proj "../project"
import ui "./ui"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

Browse_Scenes_Dialog_State :: struct {
	open:           bool,
	scene_selected: int,
	scenes:         [dynamic]Asset_Entry,
	name:           string,
}

browse_scenes_dialog_init :: proc() -> Browse_Scenes_Dialog_State {
	return Browse_Scenes_Dialog_State {
		open = false,
		scene_selected = -1,
		scenes = make([dynamic]Asset_Entry, 0),
		name = strings.clone(""),
	}
}

browse_scenes_dialog_refresh :: proc(d: ^Browse_Scenes_Dialog_State, s: ^Editor_State) {
	for entry in d.scenes {
		delete(entry.name)
		delete(entry.rel_path)
		delete(entry.full_path)
	}
	clear(&d.scenes)

	walked := walk_scene_dir(s)
	defer delete(walked)

	for entry in walked {
		if entry.kind != .JSON {
			delete(entry.name)
			delete(entry.rel_path)
			delete(entry.full_path)
			continue
		}
		append(&d.scenes, entry)
	}

	d.scene_selected = -1
}

browse_scene_dialog_render :: proc(s: ^Editor_State) -> bool {
	d := &s.browse_scene_dialog
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

	body := ui.ui_panel(rect, "Switch Scene")
	pad: f32 = ui.PADDING
	row_h: f32 = ui.ROW_HEIGHT
	row := body.y

	scene_paths := make([dynamic]string, 0, len(s.asset_browser.assets), context.temp_allocator)
	for entry in d.scenes {
		if entry.kind != .JSON do continue
		append(&scene_paths, entry.rel_path)
	}

	combo_rect := rl.Rectangle{body.x + pad, row, body.width - pad * 2, row_h}
	row += row_h + pad

	can_select := d.scene_selected >= 0 && d.scene_selected < len(d.scenes)

	btn_w := (body.width - pad * 3) / 2
	select_rect := rl.Rectangle{body.x + pad, row, btn_w, row_h}
	cancel_rect := rl.Rectangle{body.x + pad * 2 + btn_w, row, btn_w, row_h}
	rename_rect := rl.Rectangle{body.x + pad, row + row_h + pad, body.width - pad * 2, row_h}
	rename_input_rect := rl.Rectangle {
		body.x + pad,
		row + (row_h * 2) + pad * 2,
		body.width - pad * 2,
		row_h,
	}
	ui.ui_text_input(rename_input_rect, &d.name)

	select := false
	if ui.ui_button(select_rect, "Select") && can_select {
		select = true
	}
	if ui.ui_button(cancel_rect, "Cancel") {
		d.open = false
	}
	if ui.ui_button(rename_rect, "Rename") && can_select && d.name != "" {
		rename_scene(s)
	}

	if len(scene_paths) == 0 {
		rl.DrawText(
			"No scenes to select - create one first",
			i32(body.x + pad),
			i32(row + row_h + pad),
			ui.FONT_SIZE,
			ui.TEXT,
		)
	}
	ui.ui_combo(combo_rect, "Scenes", scene_paths[:], &d.scene_selected)

	return select
}

walk_scene_dir :: proc(s: ^Editor_State) -> [dynamic]Asset_Entry {
	scenes_root, _ := filepath.join({s.project_root, proj.SCENES_DIR})
	defer delete(scenes_root)

	asset_entries := make([dynamic]Asset_Entry, 0)

	scenes_walker := os.walker_create(scenes_root)
	defer os.walker_destroy(&scenes_walker)

	for info in os.walker_walk(&scenes_walker) {
		if info.type != .Regular {
			continue
		}

		rel, err := filepath.rel(scenes_root, info.fullpath)
		if err != .None {
			continue
		}

		append(
			&asset_entries,
			Asset_Entry {
				name = strings.clone(filepath.base(info.fullpath)),
				rel_path = rel,
				full_path = strings.clone(info.fullpath),
				kind = asset_classify(info.fullpath),
			},
		)
	}

	return asset_entries
}

rename_scene :: proc(s: ^Editor_State) -> bool {
	d := &s.browse_scene_dialog

	if d.scene_selected < 0 || d.scene_selected >= len(d.scenes) {
		return false
	}

	old_abs, _ := filepath.join(
		{s.project_root, proj.SCENES_DIR, d.scenes[d.scene_selected].rel_path},
	)
	defer delete(old_abs)
	new_name := fmt.tprintf("%s.json", d.name)
	new_abs, _ := filepath.join({s.project_root, proj.SCENES_DIR, new_name})
	defer delete(new_abs)
	if os.rename(old_abs, new_abs) != nil {
		return false
	}

	if s.project.entry_scene == d.scenes[d.scene_selected].rel_path {
		delete(s.project.entry_scene)
		s.project.entry_scene = strings.clone(new_name)
		proj.project_save(s.project_root, s.project)
	}

	browse_scenes_dialog_refresh(d, s)

	return true
}

select_scene :: proc(s: ^Editor_State) -> bool {
	d := &s.browse_scene_dialog

	if d.scene_selected < 0 || d.scene_selected >= len(d.scenes) {
		return false
	}

	scene_rel := d.scenes[d.scene_selected].rel_path

	scene_abs, _ := filepath.join({s.project_root, proj.SCENES_DIR, scene_rel})
	defer delete(scene_abs)

	loaded, load_ok := scene_load(scene_abs)
	if !load_ok {
		return false
	}

	eng.destroy_tilemap(&s.scene_tilemap)
	delete(s.entity_sprites)
	scene_destroy(&s.current_scene)

	s.current_scene = loaded
	scene_load_resources(s)
	tilemap_painter_on_scene_loaded(&s.tilemap_painter, s)
	s.edit_camera.camera.target = {
		f32(s.scene_tilemap.cols * s.scene_tilemap.tile_w) / 2,
		f32(s.scene_tilemap.rows * s.scene_tilemap.tile_h) / 2,
	}

	delete(s.project.entry_scene)
	s.project.entry_scene = strings.clone(scene_rel)
	proj.project_save(s.project_root, s.project)

	history_destroy(&s.history)

	return true
}

browse_scene_dialog_destroy :: proc(d: ^Browse_Scenes_Dialog_State) {
	delete(d.name)
	for entry in d.scenes {
		delete(entry.name)
		delete(entry.rel_path)
		delete(entry.full_path)
	}
	delete(d.scenes)
}

