extends Node

const FAST_PERIOD: int = 1800
const REAL_PERIOD: int = 86400
var api: RefCounted
var running: bool = false
var sync_local_time: bool = true
var period: int = REAL_PERIOD
var anchor_phase: float = 0.375
var anchor_msec: int = 0

func reset() -> void:
	running = false
	sync_local_time = true
	period = REAL_PERIOD
	anchor_phase = 0.375
	anchor_msec = Time.get_ticks_msec()

func start() -> void:
	if not api.is_host(): return
	if not running:
		sync_local_time = api.host_option("sync_local_time")
		period = REAL_PERIOD if sync_local_time else FAST_PERIOD
		anchor_phase = local_phase() if period == REAL_PERIOD else 0.375
		anchor_msec = Time.get_ticks_msec()
		running = true
	api.publish_session_state(snapshot())

static func local_phase() -> float:
	var clock: Dictionary = Time.get_datetime_dict_from_system()
	return (clock.hour * 3600 + clock.minute * 60 + clock.second) / float(REAL_PERIOD)

func phase() -> float:
	if running and api.is_host() and period == REAL_PERIOD:
		return local_phase()
	return phase_at(Time.get_ticks_msec())

func phase_at(now_msec: int) -> float:
	return fposmod(anchor_phase + maxf(0.0, (now_msec - anchor_msec) / 1000.0) / period, 1.0) if running else anchor_phase

func snapshot() -> Dictionary:
	return {"phase": phase(), "period": period} if running else {}

func receive(data: Dictionary) -> void:
	if api.is_host(): return
	if not data.get("phase") is float or not is_finite(data.phase) or data.phase < 0.0 or data.phase >= 1.0: return
	if not data.get("period") is int or data.period not in [FAST_PERIOD, REAL_PERIOD]: return
	anchor_phase = data.phase
	anchor_msec = Time.get_ticks_msec()
	period = data.period
	running = true
