package main

import eng "../engine"
import proj "../project"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"


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
}

