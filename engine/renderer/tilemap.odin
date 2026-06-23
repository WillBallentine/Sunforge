package renderer

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

MAX_TILE_LAYERS :: 4
TILED_FLIP_MASK :: u32(0xE0000000)
TILED_FLIP_H :: u32(0x80000000)
TILED_FLIP_V :: u32(0x40000000)
TILED_FLIP_D :: u32(0x20000000)

Tilemap :: struct {
	tiles:   [][]i32,
	cols:    i32,
	rows:    i32,
	tile_w:  i32,
	tile_h:  i32,
	layers:  i32,
	solid:   []bool,
	tileset: []Tileset_Info,
	layer_z: [MAX_TILE_LAYERS]f32,
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
	z:        f32,
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

Tileset_Info :: struct {
	texture:   rl.Texture2D,
	firstgid:  u32,
	columns:   i32,
	tilecount: i32,
	image_rel: string,
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

	tm.tiles = make([][]i32, layers)
	for i in 0 ..< layers {
		layer := make([]i32, rows * cols)
		for &cell in layer {
			cell = -1
		}
		tm.tiles[i] = layer
	}

	ts_rows := tileset.height / tile_h
	max_gid := u32(ts_columns * ts_rows) + 1
	tm.solid = make([]bool, int(max_gid))
	tm.tileset[0] = Tileset_Info {
		texture   = tileset,
		firstgid  = 1,
		columns   = ts_columns,
		tilecount = ts_columns * ts_rows,
		image_rel = "",
	}

	for i in 0 ..< layers {
		tm.layer_z[i] = f32(i) * 2
	}

	return tm
}

tilemap_set_tile :: proc(tm: ^Tilemap, layer, col, row: i32, tile_index: i32) {
	assert(layer >= 0 && layer < tm.layers)
	assert(col >= 0 && col < tm.cols)
	assert(row >= 0 && row < tm.rows)
	tm.tiles[layer][row * tm.cols + col] = tile_index
}

tilemap_ensure_layers :: proc(tm: ^Tilemap, min_layers: i32) {
	if tm.layers >= min_layers do return
	new_tiles := make([][]i32, min_layers)
	for i in 0 ..< tm.layers {
		new_tiles[i] = tm.tiles[i]
	}

	for i in tm.layers ..< min_layers {
		layer := make([]i32, tm.rows * tm.cols)
		for &cell in layer {
			cell = -1
		}

		new_tiles[i] = layer
	}
	delete(tm.tiles)
	tm.tiles = new_tiles
	tm.layers = min_layers
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
				tile_val := tm.tiles[layer][row * tm.cols + col]
				if tile_val < 0 do continue

				raw_gid := u32(tile_val & 0x0000FFFF)
				rotation := u8((tile_val >> 16) & 0x3)

				for ts in tm.tileset {
					if raw_gid >= ts.firstgid && raw_gid < ts.firstgid + u32(ts.tilecount) {
						local_idx := i32(raw_gid - ts.firstgid)
						ts_col := local_idx % ts.columns
						ts_row := local_idx / ts.columns

						src := rl.Rectangle {
							f32(ts_col * tm.tile_w),
							f32(ts_row * tm.tile_h),
							f32(tm.tile_w),
							f32(tm.tile_h),
						}

						dest := rl.Rectangle {
							f32(col * tm.tile_w) + f32(tm.tile_w) / 2,
							f32(row * tm.tile_h) + f32(tm.tile_h) / 2,
							f32(tm.tile_w),
							f32(tm.tile_h),
						}

						origin := rl.Vector2{f32(tm.tile_w) / 2, f32(tm.tile_h) / 2}

						rl.DrawTexturePro(
							ts.texture,
							src,
							dest,
							origin,
							f32(rotation) * 90,
							rl.WHITE,
						)
						break
					}
				}
			}
		}
	}
}

tilemap_add_layer :: proc(tm: ^Tilemap) -> bool {
	if tm.layers >= MAX_TILE_LAYERS do return false

	new_tiles := make([][]i32, tm.layers + 1)
	copy(new_tiles[:tm.layers], tm.tiles)
	layer := make([]i32, tm.rows * tm.cols)
	for &cell in layer {
		cell = -1
	}

	new_tiles[tm.layers] = layer
	tm.layer_z[tm.layers] = f32(tm.layers) * 2
	delete(tm.tiles)
	tm.tiles = new_tiles
	tm.layers += 1
	return true
}

tilemap_remove_layer :: proc(tm: ^Tilemap, layer: i32) -> bool {
	if tm.layers <= 1 do return false
	if layer < 0 || layer >= tm.layers do return false

	delete(tm.tiles[layer])

	new_tiles := make([][]i32, tm.layers - 1)
	copy(new_tiles[:layer], tm.tiles[:layer])
	copy(new_tiles[layer:], tm.tiles[layer:])

	delete(tm.tiles)
	tm.tiles = new_tiles
	tm.layers -= 1
	return true
}

tilemap_insert_layer_at :: proc(tm: ^Tilemap, layer: i32, data: []i32) -> bool {
	if tm.layers >= MAX_TILE_LAYERS do return false
	if layer < 0 || layer > tm.layers do return false

	new_tiles := make([][]i32, tm.layers + 1)
	copy(new_tiles[:layer], tm.tiles[:layer])
	new_tiles[layer] = data
	copy(new_tiles[layer + 1:], tm.tiles[layer:])

	delete(tm.tiles)
	tm.tiles = new_tiles
	tm.layers += 1
	return true
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
			tile_val := tm.tiles[layer][row * tm.cols + col]
			if tile_val < 0 do continue
			raw_gid := u32(tile_val & 0x0000FFFF)
			rotation := u8((tile_val >> 16) & 0x3)

			for ts in tm.tileset {
				if raw_gid >= ts.firstgid && raw_gid < ts.firstgid + u32(ts.tilecount) {
					local_idx := i32(raw_gid - ts.firstgid)
					ts_col := local_idx % ts.columns
					ts_row := local_idx / ts.columns
					src := rl.Rectangle {
						f32(ts_col * tm.tile_w),
						f32(ts_row * tm.tile_h),
						f32(tm.tile_w),
						f32(tm.tile_h),
					}

					dest := rl.Rectangle {
						f32(col * tm.tile_w) + f32(tm.tile_w) / 2,
						f32(row * tm.tile_h) + f32(tm.tile_h) / 2,
						f32(tm.tile_w),
						f32(tm.tile_h),
					}

					origin := rl.Vector2{f32(tm.tile_w) / 2, f32(tm.tile_h) / 2}

					rl.DrawTexturePro(ts.texture, src, dest, origin, f32(rotation) * 90, rl.WHITE)
					break
				}
			}
		}
	}
}

tilemap_is_solid :: proc(tm: ^Tilemap, gid: i32) -> bool {
	if gid <= 0 || int(gid) > len(tm.solid) do return false
	return tm.solid[gid - 1]
}

tilemap_destroy :: proc(tm: ^Tilemap) {
	for layer in tm.tiles {
		delete(layer)
	}
	delete(tm.tiles)
	delete(tm.solid)
	for ts in tm.tileset {
		delete(ts.image_rel)
	}
	delete(tm.tileset)
}

tilemap_save_tiled :: proc(path: string, tilemap: ^Tilemap) -> bool {
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
		fmt.sbprintf(&b, "      \"z\": %f,\n", tilemap.layer_z[layer_i])
		strings.write_string(&b, "      \"data\": [\n")
		count := tilemap.rows * tilemap.cols
		for i in 0 ..< count {
			tile := tilemap.tiles[layer_i][i]
			gid: u32 = 0
			if tile >= 0 {
				rotation := u8((tile >> 16) & 0x3)
				raw_gid := u32(tile & 0x0000FFFF)
				flags := rotation_to_tiled_flags(rotation)
				gid = raw_gid | flags
			}
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

	for ts, ti in tilemap.tileset {
		strings.write_string(&b, "    {\n")
		fmt.sbprintf(&b, "      \"firstgid\": %d,\n", ts.firstgid)
		fmt.sbprintf(&b, "      \"image\": \"%s\",\n", ts.image_rel)
		fmt.sbprintf(&b, "      \"tilewidth\": %d,\n", tilemap.tile_w)
		fmt.sbprintf(&b, "      \"tileheight\": %d,\n", tilemap.tile_h)
		fmt.sbprintf(&b, "      \"columns\": %d,\n", ts.columns)
		fmt.sbprintf(&b, "      \"tilecount\": %d,\n", ts.tilecount)
		strings.write_string(&b, "      \"tiles\": []\n")
		if ti < len(tilemap.tileset) - 1 {
			strings.write_string(&b, "    },\n")
		} else {
			strings.write_string(&b, "    }\n")
		}
	}
	strings.write_string(&b, "  ]\n")
	strings.write_string(&b, "}\n")

	json_str := strings.to_string(b)
	return os.write_entire_file(path, transmute([]byte)json_str) == nil
}

tilemap_load_tiled :: proc(path: string, tilesets: []rl.Texture2D) -> (Tilemap, bool) {
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

	if len(tiled.tilesets) == 0 {
		return {}, false
	}

	tile_layer_data: [MAX_TILE_LAYERS][]u32
	tile_layer_z: [MAX_TILE_LAYERS]f32
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
		if layer.z != 0 || tile_layer_z == 0 {
			tile_layer_z[tile_layer_count] = layer.z
		} else {
			tile_layer_z[tile_layer_count] = f32(tile_layer_count) * 2
		}
		tile_layer_count += 1
	}

	if tile_layer_count == 0 {
		return {}, false
	}

	max_gid := u32(0)
	for ts in tiled.tilesets {
		end := ts.firstgid + u32(ts.tilecount)
		if end > max_gid {max_gid = end}
	}


	tm: Tilemap
	tm.cols = tiled.width
	tm.rows = tiled.height
	tm.tile_w = tiled.tilewidth
	tm.tile_h = tiled.tileheight
	tm.layers = i32(tile_layer_count)

	tm.tiles = make([][]i32, tm.layers)
	for i in 0 ..< tile_layer_count {
		tm.layer_z[i] = tile_layer_z[i]
		cells := make([]i32, tm.rows * tm.cols)
		for gid, cell_i in tile_layer_data[i] {
			if gid == 0 {
				cells[cell_i] = -1
				continue
			}
			flags := gid & TILED_FLIP_MASK
			rotation := tiled_flags_to_rotation(flags)
			clean_gid := gid & ~TILED_FLIP_MASK
			cells[cell_i] = (i32(rotation) << 16) | i32(clean_gid)
		}
		tm.tiles[i] = cells
	}

	tm.solid = make([]bool, int(max_gid))
	for ts in tiled.tilesets {
		for tile in ts.tiles {
			for prop in tile.properties {
				if prop.name != "solid" do continue
				if b, bok := prop.value.(json.Boolean); bok && bool(b) {
					gid := int(ts.firstgid) + int(tile.id)
					if gid > 0 && gid <= int(max_gid) {
						tm.solid[gid - 1] = true
					}
				}
			}
		}
	}

	tex_count := min(len(tiled.tilesets), len(tilesets))
	tm.tileset = make([]Tileset_Info, len(tiled.tilesets))
	for ts, ti in tiled.tilesets {
		tex: rl.Texture2D
		if ti < tex_count {
			tex = tilesets[ti]
		}
		tm.tileset[ti] = Tileset_Info {
			texture   = tex,
			firstgid  = ts.firstgid,
			columns   = ts.columns,
			tilecount = ts.tilecount,
			image_rel = strings.clone(ts.image),
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
	defer {
		for ts in ref.tilesets {delete(ts.image)}
		delete(ref.tilesets)
	}

	if len(ref.tilesets) == 0 {return "", false}

	return strings.clone(ref.tilesets[0].image), true
}

tiled_get_all_tileset_images :: proc(path: string) -> (images: []string, ok: bool) {
	bytes, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return nil, false
	}
	defer delete(bytes)

	ref: Tiled_Tileset_Ref
	if json.unmarshal(bytes, &ref) != nil {
		return nil, false
	}
	defer {
		for ts in ref.tilesets {delete(ts.image)}
		delete(ref.tilesets)
	}

	if len(ref.tilesets) == 0 {
		return nil, false
	}

	result := make([]string, len(ref.tilesets))
	for ts, i in ref.tilesets {
		result[i] = strings.clone(ts.image)
	}
	return result, true
}

tilemap_add_tileset :: proc(tm: ^Tilemap, info: Tileset_Info) {
	new_tilesets := make([]Tileset_Info, len(tm.tileset) + 1)
	copy(new_tilesets[:len(tm.tileset)], tm.tileset)
	new_tilesets[len(tm.tileset)] = info
	delete(tm.tileset)
	tm.tileset = new_tilesets

	new_max_gid := int(info.firstgid) + int(info.tilecount)
	if new_max_gid > len(tm.solid) {
		new_solid := make([]bool, new_max_gid)
		copy(new_solid[:len(tm.solid)], tm.solid)
		delete(tm.solid)
		tm.solid = new_solid
	}
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


tiled_flags_to_rotation :: proc(flags: u32) -> u8 {
	switch flags {
	case TILED_FLIP_D | TILED_FLIP_H:
		return 1
	case TILED_FLIP_H | TILED_FLIP_V:
		return 2
	case TILED_FLIP_D | TILED_FLIP_V:
		return 3
	}
	return 0
}

rotation_to_tiled_flags :: proc(rotation: u8) -> u32 {
	switch rotation {
	case 1:
		return TILED_FLIP_D | TILED_FLIP_H
	case 2:
		return TILED_FLIP_H | TILED_FLIP_V
	case 3:
		return TILED_FLIP_D | TILED_FLIP_V
	}
	return 0
}

