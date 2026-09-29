class_name SlowCycleLogger
extends Node

## SlowCycleLogger — Full-Spectrum Diagnostic Logger (Sprint 6 v4)
## Ring-buffer logger (5000 entries) with tagged channels and persistent flush.
## Callable both as an Autoload singleton and via static helper methods.

enum Channel {
	WORLD,
	GRAMMAR,
	GEOM,
	FORK,
	TERRAIN,
	BIKE
}

const CHANNEL_NAMES: Dictionary = {
	Channel.WORLD: "WORLD",
	Channel.GRAMMAR: "GRAMMAR",
	Channel.GEOM: "GEOM",
	Channel.FORK: "FORK",
	Channel.TERRAIN: "TERRAIN",
	Channel.BIKE: "BIKE"
}

const MAX_BUFFER_LINES: int = 5000
const LOG_FILE_PATH: String = "user://slow_cycle_diagnostics.log"
const AUTO_FLUSH_INTERVAL: float = 2.0 # seconds

static var _buffer: Array[String] = []
static var _buffer_head: int = 0
static var _is_full: bool = false
static var _total_logged: int = 0
static var _enabled: bool = true
static var _print_to_console: bool = false

var _time_since_flush: float = 0.0

func _ready() -> void:
	# Clean start of session log
	_log_raw("WORLD", "=== Slow Cycle Diagnostic Session Started [%s] ===" % Time.get_datetime_string_from_system())

func _process(delta: float) -> void:
	_time_since_flush += delta
	if _time_since_flush >= AUTO_FLUSH_INTERVAL:
		_time_since_flush = 0.0
		flush()

## Static logging endpoints for low overhead and universal script access
static func log_world(message: String) -> void:
	_log_raw("WORLD", message)

static func log_grammar(message: String) -> void:
	_log_raw("GRAMMAR", message)

static func log_geom(message: String) -> void:
	_log_raw("GEOM", message)

static func log_fork(message: String) -> void:
	_log_raw("FORK", message)

static func log_terrain(message: String) -> void:
	_log_raw("TERRAIN", message)

static func log_bike(message: String) -> void:
	_log_raw("BIKE", message)

static func log_channel(channel: Channel, message: String) -> void:
	var ch_name: String = CHANNEL_NAMES.get(channel, "DIAG")
	_log_raw(ch_name, message)

static func _log_raw(channel_str: String, message: String) -> void:
	if not _enabled:
		return
	var timestamp: String = Time.get_time_string_from_system()
	var formatted_line: String = "[%s] [%s] %s" % [timestamp, channel_str, message]

	if _print_to_console:
		print(formatted_line)

	if _buffer.size() < MAX_BUFFER_LINES:
		_buffer.append(formatted_line)
	else:
		_buffer[_buffer_head] = formatted_line
		_is_full = true

	_buffer_head = (_buffer_head + 1) % MAX_BUFFER_LINES
	_total_logged += 1

static func get_recent_lines(count: int = 100) -> Array[String]:
	var result: Array[String] = []
	var total_available: int = _buffer.size()
	if total_available == 0:
		return result
	
	var actual_count: int = mini(count, total_available)
	if not _is_full:
		var start: int = maxi(0, total_available - actual_count)
		for i in range(start, total_available):
			result.append(_buffer[i])
	else:
		var start_idx: int = (_buffer_head - actual_count + MAX_BUFFER_LINES) % MAX_BUFFER_LINES
		for i in range(actual_count):
			var idx: int = (start_idx + i) % MAX_BUFFER_LINES
			result.append(_buffer[idx])
	return result

static func flush() -> void:
	if _buffer.is_empty():
		return
	var file := FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if not file:
		return
	
	if not _is_full:
		for line in _buffer:
			file.store_line(line)
	else:
		for i in range(MAX_BUFFER_LINES):
			var idx: int = (_buffer_head + i) % MAX_BUFFER_LINES
			file.store_line(_buffer[idx])
	file.close()

static func clear() -> void:
	_buffer.clear()
	_buffer_head = 0
	_is_full = false
	_total_logged = 0

static func set_console_echo(echo: bool) -> void:
	_print_to_console = echo
