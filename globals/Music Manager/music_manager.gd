extends Node

signal track_changed(track_name: String)

# Drag your MusicTrack resources into this array in the Inspector!
@export var music_tracks: Array[MusicTrack] = []
var track_db: Dictionary = {}

@export_category("PLAYLIST")
## Tracks the playlist picks from. Leave EMPTY to use every track in music_tracks.
@export var playlist_tracks: Array[MusicTrack] = []
## Seconds the next track crossfades in. It starts this long BEFORE the current one ends.
@export var playlist_crossfade: float = 3.0
## ON = "shuffle bag": every track plays once (random order) before any repeats.
## OFF = pure random each time (still never the same track twice in a row).
@export var shuffle_bag: bool = true
## Start the playlist automatically when the game launches.
@export var autostart_playlist: bool = false

var active_players: Array[AudioStreamPlayer] = []
var current_intensity: float = 0.0
var current_track_name: String = ""

var playlist_active: bool = false
var _bag: Array[String] = []
var _next_queued: bool = false # true once we've already queued the next track

func _ready() -> void:
	# Build a dictionary so we can easily search tracks by their string name
	for track in music_tracks:
		track_db[track.track_name.to_lower()] = track
	for track in playlist_tracks: # playlist tracks work even if they aren't in music_tracks
		track_db[track.track_name.to_lower()] = track
	
	if autostart_playlist:
		play_playlist()

# ------------------------------------------------------------------ PLAYLIST

## Start shuffling through the playlist. It keeps going until stop_playlist(),
## stop_music(), or you call change_music() yourself.
func play_playlist() -> void:
	if _playlist_names().is_empty():
		push_error("MusicManager: playlist is empty (no tracks to play)!")
		return
	playlist_active = true
	_bag.clear()
	_play_next()

## Stops auto-advancing AND fades the music out.
func stop_playlist(fade_out_time: float = 2.0) -> void:
	playlist_active = false
	stop_music(fade_out_time)

## Jump to the next random track right now.
func skip_track() -> void:
	if playlist_active:
		_play_next()

func _playlist_names() -> Array[String]:
	var names: Array[String] = []
	var source = playlist_tracks if not playlist_tracks.is_empty() else music_tracks
	for track in source:
		names.append(track.track_name.to_lower())
	return names

func _pick_next() -> String:
	var names = _playlist_names()
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0] # nothing to shuffle, it just loops
	
	if shuffle_bag:
		if _bag.is_empty():
			_bag = names.duplicate()
			_bag.shuffle()
			# Don't open a new round with the track that just played
			if _bag.back() == current_track_name:
				_bag.push_front(_bag.pop_back())
		return _bag.pop_back()
	
	var choice = names.pick_random()
	while choice == current_track_name:
		choice = names.pick_random()
	return choice

func _play_next() -> void:
	var next = _pick_next()
	if next == "":
		return
	current_track_name = "" # lets a one-track playlist replay itself
	_start_track(next, playlist_crossfade)

func _process(_delta: float) -> void:
	if not playlist_active or _next_queued or active_players.is_empty():
		return
	
	# Stem 0 is the clock for the whole track
	var p = active_players[0]
	if p.stream == null:
		return
	if not p.playing:
		_next_queued = true # it already finished (or got cut off) -> move on
		_play_next()
		return
	
	var length = p.stream.get_length()
	if length <= 0.0:
		return
	var remaining = length - p.get_playback_position()
	# Start the next track `playlist_crossfade` early so they overlap (capped for short tracks)
	if remaining <= min(playlist_crossfade, length * 0.5):
		_next_queued = true
		_play_next()

# ------------------------------------------------------------------ MANUAL CONTROL

# Call this to fade between songs (e.g., change_music("forest", 3.0))
# Manually changing music takes you OUT of playlist mode.
func change_music(track_name: String, crossfade_time: float = 2.0) -> void:
	playlist_active = false
	_start_track(track_name, crossfade_time)

func _start_track(track_name: String, crossfade_time: float) -> void:
	var safe_name = track_name.to_lower()
	
	if not track_db.has(safe_name):
		push_error("MusicManager: Track '" + track_name + "' not found!")
		return
	if current_track_name == safe_name:
		return # Already playing this track!
		
	current_track_name = safe_name
	_next_queued = false
	var new_track: MusicTrack = track_db[safe_name]
	
	# 1. Move current players to the chopping block
	var fading_players = active_players.duplicate()
	active_players.clear()
	
	var tween = create_tween()
	
	# 2. Fade out the old track and delete the players when done
	for player in fading_players:
		tween.parallel().tween_property(player, "volume_db", -80.0, crossfade_time)
	tween.tween_callback(func(): _cleanup_players(fading_players))
	
	# 3. Spin up new players for the new track's stems
	for i in range(new_track.stems.size()):
		var player = AudioStreamPlayer.new()
		player.stream = new_track.stems[i]
		player.volume_db = -80.0 # Start completely silent
		player.bus = "Music" # IMPORTANT: Routes to your Master/Music audio bus!
		
		add_child(player)
		player.play()
		active_players.append(player)
		
		# Figure out how loud this specific layer should be based on current intensity
		var target_vol = _get_layer_volume(i, new_track.stems.size(), current_intensity)
		tween.parallel().tween_property(player, "volume_db", target_vol, crossfade_time)
	
	track_changed.emit(safe_name)

# Call this to raise/lower the music tension (e.g., set_intensity(0.8))
func set_intensity(new_intensity: float, fade_time: float = 1.0) -> void:
	current_intensity = clamp(new_intensity, 0.0, 1.0)
	
	var tween = create_tween()
	for i in range(active_players.size()):
		var target_vol = _get_layer_volume(i, active_players.size(), current_intensity)
		tween.parallel().tween_property(active_players[i], "volume_db", target_vol, fade_time)

#Allows singular tracks to work perfectly alongside 5-layer tracks
func _get_layer_volume(index: int, total_layers: int, intensity: float) -> float:
	#Singular tracks OR the Base Layer (Index 0) always play at max volume
	if total_layers == 1 or index == 0:
		return 0.0 
		
	#Slice the intensity pie. If we have 3 layers, layer 1 fades in at 0.5, layer 2 at 1.0
	var slice = 1.0 / float(total_layers - 1)
	var start_fade = slice * (index - 1)
	var full_volume = slice * index
	
	#Calculate a 0.0 to 1.0 weight for this specific layer
	var weight = clamp((intensity - start_fade) / (full_volume - start_fade), 0.0, 1.0)
	
	if weight <= 0.01:
		return -80.0
	return linear_to_db(weight)

func _cleanup_players(players_to_kill: Array[AudioStreamPlayer]) -> void:
	for p in players_to_kill:
		p.queue_free()

func stop_music(fade_out_time: float = 2.0) -> void:
	playlist_active = false
	if active_players.is_empty():
		return # Nothing is playing so do nothing
		
	#Move all currently playing stems to the chopping block
	var fading_players = active_players.duplicate()
	
	#Clear the active list and reset the track name so it can be played again later
	active_players.clear()
	current_track_name = ""
	
	#Fade them all to silence smoothly
	var tween = create_tween()
	for player in fading_players:
		tween.parallel().tween_property(player, "volume_db", -80.0, fade_out_time)
		
	#Delete the audio nodes once the fade-out is complete
	tween.tween_callback(func(): _cleanup_players(fading_players))
