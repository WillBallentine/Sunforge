package main

import eng "../engine"

MAX_STROKE_CELLS :: 256

Tile_Edit_Data :: struct {
	tilemap:   ^eng.Tilemap,
	layer:     i32,
	col:       i32,
	row:       i32,
	old_index: i32,
	new_index: i32,
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
	eng.tilemap_set_tile(d.tilemap, d.layer, d.col, d.row, d.new_index)
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
		eng.tilemap_set_tile(d.tilemap, d.layer, cell.col, cell.row, cell.new_index)
	}
}

make_tile_stoke_command :: proc(
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

make_title_edit_command :: proc(
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

