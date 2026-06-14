package main

import "core:encoding/json"
import "core:os"
import rl "vendor:raylib"

Scene_Data :: struct {
	tilemap_path: string,
	entities:     []Entity_Data,
	camera:       Camera_Config_Data,
}

Entity_Data :: struct {
	name:              string,
	position:          rl.Vector2,
	sprite_sheet_path: string,
	animation:         string,
	tags:              []string,
	properties:        map[string]string,
}

Camera_Config_Data :: struct {
	follow_speed: f32,
	zoom:         f32,
}

scene_save :: proc(path: string, data: Scene_Data) -> bool {
	bytes, err := json.marshal(data, {pretty = true})
	if err != nil {
		return false
	}
	defer delete(bytes)

	return os.write_entire_file(path, bytes) == nil
}

scene_load :: proc(path: string) -> (Scene_Data, bool) {
	bytes, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return {}, false
	}
	defer delete(bytes)

	data: Scene_Data
	if json.unmarshal(bytes, &data) != nil {
		return {}, false
	}

	return data, true
}

scene_destroy :: proc(data: ^Scene_Data) {
	delete(data.tilemap_path)

	for entity in data.entities {
		delete(entity.name)
		delete(entity.sprite_sheet_path)
		delete(entity.animation)

		for tag in entity.tags {
			delete(tag)
		}
		delete(entity.tags)

		for key, value in entity.properties {
			delete(key)
			delete(value)
		}
		delete(entity.properties)
	}

	delete(data.entities)
}

