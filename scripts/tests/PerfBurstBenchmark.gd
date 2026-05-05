extends SceneTree

const WARMUP_SECONDS: float = 2.0
const DISCARD_SECONDS: float = 0.5
const MEASURED_SECONDS: float = 10.0
const REPEATS_PER_GROUP: int = 3
const JSON_REPORT_PATH: String = "user://test_reports/perf_burst_benchmark.json"
const CSV_REPORT_PATH: String = "user://test_reports/perf_burst_benchmark.csv"

const FORWARD_ORDER: String = "forward"
const REVERSE_ORDER: String = "reverse"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[PerfBurstBenchmark] Starting benchmark v2.0.2")

	var report: Dictionary = {
		"version": "2.0.2",
		"engine": Engine.get_version_info(),
		"warmup_seconds": WARMUP_SECONDS,
		"discard_seconds": DISCARD_SECONDS,
		"measured_seconds": MEASURED_SECONDS,
		"repeats_per_group": REPEATS_PER_GROUP,
		"raw_runs": [],
		"summaries": [],
	}

	var all_summaries: Array = []
	for case_def in _build_case_defs():
		for order_name in [FORWARD_ORDER, REVERSE_ORDER]:
			var pending_values: Array = _ordered_pending_values(case_def, order_name)
			for pending_per_turret in pending_values:
				var group_runs: Array = []
				for repeat_index in range(REPEATS_PER_GROUP):
					var run_metrics: Dictionary = await _run_single_case(case_def, int(pending_per_turret), order_name, repeat_index + 1)
					report["raw_runs"].append(run_metrics)
					group_runs.append(run_metrics)
				var summary: Dictionary = _summarize_group(case_def, order_name, int(pending_per_turret), group_runs)
				report["summaries"].append(summary)
				all_summaries.append(summary)
				_print_summary_line(summary)

	_write_json_report(report)
	_write_csv_report(all_summaries)
	print("[PerfBurstBenchmark] JSON report: %s" % JSON_REPORT_PATH)
	print("[PerfBurstBenchmark] CSV report: %s" % CSV_REPORT_PATH)
	quit(0)

func _build_case_defs() -> Array:
	return [
		{
			"case_name": "baseline_40_mid_single",
			"grid_size": 40,
			"quality_name": GameConfig.QUALITY_MEDIUM,
			"turret_ids": [GameConfig.Faction.BLUE],
			"pending_values": [512, 1024, 2048],
		},
		{
			"case_name": "stress_60_mid_single",
			"grid_size": 60,
			"quality_name": GameConfig.QUALITY_MEDIUM,
			"turret_ids": [GameConfig.Faction.BLUE],
			"pending_values": [512, 1024, 2048],
		},
		{
			"case_name": "stress_60_high_single",
			"grid_size": 60,
			"quality_name": GameConfig.QUALITY_HIGH,
			"turret_ids": [GameConfig.Faction.BLUE],
			"pending_values": [512, 1024, 2048],
		},
		{
			"case_name": "stress_60_mid_four_turrets",
			"grid_size": 60,
			"quality_name": GameConfig.QUALITY_MEDIUM,
			"turret_ids": [
				GameConfig.Faction.BLUE,
				GameConfig.Faction.RED,
				GameConfig.Faction.GREEN,
				GameConfig.Faction.YELLOW,
			],
			"pending_values": [512, 1024],
		},
		{
			"case_name": "stress_60_high_four_turrets",
			"grid_size": 60,
			"quality_name": GameConfig.QUALITY_HIGH,
			"turret_ids": [
				GameConfig.Faction.BLUE,
				GameConfig.Faction.RED,
				GameConfig.Faction.GREEN,
				GameConfig.Faction.YELLOW,
			],
			"pending_values": [512, 1024],
		},
		{
			"case_name": "dominant_faction_60_mid",
			"grid_size": 60,
			"quality_name": GameConfig.QUALITY_MEDIUM,
			"turret_ids": [GameConfig.Faction.YELLOW],
			"pending_values": [1024, 2048],
			"dominant_faction": GameConfig.Faction.YELLOW,
			"dominant_ratio": 0.82,
		},
	]

func _ordered_pending_values(case_def: Dictionary, order_name: String) -> Array:
	var values: Array = (case_def.get("pending_values", []) as Array).duplicate()
	if order_name == REVERSE_ORDER:
		values.reverse()
	return values

func _run_single_case(case_def: Dictionary, pending_per_turret: int, order_name: String, repeat_index: int) -> Dictionary:
	var case_name: String = str(case_def.get("case_name", "unknown"))
	var grid_size: int = int(case_def.get("grid_size", 40))
	var quality_name: String = str(case_def.get("quality_name", GameConfig.QUALITY_MEDIUM))
	var turret_ids: Array = case_def.get("turret_ids", [])
	var dominant_faction: int = int(case_def.get("dominant_faction", -1))
	var dominant_ratio: float = float(case_def.get("dominant_ratio", 0.0))

	GameConfig.set_quality_by_name(quality_name)
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)

	var bench_root: Node2D = Node2D.new()
	bench_root.name = "PerfBenchRoot"
	root.add_child(bench_root)

	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(grid_size)
	bench_root.add_child(battlefield)

	var trail_layer: BulletTrailLayer = BulletTrailLayer.new()
	bench_root.add_child(trail_layer)

	var bullet_pool: BulletPool = BulletPool.new()
	bench_root.add_child(bullet_pool)
	bullet_pool.set_trail_layer(trail_layer)

	var turrets: Dictionary = _create_benchmark_turrets(bench_root, battlefield, bullet_pool)
	if bullet_pool.has_method("set_tracked_turrets"):
		bullet_pool.set_tracked_turrets(turrets)

	await process_frame
	await process_frame

	if dominant_faction >= 0 and dominant_ratio > 0.0:
		_apply_dominant_faction_setup(battlefield, dominant_faction, dominant_ratio)
		await process_frame

	var active_turrets: Array = []
	for turret_id in turret_ids:
		var turret = turrets.get(int(turret_id), null)
		if turret != null and is_instance_valid(turret):
			active_turrets.append(turret)
			turret.fire_burst(pending_per_turret)

	var total_seconds: float = WARMUP_SECONDS + DISCARD_SECONDS + MEASURED_SECONDS
	var benchmark_start_usec: int = Time.get_ticks_usec()
	var frame_ms_samples: Array[float] = []
	var fps_sum: float = 0.0
	var fps_samples: int = 0
	var min_fps: int = 999999
	var active_bullets_peak: int = 0
	var active_bullets_sum: float = 0.0
	var queue_peak: int = 0
	var queue_sum: float = 0.0
	var trail_peak: int = 0
	var trail_sum: float = 0.0
	var metrics_samples: int = 0
	var spawn_sum: float = 0.0
	var capture_sum: float = 0.0
	var battlefield_redraw_sum: float = 0.0
	var trail_redraw_sum: float = 0.0
	var recycled_sum: float = 0.0
	var expired_sum: float = 0.0
	var stutter_under_30: int = 0
	var stutter_under_15: int = 0
	var max_trail_pressure_severity: int = 0
	var degrade_reason_counts: Dictionary = {}
	var draw_calls_sum: float = 0.0
	var draw_calls_peak: int = -1
	var canvas_items_sum: float = 0.0
	var canvas_items_peak: int = -1
	var trail_budget_enabled: bool = false

	while float(Time.get_ticks_usec() - benchmark_start_usec) / 1000000.0 < total_seconds:
		await process_frame
		var elapsed: float = float(Time.get_ticks_usec() - benchmark_start_usec) / 1000000.0

		for turret in active_turrets:
			if turret != null and is_instance_valid(turret) and not turret.is_destroyed and turret.burst_remaining <= 0:
				turret.fire_burst(pending_per_turret)

		if elapsed <= WARMUP_SECONDS + DISCARD_SECONDS:
			continue

		var delta: float = maxf(get_root().get_process_delta_time(), 0.000001)
		var frame_ms: float = delta * 1000.0
		frame_ms_samples.append(frame_ms)

		var fps: int = floori(Engine.get_frames_per_second())
		if fps > 0:
			fps_sum += float(fps)
			fps_samples += 1
			min_fps = mini(min_fps, fps)

		if delta > (1.0 / 30.0):
			stutter_under_30 += 1
		if delta > (1.0 / 15.0):
			stutter_under_15 += 1

		var active_count: int = bullet_pool.get_active_count()
		var queue_total: int = _sum_turret_queue(turrets)
		var bullet_metrics: Dictionary = bullet_pool.get_debug_metrics() if bullet_pool.has_method("get_debug_metrics") else {}
		var battlefield_metrics: Dictionary = battlefield.get_debug_metrics() if battlefield.has_method("get_debug_metrics") else {}
		var trail_metrics: Dictionary = trail_layer.get_debug_metrics() if trail_layer.has_method("get_debug_metrics") else {}
		var trail_segments: int = int(bullet_metrics.get("trail_segments_estimate", 0))
		var trail_budget_active: bool = bool(bullet_metrics.get("trail_budget_active", true))
		var trail_pressure_severity: int = int(bullet_metrics.get("trail_pressure_severity", 0))
		var trail_degrade_reason: String = str(bullet_metrics.get("trail_degrade_reason", "none"))
		var draw_calls: int = int(bullet_metrics.get("draw_calls", -1))
		var visible_canvas_items_estimate: int = int(bullet_metrics.get("visible_canvas_items_estimate", -1))

		active_bullets_peak = maxi(active_bullets_peak, active_count)
		queue_peak = maxi(queue_peak, queue_total)
		trail_peak = maxi(trail_peak, trail_segments)
		max_trail_pressure_severity = maxi(max_trail_pressure_severity, trail_pressure_severity)
		degrade_reason_counts[trail_degrade_reason] = int(degrade_reason_counts.get(trail_degrade_reason, 0)) + 1
		trail_budget_enabled = trail_budget_enabled or trail_budget_active
		if draw_calls >= 0:
			draw_calls_sum += float(draw_calls)
			draw_calls_peak = maxi(draw_calls_peak, draw_calls)
		if visible_canvas_items_estimate >= 0:
			canvas_items_sum += float(visible_canvas_items_estimate)
			canvas_items_peak = maxi(canvas_items_peak, visible_canvas_items_estimate)

		active_bullets_sum += float(active_count)
		queue_sum += float(queue_total)
		trail_sum += float(trail_segments)
		spawn_sum += float(bullet_metrics.get("spawned_bullets_per_second", 0.0))
		capture_sum += float(battlefield_metrics.get("cell_changes_per_second", 0))
		battlefield_redraw_sum += float(battlefield_metrics.get("redraw_calls_per_second", 0))
		trail_redraw_sum += float(trail_metrics.get("redraw_calls_per_second", 0))
		recycled_sum += float(bullet_metrics.get("recycled_bullets_per_second", 0.0))
		expired_sum += float(bullet_metrics.get("expired_bullets_per_second", 0.0))
		metrics_samples += 1

	var run_metrics: Dictionary = {
		"case_name": case_name,
		"grid_size": grid_size,
		"quality": quality_name,
		"turret_count": active_turrets.size(),
		"pending_per_turret": pending_per_turret,
		"total_pending_start": pending_per_turret * active_turrets.size(),
		"order_name": order_name,
		"repeat_index": repeat_index,
		"warmup_seconds": WARMUP_SECONDS,
		"measured_seconds": MEASURED_SECONDS,
		"avg_fps": (fps_sum / float(fps_samples)) if fps_samples > 0 else 0.0,
		"min_fps": 0 if min_fps == 999999 else min_fps,
		"p95_frame_ms": _percentile(frame_ms_samples, 0.95),
		"p99_frame_ms": _percentile(frame_ms_samples, 0.99),
		"stutter_frames_under_30fps": stutter_under_30,
		"stutter_frames_under_15fps": stutter_under_15,
		"active_bullets_peak": active_bullets_peak,
		"active_bullets_avg": _safe_average(active_bullets_sum, metrics_samples),
		"queue_peak": queue_peak,
		"queue_avg": _safe_average(queue_sum, metrics_samples),
		"spawn_per_second": _safe_average(spawn_sum, metrics_samples),
		"capture_per_second": _safe_average(capture_sum, metrics_samples),
		"trail_segments_peak": trail_peak,
		"trail_segments_avg": _safe_average(trail_sum, metrics_samples),
		"battlefield_redraws_per_second": _safe_average(battlefield_redraw_sum, metrics_samples),
		"trail_layer_redraws_per_second": _safe_average(trail_redraw_sum, metrics_samples),
		"bullets_recycled_per_second": _safe_average(recycled_sum, metrics_samples),
		"bullets_expired_per_second": _safe_average(expired_sum, metrics_samples),
		"trail_pressure_level": _severity_to_level(max_trail_pressure_severity),
		"trail_budget_active": trail_budget_enabled,
		"trail_degrade_reason": _pick_top_reason(degrade_reason_counts),
		"draw_calls": _safe_average(draw_calls_sum, metrics_samples) if draw_calls_peak >= 0 else -1.0,
		"visible_canvas_items_estimate": _safe_average(canvas_items_sum, metrics_samples) if canvas_items_peak >= 0 else -1.0,
	}

	_cleanup_benchmark_root(bench_root)
	await process_frame
	await process_frame

	return run_metrics

func _create_benchmark_turrets(parent: Node, battlefield: Battlefield, bullet_pool: BulletPool) -> Dictionary:
	var size: float = float(battlefield.grid_size * battlefield.cell_size)
	var map_origin: Vector2 = battlefield.global_position
	var turret_positions: Dictionary = {
		GameConfig.Faction.BLUE: map_origin + Vector2(-22.0, -22.0),
		GameConfig.Faction.RED: map_origin + Vector2(size + 22.0, -22.0),
		GameConfig.Faction.GREEN: map_origin + Vector2(-22.0, size + 22.0),
		GameConfig.Faction.YELLOW: map_origin + Vector2(size + 22.0, size + 22.0),
	}
	var result: Dictionary = {}
	for faction_id in turret_positions.keys():
		var turret: Turret = Turret.new()
		parent.add_child(turret)
		turret.setup(int(faction_id), turret_positions[faction_id], battlefield, bullet_pool)
		result[int(faction_id)] = turret
	for faction_id in result.keys():
		var turret: Turret = result[faction_id]
		turret.set_all_turrets(result)
	return result

func _apply_dominant_faction_setup(battlefield: Battlefield, dominant_faction: int, dominant_ratio: float) -> void:
	var total_cells: int = battlefield.grid_size * battlefield.grid_size
	var dominant_cells_target: int = int(round(float(total_cells) * dominant_ratio))
	var assigned: int = 0
	for y in range(battlefield.grid_size):
		for x in range(battlefield.grid_size):
			if assigned < dominant_cells_target:
				battlefield.owners[x][y] = dominant_faction
				assigned += 1
			else:
				var fallback_faction: int = GameConfig.Faction.BLUE
				if fallback_faction == dominant_faction:
					fallback_faction = GameConfig.Faction.RED
				battlefield.owners[x][y] = fallback_faction
	battlefield.rebuild_owner_counts()
	battlefield.flush_visual_update()
	battlefield.flush_score_emit()

func _summarize_group(case_def: Dictionary, order_name: String, pending_per_turret: int, group_runs: Array) -> Dictionary:
	var avg_fps_values: Array[float] = []
	var min_fps_values: Array[int] = []
	var p95_values: Array[float] = []
	var p99_values: Array[float] = []
	var stutter30_values: Array[int] = []
	var stutter15_values: Array[int] = []
	var active_peak_values: Array[int] = []
	var active_avg_values: Array[float] = []
	var queue_peak_values: Array[int] = []
	var queue_avg_values: Array[float] = []
	var spawn_values: Array[float] = []
	var capture_values: Array[float] = []
	var trail_peak_values: Array[int] = []
	var trail_avg_values: Array[float] = []
	var battlefield_redraw_values: Array[float] = []
	var trail_redraw_values: Array[float] = []
	var recycled_values: Array[float] = []
	var expired_values: Array[float] = []
	var trail_budget_values: Array = []
	var max_pressure_severity: int = 0
	var degrade_reason_counts: Dictionary = {}
	var draw_call_values: Array[float] = []
	var canvas_item_values: Array[float] = []

	for run_metrics in group_runs:
		avg_fps_values.append(float(run_metrics.get("avg_fps", 0.0)))
		min_fps_values.append(int(run_metrics.get("min_fps", 0)))
		p95_values.append(float(run_metrics.get("p95_frame_ms", 0.0)))
		p99_values.append(float(run_metrics.get("p99_frame_ms", 0.0)))
		stutter30_values.append(int(run_metrics.get("stutter_frames_under_30fps", 0)))
		stutter15_values.append(int(run_metrics.get("stutter_frames_under_15fps", 0)))
		active_peak_values.append(int(run_metrics.get("active_bullets_peak", 0)))
		active_avg_values.append(float(run_metrics.get("active_bullets_avg", 0.0)))
		queue_peak_values.append(int(run_metrics.get("queue_peak", 0)))
		queue_avg_values.append(float(run_metrics.get("queue_avg", 0.0)))
		spawn_values.append(float(run_metrics.get("spawn_per_second", 0.0)))
		capture_values.append(float(run_metrics.get("capture_per_second", 0.0)))
		trail_peak_values.append(int(run_metrics.get("trail_segments_peak", 0)))
		trail_avg_values.append(float(run_metrics.get("trail_segments_avg", 0.0)))
		battlefield_redraw_values.append(float(run_metrics.get("battlefield_redraws_per_second", 0.0)))
		trail_redraw_values.append(float(run_metrics.get("trail_layer_redraws_per_second", 0.0)))
		recycled_values.append(float(run_metrics.get("bullets_recycled_per_second", 0.0)))
		expired_values.append(float(run_metrics.get("bullets_expired_per_second", 0.0)))
		trail_budget_values.append(bool(run_metrics.get("trail_budget_active", false)))
		max_pressure_severity = maxi(max_pressure_severity, _level_to_severity(str(run_metrics.get("trail_pressure_level", "none"))))
		var reason: String = str(run_metrics.get("trail_degrade_reason", "none"))
		degrade_reason_counts[reason] = int(degrade_reason_counts.get(reason, 0)) + 1
		var draw_calls: float = float(run_metrics.get("draw_calls", -1.0))
		if draw_calls >= 0.0:
			draw_call_values.append(draw_calls)
		var canvas_items: float = float(run_metrics.get("visible_canvas_items_estimate", -1.0))
		if canvas_items >= 0.0:
			canvas_item_values.append(canvas_items)

	return {
		"case_name": str(case_def.get("case_name", "unknown")),
		"grid_size": int(case_def.get("grid_size", 40)),
		"quality": str(case_def.get("quality_name", GameConfig.QUALITY_MEDIUM)),
		"turret_count": (case_def.get("turret_ids", []) as Array).size(),
		"pending_per_turret": pending_per_turret,
		"total_pending_start": pending_per_turret * (case_def.get("turret_ids", []) as Array).size(),
		"order_name": order_name,
		"warmup_seconds": WARMUP_SECONDS,
		"measured_seconds": MEASURED_SECONDS,
		"repeat_count": group_runs.size(),
		"avg_fps_mean": _array_mean(avg_fps_values),
		"avg_fps_min": _array_min_float(avg_fps_values),
		"min_fps_min": _array_min_int(min_fps_values),
		"p95_frame_ms": _array_mean(p95_values),
		"p99_frame_ms": _array_mean(p99_values),
		"stutter_frames_under_30fps": _array_mean(stutter30_values),
		"stutter_frames_under_15fps": _array_mean(stutter15_values),
		"active_bullets_peak": _array_max_int(active_peak_values),
		"active_bullets_avg": _array_mean(active_avg_values),
		"queue_peak": _array_max_int(queue_peak_values),
		"queue_avg": _array_mean(queue_avg_values),
		"spawn_per_second": _array_mean(spawn_values),
		"capture_per_second": _array_mean(capture_values),
		"trail_segments_peak": _array_max_int(trail_peak_values),
		"trail_segments_avg": _array_mean(trail_avg_values),
		"battlefield_redraws_per_second": _array_mean(battlefield_redraw_values),
		"trail_layer_redraws_per_second": _array_mean(trail_redraw_values),
		"bullets_recycled_per_second": _array_mean(recycled_values),
		"bullets_expired_per_second": _array_mean(expired_values),
		"trail_pressure_level": _severity_to_level(max_pressure_severity),
		"trail_budget_active": _any_true(trail_budget_values),
		"trail_degrade_reason": _pick_top_reason(degrade_reason_counts),
		"draw_calls": _array_mean(draw_call_values) if not draw_call_values.is_empty() else -1.0,
		"visible_canvas_items_estimate": _array_mean(canvas_item_values) if not canvas_item_values.is_empty() else -1.0,
	}

func _print_summary_line(summary: Dictionary) -> void:
	print(
		"[Perf] %s | order=%s | pending=%dx%d | avg=%.2f | min=%d | p95=%.1fms | active=%d | queue=%d | trail=%d | draw=%.0f | canvas=%.0f | pressure=%s | budget=%s | reason=%s | spawn/s=%.1f"
		% [
			str(summary.get("case_name", "unknown")),
			str(summary.get("order_name", FORWARD_ORDER)),
			int(summary.get("pending_per_turret", 0)),
			int(summary.get("turret_count", 0)),
			float(summary.get("avg_fps_mean", 0.0)),
			int(summary.get("min_fps_min", 0)),
			float(summary.get("p95_frame_ms", 0.0)),
			int(summary.get("active_bullets_peak", 0)),
			int(summary.get("queue_peak", 0)),
			int(summary.get("trail_segments_peak", 0)),
			float(summary.get("draw_calls", -1.0)),
			float(summary.get("visible_canvas_items_estimate", -1.0)),
			str(summary.get("trail_pressure_level", "none")),
			"on" if bool(summary.get("trail_budget_active", false)) else "off",
			str(summary.get("trail_degrade_reason", "none")),
			float(summary.get("spawn_per_second", 0.0)),
		]
	)

func _write_json_report(report: Dictionary) -> void:
	var report_dir: String = ProjectSettings.globalize_path("user://test_reports")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var file: FileAccess = FileAccess.open(JSON_REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[PerfBurstBenchmark] Failed to open JSON report path: %s" % JSON_REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()

func _write_csv_report(summaries: Array) -> void:
	var lines: Array[String] = []
	var headers: Array[String] = [
		"case_name",
		"grid_size",
		"quality",
		"turret_count",
		"pending_per_turret",
		"total_pending_start",
		"order_name",
		"warmup_seconds",
		"measured_seconds",
		"repeat_count",
		"avg_fps_mean",
		"avg_fps_min",
		"min_fps_min",
		"p95_frame_ms",
		"p99_frame_ms",
		"stutter_frames_under_30fps",
		"stutter_frames_under_15fps",
		"active_bullets_peak",
		"active_bullets_avg",
		"queue_peak",
		"queue_avg",
		"spawn_per_second",
		"capture_per_second",
		"trail_segments_peak",
		"trail_segments_avg",
		"battlefield_redraws_per_second",
		"trail_layer_redraws_per_second",
		"bullets_recycled_per_second",
		"bullets_expired_per_second",
		"draw_calls",
		"visible_canvas_items_estimate",
		"trail_pressure_level",
		"trail_budget_active",
		"trail_degrade_reason",
	]
	lines.append(",".join(headers))
	for summary in summaries:
		var row: Array[String] = []
		for header in headers:
			row.append(_csv_escape(str(summary.get(header, ""))))
		lines.append(",".join(row))

	var report_dir: String = ProjectSettings.globalize_path("user://test_reports")
	DirAccess.make_dir_recursive_absolute(report_dir)
	var file: FileAccess = FileAccess.open(CSV_REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[PerfBurstBenchmark] Failed to open CSV report path: %s" % CSV_REPORT_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()

func _csv_escape(value: String) -> String:
	if value.contains(",") or value.contains("\"") or value.contains("\n"):
		return "\"%s\"" % value.replace("\"", "\"\"")
	return value

func _cleanup_benchmark_root(bench_root: Node) -> void:
	if bench_root == null or not is_instance_valid(bench_root):
		return
	if bench_root.get_parent() != null:
		bench_root.queue_free()
	else:
		bench_root.free()

func _safe_average(total: float, count: int) -> float:
	if count <= 0:
		return 0.0
	return total / float(count)

func _sum_turret_queue(turrets: Dictionary) -> int:
	var total: int = 0
	for turret in turrets.values():
		if turret != null and is_instance_valid(turret):
			total += int(turret.burst_remaining)
	return total

func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var idx: int = clampi(int(ceil(float(sorted_values.size()) * ratio)) - 1, 0, sorted_values.size() - 1)
	return sorted_values[idx]

func _array_mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())

func _array_min_float(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var current: float = values[0]
	for value in values:
		current = minf(current, value)
	return current

func _array_min_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var current: int = values[0]
	for value in values:
		current = mini(current, value)
	return current

func _array_max_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var current: int = values[0]
	for value in values:
		current = maxi(current, value)
	return current

func _pick_top_reason(reason_counts: Dictionary) -> String:
	var best_reason: String = "none"
	var best_count: int = -1
	for reason in reason_counts.keys():
		var count: int = int(reason_counts[reason])
		if count > best_count:
			best_reason = str(reason)
			best_count = count
		elif count == best_count and best_reason == "none":
			best_reason = str(reason)
	return best_reason

func _severity_to_level(severity: int) -> String:
	match severity:
		3:
			return "extreme"
		2:
			return "high"
		1:
			return "mid"
		_:
			return "none"

func _level_to_severity(level: String) -> int:
	match level:
		"extreme":
			return 3
		"high":
			return 2
		"mid":
			return 1
		_:
			return 0

func _any_true(values: Array) -> bool:
	for value in values:
		if bool(value):
			return true
	return false
