package project

import "core:os"
import "core:path/filepath"
import "core:testing"

@(test)
test_project_roundtrip :: proc(t: ^testing.T) {
	root := "C:/temp/sunforge_test_project"
	defer os.remove_all(root)

	created, ok := project_create(root, "Test Game")
	testing.expect(t, ok)
	testing.expect_value(t, created.name, "Test Game")
	testing.expect_value(t, created.icon_path, "")

	manifest_path, _ := filepath.join({root, PROJECT_FILE})
	defer delete(manifest_path)
	testing.expect(t, os.exists(manifest_path))

	resources_path, _ := filepath.join({root, RESOURCES_DIR})
	defer delete(resources_path)
	testing.expect(t, os.is_dir(resources_path))

	scenes_path, _ := filepath.join({root, SCENES_DIR})
	defer delete(scenes_path)
	testing.expect(t, os.is_dir(scenes_path))

	opened, ok2 := project_open(root)
	testing.expect(t, ok2)
	testing.expect_value(t, opened.name, created.name)

	_, ok3 := project_create(root, "Different Name")
	testing.expect(t, !ok3)
}

