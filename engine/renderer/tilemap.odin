package renderer

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

MAX_TILE_LAYERS :: 4
TILED_FLIP_MASK :: u32(0xE0000000)

Tilemap :: struct {
	tiles:        [][]i32,
	cols:         i32,
	rows:         i32,
	tile_w:       i32,
	tile_h:       i32,
	layers:       i32,
	solid:        []bool,
	tileset:      rl.Texture2D,
	ts_columns:   i32,
	ts_tilecount: i32,
}

Tiled_Property :: struct {
	name:  string,
	type:  string,
	value: json.Value,
}

Tiled_Tile :: struct {
	id:         i32,
	properties: []Tiled_Property,
}

Tiled_Tileset :: struct {
	firstgid:   u32,
	image:      string,
	tilewidth:  i32,
	tileheight: i32,
	columns:    i32,
	tilecount:  i32,
	tiles:      []Tiled_Tile,
}

Tiled_Layer :: struct {
	type:     string,
	name:     string,
	encoding: string,
	data:     []u32,
}

Tiled_Map :: struct {
	width:       i32,
	height:      i32,
	tilewidth:   i32,
	tileheight:  i32,
	orientation: string,
	layers:      []Tiled_Layer,
	tilesets:    []Tiled_Tileset,
}

Tiled_Tileset_Ref :: struct {
	tilesets: []struct {
		image: string,
	},
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
	tm.ts_tilecount = ts_columns * (tileset.height / tile_h)

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

tilemap_draw_layer :: proc(tm: ^Tilemap, camera: rl.Camera2D, layer: i32) {
	if layer < 0 || layer >= tm.layers do return
	inv_zoom := 1.0 / camera.zoom
	world_left := camera.target.x - camera.offset.x * inv_zoom
	world_right := camera.target.x + camera.offset.x * inv_zoom
	world_top := camera.target.y - camera.offset.y * inv_zoom
	world_bottom := camera.target.y + camera.offset.y * inv_zoom

	start_col := max(i32(0), i32(world_left / f32(tm.tile_w)) - 1)
	end_col := min(tm.cols, i32(world_right / f32(tm.tile_w)) + 2)
	start_row := max(i32(0), i32(world_top / f32(tm.tile_h)) - 1)
	end_row := min(tm.rows, i32(world_bottom / f32(tm.tile_h)) + 2)

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

tilemap_save_tiled :: proc(path: string, tilemap: ^Tilemap, image_rel: string) -> bool {
	b: strings.Builder
	strings.builder_init(&b)
	defer delete(b.buf)

	strings.write_string(&b, "{\n")
	fmt.sbprintf(&b, "  \"width\": %d,\n", tilemap.cols)
	fmt.sbprintf(&b, "  \"height\": %d,\n", tilemap.rows)
	fmt.sbprintf(&b, "  \"tilewidth\": %d,\n", tilemap.tile_w)
	fmt.sbprintf(&b, "  \"tileheight\": %d,\n", tilemap.tile_h)
	strings.write_string(&b, "  \"orientation\": \"orthogonal\",\n")
	strings.write_string(&b, "  \"layers\": [\n")

	for layer_i in 0 ..< tilemap.layers {
		strings.write_string(&b, "    {\n")
		strings.write_string(&b, "      \"type\": \"tilelayer\",\n")
		fmt.sbprintf(&b, "      \"name\": \"layer_%d\",\n", layer_i)
		strings.write_string(&b, "      \"data\": [\n")
		count := tilemap.rows * tilemap.cols
		for i in 0 ..< count {
			tile := tilemap.tiles[layer_i][i]
			gid: i32 = 0 if tile < 0 else tile + 1
			if i < count - 1 {
				fmt.sbprintf(&b, "        %d,\n", gid)
			} else {
				fmt.sbprintf(&b, "        %d\n", gid)
			}
		}
		strings.write_string(&b, "      ]\n")
		if layer_i < tilemap.layers - 1 {
			strings.write_string(&b, "    },\n")
		} else {
			strings.write_string(&b, "    }\n")
		}
	}

	strings.write_string(&b, "  ],\n")
	strings.write_string(&b, "  \"tilesets\": [\n")
	strings.write_string(&b, "    {\n")
	fmt.sbprintf(&b, "      \"firstgid\": %d,\n", 1)
	fmt.sbprintf(&b, "      \"image\": \"%s\",\n", image_rel)
	fmt.sbprintf(&b, "      \"titlewidth\": %d,\n", tilemap.tile_w)
	fmt.sbprintf(&b, "      \"titleheight\": %d,\n", tilemap.tile_h)
	fmt.sbprintf(&b, "      \"columns\": %d,\n", tilemap.ts_columns)
	fmt.sbprintf(
		&b,
		"      \"tilecount\": %d,\n",
		tilemap.ts_columns * (tilemap.tileset.height / tilemap.tile_h),
	)
	strings.write_string(&b, "      \"tiles\": []\n")
	strings.write_string(&b, "    }\n")
	strings.write_string(&b, "  ]\n")
	strings.write_string(&b, "}\n")

	json_str := strings.to_string(b)
	return os.write_entire_file(path, transmute([]byte)json_str) == nil
}

tilemap_load_tiled :: proc(path: string, tileset: rl.Texture2D) -> (Tilemap, bool) {
	bytes, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return {}, false
	}
	defer delete(bytes)

	tiled: Tiled_Map
	defer tiled_map_destroy(&tiled)
	if json.unmarshal(bytes, &tiled) != nil {
		return {}, false
	}

	if tiled.orientation != "orthogonal" {
		return {}, false
	}
	if len(tiled.tilesets) != 1 {
		return {}, false
	}

	tile_layer_data: [MAX_TILE_LAYERS][]u32
	tile_layer_count := 0
	for layer in tiled.layers {
		if layer.type != "tilelayer" do continue
		if layer.encoding != "" {
			return {}, false
		}

		if len(layer.data) != int(tiled.width * tiled.height) {
			return {}, false
		}

		if tile_layer_count >= MAX_TILE_LAYERS {
			return {}, false
		}

		tile_layer_data[tile_layer_count] = layer.data
		tile_layer_count += 1
	}

	if tile_layer_count == 0 {
		return {}, false
	}

	ts := tiled.tilesets[0]

	tm: Tilemap
	tm.cols = tiled.width
	tm.rows = tiled.height
	tm.tile_w = tiled.tilewidth
	tm.tile_h = tiled.tileheight
	tm.layers = i32(tile_layer_count)
	tm.tileset = tileset
	tm.ts_columns = ts.columns
	tm.ts_tilecount = ts.tilecount

	tm.tiles = make([][]i32, tm.layers)
	for i in 0 ..< tile_layer_count {
		cells := make([]i32, tm.rows * tm.cols)
		for gid, cell_i in tile_layer_data[i] {
			if gid == 0 {
				cells[cell_i] = -1
				continue
			}
			clean_gid := gid & ~TILED_FLIP_MASK
			cells[cell_i] = i32(clean_gid) - i32(ts.firstgid)
		}
		tm.tiles[i] = cells
	}

	ts_rows := tileset.height / tm.tile_h
	tm.solid = make([]bool, int(ts.columns * ts_rows))
	for tile in ts.tiles {
		for prop in tile.properties {
			if prop.name != "solid" do continue
			if b, bok := prop.value.(json.Boolean); bok && bool(b) {
				if int(tile.id) >= 0 && int(tile.id) < len(tm.solid) {
					tm.solid[tile.id] = true
				}
			}
		}
	}

	return tm, true
}

tiled_get_tileset_image :: proc(path: string) -> (image_path: string, ok: bool) {
	bytes, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return "", false
	}
	defer delete(bytes)

	ref: Tiled_Tileset_Ref
	if json.unmarshal(bytes, &ref) != nil {
		return "", false
	}
	defer delete(ref.tilesets)

	//only supporting one tileset for now.
	if len(ref.tilesets) != 1 {
		for ts in ref.tilesets {
			delete(ts.image)
		}
		return "", false
	}

	return ref.tilesets[0].image, true
}

tiled_map_destroy :: proc(tiled: ^Tiled_Map) {
	delete(tiled.orientation)
	for layer in tiled.layers {
		delete(layer.type)
		delete(layer.name)
		delete(layer.encoding)
		delete(layer.data)
	}
	delete(tiled.layers)

	for ts in tiled.tilesets {
		delete(ts.image)
		for tile in ts.tiles {
			for prop in tile.properties {
				delete(prop.name)
				delete(prop.type)
				json.destroy_value(prop.value)
			}
			delete(tile.properties)
		}
		delete(ts.tiles)
	}
	delete(tiled.tilesets)
}

