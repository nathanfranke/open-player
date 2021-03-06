extends Control
class_name App

func _enter_tree() -> void:
	# Change theme on enter tree before children are added.
	_on_theme_changed()
	Global.ok(Global.profile.connect("theme_changed", self, "_on_theme_changed"))

func _on_theme_changed() -> void:
	theme = Global.profile.theme

func _ready() -> void:
	randomize()
	
	Global.ok(Global.profile.tracks.connect("removed", self, "_profile_track_removed"))
	
	if "--generate-branding" in OS.get_cmdline_args():
		_generate_branding()
		return

func _profile_track_removed(entry: TrackList.Entry) -> void:
	var index := queue.find(entry.value)
	if index >= 0:
		queue.remove(index)

### BRANDING ###

func _generate_branding() -> void:
	Global.autosave_timer.stop()
	Global.profile.animations_enabled = false
	
	for track in Global.profile.tracks.iter():
		queue.add(track)
	
	### SCREENSHOTS ###
	
	if true:
		self.active_view = "import"
		
		var screen = _branding_screen(Vector2(1080, 1920))
		if screen is GDScriptFunctionState:
			screen = yield(screen, "completed")
		
		Global.ok(screen.save_png("res://app/branding/screenshots/portrait1.png"))
	
	if true:
		self.active_view = "tracks"
		
		var screen = _branding_screen(Vector2(1080, 1920))
		if screen is GDScriptFunctionState:
			screen = yield(screen, "completed")
		
		Global.ok(screen.save_png("res://app/branding/screenshots/portrait2.png"))
	
	if true:
		self.active_view = "settings"
		
		var screen = _branding_screen(Vector2(1080, 1920))
		if screen is GDScriptFunctionState:
			screen = yield(screen, "completed")
		
		Global.ok(screen.save_png("res://app/branding/screenshots/portrait3.png"))
	
	if true:
		self.active_view = "tracks"
		
		var screen = _branding_screen(Vector2(1440, 2560))
		if screen is GDScriptFunctionState:
			screen = yield(screen, "completed")
		
		Global.ok(screen.save_png("res://app/branding/screenshots/tablet.png"))
	
	### DEVICES ###
	
	var overlay := Image.new()
	Global.ok(overlay.load("res://app/branding/screenshots/devices_overlay.png"))
	overlay.lock()
	for x in overlay.get_width():
		for y in overlay.get_height():
			var color := overlay.get_pixel(x, y)
			if color == Color.black:
				overlay.set_pixel(x, y, Color.transparent)
	overlay.unlock()
	
	var canvas := Image.new()
	canvas.create(overlay.get_width(), overlay.get_height(), false, Image.FORMAT_RGBA8)
	
	if true:
		self.active_view = "tracks"
		
		var task = _branding_screen_blit(canvas, Rect2(368, 144, 1408, 792))
		if task is GDScriptFunctionState:
			yield(task, "completed")
	
	if true:
		self.active_view = "tracks"
		
		var task = _branding_screen_blit(canvas, Rect2(144, 376, 360, 720))
		if task is GDScriptFunctionState:
			task = yield(task, "completed")
	
	_branding_blit(canvas, overlay, Vector2())
	
	Global.ok(canvas.save_png("res://app/branding/screenshots/devices.png"))
	
	get_tree().quit()

func _branding_screen(size: Vector2) -> Image:
	OS.window_size = size / 4.0
	
	yield(get_tree().create_timer(0.5), "timeout")
	
	get_viewport().size = size
	
	yield(get_tree().create_timer(0.1), "timeout")
	
	self.position = 60.0
	
	if has_node("Layouts/Portrait"):
		$Layouts/Portrait.queue_container.showing = self.active_view == "tracks"
	
	yield(get_tree().create_timer(0.5), "timeout")
	
	var image := get_viewport().get_texture().get_data()
	image.flip_y()
	
	return image

func _branding_screen_blit(canvas: Image, rect: Rect2) -> void:
	var screen = _branding_screen(rect.size * 2.0)
	if screen is GDScriptFunctionState:
		screen = yield(screen, "completed")
	
	screen.shrink_x2()
	_branding_blit(canvas, screen, rect.position)

func _branding_blit(image: Image, put: Image, pos: Vector2) -> void:
	put.convert(Image.FORMAT_RGBA8)
	image.blend_rect(put, Rect2(0.0, 0.0, put.get_width(), put.get_height()), pos)

### DECREASE FRAMERATE WHEN TABBED OUT ###

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_FOCUS_IN:
			OS.low_processor_usage_mode = false
		NOTIFICATION_WM_FOCUS_OUT:
			OS.low_processor_usage_mode = true

### TRACKS ###

signal track_changed(entry)

var track_history := []

var current: TrackList.Entry setget _set_current
func _set_current(value: TrackList.Entry) -> void:
	if current == value:
		return
	
	current = value
	
	emit_signal("track_changed", current)
	
	if current != null:
		track_history.push_back(current)
		replay()

var current_track: Track setget _set_current_track, _get_current_track
func _set_current_track(_value: Track) -> void:
	assert(false)
func _get_current_track() -> Track:
	return current.value if current != null else null

### QUEUE ###

class Queue:
	extends TrackList
	
	enum {
		QUEUE_REPEAT,
		QUEUE_REPEAT_SINGLE,
		QUEUE_ONCE,
		QUEUE_MAX
	}
	
	signal mode_changed(mode)
	
	var mode: int = QUEUE_REPEAT setget _set_mode
	func _set_mode(value: int) -> void:
		if mode == value:
			return
		
		mode = value
		
		emit_signal("mode_changed", mode)
	
	var app: App
	func _init(_app):
		app = _app
		
		Global.ok(connect("removed", self, "_queue_on_removed"))
	
	func _queue_on_removed(entry: Entry) -> void:
		if app.current == entry:
			app.current = null
		
		app.track_history.erase(entry)
	
	func add(track: Track, play := false) -> void:
		var entry := ensure_has(track)
		
		if play or app.current == null:
			app.current = entry
	
	func insert(index: int, track: Track, play := false) -> void:
		var entry := ensure_at(index, track)
		
		if play or app.current == null:
			app.current = entry
	
	func shuffle() -> void:
		var size := size()
		var values := range(0, size)
		if app.current != null:
			values.remove(app.current.index)
			values.shuffle()
			values.push_front(app.current.index)
		else:
			values.shuffle()
		
		var mapping := {}
		
		for i in size:
			mapping[i] = values[i]
		
		order(mapping)
	
	func cycle_modes() -> void:
		self.mode = (mode + 1) % QUEUE_MAX

var queue := Queue.new(self)

func get_next_track(mode := queue.mode) -> TrackList.Entry:
	if current != null:
		match mode:
			Queue.QUEUE_REPEAT:
				return queue.entry((current.index + 1) % queue.size())
			Queue.QUEUE_REPEAT_SINGLE:
				return current
			Queue.QUEUE_ONCE:
				if current.index < queue.size() - 1:
					return queue.entry((current.index + 1) % queue.size())
	return null

func play_next(track: Track) -> void:
	Global.profile.tracks.ensure_has(track)
	
	var index := queue.size()
	if current != null:
		index = current.index + 1
	
	queue.insert(index, track)

### PLAYING ###

signal state_changed(playing)

var playing := true setget _set_playing
func _set_playing(value: bool) -> void:
	if playing == value:
		return
	
	playing = value
	
	emit_signal("state_changed", playing)

func toggle_playing() -> void:
	if playing:
		pause()
	else:
		play()

func play() -> void:
	self.playing = true

func pause() -> void:
	self.playing = false

func stop() -> void:
	self.playing = false
	self.position = 0.0

func replay() -> void:
	self.playing = true
	self.position = 0.0

### SEEKING ###

signal seeking_changed(seeking)

var seeking := false setget _set_seeking
func _set_seeking(value: bool) -> void:
	if seeking == value:
		return
	
	seeking = value
	
	emit_signal("seeking_changed", seeking)

### POSITION ###

signal position_changed(position)

# Changing this will not call the position changed signal.
# This is useful for automatic position change over time.
var real_position: float setget _set_real_position
func _set_real_position(value: float) -> void:
	real_position = value
	
	var duration = 0.0
	if current != null:
		duration = get_duration()
		if duration is GDScriptFunctionState:
			duration = yield(duration, "completed")
	
	real_position = clamp(real_position, 0.0, duration)

# Changing this will call the position changed signal.
# This should only be changed when the user makes a manual action.
var position: float setget _set_player_position, _get_player_position
func _set_player_position(value: float) -> void:
	var task = _set_real_position(value)
	if task is GDScriptFunctionState:
		yield(task, "completed")
	
	position = real_position
	emit_signal("position_changed", position)
func _get_player_position() -> float:
	return real_position

### DURATION ###

func get_duration() -> float:
	if current != null:
		return current.value.duration
	
	return 0.0

### PREVIOUS/NEXT ###

func previous_track() -> void:
	if track_history.size() > 1:
		var _remove_current: TrackList.Entry = track_history.pop_back()
		self.current = track_history.pop_back()

func next_track(manual := false) -> void:
	var next := get_next_track()
	
	if current == next:
		if manual:
			# Manual next track: Switch instead of looping the same track.
			next = get_next_track(Queue.QUEUE_REPEAT)
		else:
			replay()
	
	self.current = next

### VOLUME ###

signal volume_changed(volume)

var volume := 0.5 setget _set_volume
func _set_volume(value: float) -> void:
	volume = value
	
	emit_signal("volume_changed", volume)

### SPEED ###

signal speed_changed(volume)

var speed := 1.0 setget _set_speed
func _set_speed(value: float) -> void:
	speed = value
	
	emit_signal("speed_changed", speed)

### BUFFERING ###

signal buffering_changed(buffering)

var buffering := false setget _set_buffering
func _set_buffering(value: bool) -> void:
	if buffering == value:
		return
	
	buffering = value
	
	emit_signal("buffering_changed", buffering)

### ACTIVE VIEW ###

signal active_view_changed(screen)

var active_view := "home" setget _set_active_view
func _set_active_view(value: String) -> void:
	if active_view == value:
		return
	
	active_view = value
	
	emit_signal("active_view_changed", active_view)
