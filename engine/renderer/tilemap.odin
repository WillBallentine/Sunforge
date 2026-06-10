package renderer

import rl "vendor:raylib"

MAX_TILE_LAYERS :: 4

Tilemap :: struct {
	tiles:      [][]i32,
	cols:       i32,
	rows:       i32,
	tile_w:     i32,
	tile_h:     i32,
	layers:     i32,
	solid:      []bool,
	tileset:    rl.Texture2D,
	ts_columns: i32,
}


tilemap_create :: proc(
	cols, rows, tile_w, tile_h, layers: i32,
	tileset: rl.Texture2D,
	ts_columns: i32,
) -> Tilemap {
	assert(layers <= MAX_TILE_LAYERS, "tilemap_create: layers exceeds MAX_TILE_LAYERS")

	tm: Tilemap
	tm.cols = cols
	tm.rows = rows
	tm.tile_w = tile_w
	tm.tile_h = tile_h
	tm.layers = layers
	tm.tileset = tileset
	tm.ts_columns = ts_columns

	tm.tiles = make([][]i32, layers)
	for i in 0 ..< layers {
		layer := make([]i32, rows * cols)
		for &cell in layer {
			cell = -1
		}
		tm.tiles[i] = layer
	}

	ts_rows := tileset.height / tile_h
	total_tiles := ts_columns * ts_rows
	tm.solid = make([]bool, total_tiles)

	return tm
}

tilemap_set_tile :: proc(tm: ^Tilemap, layer, col, row: i32, tile_index: i32) {
	assert(layer >= 0 && layer < tm.layers)
	assert(col >= 0 && col < tm.cols)
	assert(row >= 0 && row < tm.rows)
	tm.tiles[layer][row * tm.cols + col] = tile_index
}

tilemap_draw :: proc(tm: ^Tilemap, camera: rl.Camera2D) {
	inv_zoom := 1.0 / camera.zoom

	world_left := camera.target.x - camera.offset.x * inv_zoom
	world_right := camera.target.x + camera.offset.x * inv_zoom
	world_top := camera.target.y - camera.offset.y * inv_zoom
	world_bottom := camera.target.y + camera.offset.y * inv_zoom

	start_col := max(i32(0), i32(world_left / f32(tm.tile_w)) - 1)
	end_col := min(tm.cols, i32(world_right / f32(tm.tile_w)) + 2)
	start_row := max(i32(0), i32(world_top / f32(tm.tile_h)) - 1)
	end_row := min(tm.rows, i32(world_bottom / f32(tm.tile_h)) + 2)

	for layer in 0 ..< tm.layers {
		for row in start_row ..< end_row {
			for col in start_col ..< end_col {
				tile_idx := tm.tiles[layer][row * tm.cols + col]
				if tile_idx < 0 do continue

				ts_col := tile_idx % tm.ts_columns
				ts_row := tile_idx / tm.ts_columns
				src := rl.Rectangle {
					f32(ts_col * tm.tile_w),
					f32(ts_row * tm.tile_h),
					f32(tm.tile_w),
					f32(tm.tile_h),
				}

				dest := rl.Rectangle {
					f32(col * tm.tile_w),
					f32(row * tm.tile_h),
					f32(tm.tile_w),
					f32(tm.tile_h),
				}

				rl.DrawTexturePro(tm.tileset, src, dest, {0, 0}, 0, rl.WHITE)
			}
		}
	}
}

tilemap_is_solid :: proc(tm: ^Tilemap, tile_index: i32) -> bool {
	if tile_index < 0 || int(tile_index) >= len(tm.solid) do return false
	return tm.solid[tile_index]
}

tilemap_destroy :: proc(tm: ^Tilemap) {
	for layer in tm.tiles {
		delete(layer)
	}
	delete(tm.tiles)
	delete(tm.solid)
}

