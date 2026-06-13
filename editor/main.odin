package main

import eng "../engine"
import engCore "../engine/core"
import proj "../project"
import ui "./ui"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"


main :: proc() {
	recents := recent_projects_load()

	fmt.println("Sunforge Editor")
	fmt.println("Recent projects: ")
	for p, i in recents {
		fmt.printfln(" [%d] %s", i, p)
	}
	fmt.println("Enter a project folder path (existing or new): ")

	buf: [512]byte
	n, _ := os.read(os.stdin, buf[:])
	root := strings.trim_space(string(buf[:n]))

	manifest, _ := filepath.join({root, proj.PROJECT_FILE})
	defer delete(manifest)

	project: proj.Project_Data
	ok: bool
	if os.exists(manifest) {
		project, ok = proj.project_open(root)
	} else {
		project, ok = proj.project_create(root, filepath.base(root))
	}
	if !ok {
		fmt.eprintln("could not open or create project at ", root)
		return
	}

	recents = recent_projects_add(recents, root)
	recent_projects_save(recents)

	//run the engine here once the editor shell is added

	//everything below this is just for testing the widgets and will be removed once the editor shell is written
	rl.InitWindow(800, 600, "ui check")
	defer rl.CloseWindow()

	input: engCore.Input_State
	engCore.input_init(&input)

	volume: f32 = 0.5
	brightness: f32 = 1
	enabled := true
	color := rl.Color{255, 0, 0, 255}

	name := strings.clone("Player")
	defer delete(name)
	options := []string{"idle", "walk", "jump"}
	selected := 0
	tree_open := false

	for !rl.WindowShouldClose() {

		engCore.input_poll(&input)
		ui.ui_begin(&input)

		rl.BeginDrawing()
		content := ui.ui_panel(rl.Rectangle{0, 0, 300, 400}, "Inspector")
		_ = ui.ui_button(rl.Rectangle{content.x, content.y, 100, ui.ROW_HEIGHT}, "Play")
		ui.ui_checkbox(
			rl.Rectangle{content.x, content.y + 30, 150, ui.ROW_HEIGHT},
			"Visible",
			&enabled,
		)
		ui.ui_drag_float(
			rl.Rectangle{content.x, content.y + 60, 150, ui.ROW_HEIGHT},
			"Brightness",
			&brightness,
			0.1,
		)
		ui.ui_slider_float(
			rl.Rectangle{content.x, content.y + 90, 150, ui.ROW_HEIGHT},
			"Volume",
			&volume,
			0,
			1,
		)
		ui.ui_color_picker(
			rl.Rectangle{content.x, content.y + 120, 150, ui.ROW_HEIGHT * 4},
			&color,
		)
		ui.ui_combo(
			rl.Rectangle{content.x, content.y + 220, 150, ui.ROW_HEIGHT},
			"Anim",
			options,
			&selected,
		)
		_ = ui.ui_tree_node(
			rl.Rectangle{content.x, content.y + 250, 150, ui.ROW_HEIGHT},
			"Player",
			&tree_open,
		)
		ui.ui_text_input(rl.Rectangle{content.x, content.y + 280, 150, ui.ROW_HEIGHT}, &name)
		rl.EndDrawing()

	}
}

