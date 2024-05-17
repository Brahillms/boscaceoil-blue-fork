###################################################
# Part of Bosca Ceoil Blue                        #
# Copyright (c) 2024 Yuri Sizov and contributors  #
# Provided under MIT                              #
###################################################

extends MarginContainer

const SIZE_CHANGES_SAVE_DELAY := 0.3

var _default_window_title: String = ""

@onready var _filler: Control = %Filler
@onready var _menu_bar: Control = %Menu

@onready var _pattern_editor: Control = %PatternEditor
@onready var _locked_indicator: Control = %LockedIndicator
@onready var _save_timer: Timer = %SaveTimer


func _enter_tree() -> void:
	# Ensure that the minimum size of the UI is respected and
	# the main window cannot go any lower.
	get_window().wrap_controls = true
	
	_default_window_title = get_window().title


func _ready() -> void:
	_restore_window_size()
	_update_window_size()
	Controller.settings_manager.gui_scale_changed.connect(_update_window_size)
	Controller.settings_manager.fullscreen_changed.connect(_update_window_size)
	
	_save_timer.wait_time = SIZE_CHANGES_SAVE_DELAY
	_save_timer.autostart = false
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_save_window_size_debounced)
	get_window().size_changed.connect(_save_window_size)

	# A little trick to make sure the menu is on top of the pattern editor. We use a filler control
	# and make it fit the same area in the box container.
	_filler.custom_minimum_size = _menu_bar.get_combined_minimum_size()
	
	_pattern_editor.visible = true
	_locked_indicator.visible = false
	_edit_current_song()
	
	if not Engine.is_editor_hint():
		Controller.song_loaded.connect(_edit_current_song)
		Controller.song_saved.connect(_update_window_title)
		
		Controller.controls_locked.connect(_show_locked_indicator)
		Controller.controls_unlocked.connect(_hide_locked_indicator)


func _edit_current_song() -> void:
	if Engine.is_editor_hint():
		return
	
	_update_window_title()
	if Controller.current_song:
		Controller.current_song.song_changed.connect(_update_window_title)


func _update_window_size() -> void:
	_update_window_mode()
	
	var main_window := get_window()
	var neutral_size := main_window.size / main_window.content_scale_factor
	main_window.content_scale_factor = Controller.settings_manager.get_gui_scale_factor()
	
	# HACK: This is a naive fix to an engine bug. For some reason, window's content scale factor
	# affects controls' combined required minimum size, making it smaller the larger the scale is.
	# This doesn't seem rational or logical, and the difference isn't even proportional to scale.
	#
	# Experimentally, I identified that the global transform matrix of this control (any fullscreen
	# control, really) helps to counter-act the issue. So here we are. 
	var content_minsize := (main_window.get_contents_minimum_size() * get_global_transform()).floor()
	main_window.min_size = content_minsize * main_window.content_scale_factor
	_fit_window_size(neutral_size * main_window.content_scale_factor)


func _fit_window_size(window_size: Vector2) -> void:
	var main_window := get_window()
	var window_mode := main_window.mode
	if window_mode == Window.MODE_MAXIMIZED || OS.has_feature("web"):
		return
	
	var screen_index := main_window.current_screen
	if window_mode == Window.MODE_FULLSCREEN || window_mode == Window.MODE_EXCLUSIVE_FULLSCREEN || OS.has_feature("android"):
		main_window.size = DisplayServer.screen_get_size(screen_index)
		return
	
	main_window.size = window_size
	Controller.settings_manager.set_windowed_size(main_window.size)


func _update_window_mode() -> void:
	var main_window := get_window()
	var is_actually_fullscreen := main_window.mode == Window.MODE_FULLSCREEN || main_window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	
	if Controller.settings_manager.is_fullscreen() == is_actually_fullscreen:
		return
	
	if Controller.settings_manager.is_fullscreen():
		main_window.mode = Window.MODE_FULLSCREEN
	else:
		main_window.mode = Window.MODE_WINDOWED
		main_window.size = Controller.settings_manager.get_windowed_size()
		if Controller.settings_manager.is_windowed_maximized():
			main_window.mode = Window.MODE_MAXIMIZED


func _restore_window_size() -> void:
	var main_window := get_window()
	main_window.size = Controller.settings_manager.get_windowed_size()
	
	if Controller.settings_manager.is_windowed_maximized():
		main_window.mode = Window.MODE_MAXIMIZED
	
	if Controller.settings_manager.is_fullscreen():
		main_window.mode = Window.MODE_FULLSCREEN


func _save_window_size() -> void:
	_save_timer.start()


func _save_window_size_debounced() -> void:
	var main_window := get_window()
	
	if main_window.mode == Window.MODE_WINDOWED:
		Controller.settings_manager.set_windowed_size(main_window.size)
	
	Controller.settings_manager.set_windowed_maximized(main_window.mode == Window.MODE_MAXIMIZED)
	Controller.settings_manager.set_fullscreen(main_window.mode == Window.MODE_FULLSCREEN || main_window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, true)


func _update_window_title() -> void:
	if Engine.is_editor_hint():
		return
	
	if not Controller.current_song:
		get_window().title = _default_window_title
		return
	
	var song_name := "<New Song>" if Controller.current_song.filename.is_empty() else Controller.current_song.filename.get_file()
	var song_dirty := "* " if Controller.current_song.is_dirty() else ""
	
	get_window().title = "%s%s - %s" % [ song_dirty, song_name, _default_window_title ]


func _show_locked_indicator(message: String) -> void:
	_pattern_editor.visible = false
	_locked_indicator.message = message
	_locked_indicator.visible = true


func _hide_locked_indicator() -> void:
	_pattern_editor.visible = true
	_locked_indicator.visible = false
