package main

import "core:path/filepath"
import "core:strings"

derive_save_path :: proc(s: ^Sprite_Sheet_Editor_State, es: ^Editor_State) -> string {
	if s.save_path != "" do return strings.clone(s.save_path)

	stem := filepath.stem(s.tex_path)
	dir := filepath.dir(s.tex_path)
	path, _ := filepath.join({dir, strings.concatenate({stem, ".json"})})
	return path
}

