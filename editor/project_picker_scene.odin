package main

import eng "../engine"
import proj "../project"
import ui "./ui"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

PICKER_WIDTH :: 480
PICKER_HEIGHT :: 360
PICKER_MARGIN :: 12
MAX_VISIBLE_RECENTS :: 5

PICKER_WINDOW_CONFIG :: eng.Window_Config {
	width         = PICKER_WIDTH,
	height        = PICKER_HEIGHT,
	title         = "Sunforge Editor",
	target_fps    = 60,
	is_resizeable = false,
}


Picker_State :: struct {
	recent_projects: []string,
	path_input:      string,
	status:          string,
}

picker_scene :: proc() -> eng.Scene_Procs {
	state := new(Picker_State)
	return eng.Scene_Procs {
		data = state,
		init = picker_init,
		update = picker_update,
		render = picker_render,
		destroy = picker_destroy,
	}
}

picker_init :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Picker_State)data
	s.recent_projects = recent_projects_load()
	s.path_input = strings.clone("")
	s.status = strings.clone("")
}

picker_update :: proc(e: ^eng.Engine, data: rawptr, dt: f32) {
	ui.ui_begin(&e.input)
}

picker_render :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Picker_State)data
	rl.ClearBackground(ui.PANEL_BG)
	rl.DrawText("Sunforge Editor", PICKER_MARGIN, PICKER_MARGIN, 20, ui.TEXT)
	rl.DrawText("Recent Projects", PICKER_MARGIN, 44, ui.FONT_SIZE, ui.TEXT)

	y: f32 = 64
	visible := min(len(s.recent_projects), MAX_VISIBLE_RECENTS)
	for i in 0 ..< visible {
		row := rl.Rectangle{PICKER_MARGIN, y, PICKER_WIDTH - PICKER_MARGIN * 2, ui.ROW_HEIGHT}
		if ui.ui_button(row, fmt.ctprintf("%s", s.recent_projects[i])) {
			if try_open(e, s, s.recent_projects[i]) {
				return
			}
		}
		y += ui.ROW_HEIGHT + 4
	}

	if visible == 0 {
		rl.DrawText("(no recent projects)", PICKER_MARGIN, i32(y), ui.FONT_SIZE, ui.BORDER)
		y += ui.ROW_HEIGHT
	}

	y += 16
	rl.DrawText("Open Existing", PICKER_MARGIN, i32(y), ui.FONT_SIZE, ui.TEXT)
	y += 20

	input_rect := rl.Rectangle {
		PICKER_MARGIN,
		y,
		PICKER_WIDTH - PICKER_MARGIN * 3 - 80,
		ui.ROW_HEIGHT,
	}
	open_rect := rl.Rectangle {
		input_rect.x + input_rect.width + PICKER_MARGIN,
		y,
		80,
		ui.ROW_HEIGHT,
	}

	ui.ui_text_input(input_rect, &s.path_input)
	if ui.ui_button(open_rect, "Open") && len(s.path_input) > 0 {
		if try_open(e, s, s.path_input) {
			return
		}
	}

	y += ui.ROW_HEIGHT + 16

	create_rect := rl.Rectangle{PICKER_MARGIN, y, PICKER_WIDTH - PICKER_MARGIN * 2, ui.ROW_HEIGHT}
	if ui.ui_button(create_rect, "Create New Project...") {
		if picked, ok := pick_folder("Select a folder for the new project"); ok {
			defer delete(picked)
			if try_open(e, s, picked) {
				return
			}
		}
	}
	y += ui.ROW_HEIGHT + 16

	if len(s.status) > 0 {
		rl.DrawText(fmt.ctprintf("%s", s.status), PICKER_MARGIN, i32(y), ui.FONT_SIZE, ui.TEXT)
	}

}

picker_destroy :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Picker_State)data
	for p in s.recent_projects {
		delete(p)
	}
	delete(s.recent_projects)
	delete(s.path_input)
	delete(s.status)
	free(data)
}

open_or_create_project :: proc(root: string) -> (proj.Project_Data, bool) {
	manifest, _ := filepath.join({root, proj.PROJECT_FILE})
	defer delete(manifest)

	if os.exists(manifest) {
		return proj.project_open(root)
	}
	return proj.project_create(root, filepath.base(root))
}

try_open :: proc(e: ^eng.Engine, s: ^Picker_State, root: string) -> bool {
	project, ok := open_or_create_project(root)
	if !ok {
		delete(s.status)
		s.status = strings.clone("Could not open or create project")
		return false
	}

	recents := recent_projects_load()
	recents = recent_projects_add(recents, root)
	recent_projects_save(recents)

	rl.SetWindowSize(project.window.width, project.window.height)
	rl.SetWindowTitle(project.window.title)
	eng.window_set_resizeable(&e.window, true)
	project_root := strings.clone(root)

	eng.scene_push(e, editor_scene(project_root, project))
	return true
}

