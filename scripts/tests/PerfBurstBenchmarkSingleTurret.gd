extends "res://scripts/tests/PerfBurstBenchmark.gd"

func _benchmark_label() -> String:
	return "PerfBurstBenchmarkSingleTurret"

func _benchmark_version() -> String:
	return "2.1.4-single-turret"

func _json_report_path() -> String:
	return "user://test_reports/perf_burst_benchmark_single_turret.json"

func _csv_report_path() -> String:
	return "user://test_reports/perf_burst_benchmark_single_turret.csv"

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
			"case_name": "dominant_faction_60_mid",
			"grid_size": 60,
			"quality_name": GameConfig.QUALITY_MEDIUM,
			"turret_ids": [GameConfig.Faction.YELLOW],
			"pending_values": [1024, 2048],
			"dominant_faction": GameConfig.Faction.YELLOW,
			"dominant_ratio": 0.82,
		},
	]
