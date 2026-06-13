package project

import engCore "../engine/core"
import "core:encoding/json"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

PROJECT_FILE :: "project.json"
RESOURCES_DIR :: "resources"
SCENES_DIR :: "scenes"


Project_Data :: struct {
	name:        string,
	entry_scene: string,
	window:      engCore.Window_Config,
	icon_path:   string,
}

Picker_Data :: struct {
	name:        string,
	entry_scene: string,
	window:      engCore.Window_Config,
	icon_path:   string,
}


project_create :: proc(root: string, name: string) -> (Project_Data, bool) {
	manifest_path, _ := filepath.join({root, PROJECT_FILE})
	defer delete(manifest_path)

	if os.exists(manifest_path) {
		return {}, false
	}

	if !ensure_dir(root) do return {}, false

	resources_path, _ := filepath.join({root, RESOURCES_DIR})
	defer delete(resources_path)
	if !ensure_dir(resources_path) do return {}, false

	scenes_path, _ := filepath.join({root, SCENES_DIR})
	defer delete(scenes_path)
	if !ensure_dir(scenes_path) do return {}, false

	title := strings.clone_to_cstring(name)

	data := Project_Data {
		name = strings.clone(name),
		entry_scene = strings.clone(""),
		window = engCore.Window_Config {
			width = 1280,
			height = 720,
			title = title,
			target_fps = 60,
			is_resizeable = true,
		},
		icon_path = strings.clone(""),
	}

	if !project_save(root, data) do return {}, false

	return data, true
}


ensure_dir :: proc(path: string) -> bool {
	if os.exists(path) {
		return os.is_dir(path)
	}

	return os.make_directory(path) == nil
}

project_save :: proc(root: string, data: Project_Data) -> bool {
	manifest_path, _ := filepath.join({root, PROJECT_FILE})
	defer delete(manifest_path)

	bytes, err := json.marshal(data, {pretty = true})
	if err != nil {
		return false
	}

	defer delete(bytes)
	return os.write_entire_file(manifest_path, bytes) == nil
}

project_open :: proc(root: string) -> (Project_Data, bool) {
	if !os.exists(root) || !os.is_dir(root) {
		return {}, false
	}

	manifest_path, _ := filepath.join({root, PROJECT_FILE})
	defer delete(manifest_path)

	bytes, err := os.read_entire_file(manifest_path, context.allocator)
	if err != nil {
		return {}, false
	}
	defer delete(bytes)

	data: Project_Data
	if json.unmarshal(bytes, &data) != nil {
		return {}, false
	}

	resources_path, _ := filepath.join({root, RESOURCES_DIR})
	defer delete(resources_path)
	scenes_path, _ := filepath.join({root, SCENES_DIR})
	defer delete(scenes_path)

	if !os.is_dir(resources_path) || !os.is_dir(scenes_path) {
		return {}, false
	}

	return data, true
}

project_apply_icon :: proc(project_root: string, data: ^Project_Data) {
	if data.icon_path == "" {
		return
	}
	full_path, _ := filepath.join({project_root, data.icon_path}, context.temp_allocator)
	cpath := strings.clone_to_cstring(full_path, context.temp_allocator)

	img := rl.LoadImage(cpath)
	defer rl.UnloadImage(img)

	rl.SetWindowIcon(img)
}

