
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

## Example / Tooling

- `main.odin` example scene combining the systems above: a tilemap-based level, a player character with idle/walk/jump-flip animations (landing triggers a particle burst via a frame event), jump particle bursts, camera follow with shake on jump, a font-rendered title, and a debug overlay of live input state rendered with a second font
- `build.bat` for building a debug Windows executable via `odin build`

## Looking Ahead

tier-0-editor work continues: the core editing loop (tilemap painter, scene management, undo/redo, auto-save) is in place. Remaining tier-0 work includes entity placement and inspector, particle editor, animation editor, and play-in-editor.
See [README.md](README.md#roadmap) and the [issue tracker](https://github.com/WillBallentine/Sunforge/issues) for planned work across tier-0 through tier-10 and post-v1.

