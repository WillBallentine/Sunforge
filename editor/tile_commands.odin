package main

import eng "../engine"
import "core:strings"
import rl "vendor:raylib"

MAX_STROKE_CELLS :: 256

Tile_Edit_Data :: struct {
	tilemap:   ^eng.Tilemap,
	layer:     i32,
	col:       i32,
	row:       i32,
	old_index: i32,
	new_index: i32,
}

Entity_Move_Data :: struct {
	scene:   ^Scene_Data,
	index:   int,
	old_pos: rl.Vector2,
	new_pos: rl.Vector2,
}

Entity_Delete_Data :: struct {
	scene:  ^Scene_Data,
	entity: Entity_Data,
	index:  int,
}

Entity_Place_Data :: struct {
	scene:  ^Scene_Data,
	entity: Entity_Data,
	index:  int,
}

Tile_Cell_Edit :: struct {
	col, row:             i32,
	old_index, new_index: i32,
}

Tile_Stroke_Data :: struct {
	tilemap: ^eng.Tilemap,
	layer:   i32,
	cells:   [MAX_STROKE_CELLS]Tile_Cell_Edit,
	count:   int,
}

tile_edit_do :: proc(data: rawptr) {
	d := cast(^Tile_Edit_Data)data
	eng.tilemap_set_tile(d.tilemap, d.layer, d.col, d.row, d.new_index)
}

tile_edit_undo :: proc(data: rawptr) {
	d := cast(^Tile_Edit_Data)data
	eng.tilemap_set_tile(d.tilemap, d.layer, d.col, d.row, d.old_index)
}

entity_move_do :: proc(data: rawptr) {
	d := cast(^Entity_Move_Data)data
	d.scene.entities[d.index].position = d.new_pos
}

entity_move_undo :: proc(data: rawptr) {
	d := cast(^Entity_Move_Data)data
	d.scene.entities[d.index].position = d.old_pos
}

entity_place_do :: proc(data: rawptr) {
	d := cast(^Entity_Place_Data)data
	new_list := make([]Entity_Data, len(d.scene.entities) + 1)
	copy(new_list[:d.index], d.scene.entities[:d.index])
	new_list[d.index] = entity_data_clone(d.entity)
	copy(new_list[d.index + 1:], d.scene.entities[d.index:])
	delete(d.scene.entities)
	d.scene.entities = new_list
}

entity_place_undo :: proc(data: rawptr) {
	d := cast(^Entity_Place_Data)data
	new_list := make([]Entity_Data, len(d.scene.entities) - 1)
	copy(new_list[:d.index], d.scene.entities[:d.index])
	copy(new_list[d.index:], d.scene.entities[d.index + 1:])
	entity_data_destroy(&d.scene.entities[d.index])
	delete(d.scene.entities)
	d.scene.entities = new_list
}

entity_place_destroy :: proc(data: rawptr) {
	d := cast(^Entity_Place_Data)data
	entity_data_destroy(&d.entity)
}

entity_delete_do :: proc(data: rawptr) {
	d := cast(^Entity_Delete_Data)data
	new_list := make([]Entity_Data, len(d.scene.entities) - 1)
	copy(new_list[:d.index], d.scene.entities[:d.index])
	copy(new_list[d.index:], d.scene.entities[d.index + 1:])
	entity_data_destroy(&d.scene.entities[d.index])
	delete(d.scene.entities)
	d.scene.entities = new_list
}

entity_delete_undo :: proc(data: rawptr) {
	d := cast(^Entity_Place_Data)data
	new_list := make([]Entity_Data, len(d.scene.entities) + 1)
	copy(new_list[:d.index], d.scene.entities[:d.index])
	new_list[d.index] = entity_data_clone(d.entity)
	copy(new_list[d.index + 1:], d.scene.entities[d.index:])
	delete(d.scene.entities)
	d.scene.entities = new_list
}

make_entity_delete_command :: proc(scene: ^Scene_Data, index: int) -> Editor_Command {
	d := new(Entity_Delete_Data)
	d.scene = scene
	d.entity = entity_data_clone(scene.entities[index])
	d.index = index
	return Editor_Command{do_fn = entity_delete_do, undo_fn = entity_delete_undo, data = d}
}

make_entity_place_command :: proc(
	scene: ^Scene_Data,
	entity: Entity_Data,
	index: int,
) -> Editor_Command {
	d := new(Entity_Place_Data)
	d.scene = scene
	d.entity = entity_data_clone(entity)
	d.index = index
	return Editor_Command {
		do_fn = entity_place_do,
		undo_fn = entity_place_undo,
		destroy_fn = entity_place_destroy,
		data = d,
	}
}

make_entity_move_command :: proc(
	scene: ^Scene_Data,
	index: int,
	old_pos, new_pos: rl.Vector2,
) -> Editor_Command {
	d := new(Entity_Move_Data)
	d.scene = scene
	d.index = index
	d.old_pos = old_pos
	d.new_pos = new_pos
	return Editor_Command{do_fn = entity_move_do, undo_fn = entity_move_undo, data = d}
}

tile_stroke_do :: proc(data: rawptr) {
	d := cast(^Tile_Stroke_Data)data
	for i in 0 ..< d.count {
		cell := d.cells[i]
		eng.tilemap_set_tile(d.tilemap, d.layer, cell.col, cell.row, cell.new_index)
	}
}

tile_stroke_undo :: proc(data: rawptr) {
	d := cast(^Tile_Stroke_Data)data
	for i in 0 ..< d.count {
		cell := d.cells[i]
		eng.tilemap_set_tile(d.tilemap, d.layer, cell.col, cell.row, cell.old_index)
	}
}

make_tile_stroke_command :: proc(
	tm: ^eng.Tilemap,
	layer: i32,
	cells: []Tile_Cell_Edit,
) -> Editor_Command {
	assert(len(cells) <= MAX_STROKE_CELLS)

	d := new(Tile_Stroke_Data)
	d.tilemap = tm
	d.layer = layer
	d.count = len(cells)
	for i in 0 ..< len(cells) {
		d.cells[i] = cells[i]
	}

	return Editor_Command{do_fn = tile_stroke_do, undo_fn = tile_stroke_undo, data = d}
}

make_tile_edit_command :: proc(
	tm: ^eng.Tilemap,
	layer, col, row, old_index, new_index: i32,
) -> Editor_Command {
	d := new(Tile_Edit_Data)
	d.tilemap = tm
	d.layer = layer
	d.col = col
	d.row = row
	d.old_index = old_index
	d.new_index = new_index

	return Editor_Command{do_fn = tile_edit_do, undo_fn = tile_edit_undo, data = d}
}

entity_data_clone :: proc(e: Entity_Data) -> Entity_Data {
	out: Entity_Data
	out.name = strings.clone(e.name)
	out.sprite_sheet_path = strings.clone(e.sprite_sheet_path)
	out.animation = strings.clone(e.animation)
	out.tags = make([]string, len(e.tags))
	for i in 0 ..< len(e.tags) {out.tags[i] = strings.clone(e.tags[i])}
	out.properties = make(map[string]string)
	for k, v in e.properties {out.properties[strings.clone(k)] = strings.clone(v)}
	return out
}

entity_data_destroy :: proc(e: ^Entity_Data) {
	delete(e.name)
	delete(e.sprite_sheet_path)
	delete(e.animation)
	for tag in e.tags {delete(tag)}
	delete(e.tags)
	for k, v in e.properties {delete(k); delete(v)}
	delete(e.properties)
}

