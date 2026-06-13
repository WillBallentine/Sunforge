package main

import eng "../engine"


main :: proc() {
	eng.run(eng.Engine_Config{window = PICKER_WINDOW_CONFIG}, picker_scene())
}

