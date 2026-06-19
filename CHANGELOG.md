
# Changelog

This document summarizes Sunforge's development to date, grouped by engine system. Sunforge does not yet have versioned releases; this document reflects the current state of `main`.

## Project Setup

- Initial Odin project scaffold and engine package layout (`engine/core`, `engine/renderer`, plus stub packages for `physics`, `audio`, `assets`, and `ui`)
- Unified public API re-exported from `engine/engine.odin`, with a `Scene_Procs` (init/update/render/destroy) pattern and a top-level `run`/`tick` loop

## Core

- **Window**: configurable window (size, title, target FPS), fullscreen toggle, and runtime resize handling for resizeable windows
- **Clock**: delta-time tracking with a cap to avoid large time steps after a stall
- **Input**: keyboard and gamepad action bindings (`input_bind_keyboard` / `input_bind_controller`), pressed/held/released state tracking, mouse position/delta/wheel/button state, and basic gamepad/controller support
- **Math**: `Vec2`/`Rect` types plus `lerp`/`clamp`/`vec2_*`/`rect_contains` helpers; `lerp` is used for particle color and size gradient interpolation

## Renderer

- **Render targets**: offscreen render targets for compositing multiple layers (e.g. world + UI), blitted together each frame
- **Basic shapes**: rectangle (outline), circle, and line drawing primitives
- **Fonts**: TrueType font loading via `rl.LoadFontEx`, managed through an ID-based registry (`Font_ID`) with load/unload tied into the renderer's init/shutdown lifecycle; text drawing and measurement via `draw_font` / `measure_font` (replaces the previous `rl.DrawText`-based text primitive)
- **Sprites**: sprite-sheet slicing (grid and row layouts) with horizontal/vertical flip support
- **Animation**: frame-based animation playback with configurable FPS, looping, and pause/resume; per-frame event tags (`Frame_Event`) for triggering gameplay logic on specific animation frames; fixed a possible nil dereference in animation state updates
- **Camera**: smooth follow, trauma-based screen shake, and world/screen coordinate conversion
- **Shaders**: fragment shader loading, uniform setters (float, vec2, texture), and a post-processing blit path
- **Tilemap**: multi-layer tile grids with viewport-culled rendering and a per-tile collision/solid layer
- **Particles**: fixed 1024-particle pool with per-burst configurable velocity range, color gradient, size gradient, lifetime, and gravity, with oldest-particle recycling when the pool is full
- **Draw order / z-sorting**: added `Draw_Buffer` (up to 2048 `Draw_Command`s — sprite, position, scale, rotation, pivot, flip, tint, z) to `Renderer_State`. `draw_buffer_flush` sorts by `z` ascending via insertion sort and draws each command via `renderer_draw_sprite`, then clears the buffer. Re-exported from `engine.odin`; game code now pushes draw commands (`draw_buffer_push`) once per frame instead of calling sprite-draw directly
- **Sprite rotation and pivot**: `renderer_draw_sprite` gained a `rotation` (degrees) parameter and a `Pivot_Point` enum (`CENTER`, `BOTTOM`) for the rotation/scale origin. `Draw_Command` carries both

### Tilemap — Tiled format I/O

- **`tilemap_load_tiled`**: parses a Tiled-format JSON file (width, height, tilewidth, tileheight, layers[].data, tilesets[]) into a `Tilemap` struct; maps GID 0 to -1 (empty) and GID n to n-1 (zero-based tile index)
- **`tilemap_save_tiled`**: serializes a `Tilemap` back to Tiled-format JSON, writing all layer tile arrays and reconstructing the tilesets block from the cached `image_rel` path and tileset metadata
- **`tiled_get_tileset_image`**: reads only the `image` field from a tilemap JSON file, used to resolve the tileset texture path without fully loading the map
- **`ts_tilecount`**: added to the `Tilemap` struct; populated at load time from the tileset's `tilecount` field so the tile palette knows how many tiles to display

## Project System

- **project package** (`project/project.odin`): `Project_Data` struct (name, entry_scene, window: `core.Window_Config`, icon_path) plus `project_create`/`project_open`/`project_save`, defining a portable on-disk layout (`project.json`, `resources/`, `scenes/`) independent of the Sunforge source tree
- **`project_apply_icon`**: loads `icon_path` (relative to the project root) via `rl.LoadImage` and applies it with `rl.SetWindowIcon`
- **project_test.odin**: `core:testing` roundtrip test (create -> open -> re-create rejection)

## Editor

- **Editor package** (`package main`): entry point prompts for a project folder, opens it via `project_open` if `project.json` exists or creates it via `project_create` otherwise
- **`recent_projects.odin`**: tracks recently opened/created project paths in `recent_projects.json`, stored next to the editor executable
- **Editor/ui toolkit** (`editor/ui/`): immediate-mode widget set: `ui_panel`, `ui_button`, `ui_checkbox`, `ui_drag_float`, `ui_slider_float`, `ui_color_picker`, `ui_combo`, `ui_tree_node`, and `ui_text_input`; shared hover/active state tracked via a single `UI_Context`
- **`editor_scene.odin`**: editor shell: free-fly edit camera (right/middle-mouse drag to pan, scroll wheel to zoom clamped 0.1–5.0), world viewport rendered through the render-target/camera/blit pipeline, resize-aware three-panel layout (Palette, Inspector, Assets)
- **`project_picker_scene.odin`**: initial scene when the editor launches — allows selecting a recent project or creating a new one without touching the command line
- **`asset_browser.odin`**: walks the project `resources/` directory, displays files as a selectable list with texture thumbnails, sortable by asset type
- **`build_editor.bat`**: builds the editor to `bin/editor_debug.exe`

### Scene Management

- **`new_scene_dialog.odin`**: New Scene dialog: user enters a scene name and grid dimensions (width x height in tiles); generates a blank Tiled-format JSON tilemap file in `scenes/`, sets it as the editor's active scene, and writes the entry scene back to `project.json`
- **`scene_browser_dialog.odin`**: Scene Browser: walks the `scenes/` directory, lists all `.json` files, allows switching the active scene by selection, and supports in-place rename of scene files; selected scene is persisted as `entry_scene` in `project.json`
- **`scene_data.odin`**: `Scene_Data` struct (`tilemap_path`, `entities []Entity_Data`, `camera Camera_Config_Data`) with `scene_load`/`scene_save` using `core:encoding/json` marshal/unmarshal

### Tilemap Painter

- **`tilemap_painter.odin`**: `Tilemap_Painter_State`: active tile index, active layer, erase mode, live stroke buffer, visited-cell deduplication map (`map[[2]i32]bool`), palette scroll offset, and cached tileset image path
- **Paint strokes**: left-click starts a stroke; holding left-mouse while moving across tiles paints or erases each cell once per drag (visited set prevents double-edits mid-stroke); on mouse release the full stroke is committed to history and auto-saved
- **Coordinate pipeline**: screen position -> render-target local (subtract `panels.world.{x,y}`) -> world space (`GetScreenToWorld2D`) -> tile col/row (integer divide by `tile_w`/`tile_h`)
- **Scrollable tile palette**: all tiles from the active tileset rendered as fixed-size thumbnails (48px) using `DrawTexturePro`; scissored to the panel bounds; mouse-wheel scrolls through tiles when the cursor is over the palette; selected tile highlighted with an accent border
- **Erase mode**: toggled via a button in the palette panel; sets the painted tile index to -1 (empty)
- **Tilemap boundary indicator**: a translucent white rectangle drawn in world space at the tilemap's pixel extents; line thickness = `2 / camera.zoom` to maintain consistent screen-space width at any zoom level
- **`tilemap_painter_on_scene_loaded`**: caches the tileset image path (`tileset_image_rel`) from `tiled_get_tileset_image` once per scene load, so `tilemap_save` does not need to re-parse the JSON file on every save

### Undo/Redo History

- **`editor_history.odin`**: `Editor_Command` (`do_fn`, `undo_fn`, `data rawptr`) plus `Editor_History` (undo/redo stacks as `[dynamic]Editor_Command`); `history_push` calls `do_fn` immediately and clears the redo stack; `history_undo`/`history_redo` step through the stacks
- **`tile_commands.odin`**: `Tile_Cell_Edit` (col, row, old_index, new_index) and `Tile_Stroke_Data` (pointer to tilemap, layer, fixed array of up to `MAX_STROKE_CELLS = 256` edits, count); `make_tile_stroke_command` builds a reversible command from a completed stroke; `make_tile_edit_command` wraps a single-cell edit
- Undo/redo bound to `Ctrl+Z` / `Ctrl+Y` in `editor_update`


### Entity Placement and Inspector

- **`entity_placement.odin`**: `Entity_Placement_State` tracks selected entity index, drag state, drag offset, drag start position, and list scroll offset. Click in world space to place a new `Entity_Data`; click an existing entity gizmo to select and drag it; press `Delete` to remove it.
- **Entity undo/redo commands** (`tile_commands.odin`): `Entity_Place_Data`, `Entity_Move_Data`, and `Entity_Delete_Data` command types following the same `do_fn`/`undo_fn` pattern as tile stroke commands. `entity_data_clone` deep-copies all heap-allocated fields (name, sprite_sheet_path, animation, tags, properties); `entity_data_destroy` frees them. `make_entity_place_command` clones the entity at make-time so the command owns its data independently of the placement state.
- **Entity inspector**: selected entity properties exposed in the Inspector panel — name (`ui_text_input`), X/Y position, Z depth, and scale (`ui_drag_float` pairs), sprite sheet path display, and an "Assign Sprite" button that pulls the selected texture from the asset browser and joins it with `RESOURCES_DIR`. Inspector edits are auto-saved via `scene_save_current` on mouse release.
- **Entity list panel**: in Entity Tool mode the left panel switches from the tile palette to a scrollable entity list (`entity_list_render`). Each row shows the entity name; clicking selects it. Scroll position tracked as `list_scroll: f32` with scissor-mode clipping.
- **Entity sprite rendering**: `rebuild_entity_sprites` populates a parallel `entity_sprites: []eng.Sprite` slice from each entity's `sprite_sheet_path`, using the shared `scene_texture` texture cache. Entities are submitted to the draw buffer each frame with their `z` and `scale` fields. A zero or negative scale falls back to 1.0 to handle old scene files.
- **Entity gizmos**: in Entity Tool mode a crosshair is drawn at each entity's world position (thickness = `1.5 / zoom`); the selected entity also shows a selection rectangle (`entity_gizmo_rect`). Both scale-compensate for camera zoom.
- **`scene_save_current`**: auto-saves the full scene JSON after every entity place, move, delete, and inspector commit (mouse release while an entity is selected in Entity Tool mode).

### Tilemap — Multi-layer and Dynamic Layer Management

- **`tilemap_add_layer`**: appends a new all-empty (`-1`) tile layer up to `MAX_TILE_LAYERS = 4`; initializes `layer_z` for the new slot; returns false if already at the cap.
- **`tilemap_remove_layer`**: removes a layer at a given index, freeing its backing `[]i32`; shifts remaining layers down; guards against removing the last layer.
- **`tilemap_insert_layer_at`**: inserts a caller-provided `[]i32` at a specific index (takes ownership); used by layer-remove undo to re-insert saved layer data.
- **Layer add/remove undo/redo** (`tile_commands.odin`): `Layer_Add_Data` and `Layer_Remove_Data` command types. `make_layer_remove_command` clones the layer data at make-time (before `do_fn` removes it) so undo can re-insert it; `layer_remove_undo` clones again when re-inserting so the command retains its copy for repeated undo/redo cycles.
- **Per-layer visibility**: `layer_visible: [MAX_TILE_LAYERS]bool` added to `Tilemap_Painter_State` (all true by default); hide/show toggle buttons per layer in the tools panel; hidden layers are skipped in the render loop but can still be painted.
- **Entity visibility**: `entities_visible: bool` added to `Tilemap_Painter_State`; a hide/show button in the tools panel controls whether the entity block is included in the render loop.
- **Palette UI updates**: layer selector row with per-layer label buttons, `+`/`-` add/remove buttons, per-layer hide/show toggles, and per-layer z drag floats. Erase button relocated to the tools bar. Layer controls call `history_push` and `tilemap_save` directly via the `es: ^Editor_State` parameter added to `tilemap_painter_render_palette`.

### Tilemap — Unified Z-Sort Render Ordering

- **`layer_z: [MAX_TILE_LAYERS]f32`** added to the `Tilemap` struct (value type, no allocation). Default: `layer_z[i] = f32(i) * 2`. Initialized in `tilemap_create`, `tilemap_load_tiled`, and `tilemap_add_layer`.
- **`Tiled_Layer.z: f32`**: non-standard engine extension written per-layer into the Tiled JSON by `tilemap_save_tiled` and read back by `tilemap_load_tiled`. Old files without the field unmarshal to 0.0 and receive the default.
- **Unified render loop** (`editor_scene.odin`): the hardcoded `ENTITY_LAYER :: i32(1)` split is replaced by a `Render_Item` array of up to `MAX_TILE_LAYERS + 1` items (tile layers + one entity block sentinel). Items are insertion-sorted by z each frame and executed in order — tile layer items call `eng.draw_tilemap_layer`; the entity item pushes all entities to the draw buffer and calls `draw_buffer_flush`. `ENTITY_Z :: f32(1.0)` places the entity block between layer 0 and layer 1 by default.

### Tilemap Painter — Tile Utilities

- **Tile grid overlay**: `show_grid: bool` added to `Tilemap_Painter_State`. `G` key toggles it via the `Grid` `Editor_Action` binding. When enabled, `rl.DrawRectangleLinesEx` is called once per visible tile cell after all render items are drawn; line thickness = `1 / camera.zoom`.
- **Tile eyedropper / pick mode**: `pick_mode: bool` added to `Tilemap_Painter_State`. Hold `Alt` to enter pick mode (cursor set to `.POINTING_HAND`); release `Alt` to exit (cursor reset to `.DEFAULT`). In pick mode `tilemap_painter_update` returns early, bypassing all paint logic. Right-clicking a cell with `tile_idx >= 0` sets `active_tile` and clears `erase_mode`; clicking an empty cell is a silent no-op.
- **Tile Rotation**: press `R` to rotate selected tile for painting

### Scene Management Updates

- **`new_scene_dialog.odin`**: replaces the hardcoded `default_title_scene()` test fixture. `editor_init` now reads `project.entry_scene` and auto-opens the New Scene dialog when no entry scene exists, rather than writing a scene pointing at nonexistent resources.
- **`scene_browser_dialog.odin`**: `select_scene` handles the `entity_sprites` double-free by nilling the slice after `delete` before `scene_load_resources` runs.

## Example / Tooling

- `main.odin` example scene combining the systems above: a tilemap-based level, a player character with idle/walk/jump-flip animations (landing triggers a particle burst via a frame event), jump particle bursts, camera follow with shake on jump, a font-rendered title, and a debug overlay of live input state rendered with a second font
- `build.bat` for building a debug Windows executable via `odin build`

## Looking Ahead

tier-0-editor work continues. Remaining tier-0 items: particle editor, animation editor (including data-driven sprite sheet format and entity animation wiring), play-in-editor mode, build/export pipeline.  
See [README.md](README.md#roadmap) and the [issue tracker](https://github.com/WillBallentine/Sunforge/issues) for planned work across tier-0 through tier-10 and post-v1.
