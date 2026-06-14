package main

Editor_Command :: struct {
	do_fn:   proc(_: rawptr),
	undo_fn: proc(_: rawptr),
	data:    rawptr,
}

Editor_History :: struct {
	undo_stack: [dynamic]Editor_Command,
	redo_stack: [dynamic]Editor_Command,
}

history_push :: proc(h: ^Editor_History, cmd: Editor_Command) {
	cmd.do_fn(cmd.data)

	for c in h.redo_stack {
		free(c.data)
	}

	clear(&h.redo_stack)
	append(&h.undo_stack, cmd)
}

history_undo :: proc(h: ^Editor_History) {
	if len(h.undo_stack) == 0 {
		return
	}

	cmd := pop(&h.undo_stack)
	cmd.undo_fn(cmd.data)
	append(&h.redo_stack, cmd)
}

history_redo :: proc(h: ^Editor_History) {
	if len(h.redo_stack) == 0 {
		return
	}

	cmd := pop(&h.redo_stack)
	cmd.do_fn(cmd.data)
	append(&h.undo_stack, cmd)
}

history_destroy :: proc(h: ^Editor_History) {
	for c in h.undo_stack {
		free(c.data)
	}

	for c in h.redo_stack {
		free(c.data)
	}

	delete(h.undo_stack)
	delete(h.redo_stack)
}

