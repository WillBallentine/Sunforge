package main

import "core:encoding/json"
import "core:os"
import "core:path/filepath"

RECENT_PROJECTS_FILE :: "recent_projects.json"
MAX_RECENT_PROJECTS :: 10

recent_projects_path :: proc() -> (string, bool) {
	dir, err := os.get_executable_directory(context.allocator)
	if err != nil do return "", false
	defer delete(dir)

	path, _ := filepath.join({dir, RECENT_PROJECTS_FILE})
	return path, true
}

recent_projects_load :: proc() -> []string {
	path, ok := recent_projects_path()
	if !ok do return nil
	defer delete(path)

	if !os.exists(path) {
		return nil
	}

	bytes, err := os.read_entire_file(path, context.allocator)
	if err != nil do return nil
	defer delete(bytes)

	paths: []string
	if json.unmarshal(bytes, &paths) != nil do return nil
	return paths
}

recent_projects_save :: proc(paths: []string) -> bool {
	path, ok := recent_projects_path()
	if !ok do return false
	defer delete(path)

	bytes, err := json.marshal(paths, {pretty = true})
	if err != nil do return false
	defer delete(bytes)

	return os.write_entire_file(path, bytes) == nil
}

recent_projects_add :: proc(paths: []string, root: string) -> []string {
	updated := make([dynamic]string, 0, len(paths) + 1)
	append(&updated, root)
	for p in paths {
		if p == root do continue
		if len(updated) >= MAX_RECENT_PROJECTS do break
		append(&updated, p)
	}
	return updated[:]
}

